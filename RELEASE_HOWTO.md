# Release Flow
![release flow](./docs/images/release_flow.drawio.svg)

## 1. Update screenshots
Update screenshots under `data/screenshots` of the project.

| Subdir     | Description                      | Environment to Capture               |
| :---       | :---                             | :---                                 |
| `pantheon` | Screenshots for AppCenter builds | Latest version of elementary OS      |
| `gnome`    | Screenshots for Flathub builds   | Latest version of Fedora Workstation |

Example: https://github.com/ryonakano/reco/pull/450

## 2. Bump project version to `x.y.z-rc.1`
- Decide the version number of the release
    - Versioning should follow [Semantic Versioning](https://semver.org/)
- Create a new branch named `release-x.y.z-rc.1` from latest `origin/main` (`x.y.z` is the version number)
    - Bump `version` in `meson.build`  
    ```meson
    project(
      'com.github.ryonakano.reco',
      'vala', 'c',
      version: 'x.y.z-rc.1',
      meson_version: '>= 0.58.0',
    )
    ```
- Create a PR, wait for CI succeeds, then merge it

Example: https://github.com/ryonakano/reco/pull/449

## 3. Publish a new release `x.y.z-rc.1`
[Create a new release](https://github.com/ryonakano/reco/releases/new) on the project repository.

- Create a new tag named `x.y.z-rc.1`
- Release title: `<Project Name> x.y.z-rc.1 Released`
- Release notes may be blank because this is a pre-release
- Publish it when completed

Example: https://github.com/ryonakano/reco/releases/tag/5.2.0-rc.1

## 4. Update `tag` and `commit` in the manifest file on Flathub
- Clone https://github.com/flathub/com.github.ryonakano.reco
- Create a new branch named `release-x.y.z`—**not `release-x.y.z-rc.1`**—from latest `origin/master`
  - Remember that this is the production repository, which means any changes pushed to `origin/master` are pulled on end users as updates
  - So, we keep this branch open until we publish the final version `x.y.z` on the project repository
- Perform the following changes to the manifest file `com.github.ryonakano.reco.yml`
  - Sync the content of the manifest file with the upstream `build-aux/flathub/com.github.ryonakano.reco.Devel.yml`, excepting:
    - `id` and `command`: Keep them as `com.github.ryonakano.reco` (without `.Devel` prefix)
    - `x-checker-data`: Don't use Flatpak External Data Checker here to prevent updates from being pulled to users without well tested
    - `-Ddevelopment=true` flag of the project module
  - Update `tag` and `commit` of the project module
    - These two parameters should point to the tag/revision that we published on the project repository

Example: https://github.com/flathub/com.github.ryonakano.reco/pull/17/changes/6739c20044d42cff7b7238f76391940e699b41d8

## Work in Project Repository
- See changes since the previous release  
    ```
    $ git diff $(git describe --tags --abbrev=0)..release-X.Y.Z
    ```
- Update screenshots if there are visual changes between releases
- Create a pull request with the following changes and merge it once the build succeeds
    - Write a release note in `data/reco.metainfo.xml.in.in`
        - Refer to [the Metainfo guidelines by Flathub](https://docs.flathub.org/docs/for-app-authors/metainfo-guidelines)
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
    - Change `tag` and `commit` of the project module in the manifest file
        - These two parameters should point to the tag/revision that we published on the project repository
- The new release should be available on Flathub after some time
