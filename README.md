# Reco
![Welcome view in the light mode](data/screenshots/gnome/welcome-init-light.png#gh-light-mode-only) ![Recording view in the light mode](data/screenshots/gnome/recording-light.png#gh-light-mode-only)

![Welcome view in the dark mode](data/screenshots/gnome/welcome-init-dark.png#gh-dark-mode-only) ![Recording view in the dark mode](data/screenshots/gnome/recording-dark.png#gh-dark-mode-only)

Reco is an audio recorder focused on being concise and simple to use.

You can use it to record and remember spoken words, system audio, improvized melodies, and anything else you can do with a microphone, speaker, or both.

Features include:

* **Recording sounds from both your microphone and system at the same time.** This is useful for recording calls or streaming videos on the Internet.
* **Saving in many commonly used formats.** It supports ALAC, FLAC, MP3, Ogg Vorbis, Opus, and WAV.
* **Timed recording.** You can set a delay before recording up to 15 seconds, and set the length of recording up to 600 seconds.
* **Choosing where to save recordings.** You can select whether the app saves recordings into a directory of your choosing automatically or manually.
* **Saving recordings when the app quits.** Even if you happen to quit the app while recording, the recording is either saved automatically, or the file chooser dialog is shown - depending on your preferences.

## Installation
### From Flathub or AppCenter (Recommended)
You can install Reco from Flathub:

[<img src="https://flathub.org/assets/badges/flathub-badge-en.svg" width="160" alt="Download on Flathub">](https://flathub.org/apps/com.github.ryonakano.reco)

You should install Reco from AppCenter if you're on elementary OS. This build is optimized for elementary OS:

[![Get it on AppCenter](https://appcenter.elementary.io/badge.svg)](https://appcenter.elementary.io/com.github.ryonakano.reco)

### From Community Packages
Community packages maintained by volunteers are also available on some distributions:

[![Packaging status](https://repology.org/badge/vertical-allrepos/reco.svg)](https://repology.org/project/reco/versions)

### From Source Code (Flatpak)
You'll need `flatpak` and `flatpak-builder` commands installed on your system.

Run `flatpak remote-add` to add Flathub remote for dependencies:

```
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

To build and install, use `flatpak-builder`, then execute with `flatpak run`:

```
flatpak-builder builddir --user --install --force-clean --install-deps-from=flathub build-aux/flathub/com.github.ryonakano.reco.Devel.yml
flatpak run com.github.ryonakano.reco.Devel
```

### From Source Code (Native)
You'll need the following dependencies to build:

* blueprint-compiler
* libadwaita-1-dev
* libgee-0.8-dev
* libglib2.0-dev (>= 2.74)
* libgranite-7-dev (>= 7.2.0, required only when you build with `granite` feature enabled)
* libgstreamer1.0-dev (>= 1.20)
* libgtk-4-dev (>= 4.10)
* [libryokucha](https://github.com/ryonakano/ryokucha)
* [livechart](https://github.com/lcallarec/live-chart) (>= 1.10.0)
* meson (>= 0.58.0)
* valac

You'll need the following dependencies to run:

* gstreamer1.0-libav (use the same version with libgstreamer1.0-dev)

Run `meson setup` to configure the build environment and run `meson compile` to build:

```bash
meson setup builddir --prefix=/usr
meson compile -C builddir
```

To install, use `meson install`, then execute with `com.github.ryonakano.reco`:

```bash
meson install -C builddir
com.github.ryonakano.reco
```

## Contributing
Please refer to [the contribution guideline](CONTRIBUTING.md) if you would like to:

- submit bug reports / feature requests
- propose coding changes
- translate the project

## Get Support
Need help in use of the app? Refer to [the discussions page](https://github.com/ryonakano/reco/discussions) to search for existing discussions or [start a new discussion](https://github.com/ryonakano/reco/discussions/new/choose) if none is relevant.

## The Story Behind This App
This app was originally designed and released for elementary OS.

One day, I had to take minutes for a meeting in my department with my elementary laptop. The discussion was so fast-paced, though, that I couldn't listen and write down everything in the minutes. When I got home, I searched for a sound recorder app. I found some non-elementary apps like GNOME Sound Recorder, but there were none for elementary OS. Thus, I decided to create one designed for elementary OS.
