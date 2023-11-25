/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class CountDownView : AbstractView {
    public signal void countdown_cancelled ();
    public signal void countdown_ended ();

    private Gtk.Label delay_remaining_label;
    private Gtk.Button pause_button;

    private bool is_paused;
    private CountDownTimer delaytimer;

    public CountDownView () {
    }

    construct {
        delaytimer = new CountDownTimer () {
            to_string_func = delaytimer_strfunc
        };

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
        cancel_button.add_css_class ("borderless-button");

        pause_button = new Gtk.Button () {
            halign = Gtk.Align.END
        };
        pause_button.add_css_class ("borderless-button");

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

        delaytimer.ticked.connect (() => {
            delay_remaining_label.label = delaytimer.to_string ();
        });
        delaytimer.ended.connect (() => {
            stop_countdown ();
            countdown_ended ();
        });

        cancel_button.clicked.connect (() => {
            stop_countdown ();
            countdown_cancelled ();
        });

        pause_button.clicked.connect (() => {
            if (!is_paused) {
                stop_countdown ();
                pause_button_set_resume ();
            } else {
                start_countdown ();
                pause_button_set_pause ();
            }
        });
    }

    public void init_countdown () {
        delaytimer.init ();

        uint delay_length = Application.settings.get_uint ("delay");
        delaytimer.seek (delay_length);
        delay_remaining_label.label = delaytimer.to_string ();

        pause_button_set_pause ();
    }

    public void start_countdown () {
        is_paused = false;
        delaytimer.start ();
    }

    public void stop_countdown () {
        is_paused = true;
        delaytimer.stop ();
    }

    private string delaytimer_strfunc (TimeSpan time_usec) {
        TimeSpan remain = time_usec;
        var time = TimerTime ();

        time.seconds = remain / TimeSpan.SECOND;

        return ("%" + int64.FORMAT).printf (time.seconds);
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
