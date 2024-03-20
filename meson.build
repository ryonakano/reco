project(
    'com.github.ryonakano.reco',
    'vala', 'c',
    version: '5.0.0',
    meson_version: '>=0.57.0'
)

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
    'data' / 'reco.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true
)

dependencies = [
    dependency('gee-0.8'),
    dependency('granite-7'),
    dependency('gstreamer-1.0', version: '>= 1.20'),
    dependency('gtk4', version: '>= 4.10'),
    dependency('pango')
]

sources = files(
    'src' / 'Application.vala',
    'src' / 'Define.vala',
    'src' / 'MainWindow.vala',
    'src' / 'Manager' / 'DeviceManager.vala',
    'src' / 'Manager' / 'StyleManager.vala',
    'src' / 'Model' / 'Recorder.vala',
    'src' / 'Model' / 'Timer' / 'AbstractTimer.vala',
    'src' / 'Model' / 'Timer' / 'CountDownTimer.vala',
    'src' / 'Model' / 'Timer' / 'CountUpTimer.vala',
    'src' / 'View' / 'AbstractView.vala',
    'src' / 'View' / 'CountDownView.vala',
    'src' / 'View' / 'WelcomeView.vala',
    'src' / 'View' / 'RecordView.vala',
    'src' / 'Widget' / 'LevelBar.vala',
)

if get_option('use_submodule')
    livechart_subproject = subproject('live-chart')
    livechart_deps = livechart_subproject.get_variable('livechart_static_dep')
    dependencies += livechart_deps

    ryokucha_subproject = subproject('ryokucha')
    ryokucha_deps = ryokucha_subproject.get_variable('libryokucha')
    dependencies += ryokucha_deps
else
    dependencies += dependency('livechart', version: '>= 1.10.0')
    dependencies += dependency('ryokucha')
endif

executable(
    meson.project_name(),
    asresources,
    config_file,
    sources,
    dependencies: dependencies,
    link_args: ['-lm'],
    install: true
)

subdir('data')
subdir('po')
