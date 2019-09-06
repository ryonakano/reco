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

public class Recorder : Object {
    public bool is_recording { get; private set; }
    private string suffix;
    private string tmp_full_path;
    public Gst.Pipeline pipeline { get; private set; }

    public signal void handle_error (Error err, string debug);
    public signal void handle_save_file (string tmp_full_path, string suffix);

    construct {
    }

    public void start_recording () {
        pipeline = new Gst.Pipeline ("pipeline");
        var audiobin = new Gst.Bin ("audio");
        var sink = Gst.ElementFactory.make ("filesink", "sink");

        if (pipeline == null) {
            error ("Gstreamer sink was not created correctly!");
        } else if (audiobin == null) {
            error ("Gstreamer pipeline was not created correctly!");
        } else if (sink == null) {
            error ("Gstreamer audiobin was not created correctly!");
        }

        string command = Application.settings.get_boolean ("system-sound") ? "pacmd list-sinks" : "pacmd list-sources";
        string default_device = "";
        try {
            string sound_devices = "";
            Process.spawn_command_line_sync (command, out sound_devices);
            var re = new Regex ("(?<=\\*\\sindex:\\s\\d\\s\\sname:\\s<)[\\w\\.\\-]*");
            MatchInfo mi;

            if (re.match (sound_devices, 0, out mi)) {
                default_device = mi.fetch (0);
            }

            if (Application.settings.get_boolean ("system-sound")) {
                default_device += ".monitor";
            }
        } catch (Error e) {
            warning (e.message);
        }

        assert (sink != null);
        string tmp_destination = Environment.get_tmp_dir ();
        string tmp_filename = "reco_" + new DateTime.now_local ().to_unix ().to_string ();

        string file_format = Application.settings.get_string ("format");

        try {
            switch (file_format) {
                case "aac":
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_device + " ! avenc_aac ! mp4mux", true);
                    suffix = ".m4a";
                    break;
                case "flac":
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_device + " ! flacenc", true);
                    suffix = ".flac";
                    break;
                case "mp3":
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_device + " ! lamemp3enc", true);
                    suffix = ".mp3";
                    break;
                case "ogg":
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_device + " ! vorbisenc ! oggmux", true);
                    suffix = ".ogg";
                    break;
                case "opus":
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_device + " ! opusenc ! oggmux", true);
                    suffix = ".opus";
                    break;
                default:
                    audiobin = (Gst.Bin) Gst.parse_bin_from_description ("pulsesrc device=" + default_device + " ! wavenc", true);
                    suffix = ".wav";
                    break;
            }
        } catch (Error e) {
            error ("Could not set the audio format correctly: %s", e.message);
        }

        tmp_full_path = tmp_destination + "/%s%s".printf (tmp_filename, suffix);
        sink.set ("location", tmp_full_path);
        debug ("The recording is stored at %s temporary".printf (tmp_full_path));

        pipeline.add_many (audiobin, sink);
        audiobin.link (sink);

        pipeline.get_bus ().add_watch (Priority.DEFAULT, bus_message_cb);
        set_recording_state (Gst.State.PLAYING);
    }

    private bool bus_message_cb (Gst.Bus bus, Gst.Message msg) {
        switch (msg.type) {
            case Gst.MessageType.ERROR:
                set_recording_state (Gst.State.NULL);
                pipeline.dispose ();

                Error err;
                string debug;
                msg.parse_error (out err, out debug);

                handle_error (err, debug);
                break;
            case Gst.MessageType.EOS:
                set_recording_state (Gst.State.NULL);
                pipeline.dispose ();

                handle_save_file (tmp_full_path, suffix);
                break;
            default:
                break;
        }

        return true;
    }

    public void cancel_recording () {
        set_recording_state (Gst.State.NULL);
        pipeline.dispose ();

        // Remove canceled file in /tmp
        try {
            File.new_for_path (tmp_full_path).delete ();
        } catch (Error e) {
            warning (e.message);
        }
    }

    public void set_recording_state (Gst.State state) {
        pipeline.set_state (state);

        switch (state) {
            case Gst.State.PLAYING:
                is_recording = true;
                break;
            case Gst.State.PAUSED:
            case Gst.State.NULL:
                is_recording = false;
                break;
            default:
                assert_not_reached ();
        }
    }
}
