/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2025 Ryo Nakano <ryonakaknock3@gmail.com>
 *
 * GStreamer related codes are inspired from:
 * * https://github.com/artemanufrij/screencast/blob/1.0.0/src/MainWindow.vala
 * * https://gitlab.gnome.org/World/vocalis/-/blob/3.38.1/src/recorder.js
 * * https://gitlab.freedesktop.org/gstreamer/gstreamer/-/blob/1.20.6/subprojects/gst-plugins-base/tools/gst-device-monitor.c
 */

namespace Model {
    /**
     * Error definitions for {@link Model.Recorder}.
     */
    public errordomain RecorderError {
        /** Error while creating elements. **/
        CREATE_ERROR,
        /** Error configuring elements. **/
        CONFIGURE_ERROR,
    }

    public class Recorder : Object {
        public signal void throw_error (Error err, string debug);
        public signal void save_file (string tmp_path, string suffix);

        private const string IGNORED_PROPNAMES[] = {
            "name", "parent", "direction", "template", "caps"
        };

        public enum RecordingState {
            STOPPED,                // Not recording
            PAUSED,                 // Recording is paused
            RECORDING               // Recording is ongoing
        }

        // Convert from RecordingState to Gst.State
        private const Gst.State GST_STATE_TABLE[] = {
            Gst.State.NULL,         // RecordingState.STOPPED
            Gst.State.PAUSED,       // RecordingState.PAUSED
            Gst.State.PLAYING       // RecordingState.RECORDING
        };

        public RecordingState state {
            get {
                return _state;
            }

            set {
                _state = value;

                // Control actual recording to stop, start, or pause
                pipeline.set_state (GST_STATE_TABLE[_state]);

                if (_state == RecordingState.RECORDING) {
                    inhibit_sleep ();
                } else {
                    uninhibit_sleep ();
                }
            }
        }
        private RecordingState _state = RecordingState.STOPPED;

        // current sound level, taking value from 0 to 1
        public double current_peak {
            get {
                return _current_peak;
            }
            set {
                double decibel = value;
                if (decibel > 0) {
                    decibel = 0;
                }

                double p = Math.pow (10, decibel / 20);
                if (p == _current_peak) {
                    // No need to renew value
                    return;
                }

                _current_peak = p;
            }
        }
        private double _current_peak = 0;

        private string tmp_path;
        private string suffix;
        private Gst.Pipeline pipeline;
        private uint inhibit_token = 0;
        private const uint64 NSEC = 1000000000;

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
        public static unowned Recorder get_default () {
            if (_instance == null) {
                _instance = new Recorder ();
            }

            return _instance;
        }

        private Recorder () {
        }

        public void prepare_recording () throws RecorderError {
            pipeline = new Gst.Pipeline ("pipeline");
            if (pipeline == null) {
                throw new RecorderError.CREATE_ERROR ("Failed to create element \"pipeline\"");
            }

            var level = Gst.ElementFactory.make ("level", "level");
            if (level == null) {
                throw new RecorderError.CREATE_ERROR ("Failed to create element \"level\"");
            }

            var mixer = Gst.ElementFactory.make ("audiomixer", "mixer");
            if (mixer == null) {
                throw new RecorderError.CREATE_ERROR ("Failed to create element \"audiomixer\"");
            }

            // Prevent audio from stuttering after some time, by setting the latency to other than 0.
            // This issue happens once audiomixer begins to be late and drop buffers.
            // See https://github.com/SeaDve/Kooha/issues/218#issuecomment-1948123954
            mixer.set_property ("latency", 1 * NSEC);

            var sink = Gst.ElementFactory.make ("filesink", "sink");
            if (sink == null) {
                throw new RecorderError.CREATE_ERROR ("Failed to create element \"filesink\"");
            }

            pipeline.add_many (level, mixer, sink);

            SourceID source = (SourceID) Application.settings.get_enum ("source");

            Gst.Element? sys_sound = null;
            if (source != SourceID.MIC) {
                sys_sound = Gst.ElementFactory.make ("pulsesrc", "sys_sound");
                if (sys_sound == null) {
                    throw new RecorderError.CREATE_ERROR ("Failed to create element \"sys_sound\"");
                }

                Gst.Device? default_sink = Manager.DeviceManager.get_default ().default_sink;
                string? monitor_name = get_default_monitor_name (default_sink);
                if (monitor_name == null) {
                    throw new RecorderError.CONFIGURE_ERROR (
                        "Failed to set \"device\" property of element \"sys_sound\": get_default_monitor_name () failed"
                    );
                }

                sys_sound.set ("device", monitor_name);
                debug ("sound source (system): \"Monitor of %s\"", default_sink.display_name);
                pipeline.add (sys_sound);
                sys_sound.get_static_pad ("src").link (mixer.request_pad_simple ("sink_%u"));
            }

            Gst.Element? mic_sound = null;
            if (source != SourceID.SYSTEM) {
                var index = (int) Manager.DeviceManager.get_default ().selected_source_index;
                Gst.Device microphone = Manager.DeviceManager.get_default ().sources[index];
                mic_sound = microphone.create_element ("mic_sound");
                if (mic_sound == null) {
                    throw new RecorderError.CREATE_ERROR ("Failed to create element \"mic_sound\"");
                }

                debug ("sound source (microphone): \"%s\"", microphone.display_name);
                pipeline.add (mic_sound);
                mic_sound.get_static_pad ("src").link (mixer.request_pad_simple ("sink_%u"));
            }

            FormatID file_format = (FormatID) Application.settings.get_enum ("format");
            FormatData fmt_data = format_data[file_format];

            var encoder = Gst.ElementFactory.make (fmt_data.encoder, "encoder");
            if (encoder == null) {
                throw new RecorderError.CREATE_ERROR ("Failed to create encoder element \"%s\"", fmt_data.encoder);
            }

            Gst.Element? muxer = null;
            if (fmt_data.muxer != null) {
                muxer = Gst.ElementFactory.make (fmt_data.muxer, "muxer");
                if (muxer == null) {
                    throw new RecorderError.CREATE_ERROR ("Failed to create muxer element \"%s\"", fmt_data.muxer);
                }
            }

            suffix = fmt_data.suffix;

            string tmp_filename = "reco_" + new DateTime.now_local ().to_unix ().to_string () + suffix;
            tmp_path = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_user_cache_dir (), tmp_filename);
            sink.set ("location", tmp_path);
            debug ("temporary saving path: %s", tmp_path);

