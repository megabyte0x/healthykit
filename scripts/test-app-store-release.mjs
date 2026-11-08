import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { appStoreAPI } from './app-store-api.mjs';
import { appId, buildId, prepareMigration, releaseNotes } from './prepare-app-store-migration.mjs';
import { submitMigration, versionId } from './submit-app-store-migration.mjs';

function fixture({ owner = appId, processing = 'VALID', state = 'PREPARE_FOR_SUBMISSION', selectedBuild = null, locale = 'en-US', existing = false, releaseType = 'AFTER_APPROVAL' } = {}) {
    const writes = [];
    const target = { id: 'target', attributes: { versionString: '1.0.3', appStoreState: state, releaseType } };
    return { writes, api: async (path, options = {}) => {
        if (options.method) {
            writes.push({ path, ...options });
            return path === 'appStoreVersions' ? { data: target } : {};
        }
        if (path === `apps/${appId}`) return { data: { attributes: { bundleId: 'com.megabyte0x.HealthSync' } } };
        if (path === `builds/${buildId}`) return {
            data: { attributes: { version: '35', processingState: processing, expired: false }, relationships: { app: { data: { id: owner } }, preReleaseVersion: { data: { id: 'pre' } } } },
            included: [{ type: 'preReleaseVersions', id: 'pre', attributes: { version: '1.0.3', platform: 'IOS' } }],
        };
        if (path === `apps/${appId}/appStoreVersions`) return { data: [
            { id: 'prior', attributes: { versionString: '1.0.2', appStoreState: 'READY_FOR_SALE', releaseType: 'AFTER_APPROVAL' } },
            ...(existing ? [target] : []),
        ] };
        if (path === 'appStoreVersions/target') return { data: { relationships: { build: { data: selectedBuild && { id: selectedBuild } } } } };
        if (path === 'appStoreVersions/target/appStoreVersionLocalizations') return { data: [{ id: 'english', attributes: { locale } }] };
        throw new Error(`Unexpected request ${path}`);
    } };
}

test('prepares only the verified candidate and preserves the existing release policy', async () => {
    const f = fixture();
    const result = await prepareMigration(f.api);
    assert.equal(result.version, '1.0.3');
    assert.equal(result.releaseType, 'AFTER_APPROVAL');
    assert.deepEqual(f.writes.map(x => x.path), ['appStoreVersions', 'appStoreVersionLocalizations/english', 'appStoreVersions/target']);
    assert.equal(f.writes[1].data.attributes.whatsNew, releaseNotes);
    assert.deepEqual(f.writes[2].data.relationships.build.data, { type: 'builds', id: buildId });
    assert(!f.writes.some(x => /reviewSubmissions|reviewSubmissionItems/.test(x.path)));
});

test('rejects an unrelated owner or unprocessed build before any write', async () => {
    for (const options of [{ owner: 'another-app' }, { processing: 'PROCESSING' }]) {
        const f = fixture(options);
        await assert.rejects(prepareMigration(f.api));
        assert.equal(f.writes.length, 0);
    }
});

test('does not replace another draft build or modify a version already in review', async () => {
    for (const options of [{ selectedBuild: 'another-build' }, { state: 'IN_REVIEW' }]) {
        const f = fixture({ existing: true, ...options });
        await assert.rejects(prepareMigration(f.api));
        assert.equal(f.writes.length, 0);
    }
});

test('resumes a prepared draft without recreating it or selecting another build', async () => {
    const f = fixture({ existing: true, selectedBuild: buildId });
    await prepareMigration(f.api);
    assert.deepEqual(f.writes.map(x => x.path), ['appStoreVersionLocalizations/english']);
});

test('does not overwrite non-English localized release notes', async () => {
    const f = fixture({ existing: true, locale: 'ja' });
    await assert.rejects(prepareMigration(f.api), /translations/);
    assert.equal(f.writes.length, 0);
});

test('does not overwrite a separately chosen draft release policy', async () => {
    const f = fixture({ existing: true, releaseType: 'MANUAL' });
    await assert.rejects(prepareMigration(f.api), /release policy/);
    assert.equal(f.writes.length, 0);
});

