/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2024 Ryo Nakano <ryonakaknock3@gmail.com>
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

    protected override void startup () {
        base.startup ();

        // Load and setup styles
        var display = Gdk.Display.get_default ();

        var cssprovider = new Gtk.CssProvider ();
        cssprovider.load_from_resource ("/com/github/ryonakano/reco/Application.css");
        // TODO: Deprecated in Gtk 4.10, buit no alternative api is provided so leave it for now
        Gtk.StyleContext.add_provider_for_display (display,
                                                   cssprovider,
                                                   Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        // Load GResource for our custom icons
        var icon_theme = Gtk.IconTheme.get_for_display (display);
        icon_theme.add_resource_path ("/com/github/ryonakano/reco");
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
