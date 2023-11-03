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

    public override bool on_timeout () {
        time_usec -= TimeSpan.SECOND;
        if (time_usec <= 0) {
            ended ();
            return Source.REMOVE;
        }

        return Source.CONTINUE;
    }
}
