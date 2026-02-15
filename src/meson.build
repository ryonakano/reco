config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_data.set_quoted('APP_NAME', app_name)
config_data.set_quoted('APP_ID', app_id)
config_data.set_quoted('APP_VERSION', app_version)
config_data.set_quoted('RESOURCE_PREFIX', '/' + meson.project_name().replace('.', '/'))
config_file = configure_file(
  input: 'Config.vala.in',
  output: '@BASENAME@',
  configuration: config_data,
)

# Check for the elementary fork first
livechart_dep = dependency('livechart-2', version: '>= 2.0.0', required: false)
if not livechart_dep.found()
  # Check for the upstream next
  # Fallback to the upstream submodule finally even if it not found
  livechart_dep = dependency('livechart', version: '>= 1.10.0', allow_fallback: get_option('use_submodule'))
endif

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
  dependency('libadwaita-1', version: '>= 1.6.0'),
  livechart_dep,
  dependency('pango'),
  dependency('ryokucha', allow_fallback: get_option('use_submodule')),
]

sources = files(
  'Application.vala',
  'Define.vala',
  'MainWindow.vala',
  'Util.vala',
  'Manager/DeviceManager.vala',
  'Manager/RecordManager.vala',
  'Model/Recorder/AbstractRecorder.vala',
  'Model/Recorder/ALACRecorder.vala',
  'Model/Recorder/FLACRecorder.vala',
  'Model/Recorder/MP3Recorder.vala',
  'Model/Recorder/OGGRecorder.vala',
  'Model/Recorder/OPUSRecorder.vala',
  'Model/Recorder/WAVRecorder.vala',
  'Model/Timer/AbstractTimer.vala',
  'Model/Timer/CountDownTimer.vala',
  'Model/Timer/CountUpTimer.vala',
  'View/AbstractView.vala',
  'View/CountDownView.vala',
  'View/WelcomeView.vala',
  'View/RecordView.vala',
  'Widget/FolderChooserButton.vala',
  'Widget/LevelBar.vala',
  'Widget/ProcessingDialog.vala',
)

executable(
  app_id,
  asresources,
  config_file,
  sources,
  dependencies: dependencies,
  link_args: ['-lm'],
  install: true,
)
