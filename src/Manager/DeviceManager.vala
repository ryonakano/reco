/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Manager.DeviceManager : Object {
    public signal void device_updated ();

    public ListStore sources_list { get; private set; }

    public string? default_source { get; private set; }
    public string? default_monitor { get; private set; }

    public uint selected_source_pos { get; private set; }

    private static DeviceManager? _instance = null;
    public static unowned DeviceManager get_default () {
        if (_instance == null) {
            _instance = new DeviceManager ();
        }

        return _instance;
    }

    private const string CLASS_NAME_SOURCE = "Source/Audio";
    private const string CLASS_NAME_SINK = "Sink/Audio";
    private const string IGNORED_PROPNAMES[] = {
        "name", "parent", "direction", "template", "caps"
    };

    private Gst.DeviceMonitor monitor;

    private DeviceManager () {
        monitor = new Gst.DeviceMonitor ();
        monitor.get_bus ().add_watch (Priority.DEFAULT, bus_message_cb);

        var caps = new Gst.Caps.empty_simple ("audio/x-raw");
        monitor.add_filter (CLASS_NAME_SOURCE, caps);
        monitor.add_filter (CLASS_NAME_SINK, caps);

        sources_list = new ListStore (typeof (Gst.Device));

        default_source = null;
        default_monitor = null;
        selected_source_pos = 0;

        monitor.start ();
    }

    ~DeviceManager () {
        monitor.stop ();
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
            case Gst.MessageType.DEVICE_ADDED:
                bus_message_cb_device_added (bus, message);
                break;
            case Gst.MessageType.DEVICE_CHANGED:
                bus_message_cb_device_changed (bus, message);
                break;
            case Gst.MessageType.DEVICE_REMOVED:
                bus_message_cb_device_removed (bus, message);
                break;
            default:
                break;
        }

        // Returning false means unwatching the bus as per https://valadoc.org/gstreamer-1.0/Gst.Bus.add_watch.html,
        // so return true even if we don't handle the message
        return true;
    }

    /**
     * Handles {@link Gst.MessageType.DEVICE_ADDED}
     *
     * This adds the device to a private list of devices
     *
     * @see             Gst.BusFunc
     *
     * @param bus       the {@link Gst.Bus} that sent the message
     * @param message   the {@link Gst.Message}
     *
     * @return          ``false`` if the event source should be removed
     */
    private bool bus_message_cb_device_added (Gst.Bus bus, Gst.Message message) {
        Gst.Device device;

        message.parse_device_added (out device);

        // Ignore return value because failure to add a device just results it's not shown in the UI
        add_device (device);

        device_updated ();

        return true;
    }

    /**
     * Handles {@link Gst.MessageType.DEVICE_CHANGED}
     *
     * This removes the old device from a private list of devices and adds the new device to it
     *
     * @see             Gst.BusFunc
     *
     * @param bus       the {@link Gst.Bus} that sent the message
     * @param message   the {@link Gst.Message}
     *
     * @return          ``false`` if the event source should be removed
     */
    private bool bus_message_cb_device_changed (Gst.Bus bus, Gst.Message message) {
        Gst.Device new_device;
        Gst.Device old_device;

        message.parse_device_changed (out new_device, out old_device);

        // Ignore return value because failure to remove a device just results it's remain in the UI,
        // which can be reported as an error when staring recording
        remove_device (old_device);
        // Ignore return value because failure to add a device just results it's not shown in the UI
        add_device (new_device);

        device_updated ();

        return true;
    }

    /**
     * Handles {@link Gst.MessageType.DEVICE_REMOVED}
     *
     * This removes the device from a private list of devices
     *
     * @see             Gst.BusFunc
     *
     * @param bus       the {@link Gst.Bus} that sent the message
     * @param message   the {@link Gst.Message}
     *
     * @return          ``false`` if the event source should be removed
     */
    private bool bus_message_cb_device_removed (Gst.Bus bus, Gst.Message message) {
        Gst.Device device;

        message.parse_device_removed (out device);

        // Ignore return value because failure to remove a device just results it's remain in the UI,
        // which can be reported as an error when staring recording
        remove_device (device);

        device_updated ();

        return true;
    }

    /**
     * Add a device to a private list of devices
     *
     * @param device        a device to add
     *
     * @return              ``true`` if ``device`` is added to a list, ``false`` otherwise
     */
    private bool add_device (Gst.Device device) {
        if (device.has_classes (CLASS_NAME_SOURCE)) {
            bool is_found = sources_list.find_with_equal_func (device, sources_list_equal_func, null);
            if (is_found) {
                warning ("[source] add: already added, skipping. device=\"%s\"", device.display_name);
                return true;
            }

            Gst.Structure properties = device.properties;
            if (properties.get_string ("device.class") == "monitor") {
                /*
                 * We want to know just only the default monitor device and don't need non-default ones
                 * but monitor devices does not seem to have is-default property unfortunately.
                 * So ignore all of them here and build its name from corresponding sink device instead.
                 */
                return false;
            }

            bool is_default;
            bool ret = properties.get_boolean ("is-default", out is_default);
            if (!ret) {
                warning ("[source] add: failed to get property \"is-default\". device=\"%s\"", device.display_name);
                return false;
            }

            uint pos = sources_list.insert_sorted (device, sources_list_compare_data_func);

            if (is_default) {
                default_source = device.name;
                selected_source_pos = pos;
            }

            debug ("[source] add: added device \"%s\". is_default=%s", device.display_name, is_default.to_string ());

            return true;
        }

        if (device.has_classes (CLASS_NAME_SINK)) {
            Gst.Structure properties = device.properties;
            bool is_default;
            bool ret = properties.get_boolean ("is-default", out is_default);
            if (!ret) {
                warning ("[sink] add: failed to get property \"is-default\". device=\"%s\"", device.display_name);
                return false;
            }

            if (!is_default) {
                // We don't need non-default sinks
                return false;
            }

            // Build monitor name of the default sink
            string? monitor_name = build_monitor_name (device);
            if (monitor_name == null) {
                warning ("[sink] add: failed to build monitor name of the device. device=\"%s\"", device.display_name);
                return false;
            }

            default_monitor = monitor_name;

            debug ("[sink] add: added device \"%s\"", default_monitor);

            return true;
        }

        return false;
    }

    /**
     * Remove a device from a private list of devices
     *
     * @param device        a device to remove
     *
     * @return              ``true`` if ``device`` is removed from a list, ``false`` otherwise
     */
    private bool remove_device (Gst.Device device) {
        if (device.has_classes (CLASS_NAME_SOURCE)) {
            uint position;
            bool is_found = sources_list.find_with_equal_func (device,
                (a, b) => {
                    return ((Gst.Device) a).name == ((Gst.Device) b).name;
                },
                out position
            );
            if (!is_found) {
                warning ("[source] remove: already removed, skipping. device=\"%s\"", device.display_name);
                return true;
            }

            Gst.Structure properties = device.properties;
            if (properties.get_string ("device.class") == "monitor") {
                // We ignore monitor devices so they will never be added to the list
                return false;
            }

            bool is_default;
            bool ret = properties.get_boolean ("is-default", out is_default);
            if (!ret) {
                warning ("[source] remove: failed to get property \"is-default\". device=\"%s\"", device.display_name);
                return false;
            }

            sources_list.remove (position);

            if (is_default) {
                // Clear the default device only when it's surely the removed device
                // to prevent the new default device from being cleared if it's already detected
                if (default_source == device.name) {
                    default_source = null;
                    selected_source_pos = 0;
                }
            }

            debug ("[source] remove: removed device \"%s\". is_default=%s", device.display_name, is_default.to_string ());

            return true;
        }

        if (device.has_classes (CLASS_NAME_SINK)) {
            Gst.Structure properties = device.properties;
            bool is_default;
            bool ret = properties.get_boolean ("is-default", out is_default);
            if (!ret) {
                warning ("[sink] remove: failed to get property \"is-default\". device=\"%s\"", device.display_name);
                return false;
            }

            if (is_default) {
                // Clear the default device only when it's surely the removed device
                // to prevent the new default device from being cleared if it's already set to
                // default_monitor through add_device()
                if (default_monitor == device.name) {
                    default_monitor = null;

                    debug ("[sink] remove: removed device \"%s\"", device.name);
                }
            }

            return true;
        }

        return false;
    }

    /**
     * Build name of the monitor device from a sink device
     *
     * @param sink      a sink device
     *
     * @return          name of the monitor device of ``sink`` if succeeds, ``null`` otherwise
     */
    // Inspired from ``get_launch_line()`` in GStreamer:
    // https://gitlab.freedesktop.org/gstreamer/gstreamer/-/blob/1.20.6/subprojects/gst-plugins-base/tools/gst-device-monitor.c#L45-135
    private static string? build_monitor_name (Gst.Device sink) {
        Gst.Element? element = sink.create_element (null);
        if (element == null) {
            warning ("failed to Gst.Device.create_element()");
            return null;
        }

        Gst.ElementFactory? factory = element.get_factory ();
        if (factory == null) {
            warning ("failed to Gst.Element.get_factory()");
            return null;
        }

        Gst.Element? pureelement = factory.create (null);
        if (pureelement == null) {
            warning ("failed to Gst.ElementFactory.create()");
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
                    warning ("failed to Gst.Value.serialize(). element=%s property=%s", element.name, property.name);
                    continue;
                }

                return valuestr + ".monitor";
            }
        }

        return null;
    }

    /**
     * Custom equality check function for {@link sources_list}
     *
     * See also: GLib.ListStore.find_with_equal_func
     *
     * @param a     a value, must be type of Gst.Device
     * @param a     a value to compare with, must be type of Gst.Device
     *
     * @return      ``true`` if ``a = b``; ``false`` otherwise
     */
    private static bool sources_list_equal_func (Object a, Object b) {
        return ((Gst.Device) a).name == ((Gst.Device) b).name;
    }

    /**
     * Custom pairwise comparison function for sorting {@link sources_list}
     *
     * See also: GLib.CompareDataFunc
     *
     * @param a     a value, must be type of Gst.Device
     * @param a     a value to compare with, must be type of Gst.Device
     *
     * @return      negative value if ``a < b``; zero if ``a = b``; positive value if ``a > b``
     */
    private static int sources_list_compare_data_func (Object a, Object b) {
        return ((Gst.Device) a).name.collate (((Gst.Device) b).name);
    }
}
