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
    public MainWindow window { get; construct; }
    public Application app { get; construct; }
    public bool is_recording { get; set; }
    public string suffix { get; private set; }
    public string tmp_full_path { get; private set; }
    private Gst.Bin audiobin;
    public Gst.Pipeline pipeline { get; set; }

    public Recorder (MainWindow window) {
        Object (
            window: window
        );
    }

    public void start_recording () {
        pipeline = new Gst.Pipeline ("pipeline");
        audiobin = new Gst.Bin ("audio");
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

        pipeline.get_bus ().add_watch (Priority.DEFAULT, window.record_view.bus_message_cb);
        pipeline.set_state (Gst.State.PLAYING);
    }

    public void cancel_recording () {
        pipeline.set_state (Gst.State.NULL);
        pipeline.dispose ();
        pipeline = null;

        is_recording = false;

        // Remove canceled file in /tmp
        try {
            File.new_for_path (tmp_full_path).delete ();
        } catch (Error e) {
            warning (e.message);
        }
    }
}
