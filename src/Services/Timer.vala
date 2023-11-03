/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Timer : Object {
    public signal void ticked ();

    private const uint INTERVAL_MSEC = 1000;

    private struct Time {
        TimeSpan hours;
        TimeSpan minutes;
        TimeSpan seconds;
    }

    private DateTime start_time;
    private TimeSpan elapsed_msec;
    private uint timeout;
    private bool timeout_remove_flag;

    public Timer () {
    }

    public bool init () {
        start_time = new DateTime.now ();
        elapsed_msec = 0;

        return true;
    }

    public bool start () {
        timeout_remove_flag = Source.CONTINUE;
        timeout = Timeout.add (INTERVAL_MSEC, on_timeout);
        return true;
    }

    public void stop () {
        timeout_remove_flag = Source.REMOVE;
    }

    public string to_string () {
        TimeSpan remain = elapsed_msec;
        Time time = Time ();

        time.hours = remain / TimeSpan.HOUR;
        remain %= TimeSpan.HOUR;
        time.minutes = remain / TimeSpan.MINUTE;
        remain %= TimeSpan.MINUTE;
        time.seconds = remain / TimeSpan.SECOND;

        return ("%02" + int64.FORMAT + ":%02" + int64.FORMAT + ":%02" + int64.FORMAT)
            .printf (time.hours, time.minutes, time.seconds);
    }

    private bool on_timeout () {
        if (timeout_remove_flag == Source.REMOVE) {
            return timeout_remove_flag;
        }

        elapsed_msec += TimeSpan.SECOND;
        ticked ();

        return timeout_remove_flag;
    }
}
