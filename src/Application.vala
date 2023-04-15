/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2023 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Application : Gtk.Application {
    public static bool IS_ON_PANTHEON {
        get {
            return GLib.Environment.get_variable ("XDG_CURRENT_DESKTOP") == "Pantheon";
        }
    }

    // The blank value of the "autosave-destination" key in the app's GSettings means that
    // the auto-saving is disabled.
    public static string SETTINGS_NO_AUTOSAVE {
        get {
            return "";
        }
    }

    private MainWindow window;
    public static Settings settings;

    public Application () {
        Object (
            application_id: "com.github.ryonakano.reco",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    construct {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);
    }

    static construct {
        settings = new Settings ("com.github.ryonakano.reco");
    }

    protected override void activate () {
        if (window == null) {
            window = new MainWindow (this);
        }

        window.present ();
    }

    public static int main (string[] args) {
        Gst.init (ref args);
        return new Application ().run (args);
    }
}
