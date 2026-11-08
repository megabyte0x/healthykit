import { sign } from 'node:crypto';

export const appId = '6776575569';

export function appStoreAPI(env = process.env) {
    const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
    const now = Math.floor(Date.now() / 1000);
    const message = `${encode({ alg: 'ES256', kid: env.APP_STORE_CONNECT_API_KEY_ID, typ: 'JWT' })}.${encode({
        iss: env.APP_STORE_CONNECT_API_ISSUER_ID, iat: now, exp: now + 600, aud: 'appstoreconnect-v1',
    })}`;
    const signature = sign('sha256', Buffer.from(message), {
        key: env.APP_STORE_CONNECT_API_PRIVATE_KEY.replace(/\\n/g, '\n'), dsaEncoding: 'ieee-p1363',
    }).toString('base64url');
    const token = `${message}.${signature}`;
    if (env.GITHUB_ACTIONS === 'true') process.stdout.write(`::add-mask::${token}\n`);
    return async (path, { query = {}, method = 'GET', data } = {}) => {
        if (!/^[a-zA-Z0-9_/-]+$/.test(path) || !['GET', 'POST', 'PATCH'].includes(method)) throw new Error('Unsupported App Store API request');
        const url = new URL(`https://api.appstoreconnect.apple.com/v1/${path}`);
        url.search = new URLSearchParams(query).toString();
        const response = await fetch(url, {
            method, headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
            body: data ? JSON.stringify({ data }) : undefined, redirect: 'error', signal: AbortSignal.timeout(30000),
        });
        if (!response.ok) {
            const body = await response.json().catch(() => ({}));
            const error = new Error(`App Store API HTTP ${response.status}: ${(body.errors ?? []).map(e => `${e.code} ${e.source?.pointer ?? ''}`).join('; ')}`);
            error.status = response.status;
            throw error;
        }
        return response.status === 204 ? {} : response.json();
    };
}
