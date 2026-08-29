/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

/**
 * Converts data types.
 */
namespace Util.Convert {
    /**
     * Converts hex representation of a color to {@link Gdk.RGBA}.
     *
     * @param hex   hex representation of a color
     *
     * @return      a {@link Gdk.RGBA}
     */
    public static Gdk.RGBA hex_to_rgba (string hex) {
        var rgba = Gdk.RGBA ();
        rgba.parse (hex);

        return rgba;
    }

    /**
     * Converts μs to ms.
     *
     * @param usec  μs
     *
     * @return      ms
     */
    public static int64 usec_to_msec (int64 usec) {
        return usec / 1000;
    }

    /**
     * Converts string representation of a color scheme to {@link Adw.ColorScheme}.
     *
     * @param str_scheme    string representation of a color scheme
     *
     * @return              a {@link Adw.ColorScheme}
     */
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

    /**
     * Converts {@link Adw.ColorScheme} to string representation of a color scheme.
     *
     * @param adw_scheme    a {@link Adw.ColorScheme}
     *
     * @return              string representation of a color scheme
     */
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
