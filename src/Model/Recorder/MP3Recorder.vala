/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Model.Recorder.MP3Recorder : Model.Recorder.AbstractRecorder {
    private const string NAME = "MP3";
    private const string SUFFIX = ".mp3";

    public MP3Recorder () {
    }

    public override unowned string get_name () {
        return NAME;
    }

    public override unowned string get_suffix () {
        return SUFFIX;
    }

    public override void prepare (Gst.Pipeline pipeline, Gst.Element src, Gst.Element dst) throws Error {
        var encoder = Gst.ElementFactory.make ("lamemp3enc", "encoder");
        if (encoder == null) {
            throw new Gst.LibraryError.INIT ("Failed to create lamemp3enc element");
        }

        pipeline.add (encoder);
        src.link (encoder);

        var muxer = Gst.ElementFactory.make ("id3v2mux", "muxer");
        if (muxer == null) {
            throw new Gst.LibraryError.INIT ("Failed to create id3v2mux element");
        }

        pipeline.add (muxer);
        encoder.link_many (muxer, dst);
        muxer.link (dst);
    }
}
