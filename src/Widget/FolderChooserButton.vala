/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

public class Widget.FolderChooserButton : Gtk.Button {
    public signal void folder_set (File folder);

    public new string label { get; construct set; }
    public string title { get; construct set; }

    public FolderChooserButton (string label, string title) {
        Object (
            label: label,
            title: title
        );
    }

    construct {
        var button_icon = new Gtk.Image.from_icon_name ("folder");

        var button_label = new Gtk.Label (null) {
            max_width_chars = 20,
            ellipsize = Pango.EllipsizeMode.MIDDLE,
        };

        var content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_top = 2,
            margin_bottom = 2
        };
        content_box.append (button_icon);
        content_box.append (button_label);

        child = content_box;

        clicked.connect (() => present_chooser.begin ());

        bind_property (
            "label",
            button_label, "label",
            BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE
        );
    }

    public async bool present_chooser () {
        var chooser = new Gtk.FileDialog () {
            title = title,
            modal = true
        };

        string last_path = Application.settings.get_string ("last-folder-path");
        if (FileUtils.test (last_path, FileTest.IS_DIR)) {
            // Gtk.FileDialog.initial_folder seems to must be a host path to work as expected inside sandbox
            string? last_path_host = Util.query_host_path (last_path);
            if (last_path_host != null) {
                chooser.initial_folder = File.new_for_path (last_path_host);
            }
        }

        File file;
        try {
            file = yield chooser.select_folder (((Gtk.Application) GLib.Application.get_default ()).active_window, null);
        } catch (Error e) {
            warning ("Failed to select folder: %s", e.message);
            return false;
        }

        last_path = file.get_path ();
        if (last_path == null) {
            warning ("Failed to select folder: Failed to get path");
            return false;
        }

        Application.settings.set_string ("last-folder-path", last_path);

        folder_set (file);

        return true;
    }
}
