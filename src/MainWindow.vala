/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class MainWindow : Adw.ApplicationWindow {
    private unowned Model.Recorder recorder;
    private bool destroy_on_save;

    private View.WelcomeView welcome_view;
    private View.CountDownView countdown_view;
    private View.RecordView record_view;
    private Gtk.Stack stack;
    private Adw.ToastOverlay toast_overlay;

    private static Gee.HashMap<int, string> starterr_message_table;

    public MainWindow (Application app) {
        Object (
            application: app
        );
    }

    static construct {
        starterr_message_table = new Gee.HashMap<int, string> ();
        starterr_message_table[Model.RecorderError.CREATE_ERROR] = N_("This is possibly due to missing codecs or incomplete installation of the app. Make sure you've installed them and try reinstalling them if this issue persists.");
        starterr_message_table[Model.RecorderError.CONFIGURE_ERROR] = N_("This is possibly due to missing sound input or output devices. Make sure you've connected one and try using another one if this issue persists.");
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
        // Pantheon prefers AppCenter instead of an about dialog for app details, so prevent it from being shown on Pantheon
        if (!Util.is_on_pantheon ()) {
            ///TRANSLATORS: %s will be replaced by the app name
            main_menu.append (_("_About %s").printf (Define.APP_NAME), "app.about");
        }

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
            margin_bottom = 24,
            margin_start = 6,
            margin_end = 6
        };
        stack.add_child (welcome_view);
        stack.add_child (countdown_view);
        stack.add_child (record_view);

        toast_overlay = new Adw.ToastOverlay () {
            child = stack
        };

        var toolbar_view = new Adw.ToolbarView ();
        toolbar_view.add_top_bar (headerbar);
        toolbar_view.set_content (toast_overlay);

        content = toolbar_view;
        width_request = 350;
        height_request = 480;
        resizable = false;
        title = Define.APP_NAME;

        show_welcome ();

        welcome_view.start_recording.connect ((delay_sec) => {
            if (delay_sec > 0) {
                show_countdown (delay_sec);
            } else {
                show_record ();
            }
        });

        countdown_view.countdown_cancelled.connect (show_welcome);
        countdown_view.countdown_ended.connect (show_record);

        record_view.cancel_recording.connect (cancel_warpper);
        record_view.stop_recording.connect (() => {
            stop_wrapper (false);
        });
        record_view.pause_recording.connect (() => {
            recorder.pause_recording ();
        });
        record_view.resume_recording.connect (() => {
            recorder.resume_recording ();
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

        recorder.save_file.connect ((tmp_path) => {
            debug ("recorder.save_file: tmp_path(%s)", tmp_path);

            string suffix = Util.get_suffix (tmp_path);
            var tmp_file = File.new_for_path (tmp_path);

            string default_filename = build_filename_from_datetime (recorder.start_dt, recorder.end_dt, suffix);

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
                    var saved_toast = new Adw.Toast (_("Recording Saved")) {
                        button_label = _("Open Folder"),
                        action_name = "app.open-folder",
                        action_target = new Variant.string (save_path.get_path ())
                    };

                    toast_overlay.add_toast (saved_toast);
                }

                if (destroy_on_save) {
                    destroy ();
                }
            });
        });
    }

    /**
     * Build filename using the given arguments.
     *
     * The filename includes start datetime and end time. It also includes end date if the date is different between
     * start and end.
     *
     * e.g. "2018-11-10_23:42:36 to 2018-11-11_07:13:50.wav"
     *      "2018-11-10_23:42:36 to 23:49:52.wav"
     */
    private string build_filename_from_datetime (DateTime start, DateTime end, string suffix) {
        string start_format = "%Y-%m-%d_%H:%M:%S";
        string end_format = "%Y-%m-%d_%H:%M:%S";

        bool is_same_day = Util.is_same_day (start, end);
        if (is_same_day) {
            // Avoid redundant date
            end_format = "%H:%M:%S";
        }

        string start_str = start.format (start_format);
        string end_str = end.format (end_format);

        return "%s to %s".printf (start_str, end_str) + suffix;
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
        if (autosave_dest.length == 0) {
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

    private void show_countdown (uint sec) {
        countdown_view.init_countdown (sec);
        countdown_view.start_countdown ();
        stack.visible_child = countdown_view;
    }

    private void show_record () {
        try {
            recorder.prepare_recording ();
        } catch (Model.RecorderError err) {
            string? secondary_text = starterr_message_table[err.code];
            // Errors without dedicated message
            if (secondary_text == null) {
                secondary_text = N_("There was an unknown error while starting recording.");
            }

            show_error_dialog (
                _("Failed to start recording"),
                _(secondary_text),
                err.message
            );
            return;
        }

        recorder.start_recording ();

        record_view.refresh_begin ();
        stack.visible_child = record_view;
    }

    public bool check_destroy () {
        // Stop the recording if recording is in progress
        // The window is destroyed in the save callback
        if (recorder.is_recording_progress) {
            stop_wrapper (true);
            return false;
        }

        // Otherwise we don't block the window destroyed
        return true;
    }

    private void stop_wrapper (bool destroy_flag = false) {
        destroy_on_save = destroy_flag;

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
            string detail_text = secondary_text + "\n\n" + _("Details:") + "\n\n" + error_message;

            var error_dialog = new Gtk.AlertDialog (
                primary_text
            ) {
                detail = detail_text,
                modal = true
            };
            error_dialog.show (this);
        }

        record_view.refresh_end ();
        show_welcome ();
    }
}
