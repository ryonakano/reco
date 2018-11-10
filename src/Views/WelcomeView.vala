/*
* Copyright (c) 2018 Reco Developers
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
    private Gtk.ComboBoxText format_combobox;
    private Gtk.SpinButton delay_spin;
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
        var format_label = new Gtk.Label ("Format:");
        format_label.xalign = 1;
        format_combobox = new Gtk.ComboBoxText ();
        format_combobox.append ("Ogg", "Ogg");
        format_combobox.append ("MP3", "MP3");
        format_combobox.active_id = "Ogg";

        var delay_label = new Gtk.Label ("Delay in seconds:");
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
        var close_button = new Gtk.Button.with_label ("Close");

        record_button = new Gtk.Button.with_label ("Start Recording");
        record_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var recording_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        recording_box.margin_top = 24;
        recording_box.spacing = 6;
        recording_box.halign = Gtk.Align.END;
        recording_box.add (close_button);
        recording_box.add (record_button);

        pack_start (settings_grid, false, false);
        pack_end (recording_box, false, false);

        record_button.clicked.connect (() => {
            window.show_record ();
        });
        close_button.clicked.connect (() => {
            window.destroy ();
        });
    }
}
