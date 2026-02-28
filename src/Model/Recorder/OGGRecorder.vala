/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Model.Recorder.OGGRecorder : Model.Recorder.AbstractRecorder {
    private const string NAME = "OGG";

    public OGGRecorder () {
    }

    public override unowned string get_name () {
        return NAME;
    }

    public override void prepare (Gst.Pipeline pipeline, Gst.Element src, Gst.Element dst) throws Error {
        var encoder = Gst.ElementFactory.make ("vorbisenc", "encoder");
        if (encoder == null) {
            throw new Gst.LibraryError.INIT ("Failed to create vorbisenc element");
        }

        pipeline.add (encoder);
        src.link (encoder);

        var muxer = Gst.ElementFactory.make ("oggmux", "muxer");
        if (muxer == null) {
            throw new Gst.LibraryError.INIT ("Failed to create oggmux element");
        }

        pipeline.add (muxer);
        encoder.get_static_pad ("src").link (muxer.request_pad_simple ("audio_%u"));
        muxer.link (dst);
    }
}
