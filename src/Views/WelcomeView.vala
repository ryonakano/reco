/*
* (C) 2018 Ryo Nakano
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
    public Gtk.ComboBoxText format_combobox { get; set; }
    public Gtk.SpinButton delay_spin { get; private set; }
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
        // Create settings widgets
        var format_label = new Gtk.Label (_("Format:"));
        format_label.xalign = 1;
        // TODO: Make it possible to record with various formats
        format_combobox = new Gtk.ComboBoxText ();
        format_combobox.append ("flac", _("FLAC"));
        format_combobox.append ("mp3", _("MP3"));
        format_combobox.append ("ogg", _("Ogg Vorbis"));
        format_combobox.append ("opus", _("Opus"));
        format_combobox.append ("wav", _("Wav"));
        format_combobox.active_id = "wav";

        var delay_label = new Gtk.Label (_("Delay in seconds:"));
        delay_label.xalign = 1;
        delay_spin = new Gtk.SpinButton.with_range (0, 15, 1);

        var settings_grid = new Gtk.Grid ();
        settings_grid.column_spacing = 6;
        settings_grid.row_spacing = 6;
        settings_grid.halign = Gtk.Align.CENTER;
        settings_grid.attach (format_label, 0, 1, 1, 1);
        settings_grid.attach (format_combobox, 1, 1, 1, 1);
        settings_grid.attach (delay_label, 0, 2, 1, 1);
        settings_grid.attach (delay_spin, 1, 2, 1, 1);

        // Create buttons
        record_button = new Gtk.Button ();
        record_button.image = new Gtk.Image.from_icon_name ("audio-input-microphone-symbolic", Gtk.IconSize.DND);
        record_button.tooltip_text = _("Start recording");
        record_button.get_style_context ().add_class ("record-button");
        record_button.halign = Gtk.Align.CENTER;
        record_button.margin_top = 12;
        record_button.width_request = 48;
        record_button.height_request = 48;

        pack_start (settings_grid, false, false);
        pack_end (record_button, false, false);

        record_button.clicked.connect (() => {
            if (delay_spin.value != 0) {
                window.show_countdown ();
            } else {
                window.show_record ();
            }
        });
    }
}
