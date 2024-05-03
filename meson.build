project(
    'com.github.ryonakano.reco',
    'vala', 'c',
    version: '5.0.1',
    meson_version: '>=0.58.0'
)

app_name = 'Reco'
app_id = meson.project_name()
if get_option('development')
    app_name += ' (Development)'
    app_id += '.Devel'
endif

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c'
)

gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true
)

subdir('data')
subdir('po')
subdir('src')
