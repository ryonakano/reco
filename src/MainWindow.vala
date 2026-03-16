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

    private Model.Recorder recorder;
    private DateTime start_dt;
    private string recording_tmp_path;
    private uint inhibit_token = 0;
    private bool destroy_on_save = false;

    private View.WelcomeView welcome_view;
    private View.CountDownView countdown_view;
    private View.RecordView record_view;
    private Gtk.Stack stack;
    private Adw.ToastOverlay toast_overlay;
    private Widget.ProcessingDialog processing_dialog = null;

    public MainWindow (Application app) {
        Object (
            application: app
        );
    }

    construct {
        recorder = new Model.Recorder ();

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
            main_menu.append (_("_About %s").printf (Config.APP_NAME), "app.about");
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
        record_view = new View.RecordView (recorder);

        stack = new Gtk.Stack () {
            margin_bottom = 24,
            margin_start = 6,
            margin_end = 6
        };
        stack.add_child (welcome_view);
        stack.add_child (countdown_view);
        stack.add_child (record_view);

        var clamp = new Adw.Clamp () {
            child = stack,
            maximum_size = 500,
        };

        toast_overlay = new Adw.ToastOverlay () {
            child = clamp,
        };

        var toolbar_view = new Adw.ToolbarView ();
        toolbar_view.add_top_bar (headerbar);
        toolbar_view.set_content (toast_overlay);

        content = toolbar_view;
        width_request = 360;
        height_request = 340;
        title = Config.APP_NAME;

        show_welcome ();

        welcome_view.start_recording.connect ((delay_sec) => {
            if (delay_sec > 0) {
                show_countdown (delay_sec);
            } else {
                show_record ();
            }
        });

        countdown_view.countdown_canceled.connect (show_welcome);
        countdown_view.countdown_ended.connect (show_record);

        record_view.cancel_recording.connect (cancel_warpper);
        record_view.stop_recording.connect (() => {
            present_processing_dialog ();
            recorder.stop ();
        });
        record_view.pause_recording.connect (() => {
            recorder.pause ();

            uninhibit_sleep ();
        });
        record_view.resume_recording.connect (() => {
            inhibit_sleep ();

            recorder.resume ();
        });

        close_request.connect ((event) => {
            bool can_destroy = prepare_destory ();
            if (!can_destroy) {
                // Prevent MainWindow from being destroyed right now
                return Gdk.EVENT_STOP;
            }

            // Otherwise we don't prevent MainWindow from being destroyed
            return Gdk.EVENT_PROPAGATE;
        });

        recorder.record_err.connect ((err, debug_info) => {
            record_view.stop ();

            show_error_dialog (
                _("Unable to Continue Recording"),
                _("There was an internal error while recording"),
                "%s\n%s".printf (err.message, debug_info)
            );

            show_welcome ();
        });

        recorder.record_ok.connect (save_file_wrapper);

        notify["suspended"].connect (suspended_notify_cb);
    }

    private async void save_file_wrapper () {
        // Prevent cancel option from being revealed in case users don't notice the file dialog appears
        // and tries to use the cancel option, which is no longer clickable because a transient dialog presents.
        processing_dialog.conceal_cancel_revealer ();

        var end_dt = new DateTime.now_local ();
        var format = (Define.FormatID) Application.settings.get_enum ("format");
        string suffix = format.get_suffix ();
        string default_filename = build_filename_from_datetime (start_dt, end_dt, suffix);

        string? final_path = yield save_file (recording_tmp_path, default_filename);
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
        // BUG: ``file`` is supposed to be a recording file which should have a parent
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
        start_dt = new DateTime.now_local ();

        string tmp_filename = "reco_%s.tmp".printf (start_dt.to_unix ().to_string ());
        recording_tmp_path = Path.build_filename (Environment.get_user_cache_dir (), tmp_filename);

        var source = (Define.SourceID) Application.settings.get_enum ("source");
        var channel = (Define.ChannelID) Application.settings.get_enum ("channel");
        var format = (Define.FormatID) Application.settings.get_enum ("format");
        unowned string? meta_author = null;
        DateTime? meta_record_dt = null;

        var is_add_metadata = Application.settings.get_boolean ("add-metadata");
        if (is_add_metadata) {
            meta_author = Environment.get_real_name ();
            meta_record_dt = start_dt;
        }

        bool ret = recorder.prepare (recording_tmp_path, source, channel, format, meta_author, meta_record_dt);
        if (!ret) {
            show_error_dialog (
                _("Failed to Prepare Recording"),
                _("This is possibly due to missing codecs, incomplete installation of the app, or missing sound input/output devices. Make sure you've installed necessary components correctlly and connected sound devices")
            );

            return;
        }

        inhibit_sleep ();

        recorder.start ();

        uint record_length = Application.settings.get_uint ("length");
        record_view.start (record_length);

        stack.visible_child = record_view;
    }

    /**
     * Prepare to destroy ``this``
     *
     * @return ``true`` if the caller can destroy ``this`` safely right now.<<BR>>
     * ``false`` otherwise; ``this`` will be destroyed after ongoing recording is saved, which may require interaction
     * with a user.
     */
    public bool prepare_destory () {
        bool can_destroy = recorder.request_shutdown ();
        if (!can_destroy) {
            // Recorder is shutting down so we can't destroy MainWindow now

            record_view.stop ();
            present_processing_dialog ();

            // Let MainWindow destroyed in the save callback
            destroy_on_save = true;

            return false;
        }

        return true;
    }

    private void present_processing_dialog () {
        if (processing_dialog != null) {
            // Already present
            return;
        }

        // Ideally, we should initialize processing dialog not here but in the constructor of ``this``
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
    }

    private void cancel_warpper () {
        recorder.cancel ();

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
            yield Util.trash_file (recording_tmp_path);

            cancel_toast.title = _("Recording Moved to Trash");
        } catch (Error err) {
            warning ("Failed to trash tmp recording, deleting permanently instead: %s", err.message);

            try {
                yield Util.delete_file (recording_tmp_path);
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

    private void suspended_notify_cb () {
        if (stack.visible_child != record_view) {
            return;
        }

        if (suspended) {
            record_view.draw_stop ();
        } else {
            record_view.draw_start ();
        }
    }

    /**
     * Build filename using the given arguments.
     *
     * The filename includes start datetime and end time. It also includes end date if the date is different between
     * start and end.
     *
     * examples of result:
     *
     *  * "2018-11-10_23:42:36 to 2018-11-11_07:13:50.wav"
     *  * "2018-11-10_23:42:36 to 23:49:52.wav"
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

        return "%s to %s.%s".printf (start_str, end_str, suffix);
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

    /**
     * Present an error dialog
     *
     * This uses {@link Granite.MessageDialog} on Pantheon if the app build with Granite,
     * otherwise it uses {@link Adw.AlertDialog}
     *
     * @param primary_text      the title of the dialog
     * @param secondary_text    the body of the dialog
     * @param detailed_text     the detailed error message to display if any
     */
    private void show_error_dialog (string primary_text, string secondary_text, string? detailed_text = null) {
        // A MainLoop to wait for user confirmation and interaction with the dialog
        var response_loop = new MainLoop ();

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

            if (detailed_text != null) {
                error_dialog.show_error_details (detailed_text);
            }

            error_dialog.response.connect (() => {
                error_dialog.destroy ();
                response_loop.quit ();
            });
            error_dialog.present ();
            response_loop.run ();
#endif
        } else {
            string body_text = secondary_text;
            if (detailed_text != null) {
                body_text = "%s\n\n%s".printf (secondary_text, detailed_text);
            }

            var error_dialog = new Adw.AlertDialog (primary_text, body_text) {
                default_response = Define.ErrorDialogResponseID.CLOSE,
                close_response = Define.ErrorDialogResponseID.CLOSE,
            };
            error_dialog.add_response (Define.ErrorDialogResponseID.CLOSE, _("_Close"));
            error_dialog.response.connect ((response) => {
                error_dialog.destroy ();
                response_loop.quit ();
            });
            error_dialog.present (this);
            response_loop.run ();
        }
    }
}
