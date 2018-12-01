#!/usr/bin/env python3

from os import environ, path
from subprocess import call

schemadir = path.join(environ['MESON_INSTALL_PREFIX'], 'share', 'glib-2.0', 'schemas')
iconcachedir = path.join(environ['MESON_INSTALL_PREFIX'], 'share', 'icons', 'hicolor')

if not environ.get('DESTDIR'):
    print('Completing gsettings schemas…')
    call(['glib-compile-schemas', schemadir])

    print('Rebuilding desktop icon cache…')
    call(['gtk-update-icon-cache', iconcachedir])
