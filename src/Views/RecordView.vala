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
*
* Gstreamer related codes are inspired from https://github.com/artemanufrij/screencast/blob/master/src/MainWindow.vala
*/

public class RecordView : Gtk.Box {
    public MainWindow window { get; construct; }
    private Gtk.Label time_label;
    private Gtk.Label remaining_time_label;
    private Gtk.Button stop_button;
    private Gtk.Button pause_button;
    private uint count;
    private uint countdown;
    private int past_minutes_10;
    private int past_minutes_1;
    private int past_seconds_10;
    private int past_seconds_1;
    private int remain_minutes_10;
    private int remain_minutes_1;
    private int remain_seconds_10;
    private int remain_seconds_1;

    public RecordView (MainWindow window) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            window: window,
            margin: 6
        );
    }

    construct {
        time_label = new Gtk.Label (null);
        time_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        remaining_time_label = new Gtk.Label (null);
        remaining_time_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var label_grid = new Gtk.Grid ();
        label_grid.column_spacing = 6;
        label_grid.row_spacing = 6;
        label_grid.halign = Gtk.Align.CENTER;
        label_grid.attach (time_label, 0, 1, 1, 1);
        label_grid.attach (remaining_time_label, 0, 2, 1, 1);

        var cancel_button = new Gtk.Button ();
        cancel_button.image = new Gtk.Image.from_icon_name ("user-trash-symbolic", Gtk.IconSize.BUTTON);
        cancel_button.tooltip_text = _("Cancel recording");
        cancel_button.get_style_context ().add_class ("buttons-without-border");
        cancel_button.halign = Gtk.Align.START;

        stop_button = new Gtk.Button ();
        stop_button.image = new Gtk.Image.from_icon_name ("media-playback-stop-symbolic", Gtk.IconSize.DND);
        stop_button.tooltip_markup = Granite.markup_accel_tooltip ({"<Shift><Ctrl>R"}, _("Finish recording"));
        stop_button.get_style_context ().add_class ("record-button");
        stop_button.halign = Gtk.Align.CENTER;
        stop_button.width_request = 48;
        stop_button.height_request = 48;

        pause_button = new Gtk.Button ();
        pause_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
        pause_button.tooltip_text = _("Pause recording");
        pause_button.get_style_context ().add_class ("buttons-without-border");
        pause_button.halign = Gtk.Align.END;

        var buttons_grid = new Gtk.Grid ();
        buttons_grid.column_spacing = 30;
        buttons_grid.row_spacing = 6;
        buttons_grid.margin_top = 12;
        buttons_grid.halign = Gtk.Align.CENTER;
        buttons_grid.attach (cancel_button, 0, 0, 1, 1);
        buttons_grid.attach (stop_button, 1, 0, 1, 1);
        buttons_grid.attach (pause_button, 2, 0, 1, 1);

        pack_start (label_grid, false, false);
        pack_end (buttons_grid, false, false);

        cancel_button.clicked.connect (() => {
            reset_count ();

            window.recorder.cancel_recording ();
            window.show_welcome ();
        });

        stop_button.clicked.connect (() => {
            var loop = new MainLoop ();
            stop_recording.begin ((obj, res) => {
                loop.quit ();
            });
            loop.run ();
        });

        pause_button.clicked.connect (() => {
            if (window.recorder.is_recording) {
                if (count != 0) {
                    count = 0;
                }

                if (countdown != 0) {
                    countdown = 0;
                }

                window.recorder.set_recording_state (Gst.State.PAUSED);
                pause_button.image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
                pause_button.tooltip_text = _("Resume recording");
            } else {
                start_count ();

                if (Application.settings.get_int ("length") != 0) {
                    start_countdown ();
                }

                window.recorder.set_recording_state (Gst.State.PLAYING);
                pause_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
                pause_button.tooltip_text = _("Pause recording");
            }
        });
    }

    public async void stop_recording () {
        reset_count ();

        // If a user tries to stop recording while pausing, resume recording once and reset the button icon
        if (!window.recorder.is_recording) {
            window.recorder.set_recording_state (Gst.State.PLAYING);
            pause_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
            pause_button.tooltip_text = _("Pause recording");
        }

        if (window.recorder.pipeline.send_event (new Gst.Event.eos ())) {
            window.welcome_view.show_success_button ();
        }

        window.show_welcome ();
        window.recorder.set_recording_state (Gst.State.PAUSED);
    }

    public void reset_count () {
        if (count != 0) {
            count = 0;
        }

        if (countdown != 0) {
            countdown = 0;
            remaining_time_label.label = null;
        }
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

            return window.recorder.is_recording? true : false;
        });
    }

    public void init_countdown (int remaining_time) {
        int remain_minutes = remaining_time / 60;
        if (remain_minutes < 10) {
            remain_minutes_10 = 0;
            remain_minutes_1 = remain_minutes;
        } else {
            remain_minutes_10 = remain_minutes / 10;
            remain_minutes_1 = remain_minutes % 10;
        }

        int remain_seconds = remaining_time % 60;
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
                stop_recording.begin ((obj, res) => {
                    loop.quit ();
                });
                loop.run ();
                return false;
            }

            return window.recorder.is_recording? true : false;
        });
    }

    private void show_timer_label (Gtk.Label label, int minutes_10, int minutes_1, int seconds_10, int seconds_1) {
        label.label = "%i%i:%i%i".printf (minutes_10, minutes_1, seconds_10, seconds_1);
    }
}
