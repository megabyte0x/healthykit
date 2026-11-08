import { sign } from 'node:crypto';

const appId = '6776575569';
const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const header = encode({ alg: 'ES256', kid: process.env.APP_STORE_CONNECT_API_KEY_ID, typ: 'JWT' });
const claims = encode({ iss: process.env.APP_STORE_CONNECT_API_ISSUER_ID, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' });
const message = `${header}.${claims}`;
const signature = sign('sha256', Buffer.from(message), {
    key: process.env.APP_STORE_CONNECT_API_PRIVATE_KEY.replace(/\\n/g, '\n'),
    dsaEncoding: 'ieee-p1363',
}).toString('base64url');
const token = `${message}.${signature}`;
process.stdout.write(`::add-mask::${token}\n`);

async function get(path, parameters = {}) {
    const url = new URL(`https://api.appstoreconnect.apple.com/v1/${path}`);
    url.search = new URLSearchParams(parameters).toString();
    const response = await fetch(url, {
        headers: { Authorization: `Bearer ${token}` },
        redirect: 'error', signal: AbortSignal.timeout(30000),
    });
    if (!response.ok) throw new Error(`App Store status request failed: HTTP ${response.status}`);
    return response.json();
}

const versions = await get(`apps/${appId}/appStoreVersions`, {
    limit: '10', 'fields[appStoreVersions]': 'versionString,appStoreState,releaseType',
});
const builds = await get('builds', {
    'filter[app]': appId, sort: '-uploadedDate', limit: '5',
    'fields[builds]': 'version,processingState,uploadedDate,expired,preReleaseVersion',
    include: 'preReleaseVersion', 'fields[preReleaseVersions]': 'version,platform',
});
console.log(JSON.stringify({
    versions: versions.data.map(({ id, attributes }) => ({ id, ...attributes })),
    builds: builds.data.map(({ id, attributes, relationships }) => ({
        id, ...attributes,
        appVersion: builds.included?.find(item => item.id === relationships.preReleaseVersion?.data?.id)?.attributes.version,
    })),
}, null, 2));
