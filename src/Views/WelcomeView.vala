/*
* (C) 2018 Ryo Nakano
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

public class WelcomeView : Gtk.Box {
    public MainWindow window { get; construct; }
    public Gtk.ComboBoxText format_combobox { get; set; }
    public Gtk.SpinButton delay_spin { get; private set; }
    public Gtk.SpinButton length_spin { get; private set; }
    public Gtk.Switch auto_save { get; private set; }
    public Gtk.FileChooserButton destination_chooser { get; private set; }
    private Gtk.Button record_button;

    public WelcomeView (MainWindow window) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 12,
            window: window,
            margin: 6
        );
    }

    construct {
        var delay_label = new Gtk.Label (_("Delay in seconds:"));
        delay_label.xalign = 1;
        delay_spin = new Gtk.SpinButton.with_range (0, 15, 1);

        var length_label = new Gtk.Label (_("Length in seconds:"));
        length_label.xalign = 1;
        length_spin = new Gtk.SpinButton.with_range (0, 600, 1);

        var recording_grid = new Gtk.Grid ();
        recording_grid.column_spacing = 6;
        recording_grid.row_spacing = 6;
        recording_grid.halign = Gtk.Align.CENTER;
        recording_grid.attach (delay_label, 0, 0, 1, 1);
        recording_grid.attach (delay_spin, 1, 0, 1, 1);
        recording_grid.attach (length_label, 0, 1, 1, 1);
        recording_grid.attach (length_spin, 1, 1, 1, 1);

        var format_label = new Gtk.Label (_("Format:"));
        format_label.xalign = 1;

        format_combobox = new Gtk.ComboBoxText ();
        format_combobox.halign = Gtk.Align.START;
        format_combobox.append ("aac", _("AAC"));
        format_combobox.append ("flac", _("FLAC"));
        format_combobox.append ("mp3", _("MP3"));
        format_combobox.append ("ogg", _("Ogg Vorbis"));
        format_combobox.append ("opus", _("Opus"));
        format_combobox.append ("wav", _("Wav"));
        format_combobox.active_id = "wav";

        var auto_save_label = new Gtk.Label (_("Automatically save files:"));
        auto_save_label.xalign = 1;

        auto_save = new Gtk.Switch ();
        auto_save.halign = Gtk.Align.START;

        destination_chooser = new Gtk.FileChooserButton (_("Choose a default destination"), Gtk.FileChooserAction.SELECT_FOLDER);
        destination_chooser.halign = Gtk.Align.START;
        destination_chooser.set_filename (window.app.destination);
        destination_chooser.sensitive = auto_save.active;

        var saving_grid = new Gtk.Grid ();
        saving_grid.column_spacing = 6;
        saving_grid.row_spacing = 6;
        saving_grid.halign = Gtk.Align.CENTER;
        saving_grid.attach (format_label, 0, 0, 1, 1);
        saving_grid.attach (format_combobox, 1, 0, 1, 1);
        saving_grid.attach (auto_save_label, 0, 1, 1, 1);
        saving_grid.attach (auto_save, 1, 1, 1, 1);
        saving_grid.attach (destination_chooser, 1, 2, 1, 1);

        var stack = new Gtk.Stack ();
        stack.add_titled (recording_grid, "record", _("Recording"));
        stack.add_titled (saving_grid, "saving", _("Saving"));
        stack.margin_top = stack.margin_bottom = 12;

        var stack_switcher = new Gtk.StackSwitcher ();
        stack_switcher.halign = Gtk.Align.CENTER;
        stack_switcher.homogeneous = true;
        stack_switcher.stack = stack;

        record_button = new Gtk.Button ();
        record_button.image = new Gtk.Image.from_icon_name ("audio-input-microphone-symbolic", Gtk.IconSize.DND);
        record_button.tooltip_text = _("Start recording");
        record_button.get_style_context ().add_class ("record-button");
        record_button.halign = Gtk.Align.CENTER;
        record_button.width_request = 48;
        record_button.height_request = 48;

        pack_start (stack_switcher, false, false);
        pack_start (stack, false, false);
        pack_end (record_button, false, false);

        auto_save.notify["active"].connect (() => {
            destination_chooser.sensitive = auto_save.active;
        });

        record_button.clicked.connect (() => {
            if (delay_spin.value != 0) {
                window.show_countdown ();
            } else {
                window.show_record ();
            }
        });
    }
}
