/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <fun>
#include <fakemeta>
#include <jailbreak_core>

#define PLUGIN  "[JB] LR: WESTREN Standoff"
#define AUTHOR  "Natsheh"

new const g_LR_DUEL_NAME[] = "Western Standoff";
new const g_iWESTREN_DUEL_SOUND[] = "jailbreak/western_standoff_fixed.wav";
#define TASK_STANDOFF_DURATION 22.0
#define TASK_STANDOFF_ID 9345

new g_iLR_DUEL_POINTER, g_FW_PlayerPreThink_Post, g_bUserInDuelPrepartions, g_bUserStartWalking, Float:g_flPlayerDuelYawAngle[MAX_PLAYERS+1];

public plugin_precache()
{
    PRECACHE_SOUND(g_iWESTREN_DUEL_SOUND);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    g_iLR_DUEL_POINTER = register_jailbreak_lritem(g_LR_DUEL_NAME);
}

public jb_lr_duel_start(prisoner, guard, duelid)
{
    if(g_iLR_DUEL_POINTER != duelid) return JB_IGNORED;

    new Float:flStart[3], Float:flEnd[3], Float:flViewAngle[3], iTr2 = create_tr2();
    pev(prisoner, pev_origin, flStart);
    flStart[2] += (pev(prisoner, pev_flags) & FL_DUCKING) ? 18.0 : 0.0;

    flEnd[0] = flStart[0];
    flEnd[1] = flStart[1];
    flEnd[2] = flStart[2];

    pev(prisoner, pev_v_angle, flViewAngle);
    flViewAngle[0] = flViewAngle[2] = 0.0;

    angle_vector(flViewAngle, ANGLEVECTOR_FORWARD, flViewAngle);
    flStart[0] += (flViewAngle[0] * 800.0);
    flStart[1] += (flViewAngle[1] * 800.0);
    flEnd[0] += (flViewAngle[0] * -800.0);
    flEnd[1] += (flViewAngle[1] * -800.0);

    engfunc(EngFunc_TraceHull, flStart, flEnd, IGNORE_MONSTERS, HULL_HUMAN, prisoner, iTr2);

    new Float:flFraction, bool:bStartSolid = bool:get_tr2(iTr2, TR_StartSolid), bool:bAllSolid = bool:get_tr2(iTr2, TR_AllSolid), bool:bInOpen = bool:get_tr2(iTr2, TR_InOpen);
    get_tr2(iTr2, TR_flFraction, flFraction);

    free_tr2(iTr2);

    if(flFraction != 1.0 || bStartSolid || bAllSolid || !bInOpen)
    {
        client_print(prisoner, print_center, "This not a valid space for a standoff!");
        return JB_LR_NOT_AVAILABLE;
    }

    if(!g_FW_PlayerPreThink_Post)
    {
        g_FW_PlayerPreThink_Post = register_forward(FM_PlayerPreThink, "fw_PlayerPreThink_Post", true);
    }

    pev(prisoner, pev_v_angle, flViewAngle);
    flViewAngle[0] = flViewAngle[2] = 0.0;
    g_flPlayerDuelYawAngle[prisoner] = flViewAngle[1];

    set_pev(prisoner, pev_v_angle, flViewAngle);
    set_pev(prisoner, pev_angles, flViewAngle);
    set_pev(prisoner, pev_fixangle, 2.0);

    flViewAngle[1] += 180.0;
    if(flViewAngle[1] > 180.0) flViewAngle[1] -= 360.0;
    g_flPlayerDuelYawAngle[guard] = flViewAngle[1];
    set_pev(guard, pev_v_angle, flViewAngle);
    set_pev(guard, pev_angles, flViewAngle);
    set_pev(guard, pev_fixangle, 2.0);

    new Float:fOrigin[3];
    pev(prisoner, pev_origin, fOrigin);
    angle_vector(flViewAngle, ANGLEVECTOR_FORWARD, flViewAngle);
    fOrigin[0] += (flViewAngle[0] * 40.0);
    fOrigin[1] += (flViewAngle[1] * 40.0);
    fOrigin[2] += (pev(prisoner, pev_flags) & FL_DUCKING) ? 18.0 : 0.0;
    set_pev(guard, pev_origin, fOrigin);

    strip_user_weapons(prisoner);
    strip_user_weapons(guard);

    set_user_maxspeed(prisoner, -1.0);
    set_user_maxspeed(guard, -1.0);

    set_flag(g_bUserInDuelPrepartions,prisoner);
    set_flag(g_bUserInDuelPrepartions,guard);

    return JB_IGNORED;
}

