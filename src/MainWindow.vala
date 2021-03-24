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

public class MainWindow : Gtk.ApplicationWindow {
    public Recorder recorder { get; private set; default = new Recorder (); }
    private uint configure_id;

    public WelcomeView welcome_view { get; private set; }
    private CountDownView countdown_view;
    private RecordView record_view;
    private Gtk.Stack stack;

    public MainWindow () {
        Object (
            border_width: 6,
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

        var mode_switch = new Granite.ModeSwitch.from_icon_name (
            "display-brightness-symbolic",
            "weather-clear-night-symbolic"
        ) {
            primary_icon_tooltip_text = _("Light background"),
            secondary_icon_tooltip_text = _("Dark background"),
            valign = Gtk.Align.CENTER
        };

        //TRANSLATORS: Whether to follow system's dark style settings
        var follow_system_label = new Gtk.Label (_("Follow system style:")) {
            halign = Gtk.Align.END
        };

        var follow_system_switch = new Gtk.Switch () {
            halign = Gtk.Align.START
        };

        var preferences_grid = new Gtk.Grid () {
            margin = 12,
            column_spacing = 6,
            row_spacing = 6
        };
        preferences_grid.attach (follow_system_label, 0, 0);
        preferences_grid.attach (follow_system_switch, 1, 0);

        var preferences_button = new Gtk.ToolButton (
            new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR), null
        ) {
            tooltip_text = _("Preferences")
        };

        var preferences_popover = new Gtk.Popover (preferences_button);
        preferences_popover.add (preferences_grid);

        preferences_button.clicked.connect (() => {
            preferences_popover.show_all ();
        });

        var headerbar = new Gtk.HeaderBar () {
            title = "",
            has_subtitle = false,
            show_close_button = true
        };
        headerbar.pack_end (preferences_button);
        headerbar.pack_end (mode_switch);

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
                "dialog-error", Gtk.ButtonsType.CLOSE
            ) {
                transient_for = this
            };
            error_dialog.show_error_details ("%s\n%s".printf (err.message, debug));
            error_dialog.run ();
            error_dialog.destroy ();

            record_view.stop_count ();
            show_welcome ();
        });

        recorder.handle_save_file.connect ((tmp_full_path, suffix) => {
            //TRANSLATORS: %s represents a timestamp here
            string filename = _("Recording from %s").printf (new DateTime.now_local ().format ("%Y-%m-%d %H.%M.%S"));

            var tmp_source = File.new_for_path (tmp_full_path);

            string destination = Application.settings.get_string ("destination");

            if (Application.settings.get_boolean ("auto-save")) {
                try {
                    var uri = File.new_for_path (destination + "/" + filename + suffix);

                    if (tmp_source.move (uri, FileCopyFlags.OVERWRITE)) {
                        welcome_view.show_success_button ();
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            } else {
                var filechooser = new Gtk.FileChooserNative (
                    _("Save your recording"), this, Gtk.FileChooserAction.SAVE,
                    _("Save"), _("Cancel")
                ) {
                    do_overwrite_confirmation = true
                };
                filechooser.set_current_name (filename + suffix);
                filechooser.set_filename (destination);
                filechooser.show ();

                filechooser.response.connect ((response_id) => {
                    if (response_id == Gtk.ResponseType.ACCEPT) {
                        try {
                            var uri = File.new_for_path (filechooser.get_filename ());

                            if (tmp_source.move (uri, FileCopyFlags.OVERWRITE)) {
                                welcome_view.show_success_button ();
                            }
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
                });
            }
        });

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            if (Application.settings.get_boolean ("is-follow-system-style")) {
                gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            }
        });

        follow_system_switch.notify["active"].connect (() => {
            if (follow_system_switch.active) {
                gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            } else {
                gtk_settings.gtk_application_prefer_dark_theme = Application.settings.get_boolean ("is-prefer-dark");
            }
        });

        Application.settings.bind ("is-prefer-dark", mode_switch, "active", GLib.SettingsBindFlags.DEFAULT);
        Application.settings.bind ("is-prefer-dark", gtk_settings, "gtk-application-prefer-dark-theme", GLib.SettingsBindFlags.DEFAULT);
        Application.settings.bind ("is-follow-system-style", follow_system_switch, "active", GLib.SettingsBindFlags.DEFAULT);
        Application.settings.bind ("is-follow-system-style", mode_switch, "sensitive", GLib.SettingsBindFlags.INVERT_BOOLEAN);
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

        uint record_length = Application.settings.get_uint ("length");
        if (record_length != 0) {
            record_view.init_countdown (record_length);
        }

        record_view.init_count ();
        stack.visible_child_name = "record";
    }

    protected override bool configure_event (Gdk.EventConfigure event) {
        if (configure_id != 0) {
            GLib.Source.remove (configure_id);
        }

        configure_id = Timeout.add (100, () => {
            configure_id = 0;
            int x, y;
            get_position (out x, out y);
            Application.settings.set ("window-position", "(ii)", x, y);

            return false;
        });

        return base.configure_event (event);
    }

    protected override bool key_press_event (Gdk.EventKey key) {
        if (Gdk.ModifierType.CONTROL_MASK in key.state) {
            switch (key.keyval) {
                case Gdk.Key.q:
                    if (recorder.is_recording) {
                        var loop = new MainLoop ();
                        record_view.trigger_stop_recording.begin ((obj, res) => {
                            loop.quit ();
                        });
                        loop.run ();
                    }

                    destroy ();
                    break;
                case Gdk.Key.R:
                    if (Gdk.ModifierType.SHIFT_MASK in key.state) {
                        if (stack.visible_child_name == "welcome") {
                            welcome_view.trigger_recording ();
                        } else if (stack.visible_child_name == "record") {
                            var loop = new MainLoop ();
                            record_view.trigger_stop_recording.begin ((obj, res) => {
                                loop.quit ();
                            });
                            loop.run ();
                        }
                    }

                    break;
            }
        }

        return Gdk.EVENT_PROPAGATE;
    }
}
