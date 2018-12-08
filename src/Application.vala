/*
* (C) 2018 Ryo Nakano
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

public class Application : Gtk.Application {
    private MainWindow window;
    public static GLib.Settings settings;

    public Application () {
        Object (
            application_id: "com.github.ryonakano.reco",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    static construct {
        settings = new Settings ("com.github.ryonakano.reco");
    }

    protected override void activate () {
        var window_x = settings.get_int ("window-x");
        var window_y = settings.get_int ("window-y");

        if (window != null) { // The app is already launched
            window.present ();
            return;
        } else {
            window = new MainWindow (this);

            if (window_x != -1 || window_y != -1) { // Not a first time launch
                window.move (window_x, window_y);
            } else { // First time launch
                window.window_position = Gtk.WindowPosition.CENTER;
            }

            window.show_all ();
        }

        var quit_action = new SimpleAction ("quit", null);
        add_action (quit_action);
        set_accels_for_action ("app.quit", {"<Control>q"});
        quit_action.activate.connect (() => {
            if (window != null) {
                window.destroy ();
            }
        });

        var show_file_action = new SimpleAction ("show-file", VariantType.STRING);
        add_action (show_file_action);
        show_file_action.activate.connect (show_file);
    }

    private void show_file (Variant? destination) {
        var uri = destination.get_string ();

        try {
            Process.spawn_command_line_sync ("xdg-open " + uri);
        } catch (Error e) {
            stderr.printf ("Error: %s".printf (e.message));
        }
    }

    public static int main (string[] args) {
        Gst.init (ref args);
        var app = new Application ();
        return app.run (args);
    }
}
