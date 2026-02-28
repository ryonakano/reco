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

    public override void prepare (Gst.Pipeline pipeline, Gst.Element src, Gst.Element dst) throws Error {
        var encoder = Gst.ElementFactory.make ("avenc_alac", "encoder");
        if (encoder == null) {
            throw new Gst.LibraryError.INIT ("Failed to create avenc_alac element");
        }

        pipeline.add (encoder);
        src.link (encoder);

        var muxer = Gst.ElementFactory.make ("mp4mux", "muxer");
        if (muxer == null) {
            throw new Gst.LibraryError.INIT ("Failed to create mp4mux element");
        }

        pipeline.add (muxer);
        encoder.get_static_pad ("src").link (muxer.request_pad_simple ("audio_%u"));
        muxer.link (dst);
    }
}
