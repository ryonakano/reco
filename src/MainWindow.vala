/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2025 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class MainWindow : Adw.ApplicationWindow {
    private unowned Model.Recorder recorder;
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

        // Distinct development build visually
        if (".Devel" in Config.APP_ID) {
            add_css_class ("devel");
        }

        var style_submenu = new Menu ();
        style_submenu.append (_("S_ystem"), "app.color-scheme('%s')".printf (Define.ColorScheme.DEFAULT));
        style_submenu.append (_("_Light"), "app.color-scheme('%s')".printf (Define.ColorScheme.FORCE_LIGHT));
        style_submenu.append (_("_Dark"), "app.color-scheme('%s')".printf (Define.ColorScheme.FORCE_DARK));

        var main_menu = new Menu ();
        main_menu.append_submenu (_("_Style"), style_submenu);
        main_menu.append (_("_Keyboard Shortcuts"), "win.show-help-overlay");

        var menu_button = new Gtk.MenuButton () {
            tooltip_text = _("Main Menu"),
            icon_name = "open-menu",
            menu_model = main_menu,
            primary = true
        };

        var headerbar = new Adw.HeaderBar () {
            title_widget = new Gtk.Label ("")
        };
        headerbar.pack_end (menu_button);

        welcome_view = new View.WelcomeView ();
        countdown_view = new View.CountDownView ();
        record_view = new View.RecordView ();

        stack = new Gtk.Stack () {
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6
        };
        stack.add_child (welcome_view);
        stack.add_child (countdown_view);
        stack.add_child (record_view);

        var toolbar_view = new Adw.ToolbarView ();
        toolbar_view.add_top_bar (headerbar);
        toolbar_view.set_content (stack);

        content = toolbar_view;
        width_request = 350;
        height_request = 480;

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

        close_request.connect ((event) => {
            bool can_destroy = check_destroy ();
            if (!can_destroy) {
                return Gdk.EVENT_STOP;
            }

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
            string default_filename = _("Recording from %s").printf (
                                        new DateTime.now_local ().format ("%Y-%m-%d %H.%M.%S")
                                    ) + suffix;

            ask_save_path.begin (default_filename, (obj, res) => {
                File? save_path = ask_save_path.end (res);

                if (save_path == null) {
                    // Log message is already outputted in ask_save_path method
                    return;
                }

                bool is_success = false;
                try {
                    is_success = tmp_file.move (save_path, FileCopyFlags.OVERWRITE);
                } catch (Error e) {
                    show_error_dialog (
                        _("Failed to save recording"),
                        _("There was an error while moving file to the designated location."),
                        e.message
                    );
                    recorder.remove_tmp_recording ();
                }

                if (is_success) {
                    welcome_view.show_success_button ();

                    var notification = new Notification (_("Saved recording"));
                    // The app that handles actions would be already destroyed when the user activates the notification,
                    // so do not offer actions if it's decided to be destroyed
                    if (destroy_on_save) {
                        notification.set_body (_("Recording saved successfully."));
                    } else {
                        notification.set_body (_("Click here to play."));
                        // Only actions starting with "app." can be used here
                        notification.set_default_action_and_target_value ("app.open-folder", new Variant.string (save_path.get_path ()));
                        notification.add_button_with_target_value (_("Open folder"), "app.open-folder", new Variant.string (save_path.get_parent ().get_path ()));
                    }

                    application.send_notification (Config.APP_ID, notification);
                }

                if (destroy_on_save) {
                    destroy ();
                }
            });
        });
    }

    /**
     * Query location where to save recordings.
     *
     * This method shows Gtk.FileDialog if the autosave is disabled and waits for the user input.
     * Otherwise, it returns the location depending on the autosave location.
     *
     * @param default_filename default filename of recoridngs
     *
     * @return location where to save recordings
     */
    private async File? ask_save_path (string default_filename) {
        File? dest = null;

        var autosave_dest = Application.settings.get_string ("autosave-destination");
        if (autosave_dest == Define.AUTOSAVE_DISABLED) {
            var save_dialog = new Gtk.FileDialog () {
                title = _("Save your recording"),
                accept_label = _("Save"),
                modal = true,
                initial_name = default_filename
            };

            try {
                dest = yield save_dialog.save (this, null);
            } catch (Error e) {
                warning ("Failed to Gtk.FileDialog.save: %s", e.message);

                // May be cancelled by user, so delete the tmp recording
                recorder.remove_tmp_recording ();
            }
        } else {
            dest = File.new_for_path (autosave_dest).get_child (default_filename);
        }

        return dest;
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

    public bool check_destroy () {
        // Stop the recording if recording is in progress
        // The window is destroyed in the save callback
        if (recorder.state != Model.Recorder.RecordingState.STOPPED) {
            stop_wrapper (true);
            return false;
        }

        // Otherwise we don't block the window destroyed
        return true;
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
        if (Util.is_on_pantheon ()) {
#if USE_GRANITE
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
#endif
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
