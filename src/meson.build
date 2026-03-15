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
  'Widget/ControlBar.vala',
  'Widget/FolderChooserButton.vala',
  'Widget/Waveform.vala',
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
