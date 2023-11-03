/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class CountDownTimer : AbstractTimer {
    public signal void ended ();

    public bool seeked {
        get {
            return time_usec != 0;
        }
    }

    public CountDownTimer () {
    }

    public bool seek (TimeSpan offset_sec) {
        time_usec += offset_sec * TimeSpan.SECOND;
        return true;
    }

    public override string to_string () {
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

    public override bool on_timeout () {
        time_usec -= TimeSpan.SECOND;
        if (time_usec <= 0) {
            ended ();
            return Source.REMOVE;
        }

        return Source.CONTINUE;
    }
}
