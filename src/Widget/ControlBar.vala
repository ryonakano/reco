/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

/**
 * Displays recording control buttons.
 */
public class Widget.ControlBar : Gtk.Box {
    public ControlBar () {
    }

    construct {
        orientation = Gtk.Orientation.HORIZONTAL;
        spacing = 30;
        margin_top = 12;
        halign = Gtk.Align.CENTER;
        add_css_class ("toolbar");
    }
}
