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

granite_dep = dependency('granite-7', version: '>= 7.2.0', required: get_option('granite'))
if granite_dep.found()
    add_project_arguments('--define=USE_GRANITE', language: 'vala')
endif

dependencies = [
    dependency('gee-0.8'),
    dependency('glib-2.0', version: '>= 2.74'),
    granite_dep,
    dependency('gstreamer-1.0', version: '>= 1.20'),
    dependency('gtk4', version: '>= 4.10'),
    dependency('libadwaita-1'),
    dependency('livechart', version: '>= 1.10.0', allow_fallback: get_option('use_submodule')),
    dependency('pango'),
    dependency('ryokucha', allow_fallback: get_option('use_submodule')),
]

sources = files(
    'Application.vala',
    'Define.vala',
    'MainWindow.vala',
    'Util.vala',
    'Manager/DeviceManager.vala',
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

executable(
    app_id,
    asresources,
    config_file,
    sources,
    dependencies: dependencies,
    link_args: ['-lm'],
    install: true
)
