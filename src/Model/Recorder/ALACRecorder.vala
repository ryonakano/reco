/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Model.Recorder.ALACRecorder : Model.Recorder.AbstractRecorder {
    private const string NAME = "ALAC";
    private const string SUFFIX = ".m4a";

    public ALACRecorder () {
    }

    public override unowned string get_name () {
        return NAME;
    }

    public override unowned string get_suffix () {
        return SUFFIX;
    }

    public override bool prepare (Gst.Pipeline pipeline, Gst.Element mixer, Gst.Element sink) {
        var encoder = Gst.ElementFactory.make ("avenc_alac", "encoder");
        if (encoder == null) {
            warning ("Failed to create avenc_alac element");
            return false;
        }

        pipeline.add (encoder);
        mixer.link (encoder);

        var muxer = Gst.ElementFactory.make ("mp4mux", "muxer");
        if (muxer == null) {
            warning ("Failed to create mp4mux element");
            return false;
        }

        pipeline.add (muxer);
        encoder.get_static_pad ("src").link (muxer.request_pad_simple ("audio_%u"));
        muxer.link (sink);

        return true;
    }
}
