/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Model.Recorder.WAVRecorder : Model.Recorder.AbstractRecorder {
    private const string NAME = "WAV";
    private const string SUFFIX = ".wav";

    public WAVRecorder () {
    }

    public override unowned string get_name () {
        return NAME;
    }

    public override unowned string get_suffix () {
        return SUFFIX;
    }

    public override bool prepare (Gst.Pipeline pipeline, Gst.Element mixer, Gst.Element sink) {
        var encoder = Gst.ElementFactory.make ("wavenc", "encoder");
        if (encoder == null) {
            warning ("Failed to create wavenc element");
            return false;
        }

        pipeline.add (encoder);
        mixer.link (encoder);
        encoder.link (sink);

        return true;
    }
}
