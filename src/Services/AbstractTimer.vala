/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public abstract class AbstractTimer : Object {
    public signal void ticked ();

    public delegate string ToStringFunc (TimeSpan time);
    public abstract bool on_timeout ();

    public bool is_seeked {
        get {
            return time_usec > 0;
        }
    }
    public ToStringFunc? to_string_func = null;

    private const uint INTERVAL_MSEC = 1000;

    protected TimeSpan time_usec;
    private uint timeout;
    private bool timeout_remove_flag;

    protected AbstractTimer () {
    }

    public bool init () {
        time_usec = 0;
        return true;
    }

    public bool seek (TimeSpan offset_sec) {
        time_usec += offset_sec * 1000 * 1000;
        return true;
    }

    public bool start () {
        // Already started
        if (timeout_remove_flag == Source.CONTINUE) {
            return true;
        }

        timeout_remove_flag = Source.CONTINUE;
        timeout = Timeout.add (INTERVAL_MSEC, on_timeout_cb);
        return true;
    }

    public void stop () {
        timeout_remove_flag = Source.REMOVE;
    }

    public string to_string () {
        assert (to_string_func != null);
        return to_string_func (time_usec);
    }

    private bool on_timeout_cb () {
        if (timeout_remove_flag == Source.REMOVE) {
            return timeout_remove_flag;
        }

        timeout_remove_flag = on_timeout ();

        ticked ();
        return timeout_remove_flag;
    }
}
