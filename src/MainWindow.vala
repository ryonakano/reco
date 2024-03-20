/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2024 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class MainWindow : Gtk.ApplicationWindow {
    private Model.Recorder recorder;
    private bool destroy_on_save;

    private View.WelcomeView welcome_view;
    private View.CountDownView countdown_view;
    private View.RecordView record_view;
    private Gtk.Stack stack;

    public MainWindow (Application app) {
        Object (
            application: app,
            resizable: false,
            title: "Reco"
        );
    }

    construct {
        recorder = Model.Recorder.get_default ();

        var style_submenu = new Menu ();
        style_submenu.append (_("Light"), "app.color-scheme(%d)".printf (Manager.StyleManager.ColorScheme.FORCE_LIGHT));
        style_submenu.append (_("Dark"), "app.color-scheme(%d)".printf (Manager.StyleManager.ColorScheme.FORCE_DARK));
        style_submenu.append (_("System"), "app.color-scheme(%d)".printf (Manager.StyleManager.ColorScheme.DEFAULT));

        var menu = new Menu ();
        menu.append_submenu (_("Style"), style_submenu);

        var menu_button = new Gtk.MenuButton () {
            tooltip_text = _("Main Menu"),
            icon_name = "open-menu",
            menu_model = menu,
            primary = true
        };

        var headerbar = new Gtk.HeaderBar () {
            title_widget = new Gtk.Label ("")
        };
        headerbar.pack_end (menu_button);
        set_titlebar (headerbar);
        headerbar.add_css_class (Granite.STYLE_CLASS_FLAT);
        headerbar.add_css_class (Granite.STYLE_CLASS_DEFAULT_DECORATION);

        welcome_view = new View.WelcomeView ();
        countdown_view = new View.CountDownView ();
        record_view = new View.RecordView ();

        stack = new Gtk.Stack () {
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6
        };
        stack.add_child (welcome_view);
        stack.add_child (countdown_view);
        stack.add_child (record_view);

        child = stack;
        show_welcome ();

        welcome_view.start_recording.connect (start_wrapper);

        countdown_view.countdown_cancelled.connect (show_welcome);
        countdown_view.countdown_ended.connect (show_record);

        record_view.cancel_recording.connect (cancel_warpper);
        record_view.stop_recording.connect (() => {
            stop_wrapper (false);
        });
        record_view.toggle_recording.connect ((is_recording) => {
            recorder.state = is_recording ? Model.Recorder.RecordingState.RECORDING : Model.Recorder.RecordingState.PAUSED;
        });

        var event_controller = new Gtk.EventControllerKey ();
        event_controller.key_pressed.connect ((keyval, keycode, state) => {
            if (Gdk.ModifierType.CONTROL_MASK in state) {
                switch (keyval) {
                    case Gdk.Key.q:
                        // Stop the recording if recording is in progress
                        // The window is destroyed in the save callback
                        if (recorder.state != Model.Recorder.RecordingState.STOPPED) {
                            stop_wrapper (true);
                            return Gdk.EVENT_STOP;
                        }

                        // Otherwise destroy the window
                        destroy ();
                        return Gdk.EVENT_STOP;
                    default:
                        break;
                }
            }

            return Gdk.EVENT_PROPAGATE;
        });
        ((Gtk.Widget) this).add_controller (event_controller);

        close_request.connect ((event) => {
            // Stop the recording if recording is in progress
            // The window is destroyed in the save callback
            if (recorder.state != Model.Recorder.RecordingState.STOPPED) {
                stop_wrapper (true);
                return Gdk.EVENT_STOP;
            }

            // Otherwise we don't block the window destroyed
            return Gdk.EVENT_PROPAGATE;
        });

        recorder.throw_error.connect ((err, debug) => {
            show_error_dialog (
                _("Error while recording"),
                _("There was an error while recording."),
                "%s\n%s".printf (err.message, debug)
            );
        });

        recorder.save_file.connect ((tmp_path, suffix) => {
            debug ("recorder.save_file: tmp_path(%s), suffix(%s)", tmp_path, suffix);

            var tmp_file = File.new_for_path (tmp_path);

            //TRANSLATORS: This is the format of filename and %s represents a timestamp here.
            //Suffix is automatically appended depending on the recording format.
            //e.g. "Recording from 2018-11-10 23.42.36.wav"
            string final_file_name = _("Recording from %s").printf (
                                        new DateTime.now_local ().format ("%Y-%m-%d %H.%M.%S")
                                    ) + suffix;

            var autosave_dest = Application.settings.get_string ("autosave-destination");
            if (autosave_dest != Define.AUTOSAVE_DISABLED) {
                var dest = File.new_for_path (autosave_dest).get_child (final_file_name);
                try {
                    if (tmp_file.move (dest, FileCopyFlags.OVERWRITE)) {
                        welcome_view.show_success_button ();
                    }
                } catch (Error e) {
                    show_error_dialog (
                        _("Failed to save recording"),
                        _("There was an error while moving file to the designated location."),
                        e.message
                    );
                    recorder.remove_tmp_recording ();
                }

                if (destroy_on_save) {
                    destroy ();
                }
            } else {
                var save_dialog = new Gtk.FileDialog () {
                    title = _("Save your recording"),
                    accept_label = _("Save"),
                    modal = true,
                    initial_name = final_file_name
                };
                save_dialog.save.begin (this, null, (obj, res) => {
                    File dest;
                    try {
                        dest = save_dialog.save.end (res);
                    } catch (Error e) {
                        warning ("Failed to Gtk.FileDialog.save: %s", e.message);

                        // May be cancelled by user, so delete the tmp recording
                        recorder.remove_tmp_recording ();

                        return;
                    }

                    try {
                        if (tmp_file.move (dest, FileCopyFlags.OVERWRITE)) {
                            welcome_view.show_success_button ();
                        }
                    } catch (Error e) {
                        show_error_dialog (
                            _("Failed to save recording"),
                            _("There was an error while moving file to the designated location."),
                            e.message
                        );
                        recorder.remove_tmp_recording ();
                    }

                    if (destroy_on_save) {
                        destroy ();
                    }
                });
            }
        });
    }

    private void show_welcome () {
        stack.visible_child = welcome_view;
    }

    private void show_countdown () {
        countdown_view.init_countdown ();
        countdown_view.start_countdown ();
        stack.visible_child = countdown_view;
    }

    private void show_record () {
        try {
            recorder.start_recording ();
        } catch (Model.RecorderError err) {
            show_error_dialog (
                _("Failed to start recording"),
                _("There was an error while starting recording."),
                err.message
            );
            return;
        }

        record_view.init_count ();
        record_view.start_count ();
        stack.visible_child = record_view;
    }

    private void start_wrapper () {
        uint delay = Application.settings.get_uint ("delay");
        if (delay != 0) {
            show_countdown ();
        } else {
            show_record ();
        }
    }

    private void stop_wrapper (bool destroy_flag = false) {
        destroy_on_save = destroy_flag;

        // If a user tries to stop recording while pausing, resume recording once and reset the button icon
        if (recorder.state != Model.Recorder.RecordingState.RECORDING) {
            recorder.state = Model.Recorder.RecordingState.RECORDING;
        }

        recorder.stop_recording ();
        show_welcome ();
    }

    private void cancel_warpper () {
        recorder.cancel_recording ();
        show_welcome ();
    }

    private void show_error_dialog (string primary_text, string secondary_text, string error_message) {
        if (Application.IS_ON_PANTHEON) {
            var error_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                primary_text,
                secondary_text,
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
                primary_text
            ) {
                detail = secondary_text + "\n\n" + error_message,
                modal = true
            };
            error_dialog.show (this);
        }

        record_view.stop_count ();
        show_welcome ();
    }
}
