# Release Flow
## Work in Project Repository
- Repository URL: https://github.com/ryonakano/reco
- Decide the version number of the release
    - Versioning should follow [Semantic Versioning](https://semver.org/)
- Create a new branch named `release-X.Y.Z` from latest `origin/main` (`X.Y.Z` is the version number)
- See changes since the previous release  
    ```
    $ git diff $(git describe --tags --abbrev=0)..release-X.Y.Z
    ```
- Update screenshots if there are visual changes between releases
- Create a pull request with the following changes and merge it once the build succeeds
    - Write a release note in `data/reco.metainfo.xml.in.in`
        - Refer to [the Metainfo guidelines by Flathub](https://docs.flathub.org/docs/for-app-authors/metainfo-guidelines/#release)
        - Credits contributors with their GitHub username
    - Bump `version` in `meson.build`  
    ```meson
    project(
        'com.github.ryonakano.reco',
        'vala', 'c',
        version: '5.0.2',
        meson_version: '>=0.58.0'
    )
    ```
- [Create a new release on GitHub](https://github.com/ryonakano/reco/releases/new)
    - Create a new tag named `X.Y.Z`
    - Release title: `<Project Name> X.Y.Z Released`
    - Publish it when completed

## Work in AppCenter Review Repository
- Repository URL: https://github.com/elementary/appcenter-reviews
- Fork the repository if you don't have write access to it
- Create a new branch named `com.github.ryonakano.reco-X.Y.Z` from latest `origin/main`
- Create a pull request with the following changes and await for review approval and merge
    - Change `commit` and `version` in the `applications/com.github.ryonakano.reco.json`
        - `commit` should be the release commit just we published on the project repository
        - `version` for the relase version
- The new release should be available on AppCenter after some time

## Work in Flathub Repository
- Repository URL: https://github.com/flathub/com.github.ryonakano.reco
- Create a new branch named `release-X.Y.Z` from latest `origin/master`
- Create a pull request with the following changes and merge it once the build succeeds
    - Sync the content of the manifest file with the upstream except for the project module
    - Change `url` and `sha256` of the project module in the manifest file
        - These two parameters should point to the tar.gz of the release assets just we published on the project repository
- The new release should be available on Flathub after some time
