/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2021 Ryo Nakano <ryonakaknock3@gmail.com>
 * 
 * Some code inspired from elementary/switchboard-plug-pantheon-shell, src/Views/Appearance.vala
 */

public class StyleSwitcher : Gtk.Box {
    private Gtk.Settings gtk_settings = Gtk.Settings.get_default ();

#if FOR_PANTHEON
    private Granite.Settings granite_settings = Granite.Settings.get_default ();
#endif

    private Granite.Widgets.ModeButton style_mode_button;

    public StyleSwitcher () {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 6
        );
    }

    construct {
        var style_label = new Gtk.Label (_("Style:")) {
            halign = Gtk.Align.START
        };

        var light_style_image = new Gtk.Image.from_icon_name ("display-brightness-symbolic", Gtk.IconSize.BUTTON);
        var light_style_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            tooltip_text = _("Light style")
        };
        light_style_box.add (light_style_image);
        light_style_box.add (new Gtk.Label (_("Light")));

        var dark_style_image = new Gtk.Image.from_icon_name ("weather-clear-night-symbolic", Gtk.IconSize.BUTTON);
        var dark_style_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            tooltip_text = _("Dark style")
        };
        dark_style_box.add (dark_style_image);
        dark_style_box.add (new Gtk.Label (_("Dark")));

        style_mode_button = new Granite.Widgets.ModeButton ();
        style_mode_button.append (light_style_box);
        style_mode_button.append (dark_style_box);

        add (style_label);
        add (style_mode_button);

#if FOR_PANTHEON
        var system_style_image = new Gtk.Image.from_icon_name ("emblem-system-symbolic", Gtk.IconSize.BUTTON);
        var system_style_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            tooltip_text = _("Use the same style set in the system")
        };
        system_style_box.add (system_style_image);
        system_style_box.add (new Gtk.Label (_("System")));

        style_mode_button.append (system_style_box);

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            construct_app_style ();
        });
#endif

        style_mode_button.notify["selected"].connect (() => {
            switch (style_mode_button.selected) {
                case 0:
                    set_app_style (false, false);
                    break;
                case 1:
                    set_app_style (true, false);
                    break;

#if FOR_PANTHEON
                case 2:
                    set_app_style (
                        granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK,
                        true
                    );
                    break;
#endif
            }
        });

        construct_app_style ();
    }

    private void set_app_style (bool is_prefer_dark, bool is_follow_system_style) {
        gtk_settings.gtk_application_prefer_dark_theme = is_prefer_dark;
        Application.settings.set_boolean ("is-prefer-dark", is_prefer_dark);
        Application.settings.set_boolean ("is-follow-system-style", is_follow_system_style);
    }

    private void construct_app_style () {
        if (Application.settings.get_boolean ("is-follow-system-style")) {
#if FOR_PANTHEON
            set_app_style (granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK, true);
            style_mode_button.selected = 2;
#endif
        } else {
            bool is_prefer_dark = Application.settings.get_boolean ("is-prefer-dark");
            set_app_style (is_prefer_dark, false);
            if (is_prefer_dark) {
                style_mode_button.selected = 1;
            } else {
                style_mode_button.selected = 0;
            }
        }
    }
}
