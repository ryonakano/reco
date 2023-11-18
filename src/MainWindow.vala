/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class MainWindow : Gtk.ApplicationWindow {
    private const string TITLE_TEXT = N_("Unable to Complete Recording");
    private const string DETAIL_TEXT = N_("The following error message may be helpful:");

    private Recorder recorder;
    private bool destroy_on_save;

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

        welcome_view = new WelcomeView ();
        countdown_view = new CountDownView ();
        record_view = new RecordView ();

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

        welcome_view.start_recording.connect (() => {
            debug ("welcome_view.start_recording");
            start_wrapper ();
        });

        countdown_view.countdown_cancelled.connect (() => {
            debug ("countdown_view.countdown_cancelled");
            show_welcome ();
        });
        countdown_view.countdown_ended.connect (() => {
            debug ("countdown_view.countdown_ended");
            show_record ();
        });

        record_view.cancel_recording.connect (() => {
            debug ("record_view.cancel_recording");
            cancel_warpper ();
        });
        record_view.stop_recording.connect (() => {
            debug ("record_view.stop_recording");
            stop_wrapper ();
        });
        record_view.toggle_recording.connect ((is_recording) => {
            debug ("record_view.toggle_recording: is_recording(%s)", is_recording.to_string ());
            recorder.state = is_recording ? Recorder.RecordingState.RECORDING : Recorder.RecordingState.PAUSED;
        });

        var event_controller = new Gtk.EventControllerKey ();
        event_controller.key_pressed.connect ((keyval, keycode, state) => {
            if (Gdk.ModifierType.CONTROL_MASK in state) {
                switch (keyval) {
                    case Gdk.Key.q:
                        debug ("Key pressed: Ctrl + Q");

                        // Stop the recording if recording is in progress
                        // The window is destroyed in the save callback
                        if (recorder.state != Recorder.RecordingState.STOPPED) {
                            debug ("Stopping the ongoing recording…");
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
            debug ("close_request");

            // Stop the recording if recording is in progress
            // The window is destroyed in the save callback
            if (recorder.state != Recorder.RecordingState.STOPPED) {
                debug ("Stopping the ongoing recording…");
                stop_wrapper (true);
                return Gdk.EVENT_STOP;
            }

            // Otherwise we don't block the window destroyed
            return Gdk.EVENT_PROPAGATE;
        });

        recorder.throw_error.connect ((err, debug_message) => {
            debug ("recorder.throw_error: err.message(%s), debug_message(%s)", err.message, debug_message);
            show_error_dialog ("%s\n%s".printf (err.message, debug_message));
        });

        recorder.save_file.connect ((tmp_full_path, suffix) => {
            debug ("recorder.save_file: tmp_full_path(%s), suffix(%s)", tmp_full_path, suffix);

            var tmp_file = File.new_for_path (tmp_full_path);

            //TRANSLATORS: This is the format of filename and %s represents a timestamp here.
            //Suffix is automatically appended depending on the recording format.
            //e.g. "Recording from 2018-11-10 23.42.36.wav"
            string final_file_name = _("Recording from %s").printf (
                                        new DateTime.now_local ().format ("%Y-%m-%d %H.%M.%S")
                                    ) + suffix;

            var autosave_dest = Application.settings.get_string ("autosave-destination");
            if (autosave_dest != Application.SETTINGS_NO_AUTOSAVE) {
                debug ("autosave_dest: %s", autosave_dest);

                var dest = File.new_for_path (autosave_dest).get_child (final_file_name);
                try {
                    if (tmp_file.move (dest, FileCopyFlags.OVERWRITE)) {
                        welcome_view.show_success_button ();
                    }
                } catch (Error e) {
                    warning ("Failed to GLib.File.move: destination(%s): %s", dest.get_path (), e.message);
                    show_error_dialog (e.message);
                }

                if (destroy_on_save) {
                    debug ("destroy flag is on, exiting…");
                    destroy ();
                }
            } else {
                debug ("autosave is disabled, showing saving dialog…");

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
                        try {
                            tmp_file.delete ();
                        } catch (Error e) {
                            // Just failed to remove tmp file so letting user know through error dialog is not required
                            warning (e.message);
                        }

                        return;
                    }

                    try {
                        if (tmp_file.move (dest, FileCopyFlags.OVERWRITE)) {
                            welcome_view.show_success_button ();
                        }
                    } catch (Error e) {
                        warning ("Failed to GLib.File.move: destination(%s): %s", dest.get_path (), e.message);
                        show_error_dialog (e.message);

                        try {
                            tmp_file.delete ();
                        } catch (Error e) {
                            // Just failed to remove tmp file so letting user know through error dialog is not required
                            warning (e.message);
                        }
                    }

                    if (destroy_on_save) {
                        debug ("destroy flag is on, exiting…");
                        destroy ();
                    }
                });
            }
        });
    }

    private void show_welcome () {
        debug ("show_welcome");
        stack.visible_child = welcome_view;
    }

    private void show_countdown () {
        debug ("show_countdown");
        countdown_view.init_countdown ();
        countdown_view.start_countdown ();
        stack.visible_child = countdown_view;
    }

    private void show_record () {
        debug ("show_record");

        try {
            recorder.start_recording ();
        } catch (Gst.ParseError e) {
            warning ("Failed to recorder.start_recording: %s", e.message);
            show_error_dialog (e.message);
            return;
        }

        record_view.init_count ();
        record_view.start_count ();
        stack.visible_child = record_view;
    }

    private void start_wrapper () {
        uint delay = Application.settings.get_uint ("delay");
        debug ("start_wrapper: delay(%u)", delay);

        if (delay != 0) {
            show_countdown ();
        } else {
            show_record ();
        }
    }

    private void stop_wrapper (bool destroy_flag = false) {
        debug ("stop_wrapper: destroy_flag(%s)", destroy_flag.to_string ());

        destroy_on_save = destroy_flag;

        // If a user tries to stop recording while pausing, resume recording once and reset the button icon
        if (recorder.state != Recorder.RecordingState.RECORDING) {
            recorder.state = Recorder.RecordingState.RECORDING;
        }

        recorder.stop_recording ();
        show_welcome ();
    }

    private void cancel_warpper () {
        recorder.cancel_recording ();
        show_welcome ();
    }

    private void show_error_dialog (string error_message) {
        if (Application.IS_ON_PANTHEON) {
            var error_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _(TITLE_TEXT),
                _(DETAIL_TEXT),
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
                _(TITLE_TEXT)
            ) {
                detail = _(DETAIL_TEXT) + "\n\n" + error_message,
                modal = true
            };
            error_dialog.show (this);
        }

        record_view.stop_count ();
        show_welcome ();
    }
}
