project(
    'com.github.ryonakano.reco',
    'vala', 'c',
    version: '4.0.1',
    meson_version: '>=0.57.0'
)

app_nickname = 'reco'

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c'
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
    'src' / 'Services' / 'DeviceManager.vala',
    'src' / 'Services' / 'Recorder.vala',
    'src' / 'Views' / 'CountDownView.vala',
    'src' / 'Views' / 'WelcomeView.vala',
    'src' / 'Views' / 'RecordView.vala',
    'src' / 'Widgets' / 'LevelBar.vala',
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
        dependency('gee-0.8'),
        dependency('granite-7'),
        dependency('gtk4'),
        dependency('gstreamer-1.0', version: '>= 1.20'),
        # TODO: Add limitation for GTK4 supported version
        dependency('livechart'),
        dependency('pango')
    ],
    link_args: ['-X', '-lm'],
    install: true
)

subdir('data')
subdir('po')
