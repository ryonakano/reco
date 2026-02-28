/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Model.Recorder.FLACRecorder : Model.Recorder.AbstractRecorder {
    private const string NAME = "FLAC";

    public FLACRecorder () {
    }

    public override unowned string get_name () {
        return NAME;
    }

    public override void prepare (Gst.Pipeline pipeline, Gst.Element src, Gst.Element dst) throws Error {
        var encoder = Gst.ElementFactory.make ("flacenc", "encoder");
        if (encoder == null) {
            throw new Gst.LibraryError.INIT ("Failed to create flacenc element");
        }

        pipeline.add (encoder);
        src.link (encoder);
        encoder.link (dst);
    }
}
