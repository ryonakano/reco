# Reco

Reco is a simple audio recording app that helps you recall things talked later.

![Screenshot](data/screenshots/pantheon/welcome-init.png)

Features include:

* **Recording sounds from both your microphone and system at the same time.** This would be useful when you record conversations with chat apps or stream videos on the Internet
* **Saving in some commonly used formats.** It supports ALAC, FLAC, MP3, Ogg Vorbis, Opus, and WAV
* **Timed recording.** You can set a delay before recording up to 15 seconds, and the length of recording up to 600 seconds
* **Autosaving or always-ask-where-to-save workflow.** You can select whether the app saves recordings automatically or you choose a destination each time on saving them
* **Saving recording when the app quits.** Even if you happen to quit the app while recording, the recording is saved automatically or a FileChooserDialog is shown depends on your saving setting

## Installation

### For Users

On elementary OS? Click the button to get Reco on AppCenter:

[![Get it on AppCenter](https://appcenter.elementary.io/badge.svg)](https://appcenter.elementary.io/com.github.ryonakano.reco)

You can also download the app from Flathub, in case you're using another distribution. This version is tweaked to work well and look good on other desktop environment.

[<img src="https://flathub.org/assets/badges/flathub-badge-en.svg" width="160" alt="Download on Flathub">](https://flathub.org/apps/details/com.github.ryonakano.reco)

Community packages maintained by volunteers are also available on some distributions:

[![Packaging status](https://repology.org/badge/vertical-allrepos/reco.svg)](https://repology.org/project/reco/versions)

### For Developers

You'll need the following dependencies to build:

* libgtk-3.0-dev
* libgranite-dev (>= 5.4.0)
* libgstreamer1.0-dev
* libhandy-1-dev
* libpulse-dev
* libpulse-mainloop-glib0
* meson (>= 0.57.0)
* valac

You'll need the following dependencies to run:

* gstreamer1.0-libav

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`, then execute with `com.github.ryonakano.reco`

    ninja install
    com.github.ryonakano.reco

## Contributing

There are many ways you can contribute, even if you don't know how to code.

### Reporting Bugs or Suggesting Improvements

Simply [create a new issue](https://github.com/ryonakano/reco/issues/new) describing your problem and how to reproduce or your suggestion. If you are not used to do, [this section](https://docs.elementary.io/contributor-guide/feedback/reporting-issues) is for you.

### Writing Some Code

We follow [the coding style of elementary OS](https://docs.elementary.io/develop/writing-apps/code-style) and [its Human Interface Guidelines](https://docs.elementary.io/hig/). Try to respect them.

### Translation

We accept translations of this project through [Weblate](https://weblate.org/). We would appreciate it if you would join our translation work!

Click the following graphs to get started:

| Main: Texts in the app itself | Extra: Texts in the desktop entry and the software center |
| --- | --- |
| [![Translation status](https://hosted.weblate.org/widgets/rosp/-/reco-main/multi-auto.svg)](https://hosted.weblate.org/engage/rosp/) | [![Translation status](https://hosted.weblate.org/widgets/rosp/-/reco-extra/multi-auto.svg)](https://hosted.weblate.org/engage/rosp/) |

## The Story Behind This App

This app is originally designed and released for elementary OS.

One day, I had to take minutes for a meeting in my department with my elementary laptop. The discussion was so fast-paced, though, that I couldn't listen and write down everything in the minutes. When I got home, I searched for a sound recorder app. I found some non-elementary apps like GNOME Sound Recorder, but there were none for elementary OS. Thus, I decided to create one designed for elementary OS.
