project(
  'com.github.ryonakano.reco',
  'vala', 'c',
  version: '5.1.1',
  meson_version: '>= 1.5.0',
)

app_name = 'Reco'
app_id = meson.project_name()
app_version = meson.project_version()
if get_option('development')
  app_name += ' (Development)'
  app_id += '.Devel'

  ret = run_command('git', 'rev-parse', '--short', 'HEAD', check: false)
  if ret.returncode() != 0
    version_suffix = '-devel'
  else
    version_suffix = '-@0@'.format(ret.stdout().strip())
  endif

  app_version += version_suffix
endif

app_revision = 'main'
ret = run_command('git', 'rev-parse', 'HEAD', check: false)
if ret.returncode() == 0
  app_revision = ret.stdout().strip()
endif

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  language: 'c',
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

subdir('data')
subdir('po')
subdir('src')

if get_option('doc')
  subdir('docs')
endif

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
)
