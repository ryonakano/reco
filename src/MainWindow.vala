/*
* (C) 2019 Ryo Nakano
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

public class MainWindow : Gtk.ApplicationWindow {
    public Application app { get; construct; }
    public WelcomeView welcome_view { get; private set; }
    private CountDownView countdown_view;
    public RecordView record_view { get; private set; }
    public Gtk.Stack stack { get; private set; }

    public MainWindow (Application app) {
        Object (
            border_width: 6,
            application: app,
            app: app,
            resizable: false,
            width_request: 400,
            height_request: 300
        );
    }

    construct {
        var cssprovider = new Gtk.CssProvider ();
        cssprovider.load_from_resource ("/com/github/ryonakano/reco/Application.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
                                                    cssprovider,
                                                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var headerbar = new Gtk.HeaderBar ();
        headerbar.title = "";
        headerbar.has_subtitle = false;
        headerbar.show_close_button = true;

        var headerbar_style_context = headerbar.get_style_context ();
        headerbar_style_context.add_class (Gtk.STYLE_CLASS_FLAT);
        headerbar_style_context.add_class ("default-decoration");

        welcome_view = new WelcomeView (this);
        countdown_view = new CountDownView (this);
        record_view = new RecordView (this);

        stack = new Gtk.Stack ();
        stack.add_named (welcome_view, "welcome");
        stack.add_named (countdown_view, "count");
        stack.add_named (record_view, "record");

        set_titlebar (headerbar);
        get_style_context ().add_class ("rounded");
        add (stack);
        show_welcome ();

        delete_event.connect ((event) => {
            if (record_view.is_recording) {
                var loop = new MainLoop ();
                record_view.stop_recording.begin ((obj, res) => {
                    loop.quit ();
                });
                loop.run ();
            }

            return false;
        });
    }

    public void show_welcome () {
        stack.visible_child_name = "welcome";
    }

    public void show_countdown () {
        stack.visible_child_name = "count";
        countdown_view.start_countdown ();
    }

    public void show_record () {
        stack.visible_child_name = "record";
        record_view.start_recording ();
    }

    // Save window position when changed
    public override bool configure_event (Gdk.EventConfigure event) {
        int x, y;
        get_position (out x, out y);
        Application.settings.set ("window-position", "(ii)", x, y);

        return base.configure_event (event);
    }
}
