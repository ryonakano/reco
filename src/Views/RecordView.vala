/*
* (C) 2018 Ryo Nakano
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
    private Gtk.Button stop_button;
    private bool is_recording;
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

        stop_button = new Gtk.Button ();
        stop_button.image = new Gtk.Image.from_icon_name ("media-playback-stop-symbolic", Gtk.IconSize.DND);
        stop_button.tooltip_text = _("Stop recording");
        stop_button.get_style_context ().add_class ("record-button");
        stop_button.halign = Gtk.Align.CENTER;
        stop_button.margin_top = 12;
        stop_button.width_request = 48;
        stop_button.height_request = 48;

        pack_start (label_grid, false, false);
        pack_end (stop_button, false, false);

        stop_button.clicked.connect (() => {
            stop_recording ();
            window.show_welcome ();
            is_recording = false;
        });
    }

    private bool bus_message_cb (Gst.Bus bus, Gst.Message msg) {
        switch (msg.type) {
        case Gst.MessageType.ERROR:
            GLib.Error err;

            string debug;

            msg.parse_error (out err, out debug);

            is_recording = false;
            var error_dialog = new Granite.MessageDialog.with_image_from_icon_name (_("Unable to Create an Audio File"), _("A GStreamer error happened while recording:") + "\n%s\n\n".printf (err.message) + _("Error: %s").printf (debug) + "\n", "dialog-error", Gtk.ButtonsType.CLOSE);
            error_dialog.transient_for = window;
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
            string filename = _("Recording from %s").printf (new GLib.DateTime.now_local ().format ("%Y-%m-%d %H.%M.%S"));

            var tmp_source = File.new_for_path (tmp_full_path);

            if (window.welcome_view.auto_save.active) { // The app saved files automatically
                string destination = window.welcome_view.destination_chooser.get_filename ();
                try {
                    var uri = File.new_for_path (destination + "/" + filename + suffix);
                    tmp_source.move (uri, FileCopyFlags.OVERWRITE);
                } catch (Error e) {
                    stderr.printf ("Error: %s\n", e.message);
                }
            } else { // The app asks destination and filename each time
                var filechooser = new Gtk.FileChooserDialog (_("Save your recording"), window, Gtk.FileChooserAction.SAVE, _("Cancel"), Gtk.ResponseType.CANCEL, _("Save"), Gtk.ResponseType.OK);
                filechooser.set_current_name (filename + suffix);
                filechooser.set_filename (app.destination);

                if (filechooser.run () == Gtk.ResponseType.OK) {
                    try {
                        var uri = File.new_for_path (filechooser.get_filename ());
                        tmp_source.move (uri, FileCopyFlags.OVERWRITE);
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
            GLib.Regex re = new GLib.Regex ("(?<=\\*\\sindex:\\s\\d\\s\\sname:\\s<)[\\w\\.\\-]*");
            MatchInfo mi;
            if (re.match (sound_inputs, 0, out mi)) {
                default_input = mi.fetch (0);
                stdout.printf ("Input device found: %s\n".printf (default_input));
            }
        } catch (Error e) {
            warning (e.message);
        }

        assert (sink != null);
        string tmp_destination = GLib.Environment.get_tmp_dir ();
        string tmp_filename = "reco_" + new GLib.DateTime.now_local ().to_unix ().to_string ();

        try {
            if (window.welcome_view.format_combobox.active_id == "aac") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! avenc_aac ! mp4mux", true);
                suffix = ".m4a";
            } else if (window.welcome_view.format_combobox.active_id == "flac") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! flacenc", true);
                suffix = ".flac";
            } else if (window.welcome_view.format_combobox.active_id == "mp3") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! lamemp3enc", true);
                suffix = ".mp3";
            } else if (window.welcome_view.format_combobox.active_id == "ogg") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! vorbisenc ! oggmux", true);
                suffix = ".ogg";
            } else if (window.welcome_view.format_combobox.active_id == "opus") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! opusenc ! oggmux", true);
                suffix = ".opus";
            } else if (window.welcome_view.format_combobox.active_id == "wav") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! wavenc", true);
                suffix = ".wav";
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

        int record_length = window.welcome_view.length_spin.get_value_as_int ();
        if (record_length != 0) {
            start_countdown (record_length);
        }
    }

    private void stop_recording () {
        if (count != 0) {
            count = 0;
        }
        if (countdown != 0) {
            countdown = 0;
        }
        pipeline.send_event (new Gst.Event.eos ());
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
            if (past_seconds_10 < 5 && past_seconds_1 == 9) { // The count turns from wx:y9 to wx:(y+1)0
                past_seconds_10++;
                past_seconds_1 = 0;
            } else if (past_minutes_1 < 9 && past_seconds_10 == 5 && past_seconds_1 == 9) { // The count turns from wx:59 to w(x+1):00
                past_minutes_1++;
                past_seconds_1 = past_seconds_10 = 0;
            } else if (past_minutes_1 == 9 && past_seconds_10 == 5 && past_seconds_1 == 9) { // The count turns from w9:59 to (w+1)0:00
                past_minutes_10++;
                past_minutes_1 = past_seconds_10 = past_seconds_1 = 0;
            } else { // The count turns from wx:yx to wx:y(z+1)
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
            if (remain_minutes_1 == 0 && remain_seconds_10 == 0 && remain_seconds_1 == 0) { // The count turns from w0:00 to (w-1)9:59
                remain_minutes_10--;
                remain_minutes_1 = remain_seconds_1 = 9;
                remain_seconds_10 = 5;
            } else if (remain_minutes_1 > 0 && remain_seconds_10 == 0 && remain_seconds_1 == 0) { // The count turns from wx:00 to w(x-1):59
                remain_minutes_1--;
                remain_seconds_10 = 5;
                remain_seconds_1 = 9;
            } else if (remain_seconds_10 > 0 && remain_seconds_1 == 0) { // The count turns from wx:y0 to wx:(y-1)9
                remain_seconds_10--;
                remain_seconds_1 = 9;
            } else { // The count turns from wx:yz to wx:y(z-1)
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
