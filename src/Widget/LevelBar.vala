/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023-2025 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Widget.LevelBar : Gtk.Box {
    public delegate double GetBarValueFunc ();

    private const double LEVEL_MAX_PERCENT = 100.0;
    private const int REFRESH_MSEC = 100;

    // Colors from the elementary color palette: https://elementary.io/brand#color
    private const string STRAWBERRY_500 = "#c6262e";
    private const string BANANA_500 = "#f9c440";

    private LiveChart.Serie serie;
    private LiveChart.Config config;
    private LiveChart.Chart chart;
    private uint refresh_timeout_id;
    private int64 timestamp;
    private unowned GetBarValueFunc bar_value_func;

    public LevelBar () {
    }

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        spacing = 0;

        serie = new LiveChart.Serie ("level", new LiveChart.Bar ());
        serie.line.width = 1.0;

        config = new LiveChart.Config ();
        config.x_axis.tick_interval = 1;
        config.y_axis.fixed_max = LEVEL_MAX_PERCENT;
        config.padding = LiveChart.Padding () {
            smart = LiveChart.AutoPadding.NONE,
            top = 0,
            right = 0,
            bottom = 12,
            left = 0
        };

        chart = new LiveChart.Chart (config) {
            hexpand = true,
            vexpand = true
        };
        // Hide all axis lines, legend, and background; just show the graph
        chart.grid.visible = false;
        chart.legend.visible = false;
        chart.background.color = { 0.0f, 0.0f, 0.0f, 0.0f };

        chart.add_serie (serie);

        append (chart);
    }

    public void refresh_begin (GetBarValueFunc func) {
        // Seek to the current timestamp
        int64 now_msec = usec_to_msec (GLib.get_monotonic_time ());
        timestamp = now_msec;
        config.time.current = timestamp;

        bar_value_func = func;

        refresh_resume ();
    }

    public void refresh_end () {
        refresh_pause ();
        serie.clear ();
    }

    public void refresh_pause () {
        // Already paused
        if (refresh_timeout_id == 0) {
            return;
        }

        Source.remove (refresh_timeout_id);
        refresh_timeout_id = 0;

        // Stop refreshing the graph
        chart.refresh_every (REFRESH_MSEC, 0.0);

        apply_bar_color (BANANA_500);
    }

    public void refresh_resume () {
        // Already resumed
        if (refresh_timeout_id != 0) {
            return;
        }

        refresh_timeout_id = Timeout.add (REFRESH_MSEC, () => {
            double value = bar_value_func () * LEVEL_MAX_PERCENT;
            serie.add_with_timestamp (value, timestamp);

            // Keep last bar on the right of the graph area
            config.time.current = timestamp;
            timestamp += REFRESH_MSEC;

            return Source.CONTINUE;
        });

        // Start refreshing the graph
        chart.refresh_every (REFRESH_MSEC, 1.0);

        apply_bar_color (STRAWBERRY_500);
    }

    private void apply_bar_color (string color) {
        var rgba = Gdk.RGBA ();
        rgba.parse (color);
        serie.line.color = rgba;
    }

    private int64 usec_to_msec (int64 usec) {
        return usec / 1000;
    }
}
