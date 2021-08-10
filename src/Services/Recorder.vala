/*
* Copyright 2018-2021 Ryo Nakano
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
    private uint inhibit_token = 0;

    private enum Source {
        MIC,
        SYSTEM,
        BOTH
    }

    private enum Channels {
        MONO = 1,
        STEREO = 2
    }

    public void start_recording () {
        Source source = (Source) Application.settings.get_enum ("source");

        pipeline = new Gst.Pipeline ("pipeline");
        var mic_sound = Gst.ElementFactory.make ("pulsesrc", "mic_sound");
        var sink = Gst.ElementFactory.make ("filesink", "sink");

        if (source != Source.MIC) {
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

        if (source != Source.MIC) {
            foreach (Gst.Device monitor in DeviceManager.get_default ().monitors) {
                monitor.reconfigure_element (sys_sound);
                debug ("Set system sound source device to %s", monitor.display_name);
                break;
            }
        }

        if (source != Source.SYSTEM) {
            int microphone_number = Application.settings.get_int ("microphone");
            Gst.Device microphone = DeviceManager.get_default ().microphones.get (microphone_number);
            microphone.reconfigure_element (mic_sound);
            debug ("Set source microphone to %s", microphone.display_name);
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
        caps_filter.set ("caps", new Gst.Caps.simple (
                            "audio/x-raw", "channels", GLib.Type.INT,
                            (Channels) Application.settings.get_enum ("channels")
        ));
        pipeline.add_many (caps_filter, encoder, sink);

        switch (source) {
            case Source.MIC:
                pipeline.add_many (mic_sound);
                mic_sound.link_many (caps_filter, encoder);
                break;
            case Source.SYSTEM:
                pipeline.add_many (sys_sound);
                sys_sound.link_many (caps_filter, encoder);
                break;
            case Source.BOTH:
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
        inhibit_sleep ();
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
        uninhibit_sleep ();
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
        uninhibit_sleep ();
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

    private void inhibit_sleep () {
        unowned Gtk.Application app = (Gtk.Application) GLib.Application.get_default ();
        if (inhibit_token != 0) {
            app.uninhibit (inhibit_token);
        }

        inhibit_token = app.inhibit (
            app.get_active_window (),
            Gtk.ApplicationInhibitFlags.IDLE | Gtk.ApplicationInhibitFlags.SUSPEND,
            _("Recording is ongoing")
        );
    }

    private void uninhibit_sleep () {
        if (inhibit_token != 0) {
            ((Gtk.Application) GLib.Application.get_default ()).uninhibit (inhibit_token);
            inhibit_token = 0;
        }
    }
}
