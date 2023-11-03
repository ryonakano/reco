/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public abstract class AbstractTimer : Object {
    public signal void ticked ();

    private const uint INTERVAL_MSEC = 1000;

    protected struct Time {
        TimeSpan hours;
        TimeSpan minutes;
        TimeSpan seconds;
    }

    protected TimeSpan time_usec;

    private uint timeout;
    private bool timeout_remove_flag;

    public abstract bool on_timeout ();

    protected AbstractTimer () {
    }

    public bool init () {
        time_usec = 0;

        return true;
    }

    public bool start () {
        timeout_remove_flag = Source.CONTINUE;
        timeout = Timeout.add (INTERVAL_MSEC, on_timeout_cb);
        return true;
    }

    public void stop () {
        timeout_remove_flag = Source.REMOVE;
    }

    public string to_string () {
        TimeSpan remain = time_usec;
        var time = AbstractTimer.Time ();

        time.hours = remain / TimeSpan.HOUR;
        remain %= TimeSpan.HOUR;
        time.minutes = remain / TimeSpan.MINUTE;
        remain %= TimeSpan.MINUTE;
        time.seconds = remain / TimeSpan.SECOND;

        return ("%02" + int64.FORMAT + ":%02" + int64.FORMAT + ":%02" + int64.FORMAT)
            .printf (time.hours, time.minutes, time.seconds);
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
