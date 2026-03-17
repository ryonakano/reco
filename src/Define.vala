/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2026 Ryo Nakano <ryonakaknock3@gmail.com>
 */

namespace Define {
    /**
     * Response IDs used in the error dialog.
     */
    namespace ErrorDialogResponseID {
        public const string CLOSE = "close";
    }

    /**
     * String representation of Adw.ColorScheme.
     *
     * Note: Only defines necessary strings for the app.
     */
    namespace ColorScheme {
        /** Inherit the parent color-scheme. */
        public const string DEFAULT = "default";
        /** Always use light appearance. */
        public const string FORCE_LIGHT = "force-light";
        /** Always use dark appearance. */
        public const string FORCE_DARK = "force-dark";
    }

    namespace FileAttribute {
        public const string HOST_PATH = "xattr::document-portal.host-path";
    }

    public enum SourceID {
        MIC,
        SYSTEM,
        BOTH,
    }

    public enum FormatID {
        ALAC,
        FLAC,
        MP3,
        OGG,
        OPUS,
        WAV;

        public string get_suffix () {
            switch (this) {
                case Define.FormatID.ALAC:
                    return "m4a";
                case Define.FormatID.FLAC:
                    return "flac";
                case Define.FormatID.MP3:
                    return "mp3";
                case Define.FormatID.OGG:
                    return "ogg";
                case Define.FormatID.OPUS:
                    return "opus";
                case Define.FormatID.WAV:
                    return "wav";
                default:
                    assert_not_reached ();
                    // no break, dies if reached
            }
        }
    }

    public enum ChannelID {
        MONO = 1,
        STEREO = 2,
    }
}
