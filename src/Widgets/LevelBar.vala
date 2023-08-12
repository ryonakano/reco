/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class LevelBar : Gtk.Box {
    private const double PEAK_MAX = 100.0;

    private LiveChart.Serie serie;
    private uint update_graph_timeout;

    public LevelBar () {
    }

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        spacing = 0;

        var recorder = Recorder.get_default ();

        serie = new LiveChart.Serie ("peak-value", new LiveChart.Bar ());
        serie.line.color = { 0.7f, 0.1f, 0.2f, 1.0f };
        serie.line.width = 1.0;

        var config = new LiveChart.Config ();
        config.x_axis.tick_interval = 1;
        config.y_axis.fixed_max = PEAK_MAX;
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

        recorder.notify["is-recording"].connect (() => {
            if (recorder.is_recording) {
                // Start updating the graph when recording started
                update_graph_timeout = Timeout.add (100, () => {
                    int current = (int) (recorder.current_peak * PEAK_MAX);
                    serie.add (current);
                    return GLib.Source.CONTINUE;
                });
            } else {
                // Stop updating the graph when recording stopped
                GLib.Source.remove (update_graph_timeout);
                serie.clear ();
            }
        });

    }
}
