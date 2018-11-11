project('com.github.ryonakano.reco', 'vala', 'c')

gnome = import('gnome')

asresources = gnome.compile_resources(
    'as-resources',
    'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

executable(
    meson.project_name(),
    asresources,
    'src/Views/CountDownView.vala',
    'src/Views/WelcomeView.vala',
    'src/Views/RecordView.vala',
    'src/Application.vala',
    'src/MainWindow.vala',
    dependencies: [
        dependency('granite'),
        dependency('gtk+-3.0')
    ],
    install: true
)

subdir('data')
