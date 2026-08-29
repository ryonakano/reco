/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

/**
 * Date & Time utilities.
 */
namespace Util.DateTimeUtil {
    /**
     * Check if the two {@link GLib.DateTime} is completely the same day.
     *
     * @param a     a {@link GLib.DateTime} to compare
     * @param b     a {@link GLib.DateTime} to compare
     *
     * @return      ``true`` if ``a`` and ``b`` is the same day of the same month of the same year
     */
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

    /**
     * Converts {@link GLib.DateTime} to {@link GLib.Date}.
     *
     * @param dt    a {@link GLib.DateTime}
     *
     * @return      a {@link GLib.Date}
     */
    public static Date dt_to_date (DateTime dt) {
        int year;
        int month;
        int day;

        dt.get_ymd (out year, out month, out day);

        // Declare a new Date struct and then use set_*() methods because binding for g_date_new_dmy() is not available.
        // See also: https://gitlab.gnome.org/GNOME/vala/-/issues/1327
        var date = Date ();
        date.set_day ((DateDay) day);
        date.set_month ((DateMonth) month);
        date.set_year ((DateYear) year);

        return date;
    }
}
