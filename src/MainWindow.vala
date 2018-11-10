/*
* Copyright (c) 2018 Reco Developers
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
    private Gtk.Stack stack;

    public MainWindow (Application app) {
        Object (
            border_width: 6,
            application: app,
            resizable: false,
            width_request: 400,
            height_request: 300
        );
    }

    construct {
        window_position = Gtk.WindowPosition.CENTER;

        var headerbar = new Gtk.HeaderBar ();
        headerbar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        headerbar.get_style_context ().add_class ("default-decoration");
        headerbar.title = "";
        headerbar.has_subtitle = false;

        stack = new Gtk.Stack ();
        var welcome_view = new WelcomeView (this);
        var record_view = new RecordView (this);
        stack.add_named (welcome_view, "welcome");
        stack.add_named (record_view, "record");

        set_titlebar (headerbar);
        get_style_context ().add_class ("rounded");
        show_welcome ();
        add (stack);
        show_all ();
    }

    public void show_welcome () {
        stack.visible_child_name = "welcome";
    }

    public void show_record () {
        stack.visible_child_name = "record";
    }
}
