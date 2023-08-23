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
                var filechooser = new Gtk.FileChooserNative (
                    _("Save your recording"), this, Gtk.FileChooserAction.SAVE, null, null
                ) {
                    modal = true
                };
                filechooser.set_current_name (final_file_name);

                filechooser.response.connect ((response_id) => {
                    if (response_id == Gtk.ResponseType.ACCEPT) {
                        try {
                            if (tmp_file.move (filechooser.get_file (), FileCopyFlags.OVERWRITE)) {
                                welcome_view.show_success_button ();
                            }
                        } catch (Error e) {
                            show_error_dialog (e.message);
                        }
                    } else {
                        try {
                            tmp_file.delete ();
                        } catch (Error e) {
                            show_error_dialog (e.message);
                        }
                    }

                    filechooser.destroy ();
                });
                filechooser.show ();
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
