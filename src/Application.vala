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

    public static Settings settings { get; private set; }

    /**
     * Action names and their callbacks.
     */
    private const ActionEntry[] ACTION_ENTRIES = {
        { "open", on_open_activate, "s" },
    };

    private MainWindow window;
    private unowned Manager.StyleManager style_manager;

    public Application () {
        Object (
            application_id: "com.github.ryonakano.reco",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    static construct {
        settings = new Settings ("com.github.ryonakano.reco");
    }

    private bool style_action_transform_to_cb (Binding binding, Value from_value, ref Value to_value) {
        Variant? variant = from_value.dup_variant ();
        if (variant == null) {
            warning ("Failed to Variant.dup_variant");
            return false;
        }

        var val = (Manager.StyleManager.ColorScheme) variant.get_int32 ();
        switch (val) {
            case Manager.StyleManager.ColorScheme.DEFAULT:
            case Manager.StyleManager.ColorScheme.FORCE_LIGHT:
            case Manager.StyleManager.ColorScheme.FORCE_DARK:
                to_value.set_enum (val);
                break;
            default:
                warning ("style_action_transform_to_cb: Invalid ColorScheme: %d", val);
                return false;
        }

        return true;
    }

    private bool style_action_transform_from_cb (Binding binding, Value from_value, ref Value to_value) {
        var val = (Manager.StyleManager.ColorScheme) from_value;
        switch (val) {
            case Manager.StyleManager.ColorScheme.DEFAULT:
            case Manager.StyleManager.ColorScheme.FORCE_LIGHT:
            case Manager.StyleManager.ColorScheme.FORCE_DARK:
                to_value.set_variant (new Variant.int32 (val));
                break;
            default:
                warning ("style_action_transform_from_cb: Invalid ColorScheme: %d", val);
                return false;
        }

        return true;
    }

    private static bool color_scheme_get_mapping_cb (Value value, Variant variant, void* user_data) {
        // Convert from the "style" enum defined in the gschema to Manager.StyleManager.ColorScheme
        var val = variant.get_string ();
        switch (val) {
            case Define.Style.DEFAULT:
                value.set_enum (Manager.StyleManager.ColorScheme.DEFAULT);
                break;
            case Define.Style.LIGHT:
                value.set_enum (Manager.StyleManager.ColorScheme.FORCE_LIGHT);
                break;
            case Define.Style.DARK:
                value.set_enum (Manager.StyleManager.ColorScheme.FORCE_DARK);
                break;
            default:
                warning ("color_scheme_get_mapping_cb: Invalid style: %s", val);
                return false;
        }

        return true;
    }

    private static Variant color_scheme_set_mapping_cb (Value value, VariantType expected_type, void* user_data) {
        string color_scheme;

        // Convert from Manager.StyleManager.ColorScheme to the "style" enum defined in the gschema
        var val = (Manager.StyleManager.ColorScheme) value;
        switch (val) {
            case Manager.StyleManager.ColorScheme.DEFAULT:
                color_scheme = Define.Style.DEFAULT;
                break;
            case Manager.StyleManager.ColorScheme.FORCE_LIGHT:
                color_scheme = Define.Style.LIGHT;
                break;
            case Manager.StyleManager.ColorScheme.FORCE_DARK:
                color_scheme = Define.Style.DARK;
                break;
            default:
                warning ("color_scheme_set_mapping_cb: Invalid Manager.StyleManager.ColorScheme: %d", val);
                // fallback to default
                color_scheme = Define.Style.DEFAULT;
                break;
        }

        return new Variant.string (color_scheme);
    }

    private void setup_style () {
        style_manager = Manager.StyleManager.get_default ();

        var style_action = new SimpleAction.stateful (
            "color-scheme", VariantType.INT32, new Variant.int32 (Manager.StyleManager.ColorScheme.DEFAULT)
        );
        style_action.bind_property ("state", style_manager, "color-scheme",
                                    BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE,
                                    style_action_transform_to_cb,
                                    style_action_transform_from_cb);
        settings.bind_with_mapping ("color-scheme", style_manager, "color-scheme", SettingsBindFlags.DEFAULT,
                                    color_scheme_get_mapping_cb,
                                    color_scheme_set_mapping_cb,
                                    null, null);
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
        base.startup ();

        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

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
