/*
* (C) 2019 Ryo Nakano
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

public class WelcomeView : Gtk.Box {
    public MainWindow window { get; construct; }
    private Gtk.Button record_button;

    public WelcomeView (MainWindow window) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            window: window,
            margin: 6
        );
    }

    construct {
        var behavior_header_label = new Granite.HeaderLabel (_("Recording"));

        var delay_label = new Gtk.Label (_("Delay in seconds:"));
        delay_label.halign = Gtk.Align.END;
        var delay_spin = new Gtk.SpinButton.with_range (0, 15, 1);
        delay_spin.halign = Gtk.Align.START;

        var length_label = new Gtk.Label (_("Length in seconds:"));
        length_label.halign = Gtk.Align.END;
        var length_spin = new Gtk.SpinButton.with_range (0, 600, 1);
        length_spin.halign = Gtk.Align.START;

        var system_sound_label = new Gtk.Label (_("Record from:"));
        system_sound_label.halign = Gtk.Align.END;
        var system_sound_combobox = new Gtk.ComboBoxText ();
        system_sound_combobox.halign = Gtk.Align.START;
        system_sound_combobox.append ("mic", _("Microphone"));
        system_sound_combobox.append ("pc", _("Computer"));
        system_sound_combobox.append ("both", _("Both"));

        var saving_header_label = new Granite.HeaderLabel (_("Saving"));

        var format_label = new Gtk.Label (_("Format:"));
        format_label.halign = Gtk.Align.END;

        var format_combobox = new Gtk.ComboBoxText ();
        format_combobox.halign = Gtk.Align.START;
        format_combobox.append ("aac", _("AAC"));
        format_combobox.append ("flac", _("FLAC"));
        format_combobox.append ("mp3", _("MP3"));
        format_combobox.append ("ogg", _("Ogg Vorbis"));
        format_combobox.append ("opus", _("Opus"));
        format_combobox.append ("wav", _("WAV"));

        var auto_save_label = new Gtk.Label (_("Automatically save files:"));
        auto_save_label.halign = Gtk.Align.END;

        var auto_save_switch = new Gtk.Switch ();
        auto_save_switch.halign = Gtk.Align.START;

        var destination_chooser = new Gtk.FileChooserButton (
            _("Choose a default destination"),
            Gtk.FileChooserAction.SELECT_FOLDER);
        destination_chooser.halign = Gtk.Align.START;
        destination_chooser.set_filename (get_destination ());

        var settings_grid = new Gtk.Grid ();
        settings_grid.column_spacing = 6;
        settings_grid.row_spacing = 6;
        settings_grid.halign = Gtk.Align.CENTER;
        settings_grid.attach (behavior_header_label, 0, 0, 1, 1);
        settings_grid.attach (delay_label, 0, 1, 1, 1);
        settings_grid.attach (delay_spin, 1, 1, 1, 1);
        settings_grid.attach (length_label, 0, 2, 1, 1);
        settings_grid.attach (length_spin, 1, 2, 1, 1);
        settings_grid.attach (system_sound_label, 0, 3, 1, 1);
        settings_grid.attach (system_sound_combobox, 1, 3, 1, 1);
        settings_grid.attach (saving_header_label, 0, 4, 1, 1);
        settings_grid.attach (format_label, 0, 5, 1, 1);
        settings_grid.attach (format_combobox, 1, 5, 1, 1);
        settings_grid.attach (auto_save_label, 0, 6, 1, 1);
        settings_grid.attach (auto_save_switch, 1, 6, 1, 1);
        settings_grid.attach (destination_chooser, 1, 7, 1, 1);

        record_button = new Gtk.Button ();
        record_button.image = new Gtk.Image.from_icon_name ("audio-input-microphone-symbolic", Gtk.IconSize.DND);
        record_button.tooltip_markup = Granite.markup_accel_tooltip ({"<Shift><Ctrl>R"}, _("Start recording"));
        record_button.get_style_context ().add_class ("record-button");
        record_button.halign = Gtk.Align.CENTER;
        record_button.margin_top = 12;
        record_button.width_request = 48;
        record_button.height_request = 48;

        pack_start (settings_grid, false, false);
        pack_end (record_button, false, false);

        Application.settings.bind ("delay", delay_spin, "value", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("length", length_spin, "value", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("device", system_sound_combobox, "active_id", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("format", format_combobox, "active_id", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("auto-save", auto_save_switch, "active", SettingsBindFlags.DEFAULT);
        Application.settings.bind ("auto-save", destination_chooser, "sensitive", SettingsBindFlags.DEFAULT);

        destination_chooser.file_set.connect (() => {
            Application.settings.set_string ("destination", destination_chooser.get_filename ());
        });

        record_button.clicked.connect (() => {
            trigger_recording ();
        });
    }

    private string get_destination () {
        string destination = Application.settings.get_string ("destination");

        if (destination == "") {
            ///TRANSLATORS: The name of the folder which recordings are saved
            destination = Environment.get_home_dir () + "/%s".printf (_("Recordings"));
            Application.settings.set_string ("destination", destination);
        }

        if (destination != null) {
            DirUtils.create_with_parents (destination, 0775);
        }

        return destination;
    }

    public void show_success_button () {
        record_button.get_style_context ().add_class ("record-button-success");
        record_button.image = new Gtk.Image.from_icon_name ("record-completed-symbolic", Gtk.IconSize.DND);
        uint timeout_button_color = Timeout.add (3000, () => {
            record_button.get_style_context ().remove_class ("record-button-success");
            return false;
        });
        timeout_button_color = 0;
        uint timeout_button_icon = Timeout.add (3250, () => {
            record_button.image = new Gtk.Image.from_icon_name ("audio-input-microphone-symbolic", Gtk.IconSize.DND);
            return false;
        });
        timeout_button_icon = 0;
    }

    public void trigger_recording () {
        if (Application.settings.get_int ("delay") != 0) {
            window.show_countdown ();
        } else {
            window.show_record ();
        }
    }
}
