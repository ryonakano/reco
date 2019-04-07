# Reco

Reco is an audio recording app designed for elementary OS.

![Screenshot](data/Screenshot.png)

Useful for:

* Joining meetings and taking minutes later
* Recording conversations with a friend or lover
* Streaming videos on the Internet

Features include:

* Timed recording
* Available formats: AAC, FLAC, MP3, Ogg Vorbis, Opus and WAV

## Installation

### For Users

On elementary OS? Click the button to get Reco on AppCenter:

[![Get it on AppCenter](https://appcenter.elementary.io/badge.svg)](https://appcenter.elementary.io/com.github.ryonakano.reco)

#### Arch Linux

Arch Linux users can find Reco under the name [reco-git](https://aur.archlinux.org/packages/reco-git/) in the AUR (thanks to [btd1337](https://github.com/btd1337)):

    aurman -S reco-git

### For Developers

You'll need the following dependencies:

* libgtk-3.0-dev
* libgranite-dev (>= 5.2.3)
* libgstreamer1.0-dev
* meson
* valac

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`, then execute with `com.github.ryonakano.reco`

    sudo ninja install
    com.github.ryonakano.reco

## The Story Behind This App

One day, I had to take minutes for a meeting in my department with my elementary laptop. The discussion was so fast-paced, though, that I couldn't listen and write down everything in the minutes. When I got home, I searched for a sound recorder app. I found some non-elementary apps like GNOME Sound Recorder, but there were none for elementary OS. Thus, I decided to create one designed for elementary OS.
