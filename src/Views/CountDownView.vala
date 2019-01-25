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

public class CountDownView : Gtk.Box {
    public MainWindow window { get; construct; }
    private Gtk.Label recording_label;

    public CountDownView (MainWindow window) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            window: window,
            margin: 6
        );
    }

    construct {
        recording_label = new Gtk.Label (null);
        recording_label.get_style_context ().add_class ("h2");

        var label_grid = new Gtk.Grid ();
        label_grid.column_spacing = 6;
        label_grid.row_spacing = 6;
        label_grid.halign = Gtk.Align.CENTER;
        label_grid.attach (recording_label, 0, 1, 1, 1);

        pack_start (label_grid, false, false);
    }

    public void start_count () {
        int remaining_time = Application.settings.get_int ("delay");

        // Show initial remaining_time
        recording_label.label = remaining_time.to_string ();

        // Decrease remaining_time per seconds
        Timeout.add (1000, () => {
            remaining_time--;

            // Show the decreased remaining_time
            recording_label.label = remaining_time.to_string ();

            // Start recording when remaining_time turns 0
            if (remaining_time == 0) {
                window.show_record ();
                return false;
            }

            return true;
        });
    }
}
