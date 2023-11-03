/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class RecordView : Gtk.Box {
    public signal void cancel_recording ();
    public signal void stop_recording ();

    private struct TimerTime {
        TimeSpan hours;
        TimeSpan minutes;
        TimeSpan seconds;
    }

    private Recorder recorder;

    private Gtk.Label time_label;
    private Gtk.Label remaining_time_label;
    private Gtk.Button stop_button;
    private Gtk.Button pause_button;

    private CountUpTimer uptimer;
    private CountDownTimer downtimer;

    public RecordView () {
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
        recorder = Recorder.get_default ();

        time_label = new Gtk.Label (null);
        time_label.add_css_class (Granite.STYLE_CLASS_H2_LABEL);

        remaining_time_label = new Gtk.Label (null);
        remaining_time_label.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        var label_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6,
            halign = Gtk.Align.CENTER
        };
        label_grid.attach (time_label, 0, 1, 1, 1);
        label_grid.attach (remaining_time_label, 0, 2, 1, 1);

        var levelbar = new LevelBar ();

        var cancel_button = new Gtk.Button () {
            icon_name = "user-trash-symbolic",
            tooltip_text = _("Cancel recording"),
            halign = Gtk.Align.START
        };
        cancel_button.add_css_class ("buttons-without-border");

        stop_button = new Gtk.Button () {
            icon_name = "media-playback-stop-symbolic",
            tooltip_markup = Granite.markup_accel_tooltip ({"<Shift><Ctrl>R"}, _("Finish recording")),
            halign = Gtk.Align.CENTER,
            width_request = 48,
            height_request = 48
        };
        stop_button.add_css_class ("record-button");
        ((Gtk.Image) stop_button.child).icon_size = Gtk.IconSize.LARGE;

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
                            trigger_stop_recording ();
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

        cancel_button.clicked.connect (() => {
            stop_count ();
            cancel_recording ();
        });

        stop_button.clicked.connect (() => {
            trigger_stop_recording ();
        });

        pause_button.clicked.connect (() => {
            if (recorder.state == Recorder.RecordingState.RECORDING) {
                stop_count ();
                recorder.state = Recorder.RecordingState.PAUSED;
                pause_button_set_resume ();
            } else {
                start_count ();
                recorder.state = Recorder.RecordingState.RECORDING;
                pause_button_set_pause ();
            }
        });

        uptimer = new CountUpTimer () {
            to_string_func = uptimer_strfunc
        };
        uptimer.ticked.connect (() => {
            time_label.label = uptimer.to_string ();
        });

        downtimer = new CountDownTimer () {
            to_string_func = downtimer_strfunc
        };
        downtimer.ticked.connect (() => {
            remaining_time_label.label = downtimer.to_string ();
        });
        downtimer.ended.connect (() => {
            trigger_stop_recording ();
        });
    }

    private void trigger_stop_recording () {
        stop_count ();
        stop_recording ();
    }

    public void init_count () {
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

        pause_button_set_pause ();
    }

    public void start_count () {
        uptimer.start ();
        if (downtimer.is_seeked) {
            downtimer.start ();
        }
    }

    public void stop_count () {
        uptimer.stop ();
        downtimer.stop ();
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

    private void pause_button_set_pause () {
        pause_button.icon_name = "media-playback-pause-symbolic";
        pause_button.tooltip_text = _("Pause recording");
    }

    private void pause_button_set_resume () {
        pause_button.icon_name = "media-playback-start-symbolic";
        pause_button.tooltip_text = _("Resume recording");
    }
}
