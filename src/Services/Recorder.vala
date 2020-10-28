/*
* Copyright 2018-2020 Ryo Nakano
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
* GStreamer related codes are inspired from https://github.com/artemanufrij/screencast/blob/master/src/MainWindow.vala
*/

public class Recorder : Object {
    public signal void handle_error (Error err, string debug);
    public signal void handle_save_file (string tmp_full_path, string suffix);

    public bool is_recording { get; private set; }
    private string suffix;
    private string tmp_full_path;
    private Gst.Pipeline pipeline;
    private Gst.Element sys_sound;

    private enum SourceDevice {
        MIC,
        SYSTEM,
        BOTH
    }

    private enum Channels {
        MONO = 1,
        STEREO = 2
    }

    construct {
    }

    public void start_recording () {
        SourceDevice device_id = (SourceDevice) Application.settings.get_enum ("device");

        pipeline = new Gst.Pipeline ("pipeline");
        var mic_sound = Gst.ElementFactory.make ("pulsesrc", "mic_sound");
        var sink = Gst.ElementFactory.make ("filesink", "sink");

        if (device_id != SourceDevice.MIC) {
            sys_sound = Gst.ElementFactory.make ("pulsesrc", "sys_sound");
            if (sys_sound == null) {
                error ("The GStreamer element pulsesrc (named \"sys_sound\") was not created correctly");
            }
        }

        if (pipeline == null) {
            error ("The GStreamer element pipeline was not created correctly");
        } else if (mic_sound == null) {
            error ("The GStreamer element pulsesrc (named \"mic_sound\") was not created correctly");
        } else if (sink == null) {
            error ("The GStreamer element filesink was not created correctly");
        }

        if (device_id != SourceDevice.MIC) {
            string default_output = "";
            try {
                string sound_devices = "";
                Process.spawn_command_line_sync ("pacmd list-sinks", out sound_devices);
                var regex = new Regex ("(?<=\\*\\sindex:\\s\\d+\\s\\sname:\\s<)[\\w\\.\\-]*");
                MatchInfo match_info;

                if (regex.match (sound_devices, 0, out match_info)) {
                    default_output = match_info.fetch (0);
                }

                default_output += ".monitor";
                sys_sound.set ("device", default_output);
                debug ("Detected system sound device: %s", default_output);
            } catch (Error e) {
                warning (e.message);
            }
        }

        if (device_id != SourceDevice.SYSTEM) {
            string default_input = "";
            try {
                string sound_devices = "";
                Process.spawn_command_line_sync ("pacmd list-sources", out sound_devices);
                var regex = new Regex ("(?<=\\*\\sindex:\\s\\d+\\s\\sname:\\s<)[\\w\\.\\-]*");
                MatchInfo match_info;

                if (regex.match (sound_devices, 0, out match_info)) {
                    default_input = match_info.fetch (0);
                }

                mic_sound.set ("device", default_input);
                debug ("Detected microphone: %s", default_input);
            } catch (Error e) {
                warning (e.message);
            }
        }

        Gst.Element encoder;
        Gst.Element muxer = null;

        string file_format = Application.settings.get_string ("format");
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
            case "wav":
                encoder = Gst.ElementFactory.make ("wavenc", "encoder");
                suffix = ".wav";
                break;
            default:
                assert_not_reached ();
        }

        if (encoder == null) {
            error ("The GStreamer element encoder was not created correctly");
        }

        string tmp_filename = "reco_" + new DateTime.now_local ().to_unix ().to_string ();
        tmp_full_path = Environment.get_tmp_dir () + "/%s%s".printf (tmp_filename, suffix);
        sink.set ("location", tmp_full_path);
        debug ("The recording is temporary stored at %s", tmp_full_path);

        // Dual-channelization
        var caps_filter = Gst.ElementFactory.make ("capsfilter", "filter");
        caps_filter.set ("caps", new Gst.Caps.simple ("audio/x-raw", "channels", GLib.Type.INT, (Channels) Application.settings.get_enum ("channels")));
        pipeline.add_many (caps_filter, encoder, sink);

        switch (device_id) {
            case SourceDevice.MIC:
                pipeline.add_many (mic_sound);
                mic_sound.link_many (caps_filter, encoder);
                break;
            case SourceDevice.SYSTEM:
                pipeline.add_many (sys_sound);
                sys_sound.link_many (caps_filter, encoder);
                break;
            case SourceDevice.BOTH:
                var mixer = Gst.ElementFactory.make ("audiomixer", "mixer");
                pipeline.add_many (mic_sound, sys_sound, mixer);
                mic_sound.get_static_pad ("src").link (mixer.get_request_pad ("sink_%u"));
                sys_sound.get_static_pad ("src").link (mixer.get_request_pad ("sink_%u"));
                mixer.link_many (caps_filter, encoder);
                break;
            default:
                assert_not_reached ();
        }

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
                cancel_recording ();

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
