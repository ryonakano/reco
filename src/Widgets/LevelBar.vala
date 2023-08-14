/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class LevelBar : Gtk.Box {
    private const double PEAK_PERCENTAGE = 100.0;
    private const int REFRESH_MSEC = 100;

    // Colors from the elementary color palette: https://elementary.io/brand#color
    private const string STRAWBERRY_500 = "#c6262e";
    private const string BANANA_500 = "#f9c440";

    private LiveChart.Serie serie;
    private uint update_graph_timeout;
    private int64 timestamp = -1;
    private Gdk.RGBA bar_color = Gdk.RGBA ();

    public LevelBar () {
    }

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        spacing = 0;

        var recorder = Recorder.get_default ();

        serie = new LiveChart.Serie ("peak-value", new LiveChart.Bar ());
        serie.line.width = 1.0;

        var config = new LiveChart.Config ();
        config.x_axis.tick_interval = 1;
        config.y_axis.fixed_max = PEAK_PERCENTAGE;
        config.padding = LiveChart.Padding () {
            smart = LiveChart.AutoPadding.NONE,
            top = 0,
            right = 0,
            bottom = 12,
            left = 0
        };

        var chart = new LiveChart.Chart (config) {
            hexpand = true,
            vexpand = true
        };
        // Hide all axis lines, legend, and background; just show the graph
        chart.grid.visible = false;
        chart.legend.visible = false;
        chart.background.color = { 0.0f, 0.0f, 0.0f, 0.0f };

        chart.add_serie (serie);

        append (chart);

        recorder.notify["state"].connect (() => {
            switch (recorder.state) {
                case Recorder.RecordingState.STOPPED:
                    // Stop updating the graph when recording stopped
                    if (update_graph_timeout != -1) {
                        GLib.Source.remove (update_graph_timeout);
                    }

                    timestamp = -1;
                    serie.clear ();
                    break;
                case Recorder.RecordingState.PAUSED:
                    // Stop refreshing the graph
                    GLib.Source.remove (update_graph_timeout);
                    update_graph_timeout = -1;
                    chart.refresh_every (REFRESH_MSEC, 0.0);
                    // Change the bar color to yellow
                    bar_color.parse (BANANA_500);
                    serie.line.color = bar_color;
                    break;
                case Recorder.RecordingState.RECORDING:
                    // Start updating the graph when recording started
                    chart.refresh_every (REFRESH_MSEC, 1.0);
                    // Change the bar color to red
                    bar_color.parse (STRAWBERRY_500);
                    serie.line.color = bar_color;

                    if (timestamp == -1) {
                        // Seek to the current timestamp
                        int64 now_msec = GLib.get_real_time () / 1000;
                        timestamp = now_msec;
                        config.time.current = now_msec;
                    }

                    update_graph_timeout = Timeout.add (REFRESH_MSEC, () => {
                        int current = (int) (recorder.current_peak * PEAK_PERCENTAGE);
                        serie.add_with_timestamp (current, timestamp);
                        timestamp += REFRESH_MSEC;
                        return GLib.Source.CONTINUE;
                    });
                    break;
                default:
                    assert_not_reached ();
            }
        });
    }
}
