/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2025 Ryo Nakano <ryonakaknock3@gmail.com>
 */

namespace Util {
    public static bool is_on_pantheon () {
        return Environment.get_variable ("XDG_CURRENT_DESKTOP") == "Pantheon";
    }

    public static string get_suffix (string path) {
        int suffix_index = path.last_index_of_char ('.');
        // No suffix
        if (suffix_index == -1) {
            return "";
        }

        return path.substring (suffix_index);
    }

    public static bool is_same_day (DateTime a, DateTime b) {
        int a_year;
        int a_month;
        int a_day;
        int b_year;
        int b_month;
        int b_day;

        a.get_ymd (out a_year, out a_month, out a_day);
        b.get_ymd (out b_year, out b_month, out b_day);

        if (a_day != b_day) {
            return false;
        }

        if (a_month != b_month) {
            return false;
        }

        if (a_year != b_year) {
            return false;
        }

        return true;
    }

    public static Adw.ColorScheme to_adw_scheme (string str_scheme) {
        switch (str_scheme) {
            case Define.ColorScheme.DEFAULT:
                return Adw.ColorScheme.DEFAULT;
            case Define.ColorScheme.FORCE_LIGHT:
                return Adw.ColorScheme.FORCE_LIGHT;
            case Define.ColorScheme.FORCE_DARK:
                return Adw.ColorScheme.FORCE_DARK;
            default:
                warning ("Invalid color scheme string: %s", str_scheme);
                return Adw.ColorScheme.DEFAULT;
        }
    }

    public static string to_str_scheme (Adw.ColorScheme adw_scheme) {
        switch (adw_scheme) {
            case Adw.ColorScheme.DEFAULT:
                return Define.ColorScheme.DEFAULT;
            case Adw.ColorScheme.FORCE_LIGHT:
                return Define.ColorScheme.FORCE_LIGHT;
            case Adw.ColorScheme.FORCE_DARK:
                return Define.ColorScheme.FORCE_DARK;
            default:
                warning ("Invalid color scheme: %d", adw_scheme);
                return Define.ColorScheme.DEFAULT;
        }
    }
}
