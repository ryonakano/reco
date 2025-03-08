/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2024 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Application : Adw.Application {
    public static Settings settings { get; private set; }

    /**
     * Action names and their callbacks.
     */
    private const ActionEntry[] ACTION_ENTRIES = {
        { "open", on_open_activate, "s" },
    };

    private MainWindow window;

    public Application () {
        Object (
            application_id: Config.APP_ID,
            flags: ApplicationFlags.DEFAULT_FLAGS,
            resource_base_path: Config.RESOURCE_PREFIX
        );
    }

    static construct {
        settings = new Settings (Config.APP_ID);
    }

    private void setup_style () {
        var style_action = new SimpleAction.stateful (
            "color-scheme", VariantType.STRING, new Variant.string (Define.ColorScheme.DEFAULT)
        );
        style_action.bind_property (
            "state",
            style_manager, "color-scheme",
            BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE,
            (binding, state_scheme, ref adw_scheme) => {
                Variant? state_scheme_dup = state_scheme.dup_variant ();
                if (state_scheme_dup == null) {
                    warning ("Failed to Variant.dup_variant");
                    return false;
                }

                adw_scheme = Util.to_adw_scheme ((string) state_scheme_dup);
                return true;
            },
            (binding, adw_scheme, ref state_scheme) => {
                string str_scheme = Util.to_str_scheme ((Adw.ColorScheme) adw_scheme);
                state_scheme = new Variant.string (str_scheme);
                return true;
            }
        );
        settings.bind_with_mapping (
            "color-scheme",
            style_manager, "color-scheme", SettingsBindFlags.DEFAULT,
            (adw_scheme, gschema_scheme, user_data) => {
                adw_scheme = Util.to_adw_scheme ((string) gschema_scheme);
                return true;
            },
            (adw_scheme, expected_type, user_data) => {
                string str_scheme = Util.to_str_scheme ((Adw.ColorScheme) adw_scheme);
                Variant gschema_scheme = new Variant.string (str_scheme);
                return gschema_scheme;
            },
            null, null
        );
        add_action (style_action);
    }

    private void on_open_activate (SimpleAction action, Variant? parameter) requires (parameter != null) {
        unowned string path = parameter.get_string ();
        var launcher = new Gtk.FileLauncher (File.new_for_path (path));

        launcher.launch.begin (window, null, (obj, res) => {
            try {
                launcher.launch.end (res);
            } catch (Error err) {
                warning ("on_open_activate: failed to Gtk.FileLauncher.launch: %s", err.message);
            }
        });
    }

    protected override void startup () {
#if USE_GRANITE
        // Use both compile-time and runtime conditions to:
        //
        //  * make Granite optional dependency
        //  * make sure to respect currently running DE
        if (Util.is_on_pantheon ()) {
            // Apply elementary stylesheet instead of default Adwaita stylesheet
            Granite.init ();
        }
#endif

        base.startup ();

        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
        Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (Config.GETTEXT_PACKAGE);

        // Load and setup styles
        unowned var display = Gdk.Display.get_default ();

        var cssprovider = new Gtk.CssProvider ();
        cssprovider.load_from_resource ("/com/github/ryonakano/reco/Application.css");
        Gtk.StyleContext.add_provider_for_display (display,
                                                   cssprovider,
                                                   Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        setup_style ();

        add_action_entries (ACTION_ENTRIES, this);
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
