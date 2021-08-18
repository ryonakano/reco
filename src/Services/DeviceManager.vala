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
*/

public class DeviceManager : Object {
    public signal void device_updated ();

    public Gee.ArrayList<Gst.Device> microphones { get; private set; }
    public Gee.ArrayList<Gst.Device> monitors { get; private set; }

    private static DeviceManager? _instance = null;
    public static DeviceManager get_default () {
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
                case Gst.MessageType.DEVICE_REMOVED:
                    update_devices ();
                    break;
                default:
                    break;
            }

            return Source.CONTINUE;
        });
        monitor.add_filter ("Source/Audio", new Gst.Caps.empty_simple ("audio/x-raw"));

        microphones = new Gee.ArrayList<Gst.Device> ();
        monitors = new Gee.ArrayList<Gst.Device> ();
        update_devices ();

        monitor.start ();
    }

    private void update_devices () {
        if (microphones.size > 0) {
            microphones.clear ();
        }

        if (monitors.size > 0) {
            monitors.clear ();
        }

        foreach (var device in monitor.get_devices ()) {
            Gst.Structure properties = device.properties;

            switch (properties.get_string ("device.class")) {
                case "sound":
                    if (!microphones.contains (device)) {
                        debug ("Microphone detected: %s", device.display_name);
                        microphones.add (device);
                    }

                    break;
                case "monitor":
                    if (!monitors.contains (device)) {
                        debug ("Monitor detected: %s", device.display_name);
                        monitors.add (device);
                    }

                    break;
                default:
                    warning ("Unexpected device class: %s", properties.get_string ("device.class"));
                    continue;
            }
        }

        device_updated ();
    }
}
