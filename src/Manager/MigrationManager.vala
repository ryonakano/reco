/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

/**
 * A class that handles backward compatibility.
 */
public class Manager.MigrationManager : Object {
    private delegate bool SettingsMigrationFunc (Settings settings, Variant old_val);

    /**
     * Data structure to migrate user preferences saved in {@link GLib.Settings}.
     */
    private struct SettingsMigrationEntry {
        /**
         * Key name before migration.
         */
        string old_key;

        /**
         * Migration procedure.
         */
        unowned SettingsMigrationFunc migrate;
    }
    private static SettingsMigrationEntry[] settings_migration_table = {
        {
            "autosave-destination",
            ((settings, old_val) => {
                unowned string path = old_val.get_string ();
                if (path.length <= 0) {
                    // No need to migrate; shouldn't reach here because this is the case of the default value
                    return true;
                }

                settings.set_boolean ("autosave", true);
                settings.set_string ("last-folder-path", path);

                debug ("Settings migrated. \"autosave-destination\" -> \"autosave\" & \"last-folder-path\": val=\"%s\"",
                        path);

                return true;
            }),
        },
    };

    public MigrationManager () {
    }

    /**
     * Migrate user preferences of {@link GLib.Settings} from old (deprecated) keys to new ones.
     *
     * @param settings      A {@link GLib.Settings} class storing user preferences.
     *
     * @return              true if succeed, false otherwise.
     */
    public bool migrate_settings (Settings settings) {
        SettingsSchema ss = settings.settings_schema;

        foreach (unowned var entry in settings_migration_table) {
            if (!ss.has_key (entry.old_key)) {
                continue;
            }

            var old_val = settings.get_value (entry.old_key);

            SettingsSchemaKey ssk = ss.get_key (entry.old_key);
            var default_val = ssk.get_default_value ();
            if (old_val.equal (default_val)) {
                // No need to migrate
                continue;
            }

            bool ret = entry.migrate (settings, old_val);
            if (!ret) {
                warning ("Failed to migrate settings. key=\"%s\"", entry.old_key);
                return false;
            }

            settings.reset (entry.old_key);
        }

        return true;
    }
}
