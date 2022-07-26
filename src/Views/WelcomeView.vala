/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2022 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class WelcomeView : Gtk.Box {
    public MainWindow window { get; construct; }
    private Gtk.Button record_button;

    public WelcomeView (MainWindow window) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            window: window,
            margin_top: 6,
            margin_bottom: 6,
            margin_start: 6,
            margin_end: 6
        );
    }

    construct {
        var recording_header_label = new Granite.HeaderLabel (_("Recording"));

        var source_label = new Gtk.Label (_("Record from:")) {
            halign = Gtk.Align.END
        };
        var source_combobox = new Gtk.ComboBoxText () {
            halign = Gtk.Align.START
        };
        source_combobox.append ("mic", _("Microphone"));
        source_combobox.append ("system", _("System"));
        source_combobox.append ("both", _("Both"));

        var channels_label = new Gtk.Label (_("Channels:")) {
            halign = Gtk.Align.END
        };
        var channels_combobox = new Gtk.ComboBoxText () {
            halign = Gtk.Align.START
        };
        channels_combobox.append ("mono", _("Mono"));
        channels_combobox.append ("stereo", _("Stereo"));

        var timer_header_label = new Granite.HeaderLabel (_("Timer"));

        var delay_label = new Gtk.Label (_("Delay in seconds:")) {
            halign = Gtk.Align.END
        };
        var delay_spin = new Gtk.SpinButton.with_range (0, 15, 1) {
            halign = Gtk.Align.START
        };

        var length_label = new Gtk.Label (_("Length in seconds:")) {
            halign = Gtk.Align.END
        };
        var length_spin = new Gtk.SpinButton.with_range (0, 600, 1) {
            halign = Gtk.Align.START
        };

        var saving_header_label = new Granite.HeaderLabel (_("Saving"));

        var format_label = new Gtk.Label (_("Format:")) {
            halign = Gtk.Align.END
        };

        var format_combobox = new Gtk.ComboBoxText () {
            halign = Gtk.Align.START
        };
        format_combobox.append ("alac", _("ALAC"));
        format_combobox.append ("flac", _("FLAC"));
        format_combobox.append ("mp3", _("MP3"));
        format_combobox.append ("ogg", _("Ogg Vorbis"));
        format_combobox.append ("opus", _("Opus"));
        format_combobox.append ("wav", _("WAV"));

        var auto_save_label = new Gtk.Label (_("Automatically save files:")) {
            halign = Gtk.Align.END
        };

        var auto_save_switch = new Gtk.Switch () {
            halign = Gtk.Align.START
        };

        var destination_chooser_icon = new Gtk.Image.from_icon_name ("folder");

        var destination_chooser_label = new Gtk.Label (filechooser_get_display_path (get_destination ())) {
            // Avoid the window get wider when a folder with a long directory name selected
            max_width_chars = 15,
            ellipsize = Pango.EllipsizeMode.MIDDLE
        };

        var destination_chooser_grid = new Gtk.Grid () {
            tooltip_text = _("Choose a default destination"),
            column_spacing = 6,
            margin_top = 2,
            margin_bottom = 2
        };
        destination_chooser_grid.attach (destination_chooser_icon, 0, 0);
        destination_chooser_grid.attach (destination_chooser_label, 1, 0);

        var destination_chooser_button = new Gtk.Button () {
            halign = Gtk.Align.START,
            child = destination_chooser_grid
        };

        var settings_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6,
            halign = Gtk.Align.CENTER
        };
        settings_grid.attach (recording_header_label, 0, 0, 1, 1);
        settings_grid.attach (source_label, 0, 1, 1, 1);
        settings_grid.attach (source_combobox, 1, 1, 1, 1);
        settings_grid.attach (channels_label, 0, 2, 1, 1);
        settings_grid.attach (channels_combobox, 1, 2, 1, 1);
        settings_grid.attach (timer_header_label, 0, 3, 1, 1);
        settings_grid.attach (delay_label, 0, 4, 1, 1);
        settings_grid.attach (delay_spin, 1, 4, 1, 1);
        settings_grid.attach (length_label, 0, 5, 1, 1);
        settings_grid.attach (length_spin, 1, 5, 1, 1);
        settings_grid.attach (saving_header_label, 0, 6, 1, 1);
        settings_grid.attach (format_label, 0, 7, 1, 1);
        settings_grid.attach (format_combobox, 1, 7, 1, 1);
        settings_grid.attach (auto_save_label, 0, 8, 1, 1);
        settings_grid.attach (auto_save_switch, 1, 8, 1, 1);
        settings_grid.attach (destination_chooser_button, 1, 9, 1, 1);

        record_button = new Gtk.Button () {
            icon_name = "audio-input-microphone-symbolic",
            tooltip_markup = Granite.markup_accel_tooltip ({"<Shift><Ctrl>R"}, _("Start recording")),
            halign = Gtk.Align.CENTER,
            margin_top = 12,
            width_request = 48,
            height_request = 48
        };
        record_button.get_style_context ().add_class ("record-button");
        ((Gtk.Image) record_button.child).icon_size = Gtk.IconSize.LARGE;

        append (settings_grid);
        append (record_button);

        Application.settings.bind ("delay", delay_spin, "value", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("length", length_spin, "value", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("source", source_combobox, "active_id", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("format", format_combobox, "active_id", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("channels", channels_combobox, "active_id", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("auto-save", auto_save_switch, "active", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("auto-save", destination_chooser_button, "sensitive", SettingsBindFlags.DEFAULT);

        destination_chooser_button.clicked.connect (() => {
            var filechooser = new Gtk.FileChooserNative (
                _("Choose a default destination"), window, Gtk.FileChooserAction.SELECT_FOLDER,
                _("Select"), null
            ) {
                modal = true
            };
            try {
                filechooser.set_current_folder (File.new_for_path (Application.settings.get_string ("destination")));
            } catch (Error e) {
                warning (e.message);
            }

            filechooser.response.connect ((response_id) => {
                if (response_id == Gtk.ResponseType.ACCEPT) {
                    string new_path = filechooser.get_file ().get_path ();
                    Application.settings.set_string ("destination", new_path);
                    destination_chooser_label.label = filechooser_get_display_path (new_path);
                }

                filechooser.destroy ();
            });
            filechooser.show ();
        });

        record_button.clicked.connect (() => {
            trigger_recording ();
        });
    }

    private string get_destination () {
        string destination = Application.settings.get_string ("destination");

        if (destination == "") {
            //TRANSLATORS: The name of the folder which recordings are saved
            destination = Environment.get_home_dir () + "/%s".printf (_("Recordings"));
            Application.settings.set_string ("destination", destination);
        }

        if (destination != null) {
            DirUtils.create_with_parents (destination, 0775);
        }

        return destination;
    }

    private string filechooser_get_display_path (string path) {
        string[] destination_splitted = path.split ("/");
        return destination_splitted[destination_splitted.length - 1];
    }

    public void show_success_button () {
        record_button.get_style_context ().add_class ("record-button-success");
        record_button.icon_name = "record-completed-symbolic";
        uint timeout_button_color = Timeout.add (3000, () => {
            record_button.get_style_context ().remove_class ("record-button-success");
            return false;
        });
        timeout_button_color = 0;
        uint timeout_button_icon = Timeout.add (3250, () => {
            record_button.icon_name = "audio-input-microphone-symbolic";
            return false;
        });
        timeout_button_icon = 0;
    }

    public void trigger_recording () {
        if (Application.settings.get_uint ("delay") != 0) {
            window.show_countdown ();
        } else {
            window.show_record ();
        }
    }
}
