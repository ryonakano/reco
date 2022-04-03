/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2018-2022 Ryo Nakano <ryonakaknock3@gmail.com>
 *
 * Code brought from elementary/switchboard-plug-sound, src/PulseAudioManager.vala, authored by Corentin Noël
 */

public class PulseAudioManager : GLib.Object {
    public string default_source_name { get; private set; }
    public string default_sink_name { get; private set; }

    private PulseAudio.Context context;
    private PulseAudio.GLibMainLoop loop;
    private bool is_ready = false;
    private uint reconnect_timer_id = 0U;

    private static PulseAudioManager pam;
    public static unowned PulseAudioManager get_default () {
        if (pam == null) {
            pam = new PulseAudioManager ();
        }

        return pam;
    }

    private PulseAudioManager () {
        loop = new PulseAudio.GLibMainLoop ();
    }

    public void start () {
        reconnect_to_pulse.begin ();
    }

    private bool reconnect_timeout () {
        reconnect_timer_id = 0U;
        reconnect_to_pulse.begin ();
        return false;
    }

    private async void reconnect_to_pulse () {
        if (is_ready) {
            context.disconnect ();
            context = null;
            is_ready = false;
        }

        var props = new PulseAudio.Proplist ();
        props.sets (PulseAudio.Proplist.PROP_APPLICATION_ID, "com.github.ryonakano.reco");
        context = new PulseAudio.Context (loop.get_api (), null, props);
        context.set_state_callback (context_state_callback);

        if (context.connect (null, PulseAudio.Context.Flags.NOFAIL, null) < 0) {
            warning ("pa_context_connect () failed: %s", PulseAudio.strerror (context.errno ()));
        }
    }

    private void context_state_callback (PulseAudio.Context c) {
        switch (c.get_state ()) {
            case PulseAudio.Context.State.READY:
                c.set_subscribe_callback (subscribe_callback);
                c.subscribe (PulseAudio.Context.SubscriptionMask.SERVER);
                context.get_server_info (server_info_callback);
                is_ready = true;
                break;
            case PulseAudio.Context.State.FAILED:
            case PulseAudio.Context.State.TERMINATED:
                if (reconnect_timer_id == 0U) {
                    reconnect_timer_id = Timeout.add_seconds (2, reconnect_timeout);
                }

                break;
            default:
                is_ready = false;
                break;
        }
    }

    private void subscribe_callback (PulseAudio.Context c, PulseAudio.Context.SubscriptionEventType t, uint32 index) {
        var source_type = t & PulseAudio.Context.SubscriptionEventType.FACILITY_MASK;
        if (source_type == PulseAudio.Context.SubscriptionEventType.SERVER) {
            context.get_server_info (server_info_callback);
        }
    }

    private void server_info_callback (PulseAudio.Context context, PulseAudio.ServerInfo? server) {
        if (server == null) {
            return;
        }

        if (default_sink_name == null) {
            default_sink_name = server.default_sink_name;
            debug ("Detected default sink: %s", default_sink_name);
        }

        if (default_sink_name != server.default_sink_name) {
            debug ("Detected default sink changed: %s > %s", default_sink_name, server.default_sink_name);
            default_sink_name = server.default_sink_name;
        }

        if (default_source_name == null) {
            default_source_name = server.default_source_name;
            debug ("Detected default source: %s", default_source_name);
        }

        if (default_source_name != server.default_source_name) {
            debug ("Detected default source changed: %s > %s", default_source_name, server.default_source_name);
            default_source_name = server.default_source_name;
        }
    }
}
