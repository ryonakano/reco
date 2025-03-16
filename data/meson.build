icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach i : icon_sizes
    install_data(
        'icons' / i / meson.project_name() + '.png',
        rename: app_id + '.png',
        install_dir: get_option('datadir') / 'icons' / 'hicolor' / i + 'x' + i / 'apps'
    )
endforeach

desktop_conf = configuration_data()
desktop_conf.set('APP_NAME', app_name)
desktop_conf.set('APP_ID', app_id)
desktop_file_in = configure_file(
    input: 'reco.desktop.in.in',
    output: '@0@.desktop.in'.format(app_id),
    configuration: desktop_conf
)

desktop_file = i18n.merge_file(
    input: desktop_file_in,
    output: '@0@.desktop'.format(app_id),
    po_dir: meson.project_source_root() / 'po',
    type: 'desktop',
    install: true,
    install_dir: get_option('datadir') / 'applications'
)

appstream_conf = configuration_data()
appstream_conf.set('APP_ID', app_id)
appstream_conf.set('GETTEXT_PACKAGE', meson.project_name())
# Use screenshots taken on Pantheon, which is a publishing requirement for AppCenter, if build with granite.
appstream_conf.set('DE', get_option('granite').enabled() ? 'pantheon' : 'gnome')
appstream_conf.set('VERSION', meson.project_version())
appstream_file_in = configure_file(
    input: 'reco.metainfo.xml.in.in',
    output: '@0@.metainfo.xml.in'.format(app_id),
    configuration: appstream_conf
)

appstream_file = i18n.merge_file(
    input: appstream_file_in,
    output: '@0@.metainfo.xml'.format(app_id),
    po_dir: meson.project_source_root() / 'po',
    install: true,
    install_dir: get_option('datadir') / 'metainfo'
)

gschema_conf = configuration_data()
gschema_conf.set('APP_ID', app_id)
gschema_file = configure_file(
    input: 'reco.gschema.xml.in',
    output: '@0@.gschema.xml'.format(app_id),
    configuration: gschema_conf
)

install_data(
    gschema_file,
    install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)

blueprints = custom_target('blueprints',
    input: files(
        'ui/help-overlay.blp',
    ),
    output: '.',
    command: [
        find_program('blueprint-compiler'),
        'batch-compile',
        '@OUTPUT@',
        '@CURRENT_SOURCE_DIR@',
        '@INPUT@'
    ]
)

gresource_conf = configuration_data()
gresource_conf.set('APP_ID', app_id)
gresource_file_in = configure_file(
    input: 'reco.gresource.xml.in',
    output: '@0@.gresource.xml'.format(app_id),
    configuration: gresource_conf
)

asresources = gnome.compile_resources(
    'as-resources',
    gresource_file_in,
    dependencies: blueprints,
    source_dir: 'data',
    c_name: 'as'
)

# Test definitions
desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
    test('Validate desktop file', desktop_utils, args: [desktop_file])
endif

appstreamcli = find_program('appstreamcli', required: false, disabler: true)
test('Validate appstream file', appstreamcli,
    args: ['validate', '--no-net', '--explain', appstream_file])

compile_schemas = find_program('glib-compile-schemas', required: false, disabler: true)
test('Validate schema file',
    compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()])
