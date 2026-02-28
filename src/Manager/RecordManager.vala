/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 *
 * GStreamer related codes are inspired from:
 * * https://github.com/artemanufrij/screencast/blob/1.0.0/src/MainWindow.vala
 * * https://gitlab.gnome.org/World/vocalis/-/blob/3.38.1/src/recorder.js
 * * https://gitlab.freedesktop.org/gstreamer/gstreamer/-/blob/1.20.6/subprojects/gst-plugins-base/tools/gst-device-monitor.c
 */

/**
 * Manages recording.
 */
public class Manager.RecordManager : Object {
    /**
     * Emitted when a fatal internal error occurred.
     *
     * @param err           information about the error
     * @param debug_info    debug message for the error
     */
    public signal void record_err (Error err, string debug_info);

    /**
     * Emitted when recording succeeded.
     */
    public signal void record_ok ();

    /**
     * States that {@link Manager.RecordManager} can take.
     */
    private enum RecordState {
        /**
         * Initial state; not recording.
         *
         * Use {@link prepare} to change to {@link READY} state.
         */
        IDLE,

        /**
         * Ready to start recording.
         *
         * Use {@link start} to change to {@link RECORDING} state.
         */
        READY,

        /**
         * Recording is ongoing.
         *
         * Use {@link stop} to change to {@link FINALIZING} state.<<BR>>
         * Use {@link pause} to change to {@link PAUSED} state.
         */
        RECORDING,

        /**
         * Recording is temporary paused.
         *
         * Use {@link stop} to change to {@link FINALIZING} state.<<BR>>
         * Use {@link resume} to change to {@link RECORDING} state.
         */
        PAUSED,

        /**
         * Completing recording.
         *
         * There is no method to change from this state; {@link Manager.RecordManager} automatically change to {@link IDLE}
         * state when recording completed.
         */
        FINALIZING,
    }

    /**
     * State of {@link Manager.RecordManager}.
     */
    private RecordState state = RecordState.IDLE;

    /**
     * Whether recording is ongoing.
     */
    public bool is_recording {
        get {
            return state != RecordState.IDLE;
        }
    }

    /**
     * Current sound level, taking value from 0 to 1.
     */
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

    private const uint64 NSEC = 1000000000;
    private const string IGNORED_PROPNAMES[] = {
        "name", "parent", "direction", "template", "caps"
    };

    private Gst.Pipeline pipeline;

    private static Gee.HashMap<Define.FormatID, Model.Recorder.AbstractRecorder> recorder_table;

    /**
     * Gets a unique instance of {@link RecordManager}.
     *
     * @return A unique {@link RecordManager}. Do not ref or unref it
     */
    public static unowned RecordManager get_default () {
        if (_instance == null) {
            _instance = new RecordManager ();
        }

        return _instance;
    }
    private static RecordManager _instance;

    private RecordManager () {
    }

    static construct {
        recorder_table = new Gee.HashMap<Define.FormatID, Model.Recorder.AbstractRecorder> ();
        recorder_table[Define.FormatID.ALAC] = new Model.Recorder.ALACRecorder ();
        recorder_table[Define.FormatID.FLAC] = new Model.Recorder.FLACRecorder ();
        recorder_table[Define.FormatID.MP3] = new Model.Recorder.MP3Recorder ();
        recorder_table[Define.FormatID.OGG] = new Model.Recorder.OGGRecorder ();
        recorder_table[Define.FormatID.OPUS] = new Model.Recorder.OPUSRecorder ();
        recorder_table[Define.FormatID.WAV] = new Model.Recorder.WAVRecorder ();
    }

