/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

/**
 * A transitional dialog to be shown while some process is ongoing
 * and you want to prevent users from accessing to the main content of the app.
 */
public class Widget.ProcessingDialog : Adw.Dialog {
    /**
     * Text shown in #this to let users know the reason why #this presents.
     */
    public string description { get; construct; }

    /**
     * Creates a new ProcessingDialog.
     *
     * @param description   Text shown in #this to let users know the reason why #this presents.
     *
     * @return the newly created ProcessingDialog.
     */
    public ProcessingDialog (string description) {
        Object (
            description: description
        );
    }

    construct {
        var spinner = new Adw.Spinner () {
            hexpand = true,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
        };

        var desc_label = new Gtk.Label (description) {
            halign = Gtk.Align.CENTER,
        };
        desc_label.add_css_class ("title-3");

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_start = 24,
            margin_end = 24,
            margin_top = 24,
            margin_bottom = 24,
        };
        box.append (spinner);
        box.append (desc_label);

        child = box;
    }
}
