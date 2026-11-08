import { appStoreAPI } from './app-store-api.mjs';

const appId = '6776575569';
const request = appStoreAPI();
const get = (path, query) => request(path, { query });

const versions = await get(`apps/${appId}/appStoreVersions`, {
    limit: '10', 'fields[appStoreVersions]': 'versionString,appStoreState,releaseType',
});
const builds = await get('builds', {
    'filter[app]': appId, sort: '-uploadedDate', limit: '5',
    'fields[builds]': 'version,processingState,uploadedDate,expired,preReleaseVersion',
    include: 'preReleaseVersion', 'fields[preReleaseVersions]': 'version,platform',
});
const draft = versions.data.find(x => x.attributes.versionString === '1.0.3');
let migrationDraft;
if (draft) {
    const details = await get(`appStoreVersions/${draft.id}`, { include: 'build,appStoreReviewDetail' });
    const review = details.included?.find(x => x.type === 'appStoreReviewDetails')?.attributes;
    const locales = await get(`appStoreVersions/${draft.id}/appStoreVersionLocalizations`, { limit: '200' });
    const localizedMetadata = [];
    for (const locale of locales.data) {
        const sets = await get(`appStoreVersionLocalizations/${locale.id}/appScreenshotSets`, { include: 'appScreenshots', limit: '200' });
        localizedMetadata.push({
            locale: locale.attributes.locale,
            hasDescription: Boolean(locale.attributes.description), hasSupportURL: Boolean(locale.attributes.supportUrl),
            whatsNew: locale.attributes.whatsNew,
            screenshotSets: sets.data.map(set => {
                const shots = (sets.included ?? []).filter(x => x.type === 'appScreenshots' && set.relationships.appScreenshots.data.some(y => y.id === x.id));
                return { displayType: set.attributes.screenshotDisplayType, count: shots.length,
                    allComplete: shots.length > 0 && shots.every(x => x.attributes.assetDeliveryState?.state === 'COMPLETE') };
            }),
        });
    }
    migrationDraft = {
        versionId: draft.id, selectedBuildId: details.data.relationships.build.data?.id,
        reviewContactComplete: Boolean(review && ['contactFirstName', 'contactLastName', 'contactPhone', 'contactEmail'].every(k => review[k])),
        reviewNotesPresent: Boolean(review?.notes), demoAccountRequired: review?.demoAccountRequired,
        localizations: localizedMetadata,
    };
}
console.log(JSON.stringify({
    versions: versions.data.map(({ id, attributes }) => ({ id, ...attributes })),
    builds: builds.data.map(({ id, attributes, relationships }) => ({
        id, ...attributes,
        appVersion: builds.included?.find(item => item.id === relationships.preReleaseVersion?.data?.id)?.attributes.version,
    })),
    migrationDraft,
}, null, 2));