public jb_lr_duel_started(prisoner, guard, duelid)
{
    if(g_iLR_DUEL_POINTER != duelid) return;

    set_flag(g_bUserStartWalking,prisoner);
    set_flag(g_bUserStartWalking,guard);

    set_user_health(prisoner, 1);
    set_user_health(guard, 1);

    jb_block_user_weapons(prisoner, true, ~((1<<CSW_DEAGLE)|(1<<CSW_KNIFE)));
    jb_block_user_weapons(guard, true, ~((1<<CSW_DEAGLE)|(1<<CSW_KNIFE)));

    emit_sound(prisoner, CHAN_AUTO, g_iWESTREN_DUEL_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    emit_sound(guard, CHAN_AUTO, g_iWESTREN_DUEL_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    enum (+=1)
    {
        PRISONER_ID = 0,
        GUARD_ID
    }

    new iParams[2];
    iParams[PRISONER_ID] = prisoner;
    iParams[GUARD_ID] = guard;
    set_task(TASK_STANDOFF_DURATION, "give_deagles", TASK_STANDOFF_ID, iParams, sizeof iParams);
}

public jb_lr_duel_ended(prisoner, guard, duelid)
{
    if(g_iLR_DUEL_POINTER != duelid)
    {
        return;
    }

    if(g_FW_PlayerPreThink_Post)
    {
        unregister_forward(FM_PlayerPreThink, g_FW_PlayerPreThink_Post, true);
        g_FW_PlayerPreThink_Post = 0;
    }

    if(is_user_connected(guard))
    {
        jb_block_user_weapons(guard, false);
        strip_user_weapons(guard);
        give_item(guard, "weapon_knife");
        client_cmd(guard, "stopsound;");
    }

    if(is_user_connected(prisoner))
    {
        jb_block_user_weapons(prisoner, false);
        strip_user_weapons(prisoner);
        give_item(prisoner, "weapon_knife");
        client_cmd(prisoner, "stopsound;")
    }

    g_bUserInDuelPrepartions = 0;
    g_bUserStartWalking = 0;
    remove_task(TASK_STANDOFF_ID);
}

public fw_PlayerPreThink_Post(id)
{
    if(!check_flag(g_bUserInDuelPrepartions,id)) return;

    static Float:flViewAngle[3] = { 0.0, 0.0, 0.0 };
    flViewAngle[1] = g_flPlayerDuelYawAngle[id];
    set_pev(id, pev_v_angle, flViewAngle);
    set_pev(id, pev_angles, flViewAngle);
    set_pev(id, pev_fixangle, 2.0);

    static Float:fVelocity[3];
    if(check_flag(g_bUserStartWalking,id))
    {
        angle_vector(flViewAngle, ANGLEVECTOR_FORWARD, fVelocity);
        fVelocity[0] *= 35.0; // average walking speed?
        fVelocity[1] *= 35.0; // average walking speed?
        set_pev(id, pev_velocity, fVelocity);
    }
    else
    {
        set_user_maxspeed(id, -1.0);
        pev(id, pev_velocity, fVelocity);
        fVelocity[0] = fVelocity[1] = 0.0;
        set_pev(id, pev_velocity, fVelocity);
    }
}

public give_deagles(const iParams[], const TaskID)
{
    g_bUserInDuelPrepartions = 0;
    g_bUserStartWalking = 0;

    enum (+=1)
    {
        PRISONER_ID = 0,
        GUARD_ID
    }

    new prisoner = iParams[PRISONER_ID], guard = iParams[GUARD_ID];
    give_item(prisoner, "weapon_knife");
    give_item(guard, "weapon_knife");
    give_item(prisoner, "weapon_deagle");
    give_item(guard, "weapon_deagle");
}
