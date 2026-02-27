/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Model.Recorder.FLACRecorder : Model.Recorder.AbstractRecorder {
    private const string NAME = "FLAC";
    private const string SUFFIX = ".flac";

    public FLACRecorder () {
    }

    public override unowned string get_name () {
        return NAME;
    }

    public override unowned string get_suffix () {
        return SUFFIX;
    }

    public override void prepare (Gst.Pipeline pipeline, Gst.Element mixer, Gst.Element sink) throws Error {
        var encoder = Gst.ElementFactory.make ("flacenc", "encoder");
        if (encoder == null) {
            throw new Gst.LibraryError.INIT ("Failed to create flacenc element");
        }

        pipeline.add (encoder);
        mixer.link (encoder);
        encoder.link (sink);
    }
}
