/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

namespace Util {
    public static bool is_on_pantheon () {
        return Environment.get_variable ("XDG_CURRENT_DESKTOP") == "Pantheon";
    }
}
