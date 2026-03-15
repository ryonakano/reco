/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Widget.Waveform : Adw.Bin {
    public delegate double GetVolumeFunc ();

    public enum Color {
        RED,
        YELLOW,
    }

    private const double LEVEL_MAX_PERCENT = 100.0;
    private const int REFRESH_MSEC = 100;

    // Colors from the elementary color palette: https://elementary.io/brand#color
    private const string STRAWBERRY_500 = "#c6262e";
    private const string BANANA_500 = "#f9c440";

    private LiveChart.Serie serie;
    private LiveChart.Config config;
    private LiveChart.Chart chart;
    private uint volume_update_timeout_id = 0;
    private int64 timestamp;
    private unowned GetVolumeFunc volume_func;

    public Waveform () {
    }

    construct {
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

        child = chart;
    }

    public void init (GetVolumeFunc func) {
        // Seek to the current timestamp
        int64 now_msec = Util.usec_to_msec (GLib.get_monotonic_time ());
        timestamp = now_msec;
        config.time.current = timestamp;

        volume_func = func;
    }

    public void clear () {
        serie.clear ();
    }

    public void start () {
        volume_update_start ();
        draw_start ();
    }

    public void stop () {
        volume_update_stop ();
        draw_stop ();
    }

    private void volume_update_start () {
        // Already resumed
        if (volume_update_timeout_id != 0) {
            return;
        }

        volume_update_timeout_id = Timeout.add (REFRESH_MSEC, () => {
            double value = volume_func () * LEVEL_MAX_PERCENT;
            serie.add_with_timestamp (value, timestamp);

            // Keep last bar on the right of the graph area
            config.time.current = timestamp;
            timestamp += REFRESH_MSEC;

            return Source.CONTINUE;
        });
    }

    private void volume_update_stop () {
        // Already paused
        if (volume_update_timeout_id == 0) {
            return;
        }

        Source.remove (volume_update_timeout_id);
        volume_update_timeout_id = 0;
    }

    public void draw_start () {
        // Start refreshing the graph
        chart.refresh_every (REFRESH_MSEC, 1.0);
    }

    public void draw_stop () {
        // Stop refreshing the graph
        chart.refresh_every (REFRESH_MSEC, 0.0);
    }

    public void set_color (Color color) {
        unowned string str;

        switch (color) {
            case Color.RED:
                str = STRAWBERRY_500;
                break;
            case Color.YELLOW:
                str = BANANA_500;
                break;
            default:
                error ("Invalid color: %d", color);
        }

        serie.line.color = Util.str_to_rgba (str);
    }
}