test('client signs a short-lived JWT, rejects other hosts and destructive methods, and reports no secret error data', async () => {
    const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
    const api = appStoreAPI({ APP_STORE_CONNECT_API_KEY_ID: 'synthetic', APP_STORE_CONNECT_API_ISSUER_ID: 'synthetic',
        APP_STORE_CONNECT_API_PRIVATE_KEY: privateKey.export({ type: 'pkcs8', format: 'pem' }).replaceAll('\n', '\\n') });
    const previous = globalThis.fetch;
    let calls = 0;
    globalThis.fetch = async (url, options) => {
        calls++;
        assert.equal(url.origin, 'https://api.appstoreconnect.apple.com');
        assert.equal(options.redirect, 'error');
        assert.equal(options.method, 'GET');
        const [h, c, s] = options.headers.Authorization.slice(7).split('.');
        assert(verify('sha256', Buffer.from(`${h}.${c}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(s, 'base64url')));
        const claims = JSON.parse(Buffer.from(c, 'base64url'));
        assert.equal(claims.exp - claims.iat, 600);
        return new Response(JSON.stringify({ errors: [{ code: 'SYNTHETIC', detail: 'PRIVATE CREDENTIAL' }] }), { status: 409 });
    };
    try {
        await assert.rejects(api('apps/test'), e => e.message.includes('SYNTHETIC') && !e.message.includes('PRIVATE'));
        await assert.rejects(api('https://other.test/'), /Unsupported/);
        await assert.rejects(api('apps/test', { method: 'DELETE' }), /Unsupported/);
        assert.equal(calls, 1);
    } finally { globalThis.fetch = previous; }
});

function submissionFixture({ selectedBuild = buildId, state = 'PREPARE_FOR_SUBMISSION', otherItem = false, screenshotState = 'COMPLETE', screenshotCount = 6, includedCount = screenshotCount, displayType = 'APP_IPHONE_65' } = {}) {
    const writes = [];
    let added = false;
    return { writes, api: async (path, options = {}) => {
        if (options.method) {
            writes.push({ path, ...options });
            if (path === 'reviewSubmissions') return { data: { id: 'submission', attributes: { state: 'READY_FOR_REVIEW' } } };
            if (path === 'reviewSubmissionItems') { added = true; return {}; }
            if (path === 'reviewSubmissions/submission') return { data: { attributes: { state: 'WAITING_FOR_REVIEW' } } };
            throw new Error(`Unexpected mutation ${path}`);
        }
        if (path === `appStoreVersions/${versionId}`) return {
            data: { attributes: { versionString: '1.0.3', platform: 'IOS', releaseType: 'AFTER_APPROVAL', appStoreState: state },
                relationships: { app: { data: { id: appId } }, build: { data: { id: selectedBuild } } } },
            included: [
                { type: 'builds', id: buildId, attributes: { processingState: 'VALID', expired: false } },
                { type: 'appStoreReviewDetails', attributes: { contactFirstName: 'Synthetic', contactLastName: 'Contact', contactPhone: 'synthetic', contactEmail: 'synthetic@example.test', notes: 'Synthetic review', demoAccountRequired: false } },
            ],
        };
        if (path === `appStoreVersions/${versionId}/appStoreVersionLocalizations`) return { data: [{ id: 'english', attributes: { locale: 'en-US', whatsNew: releaseNotes, description: 'Synthetic app', supportUrl: 'https://example.test' } }] };
        if (path === 'appStoreVersionLocalizations/english/appScreenshotSets') return {
            data: [{ id: 'set', attributes: { screenshotDisplayType: displayType }, relationships: { appScreenshots: { data: Array.from({ length: screenshotCount }, (_, i) => ({ id: `shot${i}` })) } } }],
            included: Array.from({ length: includedCount }, (_, i) => ({ type: 'appScreenshots', id: `shot${i}`, attributes: { assetDeliveryState: { state: screenshotState } } })),
        };
        if (path === `apps/${appId}/reviewSubmissions`) return { data: otherItem ? [{ id: 'submission', attributes: { state: 'READY_FOR_REVIEW' } }] : [] };
        if (path === 'reviewSubmissions/submission/items') return { data: added || otherItem ? [{ relationships: { appStoreVersion: { data: { id: otherItem ? 'another-version' : versionId } } } }] : [] };
        throw new Error(`Unexpected read ${path}`);
    } };
}

test('submits only the verified prepared version and confirms the waiting state', async () => {
    const f = submissionFixture();
    const result = await submitMigration(f.api);
    assert.equal(result.state, 'WAITING_FOR_REVIEW');
    assert.deepEqual(f.writes.map(x => x.path), ['reviewSubmissions', 'reviewSubmissionItems', 'reviewSubmissions/submission']);
    assert.equal(f.writes[1].data.relationships.appStoreVersion.data.id, versionId);
    assert.deepEqual(f.writes[2].data.attributes, { submitted: true });
});

test('never submits a changed build, another review item or unfinished screenshots', async () => {
    for (const options of [{ selectedBuild: 'another-build' }, { otherItem: true }, { screenshotState: 'UPLOADING' }, { screenshotCount: 1 }, { includedCount: 5 }, { displayType: 'APP_IPAD_PRO_3GEN_129' }]) {
        const f = submissionFixture(options);
        await assert.rejects(submitMigration(f.api));
        assert.equal(f.writes.length, 0);
    }
});

test('does not create duplicate review submissions for a version already waiting', async () => {
    const f = submissionFixture({ state: 'WAITING_FOR_REVIEW' });
    assert.equal((await submitMigration(f.api)).alreadySubmitted, true);
    assert.equal(f.writes.length, 0);
});
