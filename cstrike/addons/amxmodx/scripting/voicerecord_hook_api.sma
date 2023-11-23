#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#define VTC

#if !defined VTC
#include <orpheu>
#include <orpheu_memory>
#include <orpheu_stocks>
#include <orpheu_advanced>
#else
native bool:VTC_IsClientSpeaking(playerSlot);
native VTC_MuteClient(playerSlot);
native VTC_UnmuteClient(playerSlot);
native bool:VTC_IsClientMuted(playerSlot);

forward VTC_OnClientStartSpeak(playerSlot);
forward VTC_OnClientStopSpeak(playerSlot);

native VTC_PlaySound(receiver, const soundFilePath[]);
#endif

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif

#if !defined VTC
#define GetPlayerByClientStruct(%0)     ( ( %0 - g_client_t_address ) / 20200 + 1 )

new g_top_client
new g_client_t_address
new g_player_voice_status[ 32 ]
#endif

new g_fwdVoiceRecordOn
new g_fwdVoiceRecordOff
new g_iResult;

public plugin_init()
{
    #if !defined VTC
    register_forward( FM_Voice_SetClientListening, "fwd_Voice_SetClientListening" );
    OrpheuRegisterHook( OrpheuGetFunction("SV_ParseVoiceData"), "SV_ParseVoiceData" );
    RegisterHam( Ham_Spawn, "player", "hamPlayerSpawn" );

    new svs = OrpheuMemoryGet( "g_psvs" );

    g_client_t_address = OrpheuMemoryGetAtAddress( svs + 4, "g_psvs_clients" );
    arrayset( g_player_voice_status, 0, 32 );
    g_top_client = 0;
    #endif

    g_fwdVoiceRecordOn = CreateMultiForward( "client_voicerecord_on", ET_IGNORE, FP_CELL );
    g_fwdVoiceRecordOff = CreateMultiForward( "client_voicerecord_off", ET_IGNORE, FP_CELL );
}

#if !defined VTC
public SV_ParseVoiceData( cl ) // client_t* cl
{
    // int iClient = cl - g_psvs.clients;
    // Flag user as it's using voicerecord
    new player = GetPlayerByClientStruct( cl )
    g_player_voice_status[ max(player - 1, 0) ] = 1
}

public hamPlayerSpawn( id )
{
    set_top_client()
    g_player_voice_status[ id - 1 ] = 0
}

public fwd_Voice_SetClientListening( receiver, sender, bool:listen )
{
    // Detect +voicerecord
    if( receiver == 1 && g_player_voice_status[ sender - 1 ] )
    {
        ExecuteForward( g_fwdVoiceRecordOn, g_iResult, sender )
    }

    // Detect -voicerecord
    if( receiver == g_top_client && g_player_voice_status[ sender - 1 ] )
    {
        ExecuteForward( g_fwdVoiceRecordOff, g_iResult, sender )
        g_player_voice_status[ sender - 1 ] = 0
    }

    return FMRES_IGNORED
}

public client_disconnect( id )
{
    set_top_client()
    g_player_voice_status[ id - 1 ] = 0
}

set_top_client()
{
    new players[ 32 ], num

    get_players( players, num )

    for( num--; num >= 0; num-- )
    {
        if( players[ num ] > g_top_client )
          g_top_client = players[ num ]
    }
} 
#else
public VTC_OnClientStartSpeak( player )
{
    ExecuteForward( g_fwdVoiceRecordOn, g_iResult, player );
}

public VTC_OnClientStopSpeak( player )
{
    ExecuteForward( g_fwdVoiceRecordOff, g_iResult, player );
}
#endif
