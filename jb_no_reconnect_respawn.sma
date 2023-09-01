#include <amxmodx>
#include <jailbreak_core>
#include <hamsandwich>
#include <fakemeta>

#define PLUGIN  "[JB] No reconnect respawn"
#define AUTHOR "Natsheh"

#define TASK_NORECONNECT_RESPAWN 360036
#define DELAY_NO_RESPAWN_AFTER 10.0

new HamHook:g_hamhook_fwPlayerPreThinkPre, g_bFirstSpawn[MAX_PLAYERS+1];

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    DisableHamForward( (g_hamhook_fwPlayerPreThinkPre = RegisterHam(Ham_Player_PreThink, "player", "fwPlayerPreThinkPre", false)) );
}

public fwPlayerPreThinkPre(id)
{
    if(!g_bFirstSpawn[id])
    {
        g_bFirstSpawn[id] = true;

        const m_iNumSpawns = 365;
        set_pdata_int(id, m_iNumSpawns, 1);

        return HAM_IGNORED;
    }

    return HAM_IGNORED;
}

#if AMXX_VERSION_NUM > 182
public client_disconnected(id)
#else
public client_disconnect(id)
#endif
{
    g_bFirstSpawn[id] = false;
}

public enable_no_reconnect_respawn()
{
    EnableHamForward(g_hamhook_fwPlayerPreThinkPre);
}

public jb_round_start_pre()
{
    DisableHamForward(g_hamhook_fwPlayerPreThinkPre);

    remove_task(TASK_NORECONNECT_RESPAWN);
    set_task(DELAY_NO_RESPAWN_AFTER, "enable_no_reconnect_respawn", TASK_NORECONNECT_RESPAWN);

    new players[32], pnum;
    get_players(players, pnum, "h");

    for(new i; i < pnum; i++)
    {
        g_bFirstSpawn[ players[i] ] = true;
    }
}
