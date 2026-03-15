/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

/**
 * Draws an audio waveform.
 */
public class Widget.Waveform : Adw.Bin {
    /**
     * Gets volume value to draw the waveform.
     *
     * @return volume value in the range of 0.0 to 1.0
     */
    public delegate double GetVolumeFunc ();

    /**
     * Available colors of the waveform.
     */
    public enum Color {
        RED,
        YELLOW,
    }

    /**
     * Maximum volume, in percentage.
     */
    private const double LEVEL_MAX_PERCENT = 100.0;
    /**
     * Interval to draw the waveform, in msec.
     */
    private const int REFRESH_MSEC = 100;

    // Hex colors of the waveform; respects the elementary color palette: https://elementary.io/brand#color
    /**
     * The red color of the waveform, in hex.
     */
    private const string STRAWBERRY_500_HEX = "#c6262e";
    /**
     * The yellow color of the waveform, in hex.
     */
    private const string BANANA_500_HEX = "#f9c440";

    // Refer to the README of Live Chart at https://github.com/lcallarec/live-chart for summary of LiveChart classes
    private LiveChart.Serie serie;
    private LiveChart.Config config;
    private LiveChart.Chart chart;

    /**
     * ID of the interval handler that updates volume value in the waveform.
     */
    private uint volume_update_timeout_id = 0;
    /**
     * Current timestamp in the waveform chart.
     */
    private int64 timestamp;
    /**
     * Delegate to get volume value to draw the waveform.
     */
    // Declare as an instance variable instead of a property
    // because Vala does not support "construct" annotation for delegates
    private unowned GetVolumeFunc volume_func;

    /**
     * Creates a new {@link Widget.Waveform}.
     *
     * @param func  a {@link Widget.Waveform.GetVolumeFunc} to get volume value to draw ``this``
     *
     * @return      a new {@link Widget.Waveform}
     */
    public Waveform (GetVolumeFunc func) {
        volume_func = func;
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

    /**
     * Initializes the waveform.
     */
    public void init () {
        // Seek to the current timestamp
        int64 now_msec = Util.usec_to_msec (GLib.get_monotonic_time ());
        timestamp = now_msec;
        config.time.current = timestamp;
    }

    /**
     * Clears the waveform.
     */
    public void clear () {
        serie.clear ();
    }

    /**
     * Starts to update the volume value and draw the waveform.
     */
    public void start () {
        volume_update_start ();
        draw_start ();
    }

    /**
     * Stops updating the volume value and drawing the waveform.
     */
    public void stop () {
        volume_update_stop ();
        draw_stop ();
    }

    /**
     * Starts to update the volume value
     */
    private void volume_update_start () {
        // Already resumed
        if (volume_update_timeout_id != 0) {
            return;
        }

        volume_update_timeout_id = Timeout.add (REFRESH_MSEC, () => {
            double volume = volume_func () * LEVEL_MAX_PERCENT;
            serie.add_with_timestamp (volume, timestamp);

            // Keep last bar on the right of the graph area
            config.time.current = timestamp;
            timestamp += REFRESH_MSEC;

            return Source.CONTINUE;
        });
    }

    /**
     * Stops updating the volume value.
     */
    private void volume_update_stop () {
        // Already paused
        if (volume_update_timeout_id == 0) {
            return;
        }

        Source.remove (volume_update_timeout_id);
        volume_update_timeout_id = 0;
    }

    /**
     * Starts to draw the waveform.
     *
     * Being different from {@link Widget.Waveform.start}, this method keeps the underlying interval that updates volume
     * value.
     */
    public void draw_start () {
        chart.refresh_every (REFRESH_MSEC, 1.0);
    }

    /**
     * Stops drawing the waveform.
     *
     * Being different from {@link Widget.Waveform.stop}, this method keeps the underlying interval that updates volume
     * value.
     */
    public void draw_stop () {
        chart.refresh_every (REFRESH_MSEC, 0.0);
    }

    /**
     * Sets color of the waveform.
     *
     * @param color     color of the waveform
     */
    public void set_color (Color color) {
        unowned string hex;

        switch (color) {
            case Color.RED:
                hex = STRAWBERRY_500_HEX;
                break;
            case Color.YELLOW:
                hex = BANANA_500_HEX;
                break;
            default:
                error ("Invalid color: %d", color);
        }

        serie.line.color = Util.hex_to_rgba (hex);
    }
}
