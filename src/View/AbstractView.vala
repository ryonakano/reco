/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2024 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public abstract class View.AbstractView : Gtk.Box {
    protected struct TimerTime {
        TimeSpan hours;
        TimeSpan minutes;
        TimeSpan seconds;
    }

    protected AbstractView () {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            margin_top: 6,
            margin_bottom: 6,
            margin_start: 6,
            margin_end: 6
        );
    }
}
