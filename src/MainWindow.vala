/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2021 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class MainWindow : Hdy.Window {
    private Recorder recorder;
    private uint configure_id;

    private WelcomeView welcome_view;
    private CountDownView countdown_view;
    private RecordView record_view;
    private Gtk.Stack stack;

    public MainWindow (Application app) {
        Object (
            application: app,
            resizable: false,
            title: "Reco"
        );
    }

    construct {
        Hdy.init ();
        recorder = Recorder.get_default ();

        var cssprovider = new Gtk.CssProvider ();
        cssprovider.load_from_resource ("/com/github/ryonakano/reco/Application.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
                                                    cssprovider,
                                                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        if (!Application.IS_ON_PANTHEON) {
            var extra_cssprovider = new Gtk.CssProvider ();
            extra_cssprovider.load_from_resource ("/com/github/ryonakano/reco/Extra.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
                                                        extra_cssprovider,
                                                        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        var preferences_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
            margin = 12
        };
        preferences_box.add (new StyleSwitcher ());

        var preferences_button = new Gtk.ToolButton (
            new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR), null
        ) {
            tooltip_text = _("Preferences")
        };

        var preferences_popover = new Gtk.Popover (preferences_button);
        preferences_popover.add (preferences_box);

        preferences_button.clicked.connect (() => {
            preferences_popover.show_all ();
        });

        var headerbar = new Hdy.HeaderBar () {
            has_subtitle = false,
            show_close_button = true
        };
        headerbar.pack_end (preferences_button);

        var headerbar_style_context = headerbar.get_style_context ();
        headerbar_style_context.add_class (Gtk.STYLE_CLASS_FLAT);
        headerbar_style_context.add_class (Granite.STYLE_CLASS_DEFAULT_DECORATION);

        welcome_view = new WelcomeView (this);
        countdown_view = new CountDownView (this);
        record_view = new RecordView (this);

        stack = new Gtk.Stack () {
            margin = 6
        };
        stack.add_named (welcome_view, "welcome");
        stack.add_named (countdown_view, "count");
        stack.add_named (record_view, "record");

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.add (headerbar);
        main_box.add (stack);

        add (main_box);

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

        recorder.throw_error.connect ((err, debug) => {
            show_error_dialog ("%s\n%s".printf (err.message, debug));
        });

        recorder.save_file.connect ((tmp_full_path, suffix) => {
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
    }

    public void show_welcome () {
        stack.visible_child_name = "welcome";
    }

    public void show_countdown () {
        stack.visible_child_name = "count";
        countdown_view.start_countdown ();
    }

    public void show_record () {
        try {
            recorder.start_recording ();

            uint record_length = Application.settings.get_uint ("length");
            if (record_length != 0) {
                record_view.init_countdown (record_length);
            }

            record_view.init_count ();
            stack.visible_child_name = "record";
        } catch (Gst.ParseError e) {
            show_error_dialog (e.message);
        }
    }

    private void show_error_dialog (string error_message) {
        if (Application.IS_ON_PANTHEON) {
            var error_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Unable to Complete Recording"),
                _("The following error message may be helpful:"),
                "dialog-error", Gtk.ButtonsType.CLOSE
            ) {
                transient_for = this,
                modal = true
            };
            error_dialog.show_error_details (error_message);
            error_dialog.response.connect ((response_id) => {
                if (response_id == Gtk.ResponseType.CLOSE) {
                    error_dialog.destroy ();
                }
            });
            error_dialog.show_all ();
        } else {
            var error_dialog = new Gtk.MessageDialog (
                this, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE, null
            ) {
                text = _("Unable to Complete Recording"),
                secondary_text = _("The following error message may be helpful:") + "\n\n" + error_message
            };
            error_dialog.response.connect ((response_id) => {
                if (response_id == Gtk.ResponseType.CLOSE) {
                    error_dialog.destroy ();
                }
            });
            error_dialog.show_all ();    
        }

        record_view.stop_count ();
        show_welcome ();
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
