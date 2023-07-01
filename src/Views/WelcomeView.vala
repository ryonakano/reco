/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class WelcomeView : Gtk.Box {
    public MainWindow window { get; construct; }

    private Gtk.Switch auto_save_switch;
    private Gtk.Label destination_chooser_label;
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
        var source_header_label = new Granite.HeaderLabel (_("Source"));

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

        var timer_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        timer_size_group.add_widget (delay_spin);
        timer_size_group.add_widget (length_spin);

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

        auto_save_switch = new Gtk.Switch () {
            halign = Gtk.Align.START
        };

        var destination_chooser_icon = new Gtk.Image.from_icon_name ("folder");

        destination_chooser_label = new Gtk.Label (null) {
            // Avoid the window get wider when a folder with a long directory name selected
            max_width_chars = 15,
            ellipsize = Pango.EllipsizeMode.MIDDLE
        };
        get_destination ();

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
        settings_grid.attach (source_header_label, 0, 0, 1, 1);
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
        record_button.add_css_class ("record-button");
        ((Gtk.Image) record_button.child).icon_size = Gtk.IconSize.LARGE;

        append (settings_grid);
        append (record_button);

        Application.settings.bind ("delay", delay_spin, "value", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("length", length_spin, "value", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("source", source_combobox, "active_id", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("format", format_combobox, "active_id", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("channel", channels_combobox, "active_id", SettingsBindFlags.DEFAULT);

        auto_save_switch.state_set.connect ((state) => {
            if (state == true) {
                // Prevent the filechooser shown twice when enabling the autosaving
                var autosave_dest = Application.settings.get_string ("autosave-destination");
                if (autosave_dest != Application.SETTINGS_NO_AUTOSAVE) {
                    return false;
                }

                // Let the user select the autosaving destination
                show_destination_chooser ();
                return false;
            }

            // Clear the current destination and disable autosaving
            set_destination (Application.SETTINGS_NO_AUTOSAVE);
            return false;
        });

        destination_chooser_button.clicked.connect (() => {
            show_destination_chooser ();
        });

        record_button.clicked.connect (() => {
            trigger_recording ();
        });
    }

    private void get_destination () {
        string path = Application.settings.get_string ("autosave-destination");
        destination_chooser_label.label = destination_chooser_get_label (path);
        auto_save_switch.active = (path != Application.SETTINGS_NO_AUTOSAVE);

        var file = File.new_for_path (path);
        if (file.query_exists () == false) {
            DirUtils.create_with_parents (path, 0775);
        }
    }

    private void set_destination (string path) {
        Application.settings.set_string ("autosave-destination", path);
        destination_chooser_label.label = destination_chooser_get_label (path);
    }

    private string destination_chooser_get_label (string path) {
        if (path == Application.SETTINGS_NO_AUTOSAVE) {
            return _("Select destination…");
        }

        string[] destination_splitted = path.split ("/");
        return destination_splitted[destination_splitted.length - 1];
    }

    private void show_destination_chooser () {
        var filechooser = new Gtk.FileDialog () {
            title = _("Choose a default destination"),
            accept_label = _("Select"),
            modal = true
        };
        filechooser.select_folder.begin (window, null, (obj, res) => {
            try {
                var file = filechooser.select_folder.end (res);
                if (file == null) {
                    return;
                }

                string new_path = file.get_path ();
                set_destination (new_path);
                auto_save_switch.active = true;
            } catch (Error e) {
                warning ("Failed to select folder: %s", e.message);

                // If the autosave switch was off previously, turn off the autosave switch
                // because the user cancels setting the autosave destination
                // If the autosave switch was on previously, then it means the user just cancels
                // changing the destination
                var autosave_dest = Application.settings.get_string ("autosave-destination");
                if (autosave_dest == Application.SETTINGS_NO_AUTOSAVE) {
                    auto_save_switch.active = false;
                }
            }
        });
    }

    public void show_success_button () {
        record_button.add_css_class ("record-button-success");
        record_button.icon_name = "record-completed-symbolic";
        uint timeout_button_color = Timeout.add (3000, () => {
            record_button.remove_css_class ("record-button-success");
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
