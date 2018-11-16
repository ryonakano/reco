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

        stop_button = new Gtk.Button ();
        stop_button.image = new Gtk.Image.from_icon_name ("media-playback-stop-symbolic", Gtk.IconSize.DND);
        stop_button.tooltip_text = "Stop recording";
        stop_button.get_style_context ().add_class ("record-button");
        stop_button.halign = Gtk.Align.CENTER;
        stop_button.margin_top = 12;
        stop_button.width_request = 48;
        stop_button.height_request = 48;

        pack_start (label_grid, false, false);
        pack_end (stop_button, false, false);

        stop_button.clicked.connect (() => {
            window.show_welcome ();
        });
    }
}