    /**
     * Create a pipeline and add elements to it.
     *
     * @param dst_path          destination path where to save recording
     * @param source            information of which type of a device records from
     * @param channel           number of channels
     * @param format            file format that is encoded to
     * @param meta_author       artist name that will be set to metadata as value of "Artist". Set null for no metadata
     * @param meta_record_dt    date & time that will be set to metadata as value of "Year". Set null for no metadata
     *
     * @throws Error            information about an error occurred while setup
     */
    public void prepare (
        string dst_path,
        Define.SourceID source,
        Define.ChannelID channel,
        Define.FormatID format,
        string? meta_author,
        DateTime? meta_record_dt
    ) throws Error {
        pipeline = new Gst.Pipeline ("pipeline");
        if (pipeline == null) {
            throw new Gst.LibraryError.INIT ("Failed to create pipeline");
        }

        var level = Gst.ElementFactory.make ("level", "level");
        if (level == null) {
            throw new Gst.LibraryError.INIT ("Failed to create level element");
        }

        var mixer = Gst.ElementFactory.make ("audiomixer", "mixer");
        if (mixer == null) {
            throw new Gst.LibraryError.INIT ("Failed to create audiomixer element");
        }

        // Prevent audio from stuttering after some time, by setting the latency to other than 0.
        // This issue happens once audiomixer begins to be late and drop buffers.
        // See https://github.com/SeaDve/Kooha/issues/218#issuecomment-1948123954
        mixer.set_property ("latency", 1 * NSEC);

        var sink = Gst.ElementFactory.make ("filesink", "sink");
        if (sink == null) {
            throw new Gst.LibraryError.INIT ("Failed to create filesink element");
        }

        sink.set ("location", dst_path);
        pipeline.add_many (level, mixer, sink);

        Gst.Element? sys_sound = null;
        if (source != Define.SourceID.MIC) {
            sys_sound = Gst.ElementFactory.make ("pulsesrc", "sys_sound");
            if (sys_sound == null) {
                throw new Gst.LibraryError.INIT ("Failed to create pulsesrc element \"sys_sound\"");
            }

            Gst.Device? default_sink = Manager.DeviceManager.get_default ().default_sink;
            string? monitor_name = get_default_monitor_name (default_sink);
            if (monitor_name == null) {
                throw new Gst.LibraryError.SETTINGS (
                    "Failed to set \"device\" property of pulsesrc element \"sys_sound\""
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
            sys_sound.link_pads ("src", mixer, "sink_%u");
        }

        Gst.Element? mic_sound = null;
        if (source != Define.SourceID.SYSTEM) {
            var index = (int) Manager.DeviceManager.get_default ().selected_source_index;
            Gst.Device microphone = Manager.DeviceManager.get_default ().sources[index];
            mic_sound = microphone.create_element ("mic_sound");
            if (mic_sound == null) {
                throw new Gst.LibraryError.INIT ("Failed to create pulsesrc element \"mic_sound\"");
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
            mic_sound.link_pads ("src", mixer, "sink_%u");
        }

        // Dual-channelization
        var caps_channels = new Gst.Caps.simple ("audio/x-raw", "channels", Type.INT, channel);

        mixer.link_filtered (level, caps_channels);

        var recorder = recorder_table[format];
        if (recorder == null) {
            throw new Gst.ResourceError.NOT_FOUND ("No handler for the given file format. format=%d".printf (format));
        }

        recorder.prepare (pipeline, level, sink);

        if (meta_author != null && meta_record_dt != null) {
            // Ignore return value because failure to add metadata does not affect recording itself
            add_metadata (pipeline, meta_author, meta_record_dt);
        }

        pipeline.get_bus ().add_watch (Priority.DEFAULT, bus_message_cb);
    }

    /**
     * Start recording.
     *
     * NOTE: {@link record_err} is thrown if an error occurred while recording. Connect to that signal before calling
     * this method.
     *
     * @return true if succeeded, false otherwise.
     */
    public bool start () {
        if (state != RecordState.READY) {
            critical ("[BUG] RecordManager.start() error: invalid state %d", state);
            return false;
        }

        state = RecordState.RECORDING;

        pipeline.set_state (Gst.State.PLAYING);

        return true;
    }

    /**
     * Stop recording.
     *
     * NOTE: {@link record_err} is thrown if recording completed successfully. Connect to that signal before calling
     * this method.
     *
     * @return true if succeeded, false otherwise.
     */
    public bool stop () {
        if (state != RecordState.RECORDING || state != RecordState.PAUSED) {
            critical ("[BUG] RecordManager.stop() error: invalid state %d", state);
            return false;
        }

        state = RecordState.FINALIZING;

        // Pipelines don't seem to catch events when it's in the PAUSED state
        pipeline.set_state (Gst.State.PLAYING);

        pipeline.send_event (new Gst.Event.eos ());

        return true;
    }

    /**
     * Cancel recording.
     *
     * @return true if succeeded, false otherwise.
     */
    public bool cancel () {
        if (state != RecordState.RECORDING || state != RecordState.PAUSED) {
            critical ("[BUG] RecordManager.cancel() error: invalid state %d", state);
            return false;
        }

        pipeline.set_state (Gst.State.NULL);
        pipeline.dispose ();

        state = RecordState.READY;

        return true;
    }

    /**
     * Pause recording.
     *
     * @return true if succeeded, false otherwise.
     */
    public bool pause () {
        if (state != RecordState.RECORDING) {
            critical ("[BUG] RecordManager.pause() error: invalid state %d", state);
            return false;
        }

        pipeline.set_state (Gst.State.PAUSED);

        state = RecordState.PAUSED;

        return true;
    }

    /**
     * Resume recording.
     *
     * @return true if succeeded, false otherwise.
     */
    public bool resume () {
        if (state != RecordState.PAUSED) {
            critical ("[BUG] RecordManager.resume() error: invalid state %d", state);
            return false;
        }

        state = RecordState.RECORDING;

        pipeline.set_state (Gst.State.PLAYING);

        return true;
    }

    private bool bus_message_cb (Gst.Bus bus, Gst.Message message) {
        switch (message.type) {
            case Gst.MessageType.ERROR:
                return bus_message_cb_error (bus, message);
            case Gst.MessageType.EOS:
                return bus_message_cb_eos (bus, message);
            case Gst.MessageType.ELEMENT:
                return bus_message_cb_element (bus, message);
            default:
                break;
        }

        // Returning false means unwatching the bus as per https://valadoc.org/gstreamer-1.0/Gst.Bus.add_watch.html,
        // so return true even if we don't handle the message
        return true;
    }

    private bool bus_message_cb_error (Gst.Bus bus, Gst.Message message) {
        pipeline.set_state (Gst.State.NULL);
        pipeline.dispose ();

        Error err;
        string debug_info;
        message.parse_error (out err, out debug_info);

        warning ("Error received from element \"%s\": err=\"%s\" debug_info=\"%s\"",
                    message.src.name, err.message, debug_info);

        state = RecordState.IDLE;

        record_err (err, debug_info);

        return true;
    }

    private bool bus_message_cb_eos (Gst.Bus bus, Gst.Message message) {
        pipeline.set_state (Gst.State.NULL);
        pipeline.dispose ();

        state = RecordState.IDLE;

        record_ok ();

        return true;
    }

    private bool bus_message_cb_element (Gst.Bus bus, Gst.Message message) {
        unowned Gst.Structure? structure = message.get_structure ();
        if (!structure.has_name ("level")) {
            return true;
        }

        // FIXME: ValueArray is deprecated but used as an I/F structure in the GStreamer side:
        // https://gitlab.freedesktop.org/gstreamer/gstreamer/-/blob/1.20.5/subprojects/gst-plugins-good/gst/level/gstlevel.c#L579
        // We would need a patch for GStreamer to replace ValueArray with Array
        // when it's removed before GStreamer resolves
        unowned var peak_arr = (ValueArray) structure.get_value ("peak").get_boxed ();
        if (peak_arr == null) {
            return true;
        }

        current_peak = peak_arr.get_nth (0).get_double ();

        return true;
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
     * Add metadata to the stream using a {@link Gst.TagSetter} element found from #pipeline.
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
     * @param artist        artist name that will be set to metadata as value of "Artist"
     * @param date_time     date & time that will be set to metadata as value of "Year"
     *
     * @return              true if succeeded, false otherwise
     */
    private bool add_metadata (Gst.Pipeline pipeline, string artist, DateTime date_time) {
        Gst.TagSetter? tag_setter = pipeline.get_by_interface (typeof (Gst.TagSetter)) as Gst.TagSetter;
        if (tag_setter == null) {
            warning ("Element that implements GstTagSetter not found");
            return false;
        }

        // "Year" tag seems to correspond to a Gst.Tags.DATE_TIME tag (takes Gst.DateTime value)
        // and a Gst.Tags.DATE tag (takes Date value); Setting only the former results missing "Year" tag
        // in WAV and MP3 files and setting the latter too works as expected.
        var gst_date_time = new Gst.DateTime.from_g_date_time (date_time);
        Date date = Util.dt2date (date_time);

        tag_setter.add_tags (Gst.TagMergeMode.REPLACE_ALL,
                             Gst.Tags.ARTIST, artist,
                             Gst.Tags.DATE_TIME, gst_date_time,
                             Gst.Tags.DATE, date);

        return true;
    }
}
