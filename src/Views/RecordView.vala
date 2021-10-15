/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2021 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class RecordView : Gtk.Box {
    public MainWindow window { get; construct; }
    private Recorder recorder;

    private Gtk.Label time_label;
    private Gtk.Label remaining_time_label;
    private Gtk.Button stop_button;
    private Gtk.Button pause_button;
    private uint count;
    private uint countdown;
    private uint past_minutes_10;
    private uint past_minutes_1;
    private uint past_seconds_10;
    private uint past_seconds_1;
    private uint remain_minutes_10;
    private uint remain_minutes_1;
    private uint remain_seconds_10;
    private uint remain_seconds_1;

    public RecordView (MainWindow window) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            window: window,
            margin: 6
        );
    }

    construct {
        recorder = Recorder.get_default ();

        time_label = new Gtk.Label (null);
        time_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        remaining_time_label = new Gtk.Label (null);
        remaining_time_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var label_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6,
            halign = Gtk.Align.CENTER
        };
        label_grid.attach (time_label, 0, 1, 1, 1);
        label_grid.attach (remaining_time_label, 0, 2, 1, 1);

        var cancel_button = new Gtk.Button () {
            image = new Gtk.Image.from_icon_name ("user-trash-symbolic", Gtk.IconSize.BUTTON),
            tooltip_text = _("Cancel recording"),
            halign = Gtk.Align.START
        };
        cancel_button.get_style_context ().add_class ("buttons-without-border");

        stop_button = new Gtk.Button () {
            image = new Gtk.Image.from_icon_name ("media-playback-stop-symbolic", Gtk.IconSize.DND),
            tooltip_markup = Granite.markup_accel_tooltip ({"<Shift><Ctrl>R"}, _("Finish recording")),
            halign = Gtk.Align.CENTER,
            width_request = 48,
            height_request = 48
        };
        stop_button.get_style_context ().add_class ("record-button");

        pause_button = new Gtk.Button () {
            image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON),
            tooltip_text = _("Pause recording"),
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
        buttons_grid.attach (stop_button, 1, 0, 1, 1);
        buttons_grid.attach (pause_button, 2, 0, 1, 1);

        pack_start (label_grid, false, false);
        pack_end (buttons_grid, false, false);

        cancel_button.clicked.connect (() => {
            stop_count ();

            // If a user tries to cancel recording while pausing, resume recording once and reset the button icon
            if (!recorder.is_recording) {
                pause_button.image = new Gtk.Image.from_icon_name (
                    "media-playback-pause-symbolic", Gtk.IconSize.BUTTON
                );
                pause_button.tooltip_text = _("Pause recording");
            }

            recorder.cancel_recording ();
            window.show_welcome ();
        });

        stop_button.clicked.connect (() => {
            var loop = new MainLoop ();
            trigger_stop_recording.begin ((obj, res) => {
                loop.quit ();
            });
            loop.run ();
        });

        pause_button.clicked.connect (() => {
            if (recorder.is_recording) {
                stop_count ();

                recorder.set_recording_state (Gst.State.PAUSED);
                pause_button.image = new Gtk.Image.from_icon_name (
                    "media-playback-start-symbolic", Gtk.IconSize.BUTTON
                );
                pause_button.tooltip_text = _("Resume recording");
            } else {
                start_count ();

                if (Application.settings.get_uint ("length") != 0) {
                    start_countdown ();
                }

                recorder.set_recording_state (Gst.State.PLAYING);
                pause_button.image = new Gtk.Image.from_icon_name (
                    "media-playback-pause-symbolic", Gtk.IconSize.BUTTON
                );
                pause_button.tooltip_text = _("Pause recording");
            }
        });
    }

    public async void trigger_stop_recording () {
        stop_count ();

        // If a user tries to stop recording while pausing, resume recording once and reset the button icon
        if (!recorder.is_recording) {
            recorder.set_recording_state (Gst.State.PLAYING);
            pause_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
            pause_button.tooltip_text = _("Pause recording");
        }

        recorder.stop_recording ();
        window.show_welcome ();
    }

    public void init_count () {
        past_minutes_10 = 0;
        past_minutes_1 = 0;
        past_seconds_10 = 0;
        past_seconds_1 = 0;

        // Show initial time (00:00)
        show_timer_label (time_label, past_minutes_10, past_minutes_1, past_seconds_10, past_seconds_1);

        start_count ();
    }

    private void start_count () {
        count = Timeout.add (1000, () => {
            // If the user pressed "pause", do not count this second.
            if (!recorder.is_recording) {
                return false;
            }

            if (past_seconds_10 < 5 && past_seconds_1 == 9) {
                // The count turns from wx:y9 to wx:(y+1)0
                past_seconds_10++;
                past_seconds_1 = 0;
            } else if (past_minutes_1 < 9 && past_seconds_10 == 5 && past_seconds_1 == 9) {
                // The count turns from wx:59 to w(x+1):00
                past_minutes_1++;
                past_seconds_1 = past_seconds_10 = 0;
            } else if (past_minutes_1 == 9 && past_seconds_10 == 5 && past_seconds_1 == 9) {
                // The count turns from w9:59 to (w+1)0:00
                past_minutes_10++;
                past_minutes_1 = past_seconds_10 = past_seconds_1 = 0;
            } else {
                // The count turns from wx:yx to wx:y(z+1)
                past_seconds_1++;
            }

            show_timer_label (time_label, past_minutes_10, past_minutes_1, past_seconds_10, past_seconds_1);

            return true;
        });
    }

    public void stop_count () {
        if (count != 0) {
            count = 0;
        }

        if (countdown != 0) {
            countdown = 0;
        }
    }

    public void init_countdown (uint remaining_time) {
        uint remain_minutes = remaining_time / 60;
        if (remain_minutes < 10) {
            remain_minutes_10 = 0;
            remain_minutes_1 = remain_minutes;
        } else {
            remain_minutes_10 = remain_minutes / 10;
            remain_minutes_1 = remain_minutes % 10;
        }

        uint remain_seconds = remaining_time % 60;
        if (remain_seconds < 10) {
            remain_seconds_10 = 0;
            remain_seconds_1 = remain_seconds;
        } else {
            remain_seconds_10 = remain_seconds / 10;
            remain_seconds_1 = remain_seconds % 10;
        }

        // Show initial time (00:00)
        show_timer_label (time_label, past_minutes_10, past_minutes_1, past_seconds_10, past_seconds_1);

        start_countdown ();
    }

    private void start_countdown () {
        // Show initial time
        show_timer_label (remaining_time_label, remain_minutes_10, remain_minutes_1, remain_seconds_10, remain_seconds_1);

        countdown = Timeout.add (1000, () => {
            // If the user pressed "pause", do not count this second.
            if (!recorder.is_recording) {
                return false;
            }

            if (remain_minutes_1 == 0 && remain_seconds_10 == 0 && remain_seconds_1 == 0) {
                // The count turns from w0:00 to (w-1)9:59
                remain_minutes_10--;
                remain_minutes_1 = remain_seconds_1 = 9;
                remain_seconds_10 = 5;
            } else if (remain_minutes_1 > 0 && remain_seconds_10 == 0 && remain_seconds_1 == 0) {
                // The count turns from wx:00 to w(x-1):59
                remain_minutes_1--;
                remain_seconds_10 = 5;
                remain_seconds_1 = 9;
            } else if (remain_seconds_10 > 0 && remain_seconds_1 == 0) {
                // The count turns from wx:y0 to wx:(y-1)9
                remain_seconds_10--;
                remain_seconds_1 = 9;
            } else {
                // The count turns from wx:yz to wx:y(z-1)
                remain_seconds_1--;
            }

            show_timer_label (remaining_time_label, remain_minutes_10, remain_minutes_1, remain_seconds_10, remain_seconds_1);

            if (remain_minutes_10 == 0 && remain_minutes_1 == 0 && remain_seconds_10 == 0 && remain_seconds_1 == 0) {
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

    private void show_timer_label (Gtk.Label label, uint minutes_10, uint minutes_1, uint seconds_10, uint seconds_1) {
        label.label = "%ld%ld:%ld%ld".printf (minutes_10, minutes_1, seconds_10, seconds_1);
    }
}
