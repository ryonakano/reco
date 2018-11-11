# Reco

Reco is an audio recording app designed for elementary OS.

![Screenshot](data/Screenshot.png)

One day when I joined a discussion in my department I had to take a minutes with my elementary laptop. The discussion was so high-paced that I couldn't hear and write down everything into the minutes. After coming back home I searched whether there was a sound recorder designed for elementary OS but I couldn't find, althought there were some non-elementary apps like GNOME Sound Recorder. I decided to create one designed for and fits in elementary OS.

Actually, however, I don't have much experience of programming, although I know a little bit about Java. So this app will be published after I learned programming more…

## Installation

### For Users

This app is not ready for daily use yet.

### For Developers

You'll need the following dependencies:

* libgtk-3.0-dev
* libgranite-dev
* meson
* valac

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`, then execute with `com.github.ryonakano.reco`

    sudo ninja install
    com.github.ryonakano.reco
