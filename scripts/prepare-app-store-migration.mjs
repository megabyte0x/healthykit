import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { appStoreAPI } from './app-store-api.mjs';

export const appId = '6776575569';
export const buildId = '8db9cee3-41ae-40b3-a512-e52c2ecd7751';
export const version = '1.0.3';
export const releaseNotes = 'Improved hosted syncing reliability.\nExisting data, access tokens and Health permissions are preserved.\nFor external agents using the legacy URL, update only the endpoint. See https://healthysync.app/docs/agent-access#cloudflare-migration.';
const relation = (type, id) => ({ data: { type, id } });

export async function prepareMigration(api) {
    const app = (await api(`apps/${appId}`)).data;
    assert.equal(app.attributes.bundleId, 'com.megabyte0x.HealthSync', 'Unexpected app');
    const build = await api(`builds/${buildId}`, { query: { include: 'app,preReleaseVersion' } });
    assert.equal(build.data.relationships.app.data.id, appId, 'Wrong build owner');
    assert.equal(build.data.attributes.version, '35', 'Unexpected build');
    assert.equal(build.data.attributes.processingState, 'VALID', 'Build not processed');
    assert.equal(build.data.attributes.expired, false, 'Build expired');
    const prerelease = build.included.find(x => x.type === 'preReleaseVersions' && x.id === build.data.relationships.preReleaseVersion.data.id);
    assert.equal(prerelease?.attributes.version, version, 'Unexpected app version');
    assert.equal(prerelease?.attributes.platform, 'IOS', 'Unexpected platform');
    const versions = await api(`apps/${appId}/appStoreVersions`, { query: { limit: '200', 'filter[platform]': 'IOS' } });
    assert(!versions.links?.next, 'Version list requires pagination');
    const prior = versions.data.find(x => x.attributes.versionString === '1.0.2');
    assert.equal(prior?.attributes.appStoreState, 'READY_FOR_SALE', 'Expected released baseline');
    assert.equal(prior.attributes.releaseType, 'AFTER_APPROVAL', 'Unexpected release policy');
    let target = versions.data.find(x => x.attributes.versionString === version);
    if (!target) target = (await api('appStoreVersions', { method: 'POST', data: {
        type: 'appStoreVersions', attributes: { platform: 'IOS', versionString: version, copyright: prior.attributes.copyright, releaseType: prior.attributes.releaseType },
        relationships: { app: relation('apps', appId) },
    } })).data;
    assert.equal(target.attributes.appStoreState, 'PREPARE_FOR_SUBMISSION', 'Target is not an editable draft');
    assert.equal(target.attributes.releaseType, prior.attributes.releaseType, 'Draft has a different release policy');
    const details = (await api(`appStoreVersions/${target.id}`, { query: { include: 'build' } })).data;
    const selectedBuild = details.relationships.build.data?.id;
    assert(!selectedBuild || selectedBuild === buildId, 'Draft has another build selected');
    const localizations = await api(`appStoreVersions/${target.id}/appStoreVersionLocalizations`, { query: { limit: '200' } });
    assert(!localizations.links?.next && localizations.data.length > 0, 'Expected inherited localizations');
    assert(localizations.data.every(x => /^en(-|$)/.test(x.attributes.locale)), 'Release notes need additional translations');
    for (const locale of localizations.data) {
        await api(`appStoreVersionLocalizations/${locale.id}`, { method: 'PATCH', data: {
            type: 'appStoreVersionLocalizations', id: locale.id, attributes: { whatsNew: releaseNotes },
        } });
    }
    if (!selectedBuild) await api(`appStoreVersions/${target.id}`, { method: 'PATCH', data: {
        type: 'appStoreVersions', id: target.id, relationships: { build: relation('builds', buildId) },
    } });
    return { version, build: '35', versionId: target.id, releaseType: target.attributes.releaseType, localizations: localizations.data.map(x => x.attributes.locale), state: target.attributes.appStoreState };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
    assert.equal(process.env.APP_VERSION, version, 'This preparation is only for the verified 1.0.3 candidate');
    console.log(JSON.stringify(await prepareMigration(appStoreAPI()), null, 2));
}
