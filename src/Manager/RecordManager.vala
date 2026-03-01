/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 *
 * Special Thanks: Screencast was an amazing reference of GStreamer related code in early development of the app!
 * https://github.com/artemanufrij/screencast/blob/1.0.0/src/MainWindow.vala
 */

/**
 * Manages recording
 *
 * State machine:
 *
 * {{../docs/images/Manager/RecordManager/state.drawio.svg|figure of state machine}}
 *
 * Pipeline configuration, example when MP3 is selected as a format:
 *
 * {{../docs/images/Manager/RecordManager/pipeline.drawio.svg|figure of pipeline configuration}}
 */
public class Manager.RecordManager : Object {
    /**
     * Emitted when a fatal internal error occurred
     *
     * @param err           information about the error
     * @param debug_info    debug message for the error
     */
    public signal void record_err (Error err, string debug_info);

    /**
     * Emitted when recording succeeds
     */
    public signal void record_ok ();

    /**
     * States that {@link Manager.RecordManager} can take
     */
    private enum RecordState {
        /**
         * Initial state; not recording
         *
         * Use {@link Manager.RecordManager.prepare} to change to {@link READY} state
         */
        IDLE,

        /**
         * Ready to start recording
         *
         * Use {@link Manager.RecordManager.start} to change to {@link RECORDING} state
         */
        READY,

        /**
         * Recording is ongoing
         *
         * Use {@link Manager.RecordManager.stop} to change to {@link FINALIZING} state<<BR>>
         * Use {@link Manager.RecordManager.pause} to change to {@link PAUSED} state<<BR>>
         * Use {@link Manager.RecordManager.cancel} to discard recording and change to {@link IDLE} state
         */
        RECORDING,

        /**
         * Recording is temporary paused
         *
         * Use {@link Manager.RecordManager.resume} to change to {@link RECORDING} state<<BR>>
         * Use {@link Manager.RecordManager.stop} to change to {@link FINALIZING} state<<BR>>
         * Use {@link Manager.RecordManager.cancel} to discard recording and change to {@link IDLE} state
         */
        PAUSED,

        /**
         * Completing recording
         *
         * {@link Manager.RecordManager} automatically changes to {@link IDLE} state when recording completed<<BR>>
         * Use {@link Manager.RecordManager.cancel} to discard recording and change to {@link IDLE} state
         */
        FINALIZING,
    }

    /**
     * State of ``this``
     */
    private RecordState state = RecordState.IDLE;

