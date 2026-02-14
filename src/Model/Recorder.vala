/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
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
        public signal void save_file (string tmp_path, string default_filename);

        private const string IGNORED_PROPNAMES[] = {
            "name", "parent", "direction", "template", "caps"
        };

        public bool is_recording_progress { get; private set; default = false; }

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
        private DateTime start_dt;
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
            { ".mp3",   "lamemp3enc",   "id3v2mux"  },  // FormatID.MP3                       // vala-lint=double-spaces
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
                throw new RecorderError.CREATE_ERROR ("Failed to create pipeline");
            }

            var level = Gst.ElementFactory.make ("level", "level");
            if (level == null) {
                throw new RecorderError.CREATE_ERROR ("Failed to create level element named 'level'");
            }

            var mixer = Gst.ElementFactory.make ("audiomixer", "mixer");
            if (mixer == null) {
                throw new RecorderError.CREATE_ERROR ("Failed to create audiomixer element named 'mixer'");
            }

            // Prevent audio from stuttering after some time, by setting the latency to other than 0.
            // This issue happens once audiomixer begins to be late and drop buffers.
            // See https://github.com/SeaDve/Kooha/issues/218#issuecomment-1948123954
            mixer.set_property ("latency", 1 * NSEC);

            var sink = Gst.ElementFactory.make ("filesink", "sink");
            if (sink == null) {
                throw new RecorderError.CREATE_ERROR ("Failed to create filesink element named 'sink'");
            }

            pipeline.add_many (level, mixer, sink);

            SourceID source = (SourceID) Application.settings.get_enum ("source");

            Gst.Element? sys_sound = null;
            if (source != SourceID.MIC) {
                sys_sound = Gst.ElementFactory.make ("pulsesrc", "sys_sound");
                if (sys_sound == null) {
                    throw new RecorderError.CREATE_ERROR ("Failed to create pulsesrc element 'sys_sound'");
                }

                Gst.Device? default_sink = Manager.DeviceManager.get_default ().default_sink;
                string? monitor_name = get_default_monitor_name (default_sink);
                if (monitor_name == null) {
                    throw new RecorderError.CONFIGURE_ERROR (
                        "Failed to set 'device' property of pulsesrc element named 'sys_sound': get_default_monitor_name () failed"
                    );
                }

                sys_sound.set ("device", monitor_name);
                debug ("sound source (system): \"Monitor of %s\"", default_sink.display_name);

                // Set properties that can be used in monitor apps e.g. pavucontrol or gnome-system-monitor
                var pa_props = new Gst.Structure.from_string (
                    "props" + ",media.role=music"
                            + ",application.id=" + Config.APP_ID
                            + ",application.icon_name=" + Config.APP_ID
                    , null
                );
                sys_sound.set ("stream-properties", pa_props);

                pipeline.add (sys_sound);
                sys_sound.get_static_pad ("src").link (mixer.request_pad_simple ("sink_%u"));
            }

            Gst.Element? mic_sound = null;
            if (source != SourceID.SYSTEM) {
                var index = (int) Manager.DeviceManager.get_default ().selected_source_index;
                Gst.Device microphone = Manager.DeviceManager.get_default ().sources[index];
                mic_sound = microphone.create_element ("mic_sound");
                if (mic_sound == null) {
                    throw new RecorderError.CREATE_ERROR ("Failed to create pulsesrc element named 'mic_sound'");
                }

                debug ("sound source (microphone): \"%s\"", microphone.display_name);

                // Set properties that can be used in monitor apps e.g. pavucontrol or gnome-system-monitor
                var pa_props = new Gst.Structure.from_string (
                    "props" + ",media.role=music"
                            + ",application.id=" + Config.APP_ID
                            + ",application.icon_name=" + Config.APP_ID
                    , null
                );
                mic_sound.set ("stream-properties", pa_props);

                pipeline.add (mic_sound);
                mic_sound.get_static_pad ("src").link (mixer.request_pad_simple ("sink_%u"));
            }

            FormatID file_format = (FormatID) Application.settings.get_enum ("format");
            FormatData fmt_data = format_data[file_format];

            var encoder = Gst.ElementFactory.make (fmt_data.encoder, "encoder");
            if (encoder == null) {
                throw new RecorderError.CREATE_ERROR (
                    "Failed to create %s element named 'encoder'".printf (fmt_data.encoder)
                );
            }

            Gst.Element? muxer = null;
            if (fmt_data.muxer != null) {
                muxer = Gst.ElementFactory.make (fmt_data.muxer, "muxer");
                if (muxer == null) {
                    throw new RecorderError.CREATE_ERROR (
                        "Failed to create %s element named 'muxer'".printf (fmt_data.muxer)
                    );
                }
            }

            start_dt = new DateTime.now_local ();
            string tmp_filename = "reco_%s%s".printf (start_dt.to_unix ().to_string (), fmt_data.suffix);
            tmp_path = Path.build_filename (Environment.get_user_cache_dir (), tmp_filename);
            sink.set ("location", tmp_path);
            debug ("temporary saving path: %s", tmp_path);

            // Dual-channelization
            var caps_filter = Gst.ElementFactory.make ("capsfilter", "filter");
            if (caps_filter == null) {
                throw new RecorderError.CREATE_ERROR ("Failed to create capsfilter element 'filter'");
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
            inhibit_sleep ();

            pipeline.set_state (Gst.State.PLAYING);

            if (Application.settings.get_boolean ("add-metadata")) {
                unowned string real_name = Environment.get_real_name ();
                // Ignore return value because failure to add metadata does not affect to recording itself
                add_metadata (pipeline, real_name, start_dt);
            }

            is_recording_progress = true;
        }

        public void stop_recording () {
            // Pipelines don't seem to catch events when it's in the PAUSED state
            pipeline.set_state (Gst.State.PLAYING);

            pipeline.send_event (new Gst.Event.eos ());
        }

        public void cancel_recording () {
            uninhibit_sleep ();

            pipeline.set_state (Gst.State.NULL);
            pipeline.dispose ();
            is_recording_progress = false;
        }

        public void pause_recording () {
            uninhibit_sleep ();

            pipeline.set_state (Gst.State.PAUSED);
        }

        public void resume_recording () {
            start_recording ();
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
                    pipeline.set_state (Gst.State.NULL);
                    pipeline.dispose ();
                    is_recording_progress = false;

                    var end_dt = new DateTime.now_local ();
                    string suffix = Util.get_suffix (tmp_path);
                    string default_filename = build_filename_from_datetime (start_dt, end_dt, suffix);

                    save_file (tmp_path, default_filename);
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

        public async void trash_tmp_recording () throws Error {
            // It's a bug of the caller if it tries to cleanup the tmp recording while it's still writing to it
            assert (!is_recording_progress);

            if (!FileUtils.test (tmp_path, FileTest.EXISTS)) {
                return;
            }

            yield trash_file (tmp_path);
        }

        public async void delete_tmp_recording () throws Error {
            // It's a bug of the caller if it tries to cleanup the tmp recording while it's still writing to it
            assert (!is_recording_progress);

            if (!FileUtils.test (tmp_path, FileTest.EXISTS)) {
                return;
            }

            yield delete_file (tmp_path);
        }

        private async void trash_file (string path) throws Error {
            yield File.new_for_path (path).trash_async ();
        }

        private async void delete_file (string path) throws Error {
            yield File.new_for_path (path).delete_async ();
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

        /**
         * Add #artist and #date_time metadata to the stream using a {@link Gst.TagSetter} element found from #pipeline.
         *
         * NOTE:
         *  * You should call this method before #pipeline goes to {@link Gst.State.PAUSED}
         *
         * See also:
         *  * https://gstreamer.freedesktop.org/documentation/application-development/advanced/metadata.html?gi-language=c#tag-writing
         *  * https://gstreamer.freedesktop.org/documentation/gstreamer/gsttagsetter.html?gi-language=c
         *
         * @param pipeline      a {@link Gst.Pipeline} that has at least one {@link Gst.Element} that inherits
         *                      {@link Gst.TagSetter} interface, e.g. "vorbisenc", "theoraenc", "id3v2mux", etc.
         * @param artist        artist name that will be set to metadata
         * @param date_time     date & time that will be set to metadata
         *
         * @return              true if succeeded, false otherwise
         */
        private bool add_metadata (Gst.Pipeline pipeline, string artist, DateTime date_time) {
            Gst.TagSetter? tag_setter = pipeline.get_by_interface (typeof (Gst.TagSetter)) as Gst.TagSetter;
            if (tag_setter == null) {
                warning ("Element that implements GstTagSetter not found");
                return false;
            }

            var gst_date_time = new Gst.DateTime.from_g_date_time (date_time);

            tag_setter.add_tags (Gst.TagMergeMode.REPLACE_ALL,
                                    Gst.Tags.ARTIST, artist,
                                    Gst.Tags.DATE_TIME, gst_date_time);

            return true;
        }

        /**
         * Build filename using the given arguments.
         *
         * The filename includes start datetime and end time. It also includes end date if the date is different between
         * start and end.
         *
         * e.g. "2018-11-10_23:42:36 to 2018-11-11_07:13:50.wav"
         *      "2018-11-10_23:42:36 to 23:49:52.wav"
         */
        private string build_filename_from_datetime (DateTime start, DateTime end, string suffix) {
            string start_format = "%Y-%m-%d_%H:%M:%S";
            string end_format = "%Y-%m-%d_%H:%M:%S";

            bool is_same_day = Util.is_same_day (start, end);
            if (is_same_day) {
                // Avoid redundant date
                end_format = "%H:%M:%S";
            }

            string start_str = start.format (start_format);
            string end_str = end.format (end_format);

            return "%s to %s".printf (start_str, end_str) + suffix;
        }
    }
}
