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
    /**
     * Function executed when ${@link AbstractTimer.to_string} is called.
     */
    public ToStringFunc? to_string_func = null;

    private const uint INTERVAL_MSEC = 1000;

    // The time this timer holds
    protected TimeSpan time_usec;
    private uint timeout;
    private bool timeout_remove_flag;

    protected AbstractTimer () {
    }

    /**
     * Initialize the timer.
     */
    public void init () {
        time_usec = 0;
    }

    /**
     * Set the time when the timer started.
     * @param offset_sec time to add to this timer.
     */
    public void seek (TimeSpan offset_sec) {
        time_usec += offset_sec * 1000 * 1000;
    }

    /**
     * Start the timer.
     */
    public void start () {
        // Already started
        if (timeout_remove_flag == Source.CONTINUE) {
            return;
        }

        timeout_remove_flag = Source.CONTINUE;
        timeout = Timeout.add (INTERVAL_MSEC, on_timeout_cb);
    }

    /**
     * Stop the timer.
     */
    public void stop () {
        timeout_remove_flag = Source.REMOVE;
    }

    /**
     * Show the current time.<<BR>>
     * Note that you must set {@link AbstractTimer.to_string_func}.
     * @return Current time represented in string.
     */
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
