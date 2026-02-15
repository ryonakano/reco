/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Model.Recorder.FLACRecorder : Model.Recorder.AbstractRecorder {
    private const string NAME = "FLAC";
    private const string SUFFIX = ".flac";
    private const string ENCODER = "flacenc";

    public FLACRecorder () {
    }

    public override unowned string get_name () {
        return NAME;
    }

    public override unowned string get_suffix () {
        return SUFFIX;
    }

    public override bool prepare (Gst.Pipeline pipeline, Gst.Element mixer, Gst.Element sink) {
        var encoder = Gst.ElementFactory.make (ENCODER, "encoder");
        if (encoder == null) {
            warning ("Failed to create %s element named 'encoder'".printf (ENCODER));
            return false;
        }

        pipeline.add (encoder);
        mixer.link (encoder);
        encoder.link (sink);

        return true;
    }
}
