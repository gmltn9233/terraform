const https = require('https');
const url = require('url');

exports.handler = async (event) => {
    const message = JSON.parse(event.Records[0].Sns.Message);
    const deployId = message.deploymentId || 'N/A';
    const status = message.status || 'UNKNOWN';
    const appName = message.applicationName || 'CodeDeploy';
    const groupName = message.deploymentGroupName || 'N/A';

    const payload = JSON.stringify({
        text: `🚀 *${appName}* 배포 상태: *${status}*\n📦 배포 그룹: *${groupName}*\n🆔 배포 ID: \`${deployId}\``
    });

    const webhookUrl = process.env.SLACK_WEBHOOK_URL;
    const parsedUrl = url.parse(webhookUrl);

    const options = {
        hostname: parsedUrl.hostname,
        path: parsedUrl.path,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload)
        }
    };

    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            res.setEncoding('utf8');
            res.on('data', () => { });
            res.on('end', resolve);
        });

        req.on('error', reject);
        req.write(payload);
        req.end();
    });
};