/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2024 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Manager.DeviceManager : Object {
    public signal void device_updated ();

    public Gee.ArrayList<Gst.Device> sources { get; private set; }
    public Gee.ArrayList<Gst.Device> sinks { get; private set; }

    public Gst.Device? default_source { get; private set; }
    public Gst.Device? default_sink { get; private set; }

    public uint selected_source_index { get; set; }

    private static DeviceManager? _instance = null;
    public static unowned DeviceManager get_default () {
        if (_instance == null) {
            _instance = new DeviceManager ();
        }

        return _instance;
    }

    private Gst.DeviceMonitor monitor;

    private DeviceManager () {
        monitor = new Gst.DeviceMonitor ();
        monitor.get_bus ().add_watch (Priority.DEFAULT, (bus, msg) => {
            switch (msg.type) {
                case Gst.MessageType.DEVICE_ADDED:
                case Gst.MessageType.DEVICE_CHANGED:
                case Gst.MessageType.DEVICE_REMOVED:
                    update_devices ();
                    break;
                default:
                    break;
            }

            return Source.CONTINUE;
        });

        var caps = new Gst.Caps.empty_simple ("audio/x-raw");
        monitor.add_filter ("Source/Audio", caps);
        monitor.add_filter ("Sink/Audio", caps);

        sources = new Gee.ArrayList<Gst.Device> ();
        sinks = new Gee.ArrayList<Gst.Device> ();

        monitor.start ();
    }

    private void update_devices () {
        bool is_default;

        if (sources.size > 0) {
            sources.clear ();
        }

        if (sinks.size > 0) {
            sinks.clear ();
        }

        default_source = null;
        default_sink = null;

        foreach (var device in monitor.get_devices ()) {
            Gst.Structure properties = device.properties;

            if (properties.get_string ("device.class") != "sound") {
                continue;
            }

            if (device.has_classes ("Source")) {
                if (sources.contains (device)) {
                    continue;
                }

                debug ("Source detected: \"%s\"", device.display_name);
                sources.add (device);

                if (properties.get_boolean ("is-default", out is_default) && is_default) {
                    default_source = device;
                    debug ("Default source: \"%s\"", default_source.display_name);
                }
            }

            if (device.has_classes ("Sink")) {
                if (sinks.contains (device)) {
                    continue;
                }

                debug ("Sink detected: \"%s\"", device.display_name);
                sinks.add (device);

                if (properties.get_boolean ("is-default", out is_default) && is_default) {
                    default_sink = device;
                    debug ("Default sink: \"%s\"", default_sink.display_name);
                }
            }
        }

        device_updated ();
    }
}
