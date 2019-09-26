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
    private bool record_sys_sound;
    private string suffix;
    private string tmp_full_path;
    private Gst.Pipeline pipeline;

    public signal void handle_error (Error err, string debug);
    public signal void handle_save_file (string tmp_full_path, string suffix);

    construct {
    }

    public void start_recording () {
        record_sys_sound = Application.settings.get_boolean ("system-sound");

        pipeline = new Gst.Pipeline ("pipeline");
        var mic_sound = Gst.ElementFactory.make ("pulsesrc", "mic_sound");
        var sys_sound = Gst.ElementFactory.make ("pulsesrc", "sys_sound");
        var mixer = Gst.ElementFactory.make ("audiomixer", "mixer");
        var sink = Gst.ElementFactory.make ("filesink", "sink");
        Gst.Element encoder;
        Gst.Element muxer = null;

        if (pipeline == null) {
            error ("Gstreamer sink was not created correctly!");
        } else if (mic_sound == null) {
            error ("Gstreamer mic_sound was not created correctly!");
        } else if (sys_sound == null) {
            error ("Gstreamer sys_sound was not created correctly!");
        } else if (mixer == null) {
            error ("Gstreamer mixer was not created correctly!");
        } else if (sink == null) {
            error ("Gstreamer mic_sound was not created correctly!");
        }

        string default_output = "";
        if (record_sys_sound) {
            string command = "pacmd list-sinks";
            try {
                string sound_devices = "";
                Process.spawn_command_line_sync (command, out sound_devices);
                var re = new Regex ("(?<=\\*\\sindex:\\s\\d\\s\\sname:\\s<)[\\w\\.\\-]*");
                MatchInfo mi;

                if (re.match (sound_devices, 0, out mi)) {
                    default_output = mi.fetch (0);
                }

                default_output += ".monitor";
                sys_sound.set ("device", default_output);
            } catch (Error e) {
                warning (e.message);
            }
        }

        string command = "pacmd list-sources";
        string default_input = "";
        try {
            string sound_devices = "";
            Process.spawn_command_line_sync (command, out sound_devices);
            var re = new Regex ("(?<=\\*\\sindex:\\s\\d\\s\\sname:\\s<)[\\w\\.\\-]*");
            MatchInfo mi;

            if (re.match (sound_devices, 0, out mi)) {
                default_input = mi.fetch (0);
            }

            mic_sound.set ("device", default_input);
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
                    encoder = Gst.ElementFactory.make ("avenc_aac", "encoder");
                    muxer = Gst.ElementFactory.make ("mp4mux", "muxer");
                    suffix = ".m4a";
                    break;
                case "flac":
                    encoder = Gst.ElementFactory.make ("flacenc", "encoder");
                    suffix = ".flac";
                    break;
                case "mp3":
                    encoder = Gst.ElementFactory.make ("lamemp3enc", "encoder");
                    suffix = ".mp3";
                    break;
                case "ogg":
                    encoder = Gst.ElementFactory.make ("vorbisenc", "encoder");
                    muxer = Gst.ElementFactory.make ("oggmux", "muxer");
                    suffix = ".ogg";
                    break;
                case "opus":
                    encoder = Gst.ElementFactory.make ("opusenc", "encoder");
                    muxer = Gst.ElementFactory.make ("oggmux", "muxer");
                    suffix = ".opus";
                    break;
                default:
                    encoder = Gst.ElementFactory.make ("wavenc", "encoder");
                    suffix = ".wav";
                    break;
            }
        } catch (Error e) {
            error ("Could not set the audio format correctly: %s", e.message);
        }

        tmp_full_path = tmp_destination + "/%s%s".printf (tmp_filename, suffix);
        sink.set ("location", tmp_full_path);
        debug ("The recording is stored at %s temporary".printf (tmp_full_path));

        pipeline.add_many (mic_sound, mixer, encoder, sink);
        mic_sound.get_static_pad ("src").link (mixer.get_request_pad ("sink_%u"));
        if (record_sys_sound) {
            pipeline.add (sys_sound);
            sys_sound.get_static_pad ("src").link (mixer.get_request_pad ("sink_%u"));
        }

        mixer.link (encoder);
        if (muxer != null) {
            pipeline.add (muxer);
            encoder.get_static_pad ("src").link (muxer.get_request_pad ("audio_%u"));
            muxer.link (sink);
        } else {
            encoder.link (sink);
        }

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

    public void stop_recording () {
        pipeline.send_event (new Gst.Event.eos ());
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
