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
    private Gtk.Label delay_remaining_label;

    public CountDownView (MainWindow window) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            window: window,
            margin: 6
        );
    }

    construct {
        delay_remaining_label = new Gtk.Label (null);
        delay_remaining_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        var label_grid = new Gtk.Grid ();
        label_grid.column_spacing = 6;
        label_grid.row_spacing = 6;
        label_grid.halign = Gtk.Align.CENTER;
        label_grid.attach (delay_remaining_label, 0, 1, 1, 1);

        pack_start (label_grid, false, false);
    }

    public void start_count () {
        int delay_remaining_time = Application.settings.get_int ("delay");

        // Show initial delay_remaining_time
        delay_remaining_label.label = delay_remaining_time.to_string ();

        // Decrease delay_remaining_time per seconds
        Timeout.add (1000, () => {
            delay_remaining_time--;

            // Show the decreased delay_remaining_time
            delay_remaining_label.label = delay_remaining_time.to_string ();

            // Start recording when delay_remaining_time turns 0
            if (delay_remaining_time == 0) {
                window.show_record ();
                return false;
            }

            return true;
        });
    }
}
