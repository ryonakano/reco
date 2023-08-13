/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class LevelBar : Gtk.Box {
    private const double PEAK_PERCENTAGE = 100.0;
    private const int REFRESH_USEC = 100;

    private LiveChart.Serie serie;
    private uint update_graph_timeout;
    private int64 timestamp = -1;

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
                    chart.refresh_every (REFRESH_USEC, 0.0);
                    serie.line.color = { 0.97f, 0.76f, 0.25f, 1.0f };
                    break;
                case Recorder.RecordingState.RECORDING:
                    // Start updating the graph when recording started
                    chart.refresh_every (REFRESH_USEC, 1.0);
                    serie.line.color = { 0.7f, 0.1f, 0.2f, 1.0f };

                    if (timestamp == -1) {
                        timestamp = GLib.get_real_time () / 1000;
                        // Seek on the timeline
                        config.time.current = GLib.get_real_time () / config.time.conv_us;
                    }

                    update_graph_timeout = Timeout.add (REFRESH_USEC, () => {
                        int current = (int) (recorder.current_peak * PEAK_PERCENTAGE);
                        serie.add_with_timestamp (current, timestamp);
                        timestamp += REFRESH_USEC;
                        return GLib.Source.CONTINUE;
                    });
                    break;
                default:
                    assert_not_reached ();
            }
        });
    }
}
