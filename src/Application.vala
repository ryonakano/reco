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

public class Application : Gtk.Application {
    private MainWindow window;
    public static Settings settings;
    public bool is_first_run { get; private set; }

    public Application () {
        Object (
            application_id: "com.github.ryonakano.reco",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    construct {
    }

    static construct {
        settings = new Settings ("com.github.ryonakano.reco");
    }

    protected override void activate () {
        if (window != null) { // The app is already launched
            window.present ();
            return;
        }

        var window_x = settings.get_int ("window-x");
        var window_y = settings.get_int ("window-y");

        if (Application.settings.get_string ("destination") == "") {
            is_first_run = true;
            Application.settings.set_boolean ("auto-save", false);
        }

        window = new MainWindow (this);

        if (window_x != -1 || window_y != -1) { // Not a first time launch
            window.move (window_x, window_y);
        } else { // First time launch
            window.window_position = Gtk.WindowPosition.CENTER;
        }

        window.show_all ();

        var quit_action = new SimpleAction ("quit", null);
        add_action (quit_action);
        set_accels_for_action ("app.quit", {"<Control>q"});
        quit_action.activate.connect (() => {
            if (!window.record_view.is_recording) {
                window.destroy ();
            } else {
                var warning_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    _("Are you sure you want to quit Reco?"),
                    _("If you quit Reco, the recording in progress will end."),
                    "dialog-warning", Gtk.ButtonsType.NONE);
                warning_dialog.transient_for = window;
                warning_dialog.modal = true;
                warning_dialog.add_button (_("Cancel"), Gtk.ButtonsType.CANCEL);

                var quit_button = new Gtk.Button.with_label (_("Quit Reco"));
                quit_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
                warning_dialog.add_action_widget (quit_button, Gtk.ResponseType.YES);

                warning_dialog.show_all ();

                warning_dialog.response.connect ((response_id) => {
                    if (response_id == Gtk.ResponseType.YES) {
                        window.record_view.cancel_recording ();
                        window.destroy ();
                    }

                    warning_dialog.destroy ();
                });
            }
        });

        var toggle_recording_action = new SimpleAction ("toggle_recording", null);
        add_action (toggle_recording_action);
        set_accels_for_action ("app.toggle_recording", {"<Control><Shift>R"});
        toggle_recording_action.activate.connect (() => {
            if (window.stack.visible_child_name == "welcome") {
                window.welcome_view.record_button.clicked ();
            } else if (window.stack.visible_child_name == "record") {
                window.record_view.stop_button.clicked ();
            }
        });
    }

    public static int main (string[] args) {
        Gst.init (ref args);
        var app = new Application ();
        return app.run (args);
    }
}
