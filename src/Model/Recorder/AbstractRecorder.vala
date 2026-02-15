/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public abstract class Model.Recorder.AbstractRecorder : Object {
    protected AbstractRecorder () {
    }

    public abstract unowned string get_name ();
    public abstract unowned string get_suffix ();
    public abstract bool prepare (Gst.Pipeline pipeline, Gst.Element mixer, Gst.Element sink);
}
