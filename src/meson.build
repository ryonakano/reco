config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_data.set_quoted('APP_ID', app_id)
config_data.set_quoted('RESOURCE_PREFIX', '/' + meson.project_name().replace('.', '/'))
config_file = configure_file(
    input: 'Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

dependencies = [
    dependency('gee-0.8'),
    dependency('glib-2.0', version: '>= 2.74'),
    dependency('granite-7'),
    dependency('gstreamer-1.0', version: '>= 1.20'),
    dependency('gtk4', version: '>= 4.10'),
    dependency('pango'),
]

sources = files(
    'Application.vala',
    'Define.vala',
    'MainWindow.vala',
    'Manager/DeviceManager.vala',
    'Manager/StyleManager.vala',
    'Model/Recorder.vala',
    'Model/Timer/AbstractTimer.vala',
    'Model/Timer/CountDownTimer.vala',
    'Model/Timer/CountUpTimer.vala',
    'View/AbstractView.vala',
    'View/CountDownView.vala',
    'View/WelcomeView.vala',
    'View/RecordView.vala',
    'Widget/LevelBar.vala',
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
    app_id,
    asresources,
    config_file,
    sources,
    dependencies: dependencies,
    link_args: ['-lm'],
    install: true
)
