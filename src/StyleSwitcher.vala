/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Ryo Nakano <ryonakaknock3@gmail.com>
 * 
 * Some code inspired from elementary/switchboard-plug-pantheon-shell, src/Views/Appearance.vala
 */

public class StyleSwitcher : Gtk.Box {
    private Gtk.Settings gtk_settings;
    private Granite.Settings granite_settings;

    private StyleButton light_style_button;
    private StyleButton dark_style_button;
    private StyleButton system_style_button;

    public StyleSwitcher () {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 6
        );
    }

    construct {
        gtk_settings = Gtk.Settings.get_default ();

        var style_label = new Gtk.Label (_("Style:")) {
            halign = Gtk.Align.START
        };

        var buttons_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        light_style_button = new StyleButton ("display-brightness-symbolic", _("Light"));
        buttons_box.append (light_style_button);

        dark_style_button = new StyleButton ("weather-clear-night-symbolic", _("Dark"), light_style_button);
        buttons_box.append (dark_style_button);

        if (Application.IS_ON_PANTHEON) {
            granite_settings = Granite.Settings.get_default ();

            system_style_button = new StyleButton ("emblem-system-symbolic", _("System"), light_style_button);
            buttons_box.append (system_style_button);

            granite_settings.notify["prefers-color-scheme"].connect (() => {
                construct_app_style ();
            });

            system_style_button.toggled.connect (() => {
                set_app_style (
                    granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK,
                    true
                );
            });
        }

        light_style_button.toggled.connect (() => {
            set_app_style (false, false);
        });

        dark_style_button.toggled.connect (() => {
            set_app_style (true, false);
        });

        construct_app_style ();

        append (style_label);
        append (buttons_box);
    }

    private void set_app_style (bool is_prefer_dark, bool is_follow_system_style) {
        gtk_settings.gtk_application_prefer_dark_theme = is_prefer_dark;
        Application.settings.set_boolean ("is-prefer-dark", is_prefer_dark);
        Application.settings.set_boolean ("is-follow-system-style", is_follow_system_style);
    }

    private void construct_app_style () {
        if (!Application.IS_ON_PANTHEON) {
            Application.settings.set_boolean ("is-follow-system-style", false);
        }

        if (Application.settings.get_boolean ("is-follow-system-style")) {
            set_app_style (granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK, true);
            system_style_button.active = true;
        } else {
            bool is_prefer_dark = Application.settings.get_boolean ("is-prefer-dark");
            set_app_style (is_prefer_dark, false);
            if (is_prefer_dark) {
                dark_style_button.active = true;
            } else {
                light_style_button.active = true;
            }
        }
    }

    private class StyleButton : Gtk.ToggleButton {
        public new string icon_name { get; construct; }
        public string label_text { get; construct; }

        public StyleButton (string icon_name, string label_text, Gtk.ToggleButton? group = null) {
            Object (
                icon_name: icon_name,
                label_text: label_text,
                group: group
            );
        }

        construct {
            var button_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
            button_content.append (new Gtk.Image.from_icon_name (icon_name));
            button_content.append (new Gtk.Label (label_text));

            child = button_content;
            can_focus = false;
        }
    }
}
