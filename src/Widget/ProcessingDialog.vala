/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

/**
 * A transitional dialog to be shown while saving and we don't want users to access to the main content of the app.
 */
public class Widget.ProcessingDialog : Adw.Dialog {
    public signal void cancel_recording ();

    private const uint CANCEL_REVEAL_TIMEOUT_MSEC = 5000;

    // Can't make this local variable because the following critical log is shown when setting reveal_child to true
    //   Gtk-CRITICAL **: 20:59:53.389: gtk_revealer_set_reveal_child: assertion 'GTK_IS_REVEALER (revealer)' failed
    private Gtk.Revealer cancel_revealer;

    private uint cancel_reveal_timeout = 0;

    /**
     * Creates a new ProcessingDialog.
     *
     * @return the newly created ProcessingDialog.
     */
    public ProcessingDialog () {
    }

    construct {
        var spinner = new Adw.Spinner () {
            hexpand = true,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
        };

        var desc_label = new Gtk.Label (_("Saving…")) {
            halign = Gtk.Align.CENTER,
        };
        desc_label.add_css_class ("title-3");

        var cancel_label = new Gtk.Label (_("Problems?") + "\n" + _("Just hang on until the file dialog appears.")) {
            halign = Gtk.Align.CENTER,
        };

        var cancel_button = new Gtk.Button () {
            icon_name = "user-trash-symbolic",
            tooltip_text = _("Cancel recording"),
            halign = Gtk.Align.CENTER,
        };
        cancel_button.add_css_class ("borderless-button");

        var cancel_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_top = 24,
            margin_start = 24,
            margin_end = 24,
        };
        cancel_box.append (cancel_label);
        cancel_box.append (cancel_button);

        cancel_revealer = new Gtk.Revealer () {
            child = cancel_box,
            transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN,
            margin_bottom = 24,
        };

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_top = 24,
            margin_start = 24,
            margin_end = 24,
        };
        content_box.append (spinner);
        content_box.append (desc_label);
        content_box.append (cancel_revealer);

        child = content_box;

        cancel_button.clicked.connect (() => {
            cancel_button.sensitive = false;
            cancel_label.label = _("Canceling…");
            cancel_recording ();
        });

        cancel_reveal_timeout = Timeout.add_once (CANCEL_REVEAL_TIMEOUT_MSEC, () => {
            cancel_revealer.reveal_child = true;
            cancel_reveal_timeout = 0;
        });
    }

    public void conceal_cancel_revealer () {
        if (cancel_reveal_timeout > 0) {
            Source.remove (cancel_reveal_timeout);
            cancel_reveal_timeout = 0;
        }

        cancel_revealer.reveal_child = false;
    }
}
