# Release Flow

TODO: Indicate relation between the flow and the following steps

![release flow](./docs/images/release_flow.drawio.svg)

## 1. Decide Version Number of Release
Versioning should follow [Semantic Versioning](https://semver.org/).

We represents the version number as `x.y.z` in this document.

## 2. Update Screenshots
Update screenshots under `data/screenshots` of the project.

| Subdir     | Description                      | Environment to Capture               |
| :---       | :---                             | :---                                 |
| `pantheon` | Screenshots for AppCenter builds | Latest version of elementary OS      |
| `gnome`    | Screenshots for Flathub builds   | Latest version of Fedora Workstation |

Example: https://github.com/ryonakano/reco/pull/450

## 3. Bump Project Version to `x.y.z-rc.1`
* Create a new branch named `release-x.y.z-rc.1` from latest `origin/main`
* Bump `version` in `meson.build`  
```meson
project(
  'com.github.ryonakano.reco',
  'vala', 'c',
  version: 'x.y.z-rc.1',
  meson_version: '>= 0.58.0',
)
```
* Commit changes, create a PR, wait for CI succeeds, then merge it

Example: https://github.com/ryonakano/reco/pull/449

## 4. Publish New Release `x.y.z-rc.1`
[Create a new release](https://github.com/ryonakano/reco/releases/new) on the project repository.

* Create a new tag named `x.y.z-rc.1`
* Release title: `Reco x.y.z-rc.1 Released`
* Release notes may be blank because this is a pre-release
* Publish it when completed

Example: https://github.com/ryonakano/reco/releases/tag/5.2.0-rc.1

## 5. Update `tag` & `commit` in Manifest File on Flathub
* Clone https://github.com/flathub/com.github.ryonakano.reco
* Create a new branch named `release-x.y.z`—**not `release-x.y.z-rc.1`**—from latest `origin/master`
  * Remember that this is the production repository, which means any changes pushed to `origin/master` are pulled on end users as updates
  * So, we keep this branch open until we publish the final version `x.y.z` on the project repository
* Perform the following changes to the manifest file `com.github.ryonakano.reco.yml`
  * Sync the content of the manifest file with the upstream `build-aux/flathub/com.github.ryonakano.reco.Devel.yml`, excepting:
    * `id` and `command`: Keep them as `com.github.ryonakano.reco` (without `.Devel` prefix)
    * `x-checker-data`: Don't use Flatpak External Data Checker here to prevent updates from being pulled to users without well tested
    * `-Ddevelopment=true` flag of the project module
  * Update `tag` and `commit` of the project module
    * These two parameters should point to the tag/revision that we published on the project repository
* Commit changes, create a PR, and check if CI succeeds

Example: https://github.com/flathub/com.github.ryonakano.reco/pull/17/changes/6739c20044d42cff7b7238f76391940e699b41d8

## 6. (Optional) Engage Translators to Work on Translations
Requirement: needs to be a member of the project maintainers on Weblate

Go to [Operation → Post announcement](https://hosted.weblate.org/projects/rosp/reco/#announcement) and post an
announcement with the following content:

* Write a `Message` that
  * tells target date & time of release date in UTC
  * asks translators to work on translations
* Set `Severity` to `Info (light blue)`
* Set `Expiry date` to the day before the target day
* Check `Notify users` on

## 7. Add AppStream Release Note
* Create a new branch from latest `origin/main`
* Write a release note in `data/reco.metainfo.xml.in.in`
  * Refer to [the Metainfo guidelines by Flathub](https://docs.flathub.org/docs/for-app-authors/metainfo-guidelines)
* Commit changes, create a PR, wait for CI succeeds, then merge it

Example: https://github.com/ryonakano/reco/pull/460

## 8. Merge Translations
Translation updates from Hosted Weblate is configured to be submitted through a PR, e.g. https://github.com/ryonakano/reco/pull/443. Merge one before the final release if any is open.

## 9. Bump Project Version to `x.y.z`
Refer to "2. Bump Project Version to `x.y.z-rc.1`" for details.

Example: TODO

## 10. Publish New Release `x.y.z`
Refer to "3. Publish New Release `x.y.z-rc.1`" for details.

* Release notes MUST be filled because this is the final release

Example: https://github.com/ryonakano/reco/releases/tag/5.2.0

## 11. Update `tag` & `commit` in Manifest File on Flathub
Refer to "4. Update `tag` & `commit` in Manifest File on Flathub" for details.

* Use the existing `release-x.y.z` branch created in 4.
* Once CI succeeds, merge it
* The new release should be available on Flathub after some time

Example: TODO

## 12. Update `commit` & `version` in JSON File on appcenter-reviews
* Clone https://github.com/elementary/appcenter-reviews
  * Fork the repository if you don't have write access to it
* Create a new branch named `com.github.ryonakano.reco-X.Y.Z` from latest `origin/main`
* Perform the following changes to `applications/com.github.ryonakano.reco.json`
  * Update `commit` and `version`
    * These two parameters should point to the tag/revision that we published on the project repository
* Commit changes, create a PR, check if CI succeeds, and wait for review, approval, and merge by the AppCenter Reviewers
* The new release should be available on AppCenter after some time

Example: TODO
