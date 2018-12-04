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

public class MainWindow : Gtk.ApplicationWindow {
    public Application app { get; construct; }
    private Gtk.HeaderBar headerbar;
    private Gtk.Stack stack;
    public WelcomeView welcome_view { get; private set; }
    public CountDownView countdown_view { get; private set; }
    public RecordView record_view { get; private set; }

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
        // Import CSS
        var cssprovider = new Gtk.CssProvider ();
        cssprovider.load_from_resource ("/com/github/ryonakano/reco/Application.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
                                                    cssprovider,
                                                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        headerbar = new Gtk.HeaderBar ();
        headerbar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        headerbar.get_style_context ().add_class ("default-decoration");
        headerbar.title = "";
        headerbar.has_subtitle = false;

        stack = new Gtk.Stack ();
        welcome_view = new WelcomeView (this);
        countdown_view = new CountDownView (this);
        record_view = new RecordView (this, app);
        stack.add_named (welcome_view, "welcome");
        stack.add_named (countdown_view, "count");
        stack.add_named (record_view, "record");

        set_titlebar (headerbar);
        get_style_context ().add_class ("rounded");
        add (stack);
        show_welcome ();
    }

    public void show_welcome () {
        stack.visible_child_name = "welcome";
        headerbar.show_close_button = true;
    }

    public void show_countdown () {
        stack.visible_child_name = "count";
        countdown_view.start_count ();
    }

    public void show_record () {
        stack.visible_child_name = "record";
        record_view.start_recording ();
        headerbar.show_close_button = false;
    }

    // Save window position when changed
    public override bool configure_event (Gdk.EventConfigure event) {
        int x, y;
        get_position (out x, out y);
        Application.settings.set_int ("window-x", x);
        Application.settings.set_int ("window-y", y);

        return base.configure_event (event);
    }
}