    /**
     * Current sound level, taking value from 0 to 1
     */
    // Inspired from GNOME Sound Recorder:
    // https://gitlab.gnome.org/World/vocalis/-/blob/3.38.1/src/recorder.js#L229-242
    public double current_peak {
        get {
            return _current_peak;
        }
        private set {
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

    /**
     * Prepare for recording
     *
     * All elements created in this method should be added to ``pipeline`` using {@link Gst.Bin.add}
     * and linked to ``src`` or ``dst`` elements appropriately using {@link Gst.Pad.link}
     *
     * {{../docs/images/Manager/RecordManager/format_specific_elements.drawio.svg|figure of format-specific elements}}
     *
     * Note: This method should add at least one element that inherits {@link Gst.TagSetter} to ``pipeline``
     * for metadata<<BR>>
     * See {@link add_metadata} for details
     *
     * @param pipeline  pipeline that holds all elements necessary for recording
     * @param src       an element that precedes all elements created in this method
     * @param dst       an element that succeeds to all elements created in this method
     *
     * @return          ``true`` if succeeds, ``false`` otherwise
     */
    [ CCode ( has_target = false ) ]
    private delegate bool FormatSpecificPrepareFunc (Gst.Pipeline pipeline, Gst.Element src, Gst.Element dst);

    /**
     * Function table of format-specific procedure in {@link prepare}
     */
    private static Gee.HashMap<Define.FormatID, FormatSpecificPrepareFunc> prepare_fmt_table;

    /**
     * Gets a unique instance of {@link Manager.RecordManager}
     *
     * @return A unique {@link Manager.RecordManager}. Do not ref or unref it
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
        prepare_fmt_table = new Gee.HashMap<Define.FormatID, FormatSpecificPrepareFunc> ();
        prepare_fmt_table[Define.FormatID.ALAC] = prepare_alac;
        prepare_fmt_table[Define.FormatID.FLAC] = prepare_flac;
        prepare_fmt_table[Define.FormatID.MP3] = prepare_mp3;
        prepare_fmt_table[Define.FormatID.OGG] = prepare_ogg;
        prepare_fmt_table[Define.FormatID.OPUS] = prepare_opus;
        prepare_fmt_table[Define.FormatID.WAV] = prepare_wav;
    }

    /**
     * Create a pipeline and add elements to it
     *
     * This changes state of ``this`` from Idle to Ready if succeeds
     *
     * @param dst_path          destination path where to save recording
     * @param source            information of which type of a device records from
     * @param channel           number of channels
     * @param format            file format that is encoded to
     * @param meta_author       artist name that will be set to metadata as value of "Artist". Set null for no metadata
     * @param meta_record_dt    date & time that will be set to metadata as value of "Year". Set null for no metadata
     *
     * @return                  ``true`` if succeeds, ``false`` otherwise
     */
    public bool prepare (
        string dst_path,
        Define.SourceID source,
        Define.ChannelID channel,
        Define.FormatID format,
        string? meta_author,
        DateTime? meta_record_dt
    ) {
        pipeline = new Gst.Pipeline ("pipeline");
        if (pipeline == null) {
            warning ("Failed to create pipeline");
            return false;
        }

        // Use to mix sounds from a microphone and system
        var mixer = Gst.ElementFactory.make ("audiomixer", "mixer");
        if (mixer == null) {
            warning ("Failed to create audiomixer element");
            return false;
        }

        pipeline.add (mixer);

        // Prevent audio from stuttering after some time, by setting the latency to other than 0
        // This issue happens once audiomixer begins to be late and drop buffers
        // See https://github.com/SeaDve/Kooha/issues/218#issuecomment-1948123954
        mixer.set_property ("latency", 1 * NSEC);

        var sink = Gst.ElementFactory.make ("filesink", "sink");
        if (sink == null) {
            warning ("Failed to create filesink element");
            return false;
        }

        sink.set ("location", dst_path);

        pipeline.add (sink);

        if (source != Define.SourceID.MIC) {
            // Use to record sound from system
            var sys_sound = Gst.ElementFactory.make ("pulsesrc", "sys_sound");
            if (sys_sound == null) {
                warning ("Failed to create pulsesrc element \"sys_sound\"");
                return false;
            }

            Gst.Device? default_sink = Manager.DeviceManager.get_default ().default_sink;
            string? monitor_name = get_default_monitor_name (default_sink);
            if (monitor_name == null) {
                warning ("Failed to set \"device\" property of pulsesrc element \"sys_sound\"");
                return false;
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

        if (source != Define.SourceID.SYSTEM) {
            var index = (int) Manager.DeviceManager.get_default ().selected_source_index;
            Gst.Device microphone = Manager.DeviceManager.get_default ().sources[index];
            // Use to record sound from a microphone
            Gst.Element mic_sound = microphone.create_element ("mic_sound");
            if (mic_sound == null) {
                warning ("Failed to create pulsesrc element \"mic_sound\"");
                return false;
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

        // Use to retrive peak value
        var level = Gst.ElementFactory.make ("level", "level");
        if (level == null) {
            warning ("Failed to create level element");
            return false;
        }

        pipeline.add (level);
        mixer.link_filtered (level, caps_channels);

        // Format-specific prepare
        unowned var prepare_fmt = prepare_fmt_table[format];
        if (prepare_fmt == null) {
            critical ("No handler for the given file format. format=%d".printf (format));
            return false;
        }

        bool ret = prepare_fmt (pipeline, level, sink);
        if (!ret) {
            warning ("Failed to prepare for the given file format. format=%d".printf (format));
            return false;
        }

        if (meta_author != null && meta_record_dt != null) {
            // Add metadata if requested
            // Ignore return value because failure to add metadata does not affect recording itself
            add_metadata (pipeline, meta_author, meta_record_dt);
        }

        pipeline.get_bus ().add_watch (Priority.DEFAULT, bus_message_cb);

        state = RecordState.READY;

        return true;
    }

    /**
     * ALAC-specific procedure in {@link prepare}
     *
     * @see             FormatSpecificPrepareFunc
     *
     * @param pipeline  pipeline that holds all elements necessary for recording
     * @param src       an element that precedes all elements created in this method
     * @param dst       an element that succeeds to all elements created in this method
     *
     * @return          ``true`` if succeeds, ``false`` otherwise
     */
    private static bool prepare_alac (Gst.Pipeline pipeline, Gst.Element src, Gst.Element dst) {
        var encoder = Gst.ElementFactory.make ("avenc_alac", "encoder");
        if (encoder == null) {
            warning ("Failed to create avenc_alac element");
            return false;
        }

        pipeline.add (encoder);
        src.link (encoder);

        var muxer = Gst.ElementFactory.make ("mp4mux", "muxer");
        if (muxer == null) {
            warning ("Failed to create mp4mux element");
            return false;
        }

        pipeline.add (muxer);
        encoder.link_pads ("src", muxer, "audio_%u");
        muxer.link (dst);

        return true;
    }

    /**
     * FLAC-specific procedure in {@link prepare}
     *
     * @see             FormatSpecificPrepareFunc
     *
     * @param pipeline  pipeline that holds all elements necessary for recording
     * @param src       an element that precedes all elements created in this method
     * @param dst       an element that succeeds to all elements created in this method
     *
     * @return          ``true`` if succeeds, ``false`` otherwise
     */
    private static bool prepare_flac (Gst.Pipeline pipeline, Gst.Element src, Gst.Element dst) {
        var encoder = Gst.ElementFactory.make ("flacenc", "encoder");
        if (encoder == null) {
            warning ("Failed to create flacenc element");
            return false;
        }

        pipeline.add (encoder);
        src.link (encoder);
        encoder.link (dst);

        return true;
    }

    /**
     * MP3-specific procedure in {@link prepare}
     *
     * @see             FormatSpecificPrepareFunc
     *
     * @param pipeline  pipeline that holds all elements necessary for recording
     * @param src       an element that precedes all elements created in this method
     * @param dst       an element that succeeds to all elements created in this method
     *
     * @return          ``true`` if succeeds, ``false`` otherwise
     */
    private static bool prepare_mp3 (Gst.Pipeline pipeline, Gst.Element src, Gst.Element dst) {
        var encoder = Gst.ElementFactory.make ("lamemp3enc", "encoder");
        if (encoder == null) {
            warning ("Failed to create lamemp3enc element");
            return false;
        }

        pipeline.add (encoder);
        src.link (encoder);

        var muxer = Gst.ElementFactory.make ("id3v2mux", "muxer");
        if (muxer == null) {
            warning ("Failed to create id3v2mux element");
            return false;
        }

        pipeline.add (muxer);
        encoder.link_many (muxer, dst);
        muxer.link (dst);

        return false;
    }

    /**
     * OGG-specific procedure in {@link prepare}
     *
     * @see             FormatSpecificPrepareFunc
     *
     * @param pipeline  pipeline that holds all elements necessary for recording
     * @param src       an element that precedes all elements created in this method
     * @param dst       an element that succeeds to all elements created in this method
     *
     * @return          ``true`` if succeeds, ``false`` otherwise
     */
    private static bool prepare_ogg (Gst.Pipeline pipeline, Gst.Element src, Gst.Element dst) {
        var encoder = Gst.ElementFactory.make ("vorbisenc", "encoder");
        if (encoder == null) {
            warning ("Failed to create vorbisenc element");
            return false;
        }

        pipeline.add (encoder);
        src.link (encoder);

        var muxer = Gst.ElementFactory.make ("oggmux", "muxer");
        if (muxer == null) {
            warning ("Failed to create oggmux element");
            return false;
        }

        pipeline.add (muxer);
        encoder.link_pads ("src", muxer, "audio_%u");
        muxer.link (dst);

        return true;
    }

    /**
     * OPUS-specific procedure in {@link prepare}
     *
     * @see             FormatSpecificPrepareFunc
     *
     * @param pipeline  pipeline that holds all elements necessary for recording
     * @param src       an element that precedes all elements created in this method
     * @param dst       an element that succeeds to all elements created in this method
     *
     * @return          ``true`` if succeeds, ``false`` otherwise
     */
    private static bool prepare_opus (Gst.Pipeline pipeline, Gst.Element src, Gst.Element dst) {
        var encoder = Gst.ElementFactory.make ("opusenc", "encoder");
        if (encoder == null) {
            warning ("Failed to create opusenc element");
            return false;
        }

        pipeline.add (encoder);
        src.link (encoder);

        var muxer = Gst.ElementFactory.make ("oggmux", "muxer");
        if (muxer == null) {
            warning ("Failed to create oggmux element");
            return false;
        }

        pipeline.add (muxer);
        encoder.link_pads ("src", muxer, "audio_%u");
        muxer.link (dst);

        return true;
    }

    /**
     * WAV-specific procedure in {@link prepare}
     *
     * @see             FormatSpecificPrepareFunc
     *
     * @param pipeline  pipeline that holds all elements necessary for recording
     * @param src       an element that precedes all elements created in this method
     * @param dst       an element that succeeds to all elements created in this method
     *
     * @return          ``true`` if succeeds, ``false`` otherwise
     */
    private static bool prepare_wav (Gst.Pipeline pipeline, Gst.Element src, Gst.Element dst) {
        var encoder = Gst.ElementFactory.make ("wavenc", "encoder");
        if (encoder == null) {
            warning ("Failed to create wavenc element");
            return false;
        }

        pipeline.add (encoder);
        src.link (encoder);
        encoder.link (dst);

        return true;
    }

    /**
     * Start recording
     *
     * This changes state of ``this`` from Ready to Recording if succeeds
     *
     * Note: {@link record_err} is thrown if an error occurred while recording. Connect to it before calling
     * this method
     *
     * @return ``true`` if succeeds, ``false`` otherwise
     */
    public bool start () {
        if (state != RecordState.READY) {
            critical ("[BUG] invalid state %d", state);
            return false;
        }

        state = RecordState.RECORDING;

        pipeline.set_state (Gst.State.PLAYING);

        return true;
    }

    /**
     * Stop recording
     *
     * This changes state of ``this`` from Recording or Paused to Finalizing if succeeds
     *
     * Note: This method just send an end-of-stream event to an internal pipeline; the return value does not indicate
     * whether the pipeline handles the event successfully.<<BR>>
     * Instead, {@link record_err} is thrown if recording completed successfully. Connect to it before calling
     * this method
     *
     * @return ``true`` if succeeds, ``false`` otherwise
     */
    public bool stop () {
        if (state != RecordState.RECORDING && state != RecordState.PAUSED) {
            critical ("[BUG] invalid state %d", state);
            return false;
        }

        state = RecordState.FINALIZING;

        // Pipelines don't seem to catch events when it's in the PAUSED state
        pipeline.set_state (Gst.State.PLAYING);

        pipeline.send_event (new Gst.Event.eos ());

        return true;
    }

    /**
     * Cancel recording
     *
     * This changes state of ``this`` from Recording, Paused, or Finalizing to Idle if succeeds
     *
     * @return ``true`` if succeeds, ``false`` otherwise
     */
    public bool cancel () {
        if (state != RecordState.RECORDING && state != RecordState.PAUSED && state != RecordState.FINALIZING) {
            critical ("[BUG] invalid state %d", state);
            return false;
        }

        pipeline.set_state (Gst.State.NULL);
        pipeline.dispose ();

        state = RecordState.IDLE;

        return true;
    }

    /**
     * Pause recording
     *
     * This changes state of ``this`` from Recording to Paused if succeeds
     *
     * @return ``true`` if succeeds, ``false`` otherwise
     */
    public bool pause () {
        if (state != RecordState.RECORDING) {
            critical ("[BUG] invalid state %d", state);
            return false;
        }

        pipeline.set_state (Gst.State.PAUSED);

        state = RecordState.PAUSED;

        return true;
    }

    /**
     * Resume recording
     *
     * This changes state of ``this`` from Paused to Recording if succeeds
     *
     * @return ``true`` if succeeds, ``false`` otherwise
     */
    public bool resume () {
        if (state != RecordState.PAUSED) {
            critical ("[BUG] invalid state %d", state);
            return false;
        }

        state = RecordState.RECORDING;

        pipeline.set_state (Gst.State.PLAYING);

        return true;
    }

    /**
     * Request to stop ongoing recording safely if such exists
     *
     * @return ``true`` if shutdown completed; {@link state} is set to {@link RecordState.IDLE}.<<BR>>
     * ``false`` otherwise; the caller must wait until either one of {@link record_ok} or {@link record_err}
     * signals being emitted. {@link state} is set to {@link RecordState.IDLE} after either signal is emitted
     */
    public bool request_shutdown () {
        switch (state) {
            case RecordState.IDLE:
                // NOP
                return true;
            case RecordState.READY:
                // Recording not yet started so just chaing state is enough
                state = RecordState.IDLE;
                return true;
            case RecordState.RECORDING:
            case RecordState.PAUSED:
                // Start finalizing
                stop ();
                return false;
            case RecordState.FINALIZING:
                // NOP; already working for finalizing
                return false;
            default:
                critical ("[BUG] invalid state %d", state);
                assert_not_reached ();
        }
    }

    /**
     * Handles {@link Gst.Message}
     *
     * @see             Gst.BusFunc
     *
     * @param bus       the {@link Gst.Bus} that sent the message
     * @param message   the {@link Gst.Message}
     *
     * @return          ``false`` if the event source should be removed
     */
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

    /**
     * Handles {@link Gst.MessageType.ERROR}
     *
     * This stops recording and parse error message and debug info from ``message``
     *
     * @see             Gst.BusFunc
     *
     * @param bus       the {@link Gst.Bus} that sent the message
     * @param message   the {@link Gst.Message}
     *
     * @return          ``false`` if the event source should be removed
     */
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

    /**
     * Handles {@link Gst.MessageType.EOS}
     *
     * This finalizes recording
     *
     * @see             Gst.BusFunc
     *
     * @param bus       the {@link Gst.Bus} that sent the message
     * @param message   the {@link Gst.Message}
     *
     * @return          ``false`` if the event source should be removed
     */
    private bool bus_message_cb_eos (Gst.Bus bus, Gst.Message message) {
        pipeline.set_state (Gst.State.NULL);
        pipeline.dispose ();

        state = RecordState.IDLE;

        record_ok ();

        return true;
    }

    /**
     * Handles {@link Gst.MessageType.ELEMENT}
     *
     * This gets peak value from the level element in the pipeline
     *
     * @see             Gst.BusFunc
     *
     * @param bus       the {@link Gst.Bus} that sent the message
     * @param message   the {@link Gst.Message}
     *
     * @return          ``false`` if the event source should be removed
     */
    // Inspired from GNOME Sound Recorder:
    // https://gitlab.gnome.org/World/vocalis/-/blob/3.38.1/src/recorder.js#L175-191
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

    /**
     * Get name of a default monitor device from name of a default sink device
     *
     * @param default_sink      a default sink device
     *
     * @return                  name of a default monitor device if succeeds, ``null`` otherwise
     */
    // Inspired from ``get_launch_line()`` in GStreamer:
    // https://gitlab.freedesktop.org/gstreamer/gstreamer/-/blob/1.20.6/subprojects/gst-plugins-base/tools/gst-device-monitor.c#L45-135
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
     * Add metadata to the stream using a {@link Gst.TagSetter} element found from ``pipeline``
     *
     * Note: You should call this method before ``pipeline`` goes to {@link Gst.State.PAUSED}
     *
     * See also:
     *
     *  * [[https://gstreamer.freedesktop.org/documentation/application-development/advanced/metadata.html?gi-language=c#tag-writing]]
     *  * [[https://gstreamer.freedesktop.org/documentation/gstreamer/gsttagsetter.html?gi-language=c]]
     *
     * @param pipeline      a {@link Gst.Pipeline} that has at least one {@link Gst.Element} that inherits
     *                      {@link Gst.TagSetter} interface, e.g. "vorbisenc", "theoraenc", "id3v2mux", etc.
     * @param artist        artist name that will be set to metadata as value of "Artist"
     * @param date_time     date & time that will be set to metadata as value of "Year"
     *
     * @return              ``true`` if succeeds, ``false`` otherwise
     */
    private bool add_metadata (Gst.Pipeline pipeline, string artist, DateTime date_time) {
        Gst.TagSetter? tag_setter = pipeline.get_by_interface (typeof (Gst.TagSetter)) as Gst.TagSetter;
        if (tag_setter == null) {
            critical ("Element that implements GstTagSetter not found");
            return false;
        }

        // "Year" tag seems to correspond to a Gst.Tags.DATE_TIME tag (takes Gst.DateTime value)
        // and a Gst.Tags.DATE tag (takes Date value); Setting only the former results missing "Year" tag
        // in WAV and MP3 files and setting the latter too works as expected
        var gst_date_time = new Gst.DateTime.from_g_date_time (date_time);
        Date date = Util.dt2date (date_time);

        tag_setter.add_tags (Gst.TagMergeMode.REPLACE_ALL,
                             Gst.Tags.ARTIST, artist,
                             Gst.Tags.DATE_TIME, gst_date_time,
                             Gst.Tags.DATE, date);

        return true;
    }
}
