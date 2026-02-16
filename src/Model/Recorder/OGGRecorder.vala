/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Model.Recorder.OGGRecorder : Model.Recorder.AbstractRecorder {
    private const string NAME = "OGG";
    private const string SUFFIX = ".ogg";

    public OGGRecorder () {
    }

    public override unowned string get_name () {
        return NAME;
    }

    public override unowned string get_suffix () {
        return SUFFIX;
    }

    public override bool prepare (Gst.Pipeline pipeline, Gst.Element mixer, Gst.Element sink) {
        var encoder = Gst.ElementFactory.make ("vorbisenc", "encoder");
        if (encoder == null) {
            warning ("Failed to create vorbisenc element");
            return false;
        }

        pipeline.add (encoder);
        mixer.link (encoder);

        var muxer = Gst.ElementFactory.make ("oggmux", "muxer");
        if (muxer == null) {
            warning ("Failed to create oggmux element");
            return false;
        }

        pipeline.add (muxer);
        encoder.get_static_pad ("src").link (muxer.request_pad_simple ("audio_%u"));
        muxer.link (sink);

        return true;
    }
}
