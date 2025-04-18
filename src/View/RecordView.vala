/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2025 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class View.RecordView : AbstractView {
    public signal void cancel_recording ();
    public signal void stop_recording ();
    public signal void pause_recording ();
    public signal void resume_recording ();

    private Gtk.Label time_label;
    private Gtk.Label remaining_time_label;
    private Widget.LevelBar levelbar;
    private Gtk.Button pause_button;

    private bool is_recording;
    private Model.Timer.CountUpTimer uptimer;
    private Model.Timer.CountDownTimer downtimer;

    public RecordView () {
    }

    construct {
        uptimer = new Model.Timer.CountUpTimer () {
            to_string_func = uptimer_strfunc
        };

        downtimer = new Model.Timer.CountDownTimer () {
            to_string_func = downtimer_strfunc
        };

        time_label = new Gtk.Label (null);
        time_label.add_css_class ("title-2");

        remaining_time_label = new Gtk.Label (null);
        remaining_time_label.add_css_class ("title-3");

        var label_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6,
            halign = Gtk.Align.CENTER
        };
        label_grid.attach (time_label, 0, 1, 1, 1);
        label_grid.attach (remaining_time_label, 0, 2, 1, 1);

        levelbar = new Widget.LevelBar ();

        var cancel_button = new Gtk.Button () {
            icon_name = "user-trash-symbolic",
            tooltip_text = _("Cancel recording"),
            halign = Gtk.Align.START
        };
        cancel_button.add_css_class ("borderless-button");

        var stop_button = new Gtk.Button () {
            icon_name = "media-playback-stop-symbolic",
            tooltip_text = _("Finish recording"),
            halign = Gtk.Align.CENTER,
            width_request = 48,
            height_request = 48
        };
        stop_button.add_css_class ("record-button");
        ((Gtk.Image) stop_button.child).icon_size = Gtk.IconSize.LARGE;

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
        buttons_grid.attach (stop_button, 1, 0, 1, 1);
        buttons_grid.attach (pause_button, 2, 0, 1, 1);

        append (label_grid);
        append (levelbar);
        append (buttons_grid);

        var event_controller = new Gtk.EventControllerKey ();
        event_controller.key_pressed.connect ((keyval, keycode, state) => {
            if (Gdk.ModifierType.CONTROL_MASK in state) {
                switch (keyval) {
                    case Gdk.Key.R:
                        if (Gdk.ModifierType.SHIFT_MASK in state) {
                            refresh_end ();
                            stop_recording ();
                            return Gdk.EVENT_STOP;
                        }

                        break;
                    default:
                        break;
                }
            }

            return Gdk.EVENT_PROPAGATE;
        });
        ((Gtk.Widget) this).add_controller (event_controller);

        uptimer.ticked.connect (() => {
            time_label.label = uptimer.to_string ();
        });

        downtimer.ticked.connect (() => {
            remaining_time_label.label = downtimer.to_string ();
        });
        downtimer.ended.connect (() => {
            refresh_end ();
            stop_recording ();
        });

        cancel_button.clicked.connect (() => {
            refresh_end ();
            cancel_recording ();
        });

        stop_button.clicked.connect (() => {
            refresh_end ();
            stop_recording ();
        });

        pause_button.clicked.connect (() => {
            if (is_recording) {
                is_recording = false;
                refresh_pause ();
                pause_recording ();
            } else {
                is_recording = true;
                refresh_resume ();
                resume_recording ();
            }
        });
    }

    private double get_current_peak () {
        unowned var recorder = Model.Recorder.get_default ();
        return recorder.current_peak;
    }

    public void refresh_begin () {
        is_recording = true;

        uptimer.init ();
        downtimer.init ();

        time_label.label = uptimer.to_string ();

        uint record_length = Application.settings.get_uint ("length");
        if (record_length > 0) {
            downtimer.seek (record_length);
            remaining_time_label.label = downtimer.to_string ();
        } else {
            // Hide the label
            remaining_time_label.label = null;
        }

        levelbar.refresh_begin (get_current_peak);

        refresh_resume ();
    }

    public void refresh_end () {
        is_recording = false;

        refresh_pause ();

        levelbar.refresh_end ();
    }

    private void refresh_pause () {
        uptimer.stop ();
        downtimer.stop ();

        pause_button.icon_name = "media-playback-start-symbolic";
        pause_button.tooltip_text = _("Resume recording");

        levelbar.refresh_pause ();
    }

    private void refresh_resume () {
        uptimer.start ();
        if (downtimer.is_seeked) {
            downtimer.start ();
        }

        pause_button.icon_name = "media-playback-pause-symbolic";
        pause_button.tooltip_text = _("Pause recording");

        levelbar.refresh_resume ();
    }

    private string uptimer_strfunc (TimeSpan time_usec) {
        TimeSpan remain = time_usec;
        var time = TimerTime ();

        time.hours = remain / TimeSpan.HOUR;
        remain %= TimeSpan.HOUR;
        time.minutes = remain / TimeSpan.MINUTE;
        remain %= TimeSpan.MINUTE;
        time.seconds = remain / TimeSpan.SECOND;

        return ("%02" + int64.FORMAT + ":%02" + int64.FORMAT + ":%02" + int64.FORMAT)
            .printf (time.hours, time.minutes, time.seconds);
    }

    private string downtimer_strfunc (TimeSpan time_usec) {
        TimeSpan remain = time_usec;
        var time = TimerTime ();

        time.minutes = remain / TimeSpan.MINUTE;
        remain %= TimeSpan.MINUTE;
        time.seconds = remain / TimeSpan.SECOND;

        return ("%02" + int64.FORMAT + ":%02" + int64.FORMAT).printf (time.minutes, time.seconds);
    }
}
