/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
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

    private const string CLASS_NAME_SOURCE = "Source/Audio";
    private const string CLASS_NAME_SINK = "Sink/Audio";
    private Gst.DeviceMonitor monitor;

    private DeviceManager () {
        monitor = new Gst.DeviceMonitor ();
        monitor.get_bus ().add_watch (Priority.DEFAULT, bus_message_cb);

        var caps = new Gst.Caps.empty_simple ("audio/x-raw");
        monitor.add_filter (CLASS_NAME_SOURCE, caps);
        monitor.add_filter (CLASS_NAME_SINK, caps);

        sources = new Gee.ArrayList<Gst.Device> ();
        sinks = new Gee.ArrayList<Gst.Device> ();

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
            if (sources.contains (device)) {
                warning ("[source] add: already added, skipping. device=\"%s\"", device.display_name);
                return true;
            }

            Gst.Structure properties = device.properties;
            if (properties.get_string ("device.class") == "monitor") {
                // We manually build device names of monitors so don't add them as a source here
                // TODO: I can't remember why. Needs to review if this is intended
                return false;
            }

            bool is_default;
            bool ret = properties.get_boolean ("is-default", out is_default);
            if (!ret) {
                warning ("[source] add: failed to get property \"is-default\". device=\"%s\"", device.display_name);
                return false;
            }

            ret = sources.add (device);
            if (!ret) {
                warning ("[source] add: failed to add. device=\"%s\"", device.display_name);
                return false;
            }

            if (is_default) {
                default_source = device;
            }

            debug ("[source] add: added device \"%s\". is_default=%s", device.display_name, is_default.to_string ());

            return true;
        }

        if (device.has_classes (CLASS_NAME_SINK)) {
            if (sinks.contains (device)) {
                warning ("[sink] add: already added, skipping. device=\"%s\"", device.display_name);
                return true;
            }

            Gst.Structure properties = device.properties;
            bool is_default;
            bool ret = properties.get_boolean ("is-default", out is_default);
            if (!ret) {
                warning ("[sink] add: failed to get property \"is-default\". device=\"%s\"", device.display_name);
                return false;
            }

            ret = sinks.add (device);
            if (!ret) {
                warning ("[sink] add: failed to add. device=\"%s\"", device.display_name);
                return false;
            }

            if (is_default) {
                default_sink = device;
            }

            debug ("[sink] add: added device \"%s\". is_default=%s", device.display_name, is_default.to_string ());

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
            if (!sources.contains (device)) {
                warning ("[source] remove: already removed, skipping. device=\"%s\"", device.display_name);
                return true;
            }

            Gst.Structure properties = device.properties;
            if (properties.get_string ("device.class") == "monitor") {
                // We manually build device names of monitors so don't add them as a source here
                // TODO: I can't remember why. Needs to review if this is intended
                return false;
            }

            bool is_default;
            bool ret = properties.get_boolean ("is-default", out is_default);
            if (!ret) {
                warning ("[source] remove: failed to get property \"is-default\". device=\"%s\"", device.display_name);
                return false;
            }

            ret = sources.remove (device);
            if (!ret) {
                warning ("[source] remove: failed to remove device \"%s\"", device.display_name);
                return false;
            }

            if (is_default) {
                // Clear the default device only when it's surely the removed device
                // to prevent the new default device from being cleared if it's already detected
                if (default_source.name == device.name) {
                    default_source = null;
                }
            }

            debug ("[source] remove: removed device \"%s\". is_default=%s", device.display_name, is_default.to_string ());

            return true;
        }

        if (device.has_classes (CLASS_NAME_SINK)) {
            if (!sinks.contains (device)) {
                warning ("[sink] remove: already removed, skipping. device=\"%s\"", device.display_name);
                return true;
            }

            Gst.Structure properties = device.properties;
            bool is_default;
            bool ret = properties.get_boolean ("is-default", out is_default);
            if (!ret) {
                warning ("[sink] remove: failed to get property \"is-default\". device=\"%s\"", device.display_name);
                return false;
            }

            ret = sinks.remove (device);
            if (!ret) {
                warning ("[sink] remove: failed to remove device \"%s\"", device.display_name);
                return false;
            }

            if (is_default) {
                // Clear the default device only when it's surely the removed device
                // to prevent the new default device from being cleared if it's already detected
                if (default_sink.name == device.name) {
                    default_sink = null;
                }
            }

            debug ("[source] remove: removed device \"%s\". is_default=%s", device.display_name, is_default.to_string ());

            return true;
        }

        return false;
    }
}
