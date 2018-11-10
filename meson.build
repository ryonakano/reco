project('com.github.ryonakano.reco', 'vala', 'c')

executable(
    meson.project_name(),
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
