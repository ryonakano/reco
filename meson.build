project(
  'com.github.ryonakano.reco',
  'vala', 'c',
  version: '5.1.1',
  meson_version: '>= 0.58.0',
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

vapidir = meson.project_source_root() / 'vapi'

vala_flags = [
  '--vapidir', vapidir,
]
add_project_arguments(vala_flags, language: 'vala')

subdir('data')
subdir('lib')
subdir('po')
subdir('src')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
)