            // Dual-channelization
            var caps_filter = Gst.ElementFactory.make ("capsfilter", "filter");
            if (caps_filter == null) {
                throw new RecorderError.CREATE_ERROR ("Failed to create element \"capsfilter\"");
            }

            caps_filter.set ("caps", new Gst.Caps.simple ("audio/x-raw", "channels", Type.INT,
                                                          (ChannelID) Application.settings.get_enum ("channel")));

            pipeline.add_many (caps_filter, encoder);
            mixer.link_many (caps_filter, level, encoder);

            if (muxer != null) {
                pipeline.add (muxer);
                encoder.get_static_pad ("src").link (muxer.request_pad_simple ("audio_%u"));
                muxer.link (sink);
            } else {
                encoder.link (sink);
            }

            pipeline.get_bus ().add_watch (Priority.DEFAULT, bus_message_cb);
        }

        public void start_recording () {
            state = RecordingState.RECORDING;
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
                    state = RecordingState.STOPPED;
                    pipeline.dispose ();

                    save_file (tmp_path, suffix);
                    break;
                case Gst.MessageType.ELEMENT:
                    unowned Gst.Structure? structure = msg.get_structure ();
                    if (!structure.has_name ("level")) {
                        break;
                    }

                    // FIXME: ValueArray is deprecated but used as an I/F structure in the GStreamer side:
                    // https://gitlab.freedesktop.org/gstreamer/gstreamer/-/blob/1.20.5/subprojects/gst-plugins-good/gst/level/gstlevel.c#L579
                    // We would need a patch for GStreamer to replace ValueArray with Array
                    // when it's removed before GStreamer resolves
                    unowned var peak_arr = (ValueArray) structure.get_value ("peak").get_boxed ();
                    if (peak_arr != null) {
                        current_peak = peak_arr.get_nth (0).get_double ();
                    }

                    break;
                default:
                    break;
            }

            return true;
        }

        public void cancel_recording () {
            state = RecordingState.STOPPED;
            pipeline.dispose ();

            remove_tmp_recording ();
        }

        public void remove_tmp_recording () {
            var tmp_file = File.new_for_path (tmp_path);
            if (!tmp_file.query_exists ()) {
                return;
            }

            try {
                tmp_file.delete ();
            } catch (Error e) {
                // Just failed to remove tmp file so letting user know through error dialog is not necessary
                warning (e.message);
            }
        }

        public void stop_recording () {
            pipeline.send_event (new Gst.Event.eos ());
        }

        private void inhibit_sleep () {
            unowned Gtk.Application app = (Gtk.Application) GLib.Application.get_default ();
            if (inhibit_token != 0) {
                app.uninhibit (inhibit_token);
            }

            inhibit_token = app.inhibit (
                app.get_active_window (),
                Gtk.ApplicationInhibitFlags.SUSPEND,
                _("Recording is ongoing")
            );
        }

        private void uninhibit_sleep () {
            if (inhibit_token != 0) {
                ((Gtk.Application) GLib.Application.get_default ()).uninhibit (inhibit_token);
                inhibit_token = 0;
            }
        }

        // Get the name of the default monitor device from the default sink name
        private string? get_default_monitor_name (Gst.Device? default_sink) {
            if (default_sink == null) {
                warning ("default_sink is null");
                return null;
            }

            Gst.Element? element = default_sink.create_element (null);
            if (element == null) {
                warning ("element is null");
                return null;
            }

            Gst.ElementFactory? factory = element.get_factory ();
            if (factory == null) {
                warning ("factory is null");
                return null;
            }

            Gst.Element? pureelement = factory.create (null);
            if (pureelement == null) {
                warning ("pureelement is null");
                return null;
            }

            // Get paramspecs and show non-default properties
            (unowned ParamSpec)[] properties = element.get_class ().list_properties ();
            foreach (var property in properties) {
                // Skip some properties
                if ((property.flags & ParamFlags.READWRITE) != ParamFlags.READWRITE) {
                    continue;
                }

                if (property.name in IGNORED_PROPNAMES) {
                    continue;
                }

                var value = Value (property.value_type);
                element.get_property (property.name, ref value);

                var pvalue = Value (property.value_type);
                pureelement.get_property (property.name, ref pvalue);

                if (Gst.Value.compare (value, pvalue) != Gst.VALUE_EQUAL) {
                    string? valuestr = Gst.Value.serialize (value);
                    if (valuestr == null) {
                        warning ("Could not serialize property %s: %s", element.name, property.name);
                        continue;
                    }

                    return valuestr + ".monitor";
                }
            }

            return null;
        }
    }
}
