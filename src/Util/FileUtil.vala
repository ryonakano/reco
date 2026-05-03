/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

/**
 * File utilities.
 */
namespace Util.FileUtil {
    public static async void trash_file (string path) throws Error {
        if (!FileUtils.test (path, FileTest.EXISTS)) {
            return;
        }

        yield File.new_for_path (path).trash_async ();
    }

    public static async void delete_file (string path) throws Error {
        if (!FileUtils.test (path, FileTest.EXISTS)) {
            return;
        }

        yield File.new_for_path (path).delete_async ();
    }

    /**
     * Query path on host.
     * Note: This method requires xdg-desktop-portal >= 1.19.0 to work.
     *
     * @param sandbox_path  Path inside sandbox
     *
     * @return              Path inside sandbox if succeed, null otherwise
     */
    public static string? query_host_path (string sandbox_path) {
        File file = File.new_for_path (sandbox_path);

        FileInfo info;
        try {
            info = file.query_info (Define.FileAttribute.HOST_PATH, FileQueryInfoFlags.NONE);
        } catch (Error err) {
            warning ("Failed to query host path of \"%s\": %s", sandbox_path, err.message);
            return null;
        }

        return info.get_attribute_as_string (Define.FileAttribute.HOST_PATH);
    }
}
