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

public class RecordView : Gtk.Box {
    public MainWindow window { get; construct; }
    private Gtk.Button stop_button;

    public RecordView (MainWindow window) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            window: window,
            margin: 6
        );
    }

    construct {
        var recording_label = new Gtk.Label ("Recording…");
        recording_label.get_style_context ().add_class ("h2");

        var label_grid = new Gtk.Grid ();
        label_grid.column_spacing = 6;
        label_grid.row_spacing = 6;
        label_grid.halign = Gtk.Align.CENTER;
        label_grid.attach (recording_label, 0, 1, 1, 1);

        stop_button = new Gtk.Button.with_label ("Finish");
        stop_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var recording_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        recording_box.margin_top = 24;
        recording_box.spacing = 6;
        recording_box.halign = Gtk.Align.END;
        recording_box.add (stop_button);

        pack_start (label_grid, false, false);
        pack_end (recording_box, false, false);

        stop_button.clicked.connect (() => {
            window.show_welcome ();
        });
    }
}
