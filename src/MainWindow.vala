/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
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
        var display = Gdk.Display.get_default ();

        var cssprovider = new Gtk.CssProvider ();
        cssprovider.load_from_resource ("/com/github/ryonakano/reco/Application.css");
        // TODO: Deprecated in Gtk 4.10, buit no alternative api is provided so leave it for now
        Gtk.StyleContext.add_provider_for_display (display,
                                                    cssprovider,
                                                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        if (!Application.IS_ON_PANTHEON) {
            var extra_cssprovider = new Gtk.CssProvider ();
            extra_cssprovider.load_from_resource ("/com/github/ryonakano/reco/Extra.css");
            // TODO: Deprecated in Gtk 4.10, buit no alternative api is provided so leave it for now
            Gtk.StyleContext.add_provider_for_display (display,
                                                        extra_cssprovider,
                                                        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        // Load GResource for our custom icons
        var icon_theme = Gtk.IconTheme.get_for_display (display);
        icon_theme.add_resource_path ("/com/github/ryonakano/reco");

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

        var headerbar = new Gtk.HeaderBar () {
            title_widget = new Gtk.Label ("")
        };
        headerbar.pack_end (preferences_button);
        set_titlebar (headerbar);
        headerbar.add_css_class (Granite.STYLE_CLASS_FLAT);
        headerbar.add_css_class (Granite.STYLE_CLASS_DEFAULT_DECORATION);

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
                        if (recorder.state != Recorder.RecordingState.STOPPED) {
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
            if (recorder.state != Recorder.RecordingState.STOPPED) {
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

            //TRANSLATORS: This is the format of filename and %s represents a timestamp here.
            //Suffix is automatically appended depending on the recording format.
            //e.g. "Recording from 2018-11-10 23.42.36.wav"
            string final_file_name = _("Recording from %s").printf (
                                        new DateTime.now_local ().format ("%Y-%m-%d %H.%M.%S")
                                    ) + suffix;

            var autosave_dest = Application.settings.get_string ("autosave-destination");
            if (autosave_dest != Application.SETTINGS_NO_AUTOSAVE) {
                var final_dest = File.new_for_path (autosave_dest);
                try {
                    if (tmp_file.move (final_dest.get_child (final_file_name), FileCopyFlags.OVERWRITE)) {
                        welcome_view.show_success_button ();
                    }
                } catch (Error e) {
                    show_error_dialog (e.message);
                }
            } else {
                var filechooser = new Gtk.FileDialog () {
                    title = _("Save your recording"),
                    accept_label = _("Save"),
                    modal = true,
                    initial_name = final_file_name
                };
                filechooser.save.begin (this, null, (obj, res) => {
                    try {
                        var file = filechooser.save.end (res);
                        if (file == null) {
                            return;
                        }

                        try {
                            if (tmp_file.move (file, FileCopyFlags.OVERWRITE)) {
                                welcome_view.show_success_button ();
                            }
                        } catch (Error e) {
                            show_error_dialog (e.message);
                        }
                    } catch (Error e) {
                        warning ("Failed to save recording: %s", e.message);

                        // May be cancelled by user, so delete the tmp recording
                        try {
                            tmp_file.delete ();
                        } catch (Error e) {
                            show_error_dialog (e.message);
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
            } else {
                record_view.clear_countdown ();
            }

            record_view.init_count ();
            stack.visible_child_name = "record";
        } catch (Gst.ParseError e) {
            show_error_dialog (e.message);
        }
    }

    private void show_error_dialog (string error_message) {
        string title_text = _("Unable to Complete Recording");
        string detail_text = _("The following error message may be helpful:");

        if (Application.IS_ON_PANTHEON) {
            var error_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                title_text,
                detail_text,
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
            var error_dialog = new Gtk.AlertDialog (
                title_text
            ) {
                detail = detail_text + "\n\n" + error_message,
                modal = true
            };
            error_dialog.show (this);
        }

        record_view.stop_count ();
        show_welcome ();
    }
}
