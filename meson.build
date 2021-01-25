project(
    'com.github.ryonakano.reco',
    'vala', 'c',
    version: '2.4.2'
)

app_nickname = 'reco'

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c'
)

asresources = gnome.compile_resources(
    'as-resources',
    join_paths('data', app_nickname + '.gresource.xml'),
    source_dir: 'data',
    c_name: 'as'
)

executable(
    meson.project_name(),
    asresources,
    'src/Services/Recorder.vala',
    'src/Views/CountDownView.vala',
    'src/Views/WelcomeView.vala',
    'src/Views/RecordView.vala',
    'src/Application.vala',
    'src/MainWindow.vala',
    dependencies: [
        dependency('granite', version: '>=5.4.0'),
        dependency('gtk+-3.0'),
        dependency('gstreamer-1.0')
    ],
    install: true
)

subdir('data')
subdir('po')

meson.add_install_script('meson/post_install.py')
