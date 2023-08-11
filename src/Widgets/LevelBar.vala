/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class LevelBar : Gtk.Box {
    private const int LEVEL_MIN = 0;
    private const int LEVEL_LOW_MAX = 2;
    private const int LEVEL_MIDDLE_MAX = 5;
    private const int LEVEL_HIGH_MAX = 8;
    private const int LEVEL_MAX = 10;
    private const int BAR_ON = 1;
    private const int BAR_OFF = 0;

    private Gtk.LevelBar child_bars[LEVEL_MAX];

    public LevelBar () {
    }

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        spacing = 6;
        margin_top = 6;
        margin_bottom = 6;
        halign = Gtk.Align.CENTER;
        hexpand = true;
        vexpand = true;

        var recorder = Recorder.get_default ();

        for (int level = LEVEL_MIN; level < LEVEL_MAX; level++) {
            var bar = new Gtk.LevelBar.for_interval (BAR_OFF, BAR_ON) {
                mode = Gtk.LevelBarMode.DISCRETE,
                inverted = true
            };

            string css_class;
            if (level <= LEVEL_LOW_MAX) {
                css_class = "low";
            } else if (level <= LEVEL_MIDDLE_MAX) {
                css_class = "middle";
            } else if (level <= LEVEL_HIGH_MAX) {
                css_class = "high";
            } else {
                css_class = "full";
            }
            bar.add_offset_value (css_class, BAR_ON);
            bar.value = BAR_OFF;

            child_bars[level] = bar;
            prepend (bar);
        }

        recorder.notify["current-peak"].connect (() => {
            int current = (int) (recorder.current_peak * (double) LEVEL_MAX);

            for (int level = LEVEL_MIN; level < LEVEL_MAX; level++) {
                if (level < current) {
                    child_bars[level].value = BAR_ON;
                } else {
                    child_bars[level].value = BAR_OFF;
                }
            }
        });
    }
}
