/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public abstract class AbstractView : Gtk.Box {
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