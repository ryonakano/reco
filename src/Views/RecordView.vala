/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class RecordView : Gtk.Box {
    public signal void cancel_recording ();
    public signal void stop_recording ();

    private Recorder recorder;

    private Gtk.Label time_label;
    private Gtk.Label remaining_time_label;
    private Gtk.Button stop_button;
    private Gtk.Button pause_button;

    private uint count;
    private DateTime start_time;
    private DateTime end_time;
    private DateTime tick_time;

    private bool is_length_set;

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
                            var loop = new MainLoop ();
                            trigger_stop_recording.begin ((obj, res) => {
                                loop.quit ();
                            });
                            loop.run ();
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
            var loop = new MainLoop ();
            trigger_stop_recording.begin ((obj, res) => {
                loop.quit ();
            });
            loop.run ();
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
    }

    public async void trigger_stop_recording () {
        stop_count ();
        stop_recording ();
    }

    public void init_count () {
        /*
         * This is how we count time:
         *
         * start_time                          end_time
         *    ||<---------record_length--------->||
         *    ||          (if specified)         ||
         *    \/                                 \/
         * 09:45:12    09:45:13    9:45:14 ... 9:50:12
         *    /\
         *    ||
         * tick_time --> +1 per sec
         */
        start_time = new DateTime.now ();
        tick_time = start_time;

        uint record_length = Application.settings.get_uint ("length");
        end_time = start_time.add_seconds (record_length);
        // If start_time and end_time differs that means recording length being specified
        is_length_set = (start_time.compare (end_time) != 0);

        // Show initial time (00:00)
        show_timer_label (time_label, start_time, tick_time);
        if (start_time.compare (end_time) != 0) {
            show_timer_label (remaining_time_label, tick_time, end_time);
        } else {
            hide_timer_label (remaining_time_label);
        }

        pause_button_set_pause ();
    }

    public void start_count () {
        count = Timeout.add (1000, () => {
            // If the user pressed "pause", do not count this second.
            if (recorder.state != Recorder.RecordingState.RECORDING) {
                return false;
            }

            // Increment the elapsed time
            tick_time = tick_time.add (TimeSpan.SECOND);

            // Show the updated elapsed time
            show_timer_label (time_label, start_time, tick_time);
            // Show recording length
            if (is_length_set) {
                show_timer_label (remaining_time_label, tick_time, end_time);
            }

            // We consumed all of recording length so stop recording
            if (tick_time.compare (end_time) == 0) {
                var loop = new MainLoop ();
                trigger_stop_recording.begin ((obj, res) => {
                    loop.quit ();
                });
                loop.run ();
                return false;
            }

            return true;
        });
    }

    public void stop_count () {
        count = 0;
    }

    /*
     * DateTime does not have "subtract()", so calcurate the difference between start and end
     * and add it to 00:00
     */
    private void show_timer_label (Gtk.Label label, DateTime start, DateTime end) {
        TimeSpan diff = end.difference (start);

        var disp_time = new DateTime.local (start.get_year (), start.get_month (),
                                            start.get_day_of_month (), 0, 0, 0.0);
        disp_time = disp_time.add (diff);
        label.label = disp_time.format ("%M:%S");
    }

    private void hide_timer_label (Gtk.Label label) {
        label.label = null;
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
