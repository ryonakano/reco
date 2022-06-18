project(
    'com.github.ryonakano.reco',
    'vala', 'c',
    version: '3.3.1',
    meson_version: '>=0.57.0'
)

app_nickname = 'reco'

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c'
)

add_project_arguments(
    ['--vapidir', meson.current_source_dir() / 'vapi'],
    language: 'vala'
)

config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_file = configure_file(
    input: 'src' / 'Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

asresources = gnome.compile_resources(
    'as-resources',
    'data' / app_nickname + '.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true
)

sources = files(
    'src' / 'Services' / 'PulseAudioManager.vala',
    'src' / 'Services' / 'Recorder.vala',
    'src' / 'Views' / 'CountDownView.vala',
    'src' / 'Views' / 'WelcomeView.vala',
    'src' / 'Views' / 'RecordView.vala',
    'src' / 'Application.vala',
    'src' / 'MainWindow.vala',
    'src' / 'StyleSwitcher.vala'
)

executable(
    meson.project_name(),
    asresources,
    config_file,
    sources,
    dependencies: [
        dependency('granite-7'),
        dependency('gtk4'),
        dependency('gstreamer-1.0'),
        dependency('libpulse'),
        dependency('libpulse-mainloop-glib')
    ],
    install: true
)

subdir('data')
subdir('po')
