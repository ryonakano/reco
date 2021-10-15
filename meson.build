project(
    'com.github.ryonakano.reco',
    'vala', 'c',
    version: '3.0.1',
    meson_version: '>=0.49.0'
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

executable(
    meson.project_name(),
    asresources,
    config_file,
    'src' / 'Services' / 'PulseAudioManager.vala',
    'src' / 'Services' / 'Recorder.vala',
    'src' / 'Views' / 'CountDownView.vala',
    'src' / 'Views' / 'WelcomeView.vala',
    'src' / 'Views' / 'RecordView.vala',
    'src' / 'Application.vala',
    'src' / 'MainWindow.vala',
    dependencies: [
        dependency('granite', version: '>=5.4.0'),
        dependency('gtk+-3.0'),
        dependency('gstreamer-1.0'),
        dependency('libhandy-1'),
        dependency('libpulse'),
        dependency('libpulse-mainloop-glib')
    ],
    install: true
)

subdir('data')
subdir('po')

meson.add_install_script('meson' / 'post_install.py')
