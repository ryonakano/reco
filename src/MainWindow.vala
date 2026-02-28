/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class MainWindow : Adw.ApplicationWindow {
    /**
     * Action names and their callbacks.
     */
    private const ActionEntry[] ACTION_ENTRIES = {
        { "open-folder", on_open_folder_activate, "s" },
    };

    private unowned Manager.RecordManager record_manager;
    private uint inhibit_token = 0;
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
        starterr_message_table[Gst.LibraryError.INIT] = N_("This is possibly due to missing codecs or incomplete installation of the app. Make sure you've installed them and try reinstalling them if this issue persists");
        starterr_message_table[Gst.LibraryError.SETTINGS] = N_("This is possibly due to missing sound input or output devices. Make sure you've connected one and try using another one if this issue persists");
        starterr_message_table[Gst.ResourceError.NOT_FOUND] = N_("This is possibly due to invalid or broken preferences of the app. Make sure you've set valid values and try reinstalling the app if this issue persists");
    }

    construct {
        record_manager = Manager.RecordManager.get_default ();

        // Distinct development build visually
        if (".Devel" in Config.APP_ID) {
            add_css_class ("devel");
        }

        add_action_entries (ACTION_ENTRIES, this);

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
            child = stack,
        };

        var toolbar_view = new Adw.ToolbarView ();
        toolbar_view.add_top_bar (headerbar);
        toolbar_view.set_content (toast_overlay);

        content = toolbar_view;
        default_width = 360;
        default_height = 680;
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
            record_manager.pause ();

            uninhibit_sleep ();
        });
        record_view.resume_recording.connect (() => {
            inhibit_sleep ();

            record_manager.resume ();
        });

        close_request.connect ((event) => {
            bool can_destroy = check_destroy ();
            if (!can_destroy) {
                return Gdk.EVENT_STOP;
            }

            return Gdk.EVENT_PROPAGATE;
        });

        record_manager.record_err.connect ((err, debug_info) => {
            show_error_dialog (
                _("Unable to Continue Recording"),
                _("There was an internal error while recording"),
                "%s\n%s".printf (err.message, debug_info)
            );
        });

        record_manager.record_ok.connect (save_file_wrapper);
    }

    private async void save_file_wrapper (string tmp_path, string default_filename) {
        // Prevent cancel option from being revealed in case users don't notice the file dialog appears
        // and tries to use the cancel option, which is no longer clickable because a transient dialog presents.
        processing_dialog.conceal_cancel_revealer ();

        string? final_path = yield save_file (tmp_path, default_filename);
        if (final_path != null) {
            var saved_toast = new Adw.Toast (_("Recording Saved")) {
                button_label = _("Open Folder"),
                action_name = "win.open-folder",
                action_target = new Variant.string (final_path)
            };

            toast_overlay.add_toast (saved_toast);
        }

        processing_dialog.force_close ();
        processing_dialog = null;

        uninhibit_sleep ();

        if (destroy_on_save) {
            destroy ();

            // Don't go back to welcome view after we decided to quit
            // to prevent users from starting recording again accidentally.
            return;
        }

        show_welcome ();
    }

    private async string? save_file (string tmp_path, string default_filename) {
        File? final_file = yield ask_final_file (default_filename);
        if (final_file == null) {
            return null;
        }

        var tmp_file = File.new_for_path (tmp_path);
        string final_path = final_file.get_path ();
        try {
            tmp_file.move (final_file, FileCopyFlags.OVERWRITE);
        } catch (Error err) {
            warning ("Failed to File.move: src=\"%s\" dst=\"%s\": %s", tmp_path, final_path, err.message);

            show_error_dialog (
                _("Failed to Save Recording"),
                _("Unable to move a temporary recording file to the final path. Make sure the destination exists and you have write access to it"),
                err.message
            );

            return null;
        }

        return final_path;
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
    private async File? ask_final_file (string default_filename) {
        string autosave_dest = Application.settings.get_string ("autosave-destination");
        if (FileUtils.test (autosave_dest, FileTest.IS_DIR)) {
            return File.new_for_path (autosave_dest).get_child (default_filename);
        }

        var save_dialog = new Gtk.FileDialog () {
            title = _("Save Recording"),
            modal = true,
            initial_name = default_filename,
        };

        string last_path = Application.settings.get_string ("last-folder-path");
        if (FileUtils.test (last_path, FileTest.IS_DIR)) {
            // Gtk.FileDialog.initial_folder seems to must be a host path to work as expected inside sandbox
            string? last_path_host = Util.query_host_path (last_path);
            if (last_path_host != null) {
                save_dialog.initial_folder = File.new_for_path (last_path_host);
            }
        }

        File? final_file;
        try {
            final_file = yield save_dialog.save (this, null);
        } catch (Error err) {
            if (err.domain == Gtk.DialogError.quark () && err.code == Gtk.DialogError.DISMISSED) {
                yield cleanup_tmp_recording ();

                // Don't show the warning log when the dialog is just dismissed by the user
                return null;
            }

            warning ("Failed to Gtk.FileDialog.save: %s", err.message);

            show_error_dialog (
                _("Failed to Save Recording"),
                _("Unable to determine where to save recording finally. Try again using autosave instead"),
                err.message
            );

            return null;
        }

        // Ignore return value because failure does not affect saving recording itself
        remember_last_folder_path (final_file);

        return final_file;
    }

    private bool remember_last_folder_path (File file) {
        File? parent_dir = file.get_parent ();
        // BUG: #file is supposed to be a recording file which should have a parent
        assert (parent_dir != null);

        string? path = parent_dir.get_path ();
        if (path == null) {
            warning ("Failed to remember last folder path: Failed to get parent dir path");
            return false;
        }

        Application.settings.set_string ("last-folder-path", path);

        return true;
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
            record_manager.prepare ();
        } catch (Error err) {
            warning ("Failed to record_manager.prepare: %s", err.message);

            string? secondary_text = starterr_message_table[err.code];
            // Errors without dedicated message
            if (secondary_text == null) {
                secondary_text = N_("There was an unknown error while starting recording");
            }

            show_error_dialog (
                _("Failed to Start Recording"),
                _(secondary_text),
                err.message
            );

            return;
        }

        inhibit_sleep ();

        record_manager.start ();

        record_view.refresh_begin ();
        stack.visible_child = record_view;
    }

    public bool check_destroy () {
        // Stop ongoing recording
        // The window is destroyed in the save callback
        if (record_manager.is_recording) {
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

        record_manager.stop ();
    }

    private void cancel_warpper () {
        record_manager.cancel ();

        cleanup_tmp_recording.begin ((obj, res) => {
            cleanup_tmp_recording.end (res);

            if (processing_dialog != null) {
                processing_dialog.force_close ();
                processing_dialog = null;
            }

            uninhibit_sleep ();

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

    private void inhibit_sleep () {
        if (inhibit_token != 0) {
            application.uninhibit (inhibit_token);
        }

        inhibit_token = application.inhibit (
            this,
            Gtk.ApplicationInhibitFlags.SUSPEND,
            _("Recording is ongoing")
        );
    }

    private void uninhibit_sleep () {
        if (inhibit_token != 0) {
            application.uninhibit (inhibit_token);
            inhibit_token = 0;
        }
    }

    private void on_open_folder_activate (SimpleAction action, Variant? parameter) requires (parameter != null) {
        unowned string path = parameter.get_string ();
        var launcher = new Gtk.FileLauncher (File.new_for_path (path));

        launcher.open_containing_folder.begin (this, null, (obj, res) => {
            try {
                launcher.open_containing_folder.end (res);
            } catch (Error err) {
                warning ("Failed to Gtk.FileLauncher.open_containing_folder: %s", err.message);

                show_error_dialog (
                    _("Failed to Open Folder"),
                    _("Unable to open folder containing \"%s\"").printf (path),
                    err.message
                );
            }
        });
    }

    private void show_error_dialog (string primary_text, string secondary_text, string detailed_text) {
        if (Util.is_on_pantheon ()) {
#if USE_GRANITE
            var error_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                primary_text,
                secondary_text,
                "dialog-error", Gtk.ButtonsType.CLOSE
            ) {
                transient_for = this,
                modal = true,
            };
            error_dialog.show_error_details (detailed_text);
            error_dialog.response.connect (() => {
                error_dialog.destroy ();
            });
            error_dialog.present ();
#endif
        } else {
            string body_text = "%s\n\n%s".printf (secondary_text, detailed_text);

            var error_dialog = new Adw.AlertDialog (primary_text, body_text) {
                default_response = Define.ErrorDialogResponseID.CLOSE,
                close_response = Define.ErrorDialogResponseID.CLOSE,
            };
            error_dialog.add_response (Define.ErrorDialogResponseID.CLOSE, _("_Close"));
            error_dialog.response.connect ((response) => {
                error_dialog.destroy ();
            });
            error_dialog.present (this);
        }

        record_view.refresh_end ();
        show_welcome ();
    }
}
