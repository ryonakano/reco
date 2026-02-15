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

    public override bool prepare (Gst.Pipeline pipeline, Gst.Element mixer, Gst.Element sink) {
        var encoder = Gst.ElementFactory.make ("lamemp3enc", "encoder");
        if (encoder == null) {
            warning ("Failed to create lamemp3enc element");
            return false;
        }

        pipeline.add (encoder);
        mixer.link (encoder);

        var muxer = Gst.ElementFactory.make ("id3v2mux", "muxer");
        if (muxer == null) {
            warning ("Failed to create id3v2mux element");
            return false;
        }

        pipeline.add (muxer);
        encoder.link_many (muxer, sink);
        muxer.link (sink);

        return true;
    }
}
