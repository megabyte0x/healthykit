import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { appStoreAPI } from './app-store-api.mjs';
import { appId, buildId, version, releaseNotes } from './prepare-app-store-migration.mjs';

export const versionId = 'eb0e4324-71f2-4266-ad00-55366fd570f2';
const relation = (type, id) => ({ data: { type, id } });

export async function submitMigration(api) {
    const target = await api(`appStoreVersions/${versionId}`, { query: { include: 'app,build,appStoreReviewDetail' } });
    const attrs = target.data.attributes, rels = target.data.relationships;
    assert.equal(attrs.versionString, version);
    assert.equal(attrs.platform, 'IOS');
    assert.equal(attrs.releaseType, 'AFTER_APPROVAL');
    assert.equal(rels.app.data.id, appId);
    assert.equal(rels.build.data.id, buildId);
    if (['WAITING_FOR_REVIEW', 'IN_REVIEW', 'PENDING_APPLE_RELEASE', 'READY_FOR_SALE'].includes(attrs.appStoreState))
        return { version, build: '35', state: attrs.appStoreState, alreadySubmitted: true };
    assert(['PREPARE_FOR_SUBMISSION', 'READY_FOR_REVIEW'].includes(attrs.appStoreState), 'Unexpected version state');
    const build = target.included.find(x => x.type === 'builds' && x.id === buildId);
    assert.equal(build?.attributes.processingState, 'VALID');
    assert.equal(build.attributes.expired, false);
    const review = target.included.find(x => x.type === 'appStoreReviewDetails')?.attributes;
    assert(review && ['contactFirstName', 'contactLastName', 'contactPhone', 'contactEmail', 'notes'].every(k => review[k]), 'Review information incomplete');
    assert.equal(review.demoAccountRequired, false, 'Unexpected demo account requirement');
    const locales = await api(`appStoreVersions/${versionId}/appStoreVersionLocalizations`, { query: { limit: '200' } });
    assert(!locales.links?.next && locales.data.length === 1 && locales.data[0].attributes.locale === 'en-US', 'Unexpected localization set');
    for (const locale of locales.data) {
        assert.equal(locale.attributes.whatsNew, releaseNotes, 'Unexpected release notes');
        assert(locale.attributes.description && locale.attributes.supportUrl, 'Store metadata incomplete');
        const sets = await api(`appStoreVersionLocalizations/${locale.id}/appScreenshotSets`, { query: { include: 'appScreenshots', limit: '200' } });
        assert(!sets.links?.next && sets.data.length === 1 && sets.data[0].attributes.screenshotDisplayType === 'APP_IPHONE_65', 'Unexpected screenshot set');
        for (const set of sets.data) {
            const linked = set.relationships.appScreenshots.data;
            const shots = (sets.included ?? []).filter(x => x.type === 'appScreenshots' && linked.some(y => y.id === x.id));
            assert(linked.length === 6 && new Set(linked.map(x => x.id)).size === 6 && shots.length === 6 && shots.every(x => x.attributes.assetDeliveryState?.state === 'COMPLETE'), 'Screenshots not ready');
        }
    }
    const submissions = await api(`apps/${appId}/reviewSubmissions`, { query: { limit: '200' } });
    assert(!submissions.links?.next, 'Submission list requires pagination');
    const active = submissions.data.filter(x => !['COMPLETE', 'CANCELED'].includes(x.attributes.state));
    assert(active.length <= 1, 'Other review submissions require inspection');
    let submission = active[0];
    if (submission) assert.equal(submission.attributes.state, 'READY_FOR_REVIEW', 'Another review is active');
    else submission = (await api('reviewSubmissions', { method: 'POST', data: {
        type: 'reviewSubmissions', attributes: { platform: 'IOS' }, relationships: { app: relation('apps', appId) },
    } })).data;
    let items = await api(`reviewSubmissions/${submission.id}/items`, { query: { include: 'appStoreVersion', limit: '200' } });
    assert(!items.links?.next && items.data.length <= 1, 'Submission contains other items');
    if (!items.data.length) await api('reviewSubmissionItems', { method: 'POST', data: {
        type: 'reviewSubmissionItems', relationships: { reviewSubmission: relation('reviewSubmissions', submission.id), appStoreVersion: relation('appStoreVersions', versionId) },
    } });
    items = await api(`reviewSubmissions/${submission.id}/items`, { query: { include: 'appStoreVersion', limit: '200' } });
    assert(!items.links?.next && items.data.length === 1 && items.data[0].relationships.appStoreVersion.data.id === versionId, 'Submission must contain only the prepared migration');
    const result = await api(`reviewSubmissions/${submission.id}`, { method: 'PATCH', data: {
        type: 'reviewSubmissions', id: submission.id, attributes: { submitted: true },
    } });
    return { version, build: '35', versionId, submissionId: submission.id, state: result.data.attributes.state };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
    assert.equal(process.env.APP_VERSION, version, 'This submission is only for the verified migration');
    console.log(JSON.stringify(await submitMigration(appStoreAPI()), null, 2));
}
