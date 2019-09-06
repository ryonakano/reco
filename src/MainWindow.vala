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
    public WelcomeView welcome_view { get; private set; }
    private CountDownView countdown_view;
    public RecordView record_view { get; private set; }
    public Recorder recorder { get; private set; default = new Recorder (); }
    public Gtk.Stack stack { get; private set; }

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
            if (recorder.is_recording) {
                var loop = new MainLoop ();
                record_view.trigger_stop_recording.begin ((obj, res) => {
                    loop.quit ();
                });
                loop.run ();
            }

            return false;
        });

        recorder.handle_error.connect ((err, debug) => {
            var error_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Unable to Create an Audio File"),
                _("A GStreamer error happened while recording, the following error message may be helpful:"),
                "dialog-error", Gtk.ButtonsType.CLOSE);
            error_dialog.transient_for = this;
            error_dialog.show_error_details ("%s\n%s".printf (err.message, debug));
            error_dialog.run ();
            error_dialog.destroy ();

            record_view.reset_count ();
            show_welcome ();
        });

        recorder.handle_save_file.connect ((tmp_full_path, suffix) => {
            ///TRANSLATORS: %s represents a timestamp here
            string filename = _("Recording from %s").printf (new DateTime.now_local ().format ("%Y-%m-%d %H.%M.%S"));

            var tmp_source = File.new_for_path (tmp_full_path);

            string destination = Application.settings.get_string ("destination");

            if (Application.settings.get_boolean ("auto-save")) {
                try {
                    var uri = File.new_for_path (destination + "/" + filename + suffix);
                    tmp_source.move (uri, FileCopyFlags.OVERWRITE);
                } catch (Error e) {
                    warning (e.message);
                }
            } else {
                var filechooser = new Gtk.FileChooserNative (
                    _("Save your recording"), this, Gtk.FileChooserAction.SAVE,
                    _("Save"), _("Cancel"));
                filechooser.set_current_name (filename + suffix);
                filechooser.set_filename (destination);
                filechooser.do_overwrite_confirmation = true;

                if (filechooser.run () == Gtk.ResponseType.ACCEPT) {
                    try {
                        var uri = File.new_for_path (filechooser.get_filename ());
                        tmp_source.move (uri, FileCopyFlags.OVERWRITE);
                    } catch (Error e) {
                        warning (e.message);
                    }
                } else {
                    try {
                        tmp_source.delete ();
                    } catch (Error e) {
                        warning (e.message);
                    }
                }

                filechooser.destroy ();
            }
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
        recorder.start_recording ();

        int record_length = Application.settings.get_int ("length");
        if (record_length != 0) {
            record_view.init_countdown (record_length);
        }

        record_view.init_count ();
        stack.visible_child_name = "record";
    }

    // Save window position when changed
    public override bool configure_event (Gdk.EventConfigure event) {
        int x, y;
        get_position (out x, out y);
        Application.settings.set ("window-position", "(ii)", x, y);

        return base.configure_event (event);
    }
}
