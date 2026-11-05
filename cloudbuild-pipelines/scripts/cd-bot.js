#!/usr/bin/env node

/**
 * ==============================================================================
 * GitHub App CD Deployment Bot Publisher
 * Authenticates as GitHub App via JWT -> Posts Deployment Audit Report to PR
 * ==============================================================================
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const APP_ID = process.env.GITHUB_APP_ID;
const PRIVATE_KEY = process.env.GITHUB_APP_PRIVATE_KEY;
const REPO_OWNER = process.env.REPO_OWNER || process.argv[2];
const REPO_NAME = process.env.REPO_NAME || process.argv[3];
const DEPLOYMENT_SCOPE_FILE = process.env.DEPLOYMENT_SCOPE || process.argv[4] || 'deployment_scope.json';
const COMMIT_SHA = process.env.SHORT_SHA || 'latest';
const BUILD_ID = process.env.BUILD_ID || 'N/A';
const STATE_BUCKET = process.env.STATE_BUCKET || 'yuvaraj-internal-project-terraform-state';

if (!APP_ID || !PRIVATE_KEY) {
    console.error('❌ Error: GITHUB_APP_ID and GITHUB_APP_PRIVATE_KEY must be provided.');
    process.exit(1);
}

// 1. JWT Helpers
function base64UrlEncode(str) {
    return Buffer.from(str).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function generateAppJwt(appId, privateKeyPem) {
    const now = Math.floor(Date.now() / 1000);
    const header = { alg: 'RS256', typ: 'JWT' };
    const payload = { iat: now - 60, exp: now + (10 * 60), iss: appId };

    const encodedHeader = base64UrlEncode(JSON.stringify(header));
    const encodedPayload = base64UrlEncode(JSON.stringify(payload));
    const message = `${encodedHeader}.${encodedPayload}`;

    const signer = crypto.createSign('RSA-SHA256');
    signer.update(message);
    const signature = signer.sign(privateKeyPem, 'base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
    return `${message}.${signature}`;
}

async function githubRequest(url, method = 'GET', token = null, body = null) {
    const headers = {
        'User-Agent': 'CloudBuild-CD-Bot',
        'Accept': 'application/vnd.github.v3+json'
    };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const options = { method, headers };
    if (body) {
        headers['Content-Type'] = 'application/json';
        options.body = JSON.stringify(body);
    }

    const res = await fetch(url, options);
    if (!res.ok) {
        const errorText = await res.text();
        throw new Error(`GitHub API error (${res.status} ${res.statusText}): ${errorText}`);
    }
    return res.json();
}

async function main() {
    try {
        let scope = { environment: 'dev', pr_number: 'N/A', targets: [] };
        if (fs.existsSync(DEPLOYMENT_SCOPE_FILE)) {
            scope = JSON.parse(fs.readFileSync(DEPLOYMENT_SCOPE_FILE, 'utf8'));
        }

        const prNumber = scope.pr_number;
        if (!prNumber || prNumber === 'N/A') {
            console.log('ℹ️ No PR number associated with this deployment. Skipping PR audit comment.');
            process.exit(0);
        }

        console.log('🔑 Authenticating GitHub App for CD Audit...');
        const jwt = generateAppJwt(APP_ID, PRIVATE_KEY);

        const installation = await githubRequest(
            `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/installation`,
            'GET',
            jwt
        );

        const tokenData = await githubRequest(
            `https://api.github.com/app/installations/${installation.id}/access_tokens`,
            'POST',
            jwt
        );
        const token = tokenData.token;

        const envName = (scope.environment || 'dev').toUpperCase();
        const infraPath = scope.targets.map(t => t.name).join(' ➔ ') || 'network';
        const timestamp = new Date().toISOString();

        // Build Audit Markdown Comment
        let commentBody = `## 🚀 Terraform CD Deployment Audit Report\n\n`;
        commentBody += `| **Target Environment** | **Deployment Status** | **Applied Layers** | **Execution Trigger** |\n`;
        commentBody += `| :---: | :---: | :---: | :---: |\n`;
        commentBody += `| \`${envName}\` | 🟢 **DEPLOYMENT SUCCESSFUL** | \`${infraPath}\` | Push / Merge to \`main\` |\n\n`;
        commentBody += `---\n\n`;
        commentBody += `### 📦 Applied Infrastructure Layers\n\n`;

        for (const target of scope.targets) {
            const statePrefix = `${scope.environment}/${target.name}`;
            const outputFile = path.join(target.dir, 'outputs.json');

            commentBody += `#### 🔹 **${target.name.toUpperCase()}** (\`${statePrefix}\`)\n`;
            commentBody += `* **State Path**: \`gs://${STATE_BUCKET}/${statePrefix}/default.tfstate\`\n`;
            commentBody += `* **Status**: ✅ All resources successfully provisioned to Google Cloud.\n\n`;

            if (fs.existsSync(outputFile)) {
                try {
                    const outputs = JSON.parse(fs.readFileSync(outputFile, 'utf8'));
                    const outEntries = Object.entries(outputs);
                    if (outEntries.length > 0) {
                        commentBody += `<details open>\n<summary><b>Click to View Deployed Outputs (${outEntries.length} Outputs)</b></summary>\n\n`;
                        commentBody += `| Output Name | Value |\n| :--- | :--- |\n`;
                        for (const [key, obj] of outEntries) {
                            const valStr = typeof obj.value === 'object' ? JSON.stringify(obj.value) : String(obj.value);
                            commentBody += `| \`${key}\` | \`${valStr}\` |\n`;
                        }
                        commentBody += `\n</details>\n\n`;
                    }
                } catch (e) {
                    // ignore output parse errors
                }
            }
        }

        commentBody += `---\n\n`;
        commentBody += `### 📋 Audit & Provenance Metadata\n`;
        commentBody += `* **Merged PR**: \`#${prNumber}\`\n`;
        commentBody += `* **Commit SHA**: \`${COMMIT_SHA}\`\n`;
        commentBody += `* **Cloud Build ID**: \`${BUILD_ID}\`\n`;
        commentBody += `* **Deployment Timestamp**: \`${timestamp}\`\n`;

        console.log(`💬 Posting Deployment Audit comment on PR #${prNumber}...`);
        await githubRequest(
            `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues/${prNumber}/comments`,
            'POST',
            token,
            { body: commentBody }
        );
        console.log('✅ Deployment Audit Comment successfully posted to PR!');

    } catch (err) {
        console.error('❌ Error executing cd-bot.js:', err.message);
        process.exit(1);
    }
}

main();