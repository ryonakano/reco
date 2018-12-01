i18n.merge_file(
    input: 'com.github.ryonakano.reco.desktop.in',
    output: 'com.github.ryonakano.reco.desktop',
    po_dir: join_paths(meson.source_root(), 'po', 'extra'),
    type: 'desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications')
)

i18n.merge_file(
    input: 'com.github.ryonakano.reco.appdata.xml.in',
    output: 'com.github.ryonakano.reco.appdata.xml',
    po_dir: join_paths(meson.source_root(), 'po', 'extra'),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

install_data(
    'com.github.ryonakano.reco.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)
