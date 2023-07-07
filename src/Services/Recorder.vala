/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 *
 * GStreamer related codes are inspired from artemanufrij/screencast, src/MainWindow.vala
 */

public class Recorder : Object {
    public signal void throw_error (Error err, string debug);
    public signal void save_file (string tmp_full_path, string suffix);

    public bool is_recording { get; private set; }

    private PulseAudioManager pam;
    private string tmp_full_path;
    private string suffix;
    private Gst.Pipeline pipeline;
    private uint inhibit_token = 0;

    private enum SourceID {
        MIC,
        SYSTEM,
        BOTH
    }

    private enum FormatID {
        ALAC,
        FLAC,
        MP3,
        OGG,
        OPUS,
        WAV
    }

    private enum ChannelID {
        MONO = 1,
        STEREO = 2
    }

    private struct FormatData {
        string suffix;
        string encoder;
        string? muxer;
    }
    private FormatData[] format_data = {
        { ".m4a",   "avenc_alac",   "mp4mux"    },  // FormatID.ALAC                      // vala-lint=double-spaces
        { ".flac",  "flacenc",      null        },  // FormatID.FLAC                      // vala-lint=double-spaces
        { ".mp3",   "lamemp3enc",   null        },  // FormatID.MP3                       // vala-lint=double-spaces
        { ".ogg",   "vorbisenc",    "oggmux"    },  // FormatID.OGG                       // vala-lint=double-spaces
        { ".opus",  "opusenc",      "oggmux"    },  // FormatID.OPUS                      // vala-lint=double-spaces
        { ".wav",   "wavenc",       null        },  // FormatID.WAV                       // vala-lint=double-spaces
    };

    private static Recorder _instance;
    public static Recorder get_default () {
        if (_instance == null) {
            _instance = new Recorder ();
        }

        return _instance;
    }

    private Recorder () {
        pam = PulseAudioManager.get_default ();
        pam.start ();
    }

    public void start_recording () throws Gst.ParseError {
        pipeline = new Gst.Pipeline ("pipeline");
        if (pipeline == null) {
            throw new Gst.ParseError.NO_SUCH_ELEMENT ("Failed to create element \"pipeline\"");
        }

        var sink = Gst.ElementFactory.make ("filesink", "sink");
        if (sink == null) {
            throw new Gst.ParseError.NO_SUCH_ELEMENT ("Failed to create element \"filesink\"");
        }

        SourceID source = (SourceID) Application.settings.get_uint ("source");

        Gst.Element? sys_sound = null;
        if (source != SourceID.MIC) {
            sys_sound = Gst.ElementFactory.make ("pulsesrc", "sys_sound");
            if (sys_sound == null) {
                throw new Gst.ParseError.NO_SUCH_ELEMENT ("Failed to create pulsesrc element \"sys_sound\"");
            }

            string default_monitor = pam.default_sink_name + ".monitor";
            sys_sound.set ("device", default_monitor);
            debug ("sound source (system): \"%s\"", default_monitor);
        }

        Gst.Element? mic_sound = null;
        if (source != SourceID.SYSTEM) {
            mic_sound = Gst.ElementFactory.make ("pulsesrc", "mic_sound");
            if (mic_sound == null) {
                throw new Gst.ParseError.NO_SUCH_ELEMENT ("Failed to create pulsesrc element \"mic_sound\"");
            }

            mic_sound.set ("device", pam.default_source_name);
            debug ("sound source (microphone): \"%s\"", pam.default_source_name);
        }

        FormatID file_format = (FormatID) Application.settings.get_uint ("format");
        FormatData fmt_data = format_data[file_format];

        var encoder = Gst.ElementFactory.make (fmt_data.encoder, "encoder");
        if (encoder == null) {
            throw new Gst.ParseError.NO_SUCH_ELEMENT ("Failed to create encoder element \"%s\"", fmt_data.encoder);
        }

        Gst.Element? muxer = null;
        if (fmt_data.muxer != null) {
            muxer = Gst.ElementFactory.make (fmt_data.muxer, "muxer");
            if (encoder == null) {
                throw new Gst.ParseError.NO_SUCH_ELEMENT ("Failed to create muxer element \"%s\"", fmt_data.muxer);
            }
        }

        suffix = fmt_data.suffix;

        string tmp_filename = "reco_" + new DateTime.now_local ().to_unix ().to_string () + suffix;
        tmp_full_path = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_user_cache_dir (), tmp_filename);
        sink.set ("location", tmp_full_path);
        debug ("temporary saving path: %s", tmp_full_path);

        // Dual-channelization
        var caps_filter = Gst.ElementFactory.make ("capsfilter", "filter");
        caps_filter.set ("caps", new Gst.Caps.simple (
                            "audio/x-raw", "channels", Type.INT,
                            (ChannelID) Application.settings.get_uint ("channel")
        ));
        pipeline.add_many (caps_filter, encoder, sink);

        switch (source) {
            case SourceID.MIC:
                pipeline.add_many (mic_sound);
                mic_sound.link_many (caps_filter, encoder);
                break;
            case SourceID.SYSTEM:
                pipeline.add_many (sys_sound);
                sys_sound.link_many (caps_filter, encoder);
                break;
            case SourceID.BOTH:
                var mixer = Gst.ElementFactory.make ("audiomixer", "mixer");
                pipeline.add_many (mic_sound, sys_sound, mixer);
                mic_sound.get_static_pad ("src").link (mixer.request_pad_simple ("sink_%u"));
                sys_sound.get_static_pad ("src").link (mixer.request_pad_simple ("sink_%u"));
                mixer.link_many (caps_filter, encoder);
                break;
            default:
                assert_not_reached ();
        }

        if (muxer != null) {
            pipeline.add (muxer);
            encoder.get_static_pad ("src").link (muxer.request_pad_simple ("audio_%u"));
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

                throw_error (err, debug);
                break;
            case Gst.MessageType.EOS:
                set_recording_state (Gst.State.NULL);
                pipeline.dispose ();

                save_file (tmp_full_path, suffix);
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
