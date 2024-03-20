/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2024 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Model.Timer.CountUpTimer : AbstractTimer {
    public CountUpTimer () {
    }

    protected override bool on_timeout () {
        time_usec += TimeSpan.SECOND;
        return Source.CONTINUE;
    }
}
