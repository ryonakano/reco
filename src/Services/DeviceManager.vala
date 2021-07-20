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
    public Gee.ArrayList<Device> devices { get; private set; }

    private Gst.DeviceMonitor monitor;

    private static DeviceManager? _instance = null;
    public static DeviceManager get_default () {
        if (_instance == null) {
            _instance = new DeviceManager ();
        }

        return _instance;
    }

    private DeviceManager () {
        monitor = new Gst.DeviceMonitor ();
        monitor.get_bus ().add_watch (Priority.DEFAULT, (bus, msg) => {
            switch (msg.type) {
                case Gst.MessageType.DEVICE_ADDED:
                case Gst.MessageType.DEVICE_REMOVED:
                    devices.clear ();
                    update_devices ();
                    break;
                default:
                    break;
            }

            return Source.CONTINUE;
        });
        monitor.add_filter ("Source/Audio", new Gst.Caps.empty_simple ("audio/x-raw"));

        devices = new Gee.ArrayList<Device> ();
        update_devices ();

        monitor.start ();
    }

    private void update_devices () {
        foreach (var device in monitor.get_devices ()) {
            Gst.Structure properties = device.properties;
            string bus_path = properties.get_string ("device.bus_path").replace (":", "_");

            string device_name = "";
            switch (properties.get_string ("device.class")) {
                case "sound":
                    device_name = "alsa_input.%s.%s".printf (bus_path, properties.get_string ("device.profile.name"));
                    break;
                case "monitor":
                    device_name = "alsa_output.%s.analog-stereo.monitor".printf (bus_path);
                    break;
                default:
                    warning ("Unexpected device class: %s", properties.get_string ("device.class"));
                    break;
            }

            var detected_device = new Device (device.display_name, device_name);
            if (!(devices.contains (detected_device))) {
                debug ("Device detected: %s, %s\n", device.display_name, device_name);
                devices.add (detected_device);
            }
        }

        device_updated ();
    }

    public class Device : Object {
        public string display_name { get; private set ; }
        public string name { get; private set; }

        public Device (string display_name, string name) {
            this.display_name = display_name;
            this.name = name;
        }
    }
}
