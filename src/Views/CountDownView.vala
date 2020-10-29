/*
* Copyright 2018-2020 Ryo Nakano
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
    private Gtk.Button pause_button;
    private uint paused_time;
    private uint delay_remaining_time;
    private uint countdown;
    private bool is_paused;

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

        var label_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6,
            halign = Gtk.Align.CENTER
        };
        label_grid.attach (delay_remaining_label, 0, 1, 1, 1);

        var cancel_button = new Gtk.Button () {
            image = new Gtk.Image.from_icon_name ("user-trash-symbolic", Gtk.IconSize.BUTTON),
            tooltip_text = _("Cancel the countdown"),
            halign = Gtk.Align.START
        };
        cancel_button.get_style_context ().add_class ("buttons-without-border");

        pause_button = new Gtk.Button () {
            image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON),
            tooltip_text = _("Pause the countdown"),
            halign = Gtk.Align.END
        };
        pause_button.get_style_context ().add_class ("buttons-without-border");

        var buttons_grid = new Gtk.Grid () {
            column_spacing = 30,
            row_spacing = 6,
            margin_top = 12,
            halign = Gtk.Align.CENTER
        };
        buttons_grid.attach (cancel_button, 0, 0, 1, 1);
        buttons_grid.attach (pause_button, 1, 0, 1, 1);

        pack_start (label_grid, false, false);
        pack_end (buttons_grid, false, false);

        cancel_button.clicked.connect (() => {
            paused_time = 0;
            cancel_countdown ();
        });

        pause_button.clicked.connect (() => {
            pause_countdown ();
        });
    }

    public void start_countdown () {
        is_paused = false;
        delay_remaining_time = init_delay_remaining_time ();

        // Show initial delay_remaining_time
        delay_remaining_label.label = delay_remaining_time.to_string ();

        // Decrease delay_remaining_time per seconds
        countdown = Timeout.add (1000, () => {
            // If the user pressed "pause", do not count this second.
            if (is_paused) {
                return false;
            }

            delay_remaining_time--;
            paused_time = delay_remaining_time;

            // Show the decreased delay_remaining_time
            delay_remaining_label.label = delay_remaining_time.to_string ();

            // Start recording when delay_remaining_time turns 0
            if (delay_remaining_time == 0) {
                window.show_record ();
                delay_remaining_label.label = null;
                return false;
            }

            return true;
        });
    }

    private void cancel_countdown () {
        // Immediately stop the countdown Timeout
        if (!is_paused) {
            Source.remove (countdown);
        }

        is_paused = true;

        if (countdown != 0) {
            countdown = 0;
            delay_remaining_time = init_delay_remaining_time ();
            delay_remaining_label.label = null;
        }

        pause_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
        pause_button.tooltip_text = _("Pause the countdown");

        window.show_welcome ();
    }

    private void pause_countdown () {
        if (!is_paused) {
            // Immediately stop the countdown Timeout - This avoids unnecessary callback
            Source.remove (countdown);

            is_paused = true;

            pause_button.image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
            pause_button.tooltip_text = _("Resume the countdown");
        } else {
            is_paused = false;

            if (paused_time != 0) {
                start_countdown ();
            }

            pause_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
            pause_button.tooltip_text = _("Pause the countdown");
        }
    }

    private uint init_delay_remaining_time () {
        return paused_time != 0 ? paused_time : Application.settings.get_uint ("delay");
    }
}
