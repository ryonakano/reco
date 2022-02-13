/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2021 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class MainWindow : Gtk.ApplicationWindow {
    private Recorder recorder;

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
        recorder = Recorder.get_default ();

        var cssprovider = new Gtk.CssProvider ();
        cssprovider.load_from_resource ("/com/github/ryonakano/reco/Application.css");
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (),
                                                    cssprovider,
                                                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        if (!Application.IS_ON_PANTHEON) {
            var extra_cssprovider = new Gtk.CssProvider ();
            extra_cssprovider.load_from_resource ("/com/github/ryonakano/reco/Extra.css");
            Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (),
                                                        extra_cssprovider,
                                                        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        var preferences_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };
        preferences_box.append (new StyleSwitcher ());

        var preferences_popover = new Gtk.Popover () {
            child = preferences_box
        };

        var preferences_button = new Gtk.MenuButton () {
            tooltip_text = _("Preferences"),
            icon_name = "open-menu",
            popover = preferences_popover
        };

        var headerbar = new Gtk.HeaderBar ();
        headerbar.pack_end (preferences_button);
        set_titlebar (headerbar);

        var headerbar_style_context = headerbar.get_style_context ();
        headerbar_style_context.add_class (Granite.STYLE_CLASS_FLAT);
        headerbar_style_context.add_class (Granite.STYLE_CLASS_DEFAULT_DECORATION);

        welcome_view = new WelcomeView (this);
        countdown_view = new CountDownView (this);
        record_view = new RecordView (this);

        stack = new Gtk.Stack () {
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6
        };
        stack.add_named (welcome_view, "welcome");
        stack.add_named (countdown_view, "count");
        stack.add_named (record_view, "record");

        child = stack;
        show_welcome ();

        var event_controller = new Gtk.EventControllerKey ();
        event_controller.key_pressed.connect ((keyval, keycode, state) => {
            if (Gdk.ModifierType.CONTROL_MASK in state) {
                switch (keyval) {
                    case Gdk.Key.q:
                        if (recorder.is_recording) {
                            var loop = new MainLoop ();
                            record_view.trigger_stop_recording.begin ((obj, res) => {
                                loop.quit ();
                            });
                            loop.run ();
                        }

                        destroy ();
                        return true;
                    case Gdk.Key.R:
                        if (Gdk.ModifierType.SHIFT_MASK in state) {
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

                        return true;
                }
            }

            return false;
        });
        ((Gtk.Widget) this).add_controller (event_controller);

        close_request.connect ((event) => {
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
            var tmp_file = File.new_for_path (tmp_full_path);

            //TRANSLATORS: %s represents a timestamp here
            var final_file = File.new_for_path (Application.settings.get_string ("destination") + "/" +
                                _("Recording from %s").printf (new DateTime.now_local ().format ("%Y-%m-%d %H.%M.%S"))
                                + suffix);

            if (Application.settings.get_boolean ("auto-save")) {
                try {
                    if (tmp_file.move (final_file, FileCopyFlags.OVERWRITE)) {
                        welcome_view.show_success_button ();
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            } else {
                var filechooser = new Gtk.FileChooserNative (
                    _("Save your recording"), this, Gtk.FileChooserAction.SAVE,
                    _("Save"), _("Cancel")
                );
                try {
                    filechooser.set_file (final_file);
                } catch (Error e) {
                    warning (e.message);
                }

                filechooser.show ();
                filechooser.response.connect ((response_id) => {
                    if (response_id == Gtk.ResponseType.ACCEPT) {
                        try {
                            if (tmp_file.move (filechooser.get_file (), FileCopyFlags.OVERWRITE)) {
                                welcome_view.show_success_button ();
                            }
                        } catch (Error e) {
                            warning (e.message);
                        }
                    } else {
                        try {
                            tmp_file.delete ();
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
            error_dialog.present ();
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
            error_dialog.present ();
        }

        record_view.stop_count ();
        show_welcome ();
    }
}
