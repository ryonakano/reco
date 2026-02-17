/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

[CCode (lower_case_cprefix = "g_date_util_")]
namespace GDateUtil {
    [CCode (cheader_filename = "g_date_util.h")]
    public static GLib.Date new_wrap ();
}
