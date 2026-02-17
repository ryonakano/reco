/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

/**
 * An abstract class that handles unique procedues for a specific file format like WAV or MP3.
 */
public abstract class Model.Recorder.AbstractRecorder : Object {
    protected AbstractRecorder () {
    }

    /**
     * Get name of the file format #this handles.
     *
     * @return  name of the file format #this handles.
     */
    public abstract unowned string get_name ();

    /**
     * Get suffix of the file format #this handles.
     *
     * @return  suffix of the file format #this handles.
     */
    public abstract unowned string get_suffix ();

    /**
     * Prepare for recording.<<BR>>
     * All elements created in this method should be added to #pipeline using {@link Gst.Bin.add}
     * and linked to #mixer or #sink appropriately using {@link Gst.Pad.link}.
     *
     * |-- #pipeline --------------------------------------------------------------------|
     * |           |------------|  |-----------------|                    |------------| |
     * |  (snip) --|   #mixer   |--| format-specific |-- (snip, if any) --|   #sink    | |
     * |         --|            |--|     element     |--                --|            | |
     * |           |------------|  |-----------------|                    |------------| |
     * |---------------------------------------------------------------------------------|
     *                          <--------- scope of this method ---------->
     *
     * NOTE:<<BR>>
     * You should add at least an element that inherits {@link Gst.TagSetter} to #pipeline for metadata.<<BR>>
     * See Manager.RecordManager.add_metadata() for detail.
     *
     * @param pipeline  pipeline that holds all elements necessary for recording.
     * @param mixer     audiomixer that precedes all elements created in this method.
     * @param sink      filesink that succeeds to all elements created in this method.
     *
     * @return          true if succeeds, false otherwise.
     */
    public abstract bool prepare (Gst.Pipeline pipeline, Gst.Element mixer, Gst.Element sink);
}
