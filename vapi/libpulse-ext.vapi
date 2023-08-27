[CCode (cheader_filename="pulse/ext-stream-restore.h")]
namespace PulseAudio {
    [CCode (cname="pa_ext_stream_restore_read", cheader_filename="pulse/ext-stream-restore.h")]
    public static Operation? ext_stream_restore_read (Context c, ExtStreamRestoreReadCb cb);
    [CCode (cname="pa_ext_stream_restore_write", cheader_filename="pulse/ext-stream-restore.h")]
    public static Operation? ext_stream_restore_write (Context c, UpdateMode mode, [CCode (array_length_cname = "n", array_length_pos = 3.1)] ExtStreamRestoreInfo[] data, int apply_immediately, Context.SuccessCb? cb = null);
    public delegate void ExtStreamRestoreReadCb (Context c, ExtStreamRestoreInfo? info, int eol);

    [CCode (cname = "pa_ext_stream_restore_info", has_type_id = false)]
    public struct ExtStreamRestoreInfo {
            public unowned string name;
            public int mute;
            public unowned string device;
            public ChannelMap channel_map;
            public CVolume volume;
    }
}
