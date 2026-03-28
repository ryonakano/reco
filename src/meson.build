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
  'Widget/SavingDialog.vala',
)

# Enables debug code to check if the waveform is not refreshed when the window is suspended.
# The waveform is not refreshed when the window goes suspended, i.e. it's not a foreground window,
# which is difficult to confirm visually if it works as expected.
# Uncommenting the line below adds debug code that stops or resumes refreshing the waveform every 5 sec
# after recording started or resumed.
#add_project_arguments('--define=DEBUG_DRAW_STOP', language: 'vala')

executable(
  app_id,
  asresources,
  config_file,
  sources,
  dependencies: dependencies,
  link_args: ['-lm'],
  install: true,
)
