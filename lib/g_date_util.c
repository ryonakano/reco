/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

#include "g_date_util.h"

// Workaround for https://gitlab.gnome.org/GNOME/vala/-/issues/1327
GDate *
g_date_util_new_wrap (void)
{
    return g_date_new ();
}
