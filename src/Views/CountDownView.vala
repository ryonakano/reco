/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class CountDownView : Gtk.Box {
    public signal void cancelled ();
    public signal void ended ();

    private Gtk.Label delay_remaining_label;
    private Gtk.Button pause_button;

    private uint delay_remaining_time;
    private uint countdown;
    private bool is_paused;

    public CountDownView () {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            margin_top: 6,
            margin_bottom: 6,
            margin_start: 6,
            margin_end: 6
        );
    }

    construct {
        delay_remaining_label = new Gtk.Label (null);
        delay_remaining_label.add_css_class (Granite.STYLE_CLASS_H2_LABEL);

        var label_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6,
            halign = Gtk.Align.CENTER,
            vexpand = true
        };
        label_grid.attach (delay_remaining_label, 0, 1, 1, 1);

        var cancel_button = new Gtk.Button () {
            icon_name = "user-trash-symbolic",
            tooltip_text = _("Cancel the countdown"),
            halign = Gtk.Align.START
        };
        cancel_button.add_css_class ("buttons-without-border");

        pause_button = new Gtk.Button () {
            halign = Gtk.Align.END
        };
        pause_button.add_css_class ("buttons-without-border");

        var buttons_grid = new Gtk.Grid () {
            column_spacing = 30,
            row_spacing = 6,
            margin_top = 12,
            halign = Gtk.Align.CENTER
        };
        buttons_grid.attach (cancel_button, 0, 0, 1, 1);
        buttons_grid.attach (pause_button, 1, 0, 1, 1);

        append (label_grid);
        append (buttons_grid);

        cancel_button.clicked.connect (() => {
            stop_countdown ();
            cancelled ();
        });

        pause_button.clicked.connect (() => {
            toggle_countdown ();
        });
    }

    public void init_countdown () {
        delay_remaining_time = Application.settings.get_uint ("delay");

        // Show initial delay_remaining_time
        delay_remaining_label.label = "%u".printf (delay_remaining_time);

        pause_button_set_pause ();
    }

    public void start_countdown () {
        is_paused = false;
        // Decrease delay_remaining_time per seconds
        countdown = Timeout.add (1000, () => {
            // If the user pressed "pause", do not count this second.
            if (is_paused) {
                return false;
            }

            delay_remaining_time--;

            // Show the decreased delay_remaining_time
            delay_remaining_label.label = "%u".printf (delay_remaining_time);

            // Start recording when delay_remaining_time turns 0
            if (delay_remaining_time == 0) {
                stop_countdown ();
                ended ();
                return false;
            }

            return true;
        });
    }

    public void stop_countdown () {
        is_paused = true;
        if (countdown != 0) {
            Source.remove (countdown);
            countdown = 0;
        }
    }

    private void toggle_countdown () {
        if (!is_paused) {
            stop_countdown ();
            pause_button_set_resume ();
        } else {
            start_countdown ();
            pause_button_set_pause ();
        }
    }

    private void pause_button_set_pause () {
        pause_button.icon_name = "media-playback-pause-symbolic";
        pause_button.tooltip_text = _("Pause the countdown");
    }

    private void pause_button_set_resume () {
        pause_button.icon_name = "media-playback-start-symbolic";
        pause_button.tooltip_text = _("Resume the countdown");
    }
}
