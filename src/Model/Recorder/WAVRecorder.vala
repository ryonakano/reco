/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Model.Recorder.WAVRecorder : Model.Recorder.AbstractRecorder {
    private const string NAME = "WAV";
    private const string SUFFIX = ".wav";
    private const string ENCODER = "wavenc";

    public WAVRecorder () {
    }

    public override unowned string get_name () {
        return NAME;
    }

    public override unowned string get_suffix () {
        return SUFFIX;
    }

    public override bool prepare (Gst.Pipeline pipeline, Gst.Element sink) {
        var encoder = Gst.ElementFactory.make (ENCODER, "encoder");
        if (encoder == null) {
            warning ("Failed to create %s element named 'encoder'".printf (ENCODER));
            return false;
        }

        pipeline.add (encoder);
        encoder.link (sink);

        return true;
    }
}
