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
    private Gtk.Label time_label;
    private Gtk.Button stop_button;
    private bool is_recording;
    private Gst.Bin audiobin;
    private Gst.Pipeline pipeline;
    private int past_seconds_1; // Used for the 1's place of seconds
    private int past_seconds_10; // Used for the 10's place of seconds
    private int past_minutes_1; // Used for the 1's place of minutes
    private int past_minutes_10; // Used for the 10's place of minutes

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
        time_label.get_style_context ().add_class ("h2");

        var label_grid = new Gtk.Grid ();
        label_grid.column_spacing = 6;
        label_grid.row_spacing = 6;
        label_grid.halign = Gtk.Align.CENTER;
        label_grid.attach (time_label, 0, 1, 1, 1);

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
            var error_dialog = new Granite.MessageDialog.with_image_from_icon_name (_("Unable to Create an Audio File"), _("A gstreamer error happened while recording:") + "\n%s\n\n".printf (err.message) + _("Error: %s").printf (debug) + "\n", "dialog-error", Gtk.ButtonsType.CLOSE);
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
        string destination = GLib.Environment.get_home_dir () + "/%s".printf (_("Recordings"));
        if (destination != null) {
            DirUtils.create_with_parents (destination, 0775);
        }
        string filename = destination + "/reco_" + new GLib.DateTime.now_local ().to_unix ().to_string ();

        try {
            if (window.welcome_view.format_combobox.active_id == "aac") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! avenc_aac ! mp4mux", true);
                filename += ".m4a";
            } else if (window.welcome_view.format_combobox.active_id == "flac") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! flacenc", true);
                filename += ".flac";
            } else if (window.welcome_view.format_combobox.active_id == "mp3") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! lamemp3enc", true);
                filename += ".mp3";
            } else if (window.welcome_view.format_combobox.active_id == "ogg") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! vorbisenc ! oggmux", true);
                filename += ".ogg";
            } else if (window.welcome_view.format_combobox.active_id == "opus") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! opusenc ! oggmux", true);
                filename += ".opus";
            } else if (window.welcome_view.format_combobox.active_id == "wav") {
                audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_input + " ! wavenc", true);
                filename += ".wav";
            }
        } catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
        }

        sink.set ("location", filename);
        stdout.printf ("Audio is stored as %s\n".printf (filename));

        pipeline.add_many (audiobin, sink);
        audiobin.link (sink);

        pipeline.get_bus ().add_watch (Priority.DEFAULT, bus_message_cb);
        pipeline.set_state (Gst.State.PLAYING);
    }

    private void stop_recording () {
        pipeline.send_event (new Gst.Event.eos ());
    }

    private void start_count () {
        past_minutes_10 = past_minutes_1 = past_seconds_10 = past_seconds_1 = 0;

        // Show initial time (00:00)
        show_timer_label ();
        is_recording = true;

        Timeout.add (1000, () => {
            if (past_seconds_10 < 5 && past_seconds_1 == 9) { // The count turns from XX:X9 to XX:X0
                past_seconds_10++;
                past_seconds_1 = 0;
                show_timer_label ();
            } else if (past_minutes_1 < 9 && past_seconds_10 == 5 && past_seconds_1 == 9) { // The count turns from X0:59 to X1:00
                past_minutes_1++;
                past_seconds_1 = past_seconds_10 = 0;
                show_timer_label ();
            } else if (past_minutes_1 == 9 && past_seconds_10 == 5 && past_seconds_1 == 9) { // The count turns from 09:59 to 10:00
                past_minutes_10++;
                past_minutes_1 = past_seconds_10 = past_seconds_1 = 0;
                show_timer_label ();
            } else { // The count increases 1 second
                past_seconds_1++;
                show_timer_label ();
            }

            return is_recording? true : false;
        });
    }

    private void show_timer_label () {
        time_label.label = "%i%i:%i%i".printf (past_minutes_10, past_minutes_1, past_seconds_10, past_seconds_1);
    }
}
