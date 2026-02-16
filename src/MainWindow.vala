/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class MainWindow : Adw.ApplicationWindow {
    private unowned Manager.RecordManager record_manager;
    private bool destroy_on_save;

    private View.WelcomeView welcome_view;
    private View.CountDownView countdown_view;
    private View.RecordView record_view;
    private Gtk.Stack stack;
    private Adw.ToastOverlay toast_overlay;
    private Widget.ProcessingDialog processing_dialog = null;

    private static Gee.HashMap<int, string> starterr_message_table;

    public MainWindow (Application app) {
        Object (
            application: app
        );
    }

    static construct {
        starterr_message_table = new Gee.HashMap<int, string> ();
        starterr_message_table[Define.RecordError.CREATE_ERROR] = N_("This is possibly due to missing codecs or incomplete installation of the app. Make sure you've installed them and try reinstalling them if this issue persists.");
        starterr_message_table[Define.RecordError.CONFIGURE_ERROR] = N_("This is possibly due to missing sound input or output devices. Make sure you've connected one and try using another one if this issue persists.");
    }

    construct {
        record_manager = Manager.RecordManager.get_default ();

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
            record_manager.pause_recording ();
        });
        record_view.resume_recording.connect (() => {
            record_manager.resume_recording ();
        });

        close_request.connect ((event) => {
            bool can_destroy = check_destroy ();
            if (!can_destroy) {
                return Gdk.EVENT_STOP;
            }

            return Gdk.EVENT_PROPAGATE;
        });

        record_manager.throw_error.connect ((err, debug) => {
            show_error_dialog (
                _("Error while recording"),
                _("There was an error while recording."),
                "%s\n%s".printf (err.message, debug)
            );
        });

        record_manager.save_file.connect (save_file_wrapper);
    }

    private async void save_file_wrapper (string tmp_path, string default_filename) {
        // Prevent cancel option from being revealed in case users don't notice the file dialog appears
        // and tries to use the cancel option, which is no longer clickable because a transient dialog presents.
        processing_dialog.conceal_cancel_revealer ();

        string? final_path = yield save_file (tmp_path, default_filename);
        if (final_path != null) {
            var saved_toast = new Adw.Toast (_("Recording Saved")) {
                button_label = _("Open Folder"),
                action_name = "app.open-folder",
                action_target = new Variant.string (final_path)
            };

            toast_overlay.add_toast (saved_toast);
        }

        processing_dialog.force_close ();
        processing_dialog = null;

        if (destroy_on_save) {
            destroy ();

            // Don't go back to welcome view after we decided to quit
            // to prevent users from starting recording again accidentally.
            return;
        }

        show_welcome ();
    }

    private async string? save_file (string tmp_path, string default_filename) {
        debug ("record_manager.save_file: tmp_path(%s)", tmp_path);

        File? final_file;
        var autosave_dest = Application.settings.get_string ("autosave-destination");
        if (autosave_dest.length > 0) {
            final_file = File.new_for_path (autosave_dest).get_child (default_filename);
        } else {
            try {
                final_file = yield ask_final_file (default_filename);
            } catch (Error err) {
                if (err.domain == Gtk.DialogError.quark () && err.code == Gtk.DialogError.DISMISSED) {
                    yield cleanup_tmp_recording ();

                    // Don't show the warning log when the dialog is just dismissed by the user
                    return null;
                }

                show_error_dialog (
                    _("Failed to save recording"),
                    _("There was an error while asking for final path where to move the temporary recording file \"%s\"."
                        .printf (tmp_path)
                    ),
                    err.message
                );

                return null;
            }
        }

        var tmp_file = File.new_for_path (tmp_path);
        string final_path = final_file.get_path ();
        try {
            tmp_file.move (final_file, FileCopyFlags.OVERWRITE);
        } catch (Error err) {
            show_error_dialog (
                _("Failed to save recording"),
                _("There was an error while moving the temporary recording file \"%s\" to \"%s\"."
                    .printf (tmp_file.get_path (), final_path)
                ),
                err.message
            );

            return null;
        }

        return final_path;
    }

    /**
     * Query location where to save recordings.
     *
     * This method shows Gtk.FileDialog and waits for the user input.
     *
     * @param default_filename default filename of recoridngs
     *
     * @return location where to save recordings
     */
    private async File? ask_final_file (string default_filename) throws Error {
        var save_dialog = new Gtk.FileDialog () {
            title = _("Save your recording"),
            accept_label = _("Save"),
            modal = true,
            initial_name = default_filename
        };

        var last_folder = Application.settings.get_string ("manual-save-last-folder");
        if (FileUtils.test (last_folder, FileTest.IS_DIR)) {
            save_dialog.initial_folder = File.new_for_path (last_folder);
        }

        File? final_file = yield save_dialog.save (this, null);

        File? parent_dir = final_file.get_parent ();
        string? path = null;
        try {
            FileInfo info = parent_dir.query_info (Define.FileAttribute.HOST_PATH, FileQueryInfoFlags.NONE);

            path = info.get_attribute_as_string (Define.FileAttribute.HOST_PATH);
        } catch (Error err) {
            warning ("Failed to query file info: %s", err.message);
        }

        if (path == null) {
            // Getting host path requires xdg-desktop-portal >= 1.19.0; fallback to path inside sandbox
            path = parent_dir.get_path ();
        }

        info ("Setting manual-save-last-folder to parent dir (%s)", path);
        Application.settings.set_string ("manual-save-last-folder", path);

        return final_file;
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
            record_manager.prepare_recording ();
        } catch (Define.RecordError err) {
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

        record_manager.start_recording ();

        record_view.refresh_begin ();
        stack.visible_child = record_view;
    }

    public bool check_destroy () {
        // Stop the recording if recording is in progress
        // The window is destroyed in the save callback
        if (record_manager.is_recording_progress) {
            stop_wrapper (true);
            return false;
        }

        // Otherwise we don't block the window destroyed
        return true;
    }

    private void stop_wrapper (bool destroy_flag = false) {
        destroy_on_save = destroy_flag;

        // Ideally, we should initialize processing dialog not here but in the constructor of #this
        // and keep the same instance during the lifetime of the app.
        // When you record more than twice, however, that results it being not shown
        // and the following critical log shown instead:
        //   Gtk-CRITICAL **: 20:12:33.353: gtk_window_present: assertion 'GTK_IS_WINDOW (window)' failed
        processing_dialog = new Widget.ProcessingDialog () {
            // Prevent users from closing the dialog manually and access to the main content behind it accidentally
            can_close = false,
        };
        processing_dialog.cancel.connect (cancel_warpper);
        processing_dialog.present (this);

        record_manager.stop_recording ();
    }

    private void cancel_warpper () {
        record_manager.cancel_recording ();

        cleanup_tmp_recording.begin ((obj, res) => {
            cleanup_tmp_recording.end (res);

            if (processing_dialog != null) {
                processing_dialog.force_close ();
                processing_dialog = null;
            }

            show_welcome ();
        });
    }

    private async void cleanup_tmp_recording () {
        var cancel_toast = new Adw.Toast (_("Recording Canceled"));

        try {
            yield record_manager.trash_tmp_recording ();

            cancel_toast.title = _("Recording Moved to Trash");
        } catch (Error err) {
            warning ("Failed to trash tmp recording, deleting permanently instead: %s", err.message);

            try {
                yield record_manager.delete_tmp_recording ();
            } catch (Error err) {
                // Just failed to remove tmp recording so letting user know through error dialog is not necessary
                warning ("Failed to delete tmp recording: %s", err.message);
            }
        }

        toast_overlay.add_toast (cancel_toast);
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
