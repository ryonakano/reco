/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Model.Recorder.ALACRecorder : Model.Recorder.AbstractRecorder {
    private const string NAME = "ALAC";
    private const string SUFFIX = ".m4a";
    private const string ENCODER = "avenc_alac";
    private const string MUXER = "mp4mux";

    public ALACRecorder () {
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

        var muxer = Gst.ElementFactory.make (MUXER, "muxer");
        if (muxer == null) {
            warning ("Failed to create %s element named 'muxer'".printf (MUXER));
            return false;
        }

        pipeline.add_many (encoder, muxer);
        encoder.get_static_pad ("src").link (muxer.request_pad_simple ("audio_%u"));
        muxer.link_many (encoder, sink);

        return true;
    }
}
