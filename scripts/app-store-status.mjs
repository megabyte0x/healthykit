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
console.log(JSON.stringify({
    versions: versions.data.map(({ id, attributes }) => ({ id, ...attributes })),
    builds: builds.data.map(({ id, attributes, relationships }) => ({
        id, ...attributes,
        appVersion: builds.included?.find(item => item.id === relationships.preReleaseVersion?.data?.id)?.attributes.version,
    })),
}, null, 2));
