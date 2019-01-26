/*
* (C) 2019 Ryo Nakano
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
*
*/

public class DestructionWarnginDialog : Granite.MessageDialog {
    public MainWindow window { get; construct; }

    public DestructionWarnginDialog (MainWindow window) {
        Object (
            image_icon: new ThemedIcon ("dialog-warning"),
            primary_text: _("Are you sure you want to quit Reco?"),
            secondary_text: _("If you quit Reco, the recording in progress will end."),
            deletable: false,
            modal: true,
            resizable: false,
            window: window,
            transient_for: window
        );
    }

    construct {
        add_button (_("Cancel"), Gtk.ButtonsType.CANCEL);

        var quit_button = new Gtk.Button.with_label (_("Quit Reco"));
        quit_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
        add_action_widget (quit_button, Gtk.ResponseType.YES);

        response.connect ((response_id) => {
            if (response_id == Gtk.ResponseType.YES) {
                window.destroy ();
            }

            destroy ();
        });
    }
}
