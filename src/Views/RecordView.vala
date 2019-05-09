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
    public Application app { get; construct; }
    private Gtk.Label time_label;
    private Gtk.Label remaining_time_label;
    public Gtk.Button stop_button { get; private set; }
    private Gtk.Button pause_button;
    public bool is_recording { get; private set; }
    private string suffix;
    private string tmp_full_path;
    private uint count;
    private uint countdown;
    private Gst.Bin audiobin;
    private Gst.Pipeline pipeline;

    public RecordView (MainWindow window, Application app) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            window: window,
            app: app,
            margin: 6
        );
    }

    construct {
        time_label = new Gtk.Label (null);
        time_label.get_style_context ().add_class ("h2");

        remaining_time_label = new Gtk.Label (null);
        remaining_time_label.get_style_context ().add_class ("h3");

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
            cancel_recording ();
            window.show_welcome ();
            is_recording = false;
        });

        stop_button.clicked.connect (() => {
            stop_recording ();
            window.show_welcome ();
            is_recording = false;
        });

        pause_button.clicked.connect (() => {
            pause_recording ();
        });
    }

    private bool bus_message_cb (Gst.Bus bus, Gst.Message msg) {
        switch (msg.type) {
            case Gst.MessageType.ERROR:
                Error err;

                string debug;

                msg.parse_error (out err, out debug);

                is_recording = false;
                var error_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    _("Unable to Create an Audio File"),
                    _("A GStreamer error happened while recording, the following error message may be helpful:"),
                    "dialog-error", Gtk.ButtonsType.CLOSE);
                error_dialog.transient_for = window;
                error_dialog.show_error_details ("%s\n%s".printf (err.message, debug));
                error_dialog.run ();
                error_dialog.destroy ();
                stop_recording ();
                window.show_welcome ();

                pipeline.set_state (Gst.State.NULL);
                break;
            case Gst.MessageType.EOS:
                pipeline.set_state (Gst.State.NULL);

                is_recording = false;

                /// TRANSLATORS: %s represents a timestamp here
                string filename = _("Recording from %s").printf (new DateTime.now_local ().format ("%Y-%m-%d %H.%M.%S"));

                var tmp_source = File.new_for_path (tmp_full_path);

                string destination = Application.settings.get_string ("destination");

                if (Application.settings.get_boolean ("auto-save")) { // The app saved files automatically
                    try {
                        var uri = File.new_for_path (destination + "/" + filename + suffix);
                        tmp_source.move (uri, FileCopyFlags.OVERWRITE);
                        window.welcome_view.show_success_button ();
                    } catch (Error e) {
                        stderr.printf ("Error: %s\n", e.message);
                    }
                } else { // The app asks destination and filename each time
                    var filechooser = new Gtk.FileChooserNative (
                        _("Save your recording"), window, Gtk.FileChooserAction.SAVE,
                        _("Save"), _("Cancel"));
                    filechooser.set_current_name (filename + suffix);
                    filechooser.set_filename (destination);
                    filechooser.do_overwrite_confirmation = true;

                    if (filechooser.run () == Gtk.ResponseType.ACCEPT) {
                        try {
                            var uri = File.new_for_path (filechooser.get_filename ());
                            tmp_source.move (uri, FileCopyFlags.OVERWRITE);
                            window.welcome_view.show_success_button ();
                        } catch (Error e) {
                            stderr.printf ("Error: %s\n", e.message);
                        }
                    } else {
                        try {
                            tmp_source.delete ();
                        } catch (Error e) {
                            stderr.printf ("Error: %s", e.message);
                        }
                    }

                    filechooser.destroy ();
                }

                pipeline.dispose ();
                pipeline = null;
                break;
            default:
                break;
        }

        return true;
    }

    public void start_recording () {
        start_count ();

        pipeline = new Gst.Pipeline ("pipeline");
        audiobin = new Gst.Bin ("audio");
        var sink = Gst.ElementFactory.make ("filesink", "sink");

        if (pipeline == null) {
            stderr.printf ("Error: Gstreamer sink was not created correctly!\n");
        } else if (audiobin == null) {
            stderr.printf ("Error: Gstreamer pipeline was not created correctly!\n");
        } else if (sink == null) {
            stderr.printf ("Error: Gstreamer audiobin was not created correctly!\n");
        }

        string default_input = "";
        try {
            string sound_inputs = "";
            Process.spawn_command_line_sync ("pacmd list-sources", out sound_inputs);
            var re = new Regex ("(?<=\\*\\sindex:\\s\\d\\s\\sname:\\s<)[\\w\\.\\-]*");
            MatchInfo mi;
            if (re.match (sound_inputs, 0, out mi)) {
                default_input = mi.fetch (0);
                stdout.printf ("Input device found: %s\n".printf (default_input));
            }
        } catch (Error e) {
            warning (e.message);
        }

        string default_output = "";
        if (Application.settings.get_boolean ("system-sound")) {
            try {
                string sound_outputs = "";
                Process.spawn_command_line_sync ("pacmd list-sinks", out sound_outputs);
                var re = new Regex ("(?<=\\*\\sindex:\\s\\d\\s\\sname:\\s<)[\\w\\.\\-]*");
                MatchInfo mi;
                if (re.match (sound_outputs, 0, out mi)) {
                    default_output = mi.fetch (0);
                    stdout.printf ("Recording system sound is enabled: %s\n".printf (default_output));
                }
            } catch (Error e) {
                warning (e.message);
            }
        }

        assert (sink != null);
        string tmp_destination = Environment.get_tmp_dir ();
        string tmp_filename = "reco_" + new DateTime.now_local ().to_unix ().to_string ();

        string file_format = Application.settings.get_string ("format");

        try {
            switch (file_format) {
                case "aac":
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! avenc_aac ! mp4mux", true);
                    suffix = ".m4a";
                    break;
                case "flac":
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! flacenc", true);
                    suffix = ".flac";
                    break;
                case "mp3":
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! lamemp3enc", true);
                    suffix = ".mp3";
                    break;
                case "ogg":
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! vorbisenc ! oggmux", true);
                    suffix = ".ogg";
                    break;
                case "opus":
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! opusenc ! oggmux", true);
                    suffix = ".opus";
                    break;
                default:
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! wavenc", true);
                    suffix = ".wav";
                    break;
            }
        } catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
        }

        tmp_full_path = tmp_destination + "/%s%s".printf (tmp_filename, suffix);
        sink.set ("location", tmp_full_path);
        stdout.printf ("Audio is stored as %s temporary\n".printf (tmp_full_path));

        pipeline.add_many (audiobin, sink);
        audiobin.link (sink);

        pipeline.get_bus ().add_watch (Priority.DEFAULT, bus_message_cb);
        pipeline.set_state (Gst.State.PLAYING);

        int record_length = Application.settings.get_int ("length");
        if (record_length != 0) {
            start_countdown (record_length);
        }
    }

    public void cancel_recording () {
        if (count != 0) {
            count = 0;
        }

        if (countdown != 0) {
            countdown = 0;
            remaining_time_label.label = null;
        }

        pipeline.set_state (Gst.State.NULL);
        pipeline.dispose ();
        pipeline = null;

        // Remove canceled file in /tmp
        try {
            File.new_for_path (tmp_full_path).delete ();
        } catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
        }
    }

    private void stop_recording () {
        if (count != 0) {
            count = 0;
        }

        if (countdown != 0) {
            countdown = 0;
            remaining_time_label.label = null;
        }

        // If a user tries to stop recording while pausing, resume recording once and reset the button icon
        if (!is_recording) {
            pipeline.set_state (Gst.State.PLAYING);
            is_recording = true;
            pause_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
            pause_button.tooltip_text = _("Pause recording");
        }

        pipeline.send_event (new Gst.Event.eos ());
    }

    private void pause_recording () {
        if (is_recording) {
            pipeline.set_state (Gst.State.PAUSED);
            is_recording = false;
            pause_button.image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
            pause_button.tooltip_text = _("Resume recording");
        } else {
            pipeline.set_state (Gst.State.PLAYING);
            is_recording = true;
            pause_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
            pause_button.tooltip_text = _("Pause recording");
        }
    }

    private void start_count () {
        int past_minutes_10 = 0;
        int past_minutes_1 = 0;
        int past_seconds_10 = 0;
        int past_seconds_1 = 0;

        // Show initial time (00:00)
        show_timer_label (time_label, past_minutes_10, past_minutes_1, past_seconds_10, past_seconds_1);
        is_recording = true;

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

            return is_recording? true : false;
        });
    }

    private void start_countdown (int remaining_time) {
        int remain_minutes_10;
        int remain_minutes_1;
        int remain_seconds_10;
        int remain_seconds_1;

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
                stop_recording ();
                window.show_welcome ();
                is_recording = false;
                return false;
            }

            return true;
        });
    }

    private void show_timer_label (Gtk.Label label, int minutes_10, int minutes_1, int seconds_10, int seconds_1) {
        label.label = "%i%i:%i%i".printf (minutes_10, minutes_1, seconds_10, seconds_1);
    }
}
