/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2025 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class View.WelcomeView : AbstractView {
    public signal void start_recording (uint delay_sec);

    private unowned Manager.DeviceManager device_manager;

    private uint record_button_timeout_color = 0;
    private uint record_button_timeout_icon = 0;

    private Ryokucha.DropDownText source_combobox;
    private Ryokucha.DropDownText mic_combobox;
    private Gtk.SpinButton delay_spin;
    private Gtk.Switch autosave_switch;
    private Widget.FolderChooserButton destination_chooser_button;
    private Gtk.Button record_button;

    public WelcomeView () {
    }

    construct {
        device_manager = Manager.DeviceManager.get_default ();

        var source_header_label = new Gtk.Label (_("Source")) {
            halign = Gtk.Align.START
        };
        source_header_label.add_css_class ("title-4");

        var source_label = new Gtk.Label (_("Record from:")) {
            halign = Gtk.Align.END
        };
        source_combobox = new Ryokucha.DropDownText () {
            halign = Gtk.Align.START
        };
        source_combobox.append ("mic", _("Microphone"));
        source_combobox.append ("system", _("System"));
        source_combobox.append ("both", _("Both"));

        var mic_label = new Gtk.Label (_("Microphone:")) {
            halign = Gtk.Align.END
        };
        mic_combobox = new Ryokucha.DropDownText () {
            halign = Gtk.Align.START,
            // Ellipsize if device name is long; otherwise the app window get stretched
            max_width_chars = 20,
            ellipsize = Pango.EllipsizeMode.END
        };

        var channels_label = new Gtk.Label (_("Channels:")) {
            halign = Gtk.Align.END
        };
        var channels_combobox = new Ryokucha.DropDownText () {
            halign = Gtk.Align.START
        };
        channels_combobox.append ("mono", _("Mono"));
        channels_combobox.append ("stereo", _("Stereo"));

        var timer_header_label = new Gtk.Label (_("Timer")) {
            halign = Gtk.Align.START
        };
        timer_header_label.add_css_class ("title-4");

        var delay_label = new Gtk.Label (_("Delay in seconds:")) {
            halign = Gtk.Align.END
        };
        delay_spin = new Gtk.SpinButton.with_range (0, 15, 1) {
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

        var saving_header_label = new Gtk.Label (_("Saving")) {
            halign = Gtk.Align.START
        };
        saving_header_label.add_css_class ("title-4");

        var format_label = new Gtk.Label (_("Format:")) {
            halign = Gtk.Align.END
        };

        var format_combobox = new Ryokucha.DropDownText () {
            halign = Gtk.Align.START
        };
        format_combobox.append ("alac", _("ALAC"));
        format_combobox.append ("flac", _("FLAC"));
        format_combobox.append ("mp3", _("MP3"));
        format_combobox.append ("ogg", _("Ogg Vorbis"));
        format_combobox.append ("opus", _("Opus"));
        format_combobox.append ("wav", _("WAV"));

        var autosave_label = new Gtk.Label (_("Automatically save files:")) {
            halign = Gtk.Align.END
        };

        autosave_switch = new Gtk.Switch () {
            halign = Gtk.Align.START,
            active = false
        };

        destination_chooser_button = new Widget.FolderChooserButton (
            _("Select destination…"),
            _("Choose a default destination"),
            _("Select")
        ) {
            halign = Gtk.Align.START,
            tooltip_text = _("Choose a default destination")
        };

        string autosave_path = Application.settings.get_string ("autosave-destination");
        if (check_path_is_dir (autosave_path)) {
            autosave_switch.active = true;
            destination_chooser_button.label = Path.get_basename (autosave_path);
        }

        var settings_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6,
            halign = Gtk.Align.CENTER
        };
        settings_grid.attach (source_header_label, 0, 0, 1, 1);
        settings_grid.attach (source_label, 0, 1, 1, 1);
        settings_grid.attach (source_combobox, 1, 1, 1, 1);
        settings_grid.attach (mic_label, 0, 2, 1, 1);
        settings_grid.attach (mic_combobox, 1, 2, 1, 1);
        settings_grid.attach (channels_label, 0, 3, 1, 1);
        settings_grid.attach (channels_combobox, 1, 3, 1, 1);
        settings_grid.attach (timer_header_label, 0, 4, 1, 1);
        settings_grid.attach (delay_label, 0, 5, 1, 1);
        settings_grid.attach (delay_spin, 1, 5, 1, 1);
        settings_grid.attach (length_label, 0, 6, 1, 1);
        settings_grid.attach (length_spin, 1, 6, 1, 1);
        settings_grid.attach (saving_header_label, 0, 7, 1, 1);
        settings_grid.attach (format_label, 0, 8, 1, 1);
        settings_grid.attach (format_combobox, 1, 8, 1, 1);
        settings_grid.attach (autosave_label, 0, 9, 1, 1);
        settings_grid.attach (autosave_switch, 1, 9, 1, 1);
        settings_grid.attach (destination_chooser_button, 1, 10, 1, 1);

        record_button = new Gtk.Button () {
            icon_name = "audio-input-microphone-symbolic",
            tooltip_text = _("Start recording"),
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
        Application.settings.bind ("source", source_combobox, "active-id", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("format", format_combobox, "active-id", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("channel", channels_combobox, "active-id", SettingsBindFlags.DEFAULT);
        // Make mic_combobox insensitive if selected source is "system" and sensitive otherwise
        source_combobox.bind_property ("active-id", mic_combobox, "sensitive",
            BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
            (binding, from_value, ref to_value) => {
                var active_id = (string) from_value;
                to_value.set_boolean (active_id != "system");
                return true;
            }
        );
        mic_combobox.dropdown.bind_property ("selected", device_manager, "selected-source-index",
            BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE
        );

        var event_controller = new Gtk.EventControllerKey ();
        event_controller.key_pressed.connect ((keyval, keycode, state) => {
            if (Gdk.ModifierType.CONTROL_MASK in state) {
                switch (keyval) {
                    case Gdk.Key.R:
                        if (Gdk.ModifierType.SHIFT_MASK in state) {
                            // Only start recording when recording source is connected
                            bool is_connected = get_is_source_connected ();
                            if (is_connected) {
                                start_recording ((uint) delay_spin.value);
                            }

                            return Gdk.EVENT_STOP;
                        }

                        break;
                    default:
                        break;
                }
            }

            return Gdk.EVENT_PROPAGATE;
        });
        ((Gtk.Widget) this).add_controller (event_controller);

        source_combobox.changed.connect (() => {
            record_button.sensitive = get_is_source_connected ();
        });

        autosave_switch.notify["active"].connect (toggle_autosave);

        destination_chooser_button.folder_set.connect (remember_autosave_dir);

        record_button.clicked.connect (() => {
            start_recording ((uint) delay_spin.value);
        });

        device_manager.device_updated.connect (() => {
            record_button.sensitive = get_is_source_connected ();
            update_mic_combobox ();
        });
    }

    private async void toggle_autosave () {
        if (autosave_switch.active) {
            // Prevent the filechooser shown twice when enabling the autosaving
            var autosave_dest = Application.settings.get_string ("autosave-destination");
            if (autosave_dest.length != 0) {
                return;
            }

            // Let the user select the autosaving destination
            bool ret = yield destination_chooser_button.present_chooser ();
            if (!ret) {
                autosave_switch.active = false;
            }
        } else {
            // Clear the current destination and disable autosaving
            Application.settings.reset ("autosave-destination");
            destination_chooser_button.label = _("Select destination…");
        }
    }

    private void remember_autosave_dir (File file) {
        string path = file.get_path ();
        Application.settings.set_string ("autosave-destination", path);
        destination_chooser_button.label = Path.get_basename (path);
        autosave_switch.active = true;
    }

    private bool check_path_is_dir (string path) {
        if (path.length == 0) {
            return false;
        }

        var file = File.new_for_path (path);
        if (!file.query_exists ()) {
            DirUtils.create_with_parents (path, 0775);
        }

        return true;
    }

    public void succeeded_animation_begin () {
        record_button.add_css_class ("record-button-success");
        record_button.icon_name = "record-completed-symbolic";
        record_button_timeout_color = Timeout.add_once (3000, () => {
            record_button.remove_css_class ("record-button-success");
            record_button_timeout_color = 0;
        });
        record_button_timeout_icon = Timeout.add_once (3250, () => {
            record_button.icon_name = "audio-input-microphone-symbolic";
            record_button_timeout_icon = 0;
        });
    }

    public void succeeded_animation_end () {
        if (record_button_timeout_color != 0) {
            Source.remove (record_button_timeout_color);
            record_button_timeout_color = 0;
            record_button.remove_css_class ("record-button-success");
        }

        if (record_button_timeout_icon != 0) {
            Source.remove (record_button_timeout_icon);
            record_button_timeout_icon = 0;
            record_button.icon_name = "audio-input-microphone-symbolic";
        }
    }

    private bool get_is_source_connected () {
        switch (source_combobox.active_id) {
            case "mic":
                return (device_manager.sources.size > 0);
            case "system":
                return (device_manager.sinks.size > 0);
            case "both":
                return (device_manager.sources.size > 0) && (device_manager.sinks.size > 0);
            default:
                assert_not_reached ();
        }
    }

    private void update_mic_combobox () {
        mic_combobox.remove_all ();

        foreach (Gst.Device device in device_manager.sources) {
            mic_combobox.append (null, device.display_name);
        }
    }
}
