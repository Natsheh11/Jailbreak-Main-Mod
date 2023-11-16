/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <amxmisc>
#include <npc_library>
#include <jailbreak_core>
#include <jailbreak_minigames>

#define PLUGIN  "Ugandan Knuckle"
#define AUTHOR  "Natsheh"

new const KNUCKLE_CLASSNAME[] = "knuckle";
new const KNUCKLE_MODEL[] = "models/npc/ugandan_knuckle.mdl";
new const Float:g_fMaxS[3] = { 10.0, 10.0, 18.0 };
new const Float:g_fMinS[3] = { -10.0, -10.0, 0.0 };

new const KNUCKLE_SOUNDS[][] = {
    "knuckle/da_wae1.wav",
    "knuckle/da_wae2.wav",
    "knuckle/da_wae3.wav",
    "knuckle/da_wae4.wav",
    "knuckle/da_wae5.wav"
}

enum any:CVARS_KNUCKLE
{
    CVAR_KNUCKLE_ATTACK_DAMAGE,
    CVAR_KNUCKLE_TRACE_ATTACK,
    CVAR_KNUCKLE_ATTACK_DELAY,
    CVAR_KNUCKLE_SHOVE_FORCE
}

new Array:g_animArrays[NPC_ACTIVITY], g_sizeAnimArrays[NPC_ACTIVITY], g_iCvars[CVARS_KNUCKLE], MINIGAME_INDEX, g_Flesh_gibs,
HamHook:g_fw_HamTakeDamage, HamHook:g_fw_HamTraceAttack, HamHook:g_fw_ham_player_traceattack_post;

public plugin_precache()
{
    precache_model(KNUCKLE_MODEL);

    for(new i ; i < sizeof KNUCKLE_SOUNDS; i++)
    {
        precache_sound(KNUCKLE_SOUNDS[i]);
    }

    g_Flesh_gibs = PRECACHE_WORLD_ITEM_I("models/hgibs.mdl");
}

public plugin_end()
{
    NPC_FREE_HOOKS(KNUCKLE_CLASSNAME);
    MDL_STUDIO_FREE_DATA(g_animArrays, g_sizeAnimArrays);
    MDL_STUDIO_DESTROY_HOOKS(engfunc(EngFunc_ModelIndex, KNUCKLE_MODEL));
}

public plugin_init()
{
    new iPluginID = register_plugin(PLUGIN, VERSION, AUTHOR);

    g_iCvars[CVAR_KNUCKLE_ATTACK_DAMAGE] = register_cvar("knuckle_attack_damage", "25");
    g_iCvars[CVAR_KNUCKLE_TRACE_ATTACK] = register_cvar("knuckle_traceattk", "200");
    g_iCvars[CVAR_KNUCKLE_ATTACK_DELAY] = register_cvar("knuckle_attack_delay", "1.0");
    g_iCvars[CVAR_KNUCKLE_SHOVE_FORCE] = register_cvar("knuckle_player_shove_force", "500");

    DisableHamForward( (g_fw_ham_player_traceattack_post=RegisterHam(Ham_TraceAttack, "player", "fw_player_traceattack_post", true)) );
    DisableHamForward( (g_fw_HamTraceAttack = RegisterHam(Ham_TraceAttack, "player", "fw_traceattack_player_pre")));
    DisableHamForward( (g_fw_HamTakeDamage = RegisterHam(Ham_TakeDamage, "player", "fw_takedamage_pre")));

    MDL_STUDIO_LOAD_ANIMATIONS(KNUCKLE_MODEL, g_animArrays, g_sizeAnimArrays);
    //MDL_STUDIO_HOOK_EVENT(engfunc(EngFunc_ModelIndex, KNUCKLE_MODEL), "task_npc_event");

    NPC_Hook_Event(KNUCKLE_CLASSNAME, NPC_EVENT_DEATH, "knuckle_killed", iPluginID);

    register_think(KNUCKLE_CLASSNAME, "knuckle_thinks");
    register_touch(KNUCKLE_CLASSNAME, "player", "knuckle_touch");

    register_jb_minigame("Spare the knuckle", "minigame_spare_knuckles");

    register_concmd("amx_knuckle_curse", "cmd_curse", ADMIN_KICK);
}

public jb_round_start_pre()
{
    destroy_knuckles();
}

public fw_player_traceattack_post(victim, attacker, Float:fDamage, Float:fDirection[3], traceresults, dmgbits)
{
    if(!IsPlayer(attacker) || victim == attacker) return;

    if(jb_is_user_inminigame(victim) != MINIGAME_INDEX ||
        jb_is_user_inminigame(attacker) != MINIGAME_INDEX)
            return;

    // lets shove that mother f***er
    static Float:fVelo[3];
    xs_vec_copy(fDirection, fVelo);
    xs_vec_mul_scalar(fVelo, get_pcvar_float(g_iCvars[CVAR_KNUCKLE_SHOVE_FORCE]), fVelo);
    set_pev(victim, pev_velocity, fVelo);
}

public fw_traceattack_player_pre(victim, attacker, Float:damage, Float:direction[3], traceresults, dmgbits)
{
    if(!IsPlayer(attacker) || victim == attacker) return HAM_IGNORED;

    if(jb_is_user_inminigame(victim) != MINIGAME_INDEX ||
        jb_is_user_inminigame(attacker) != MINIGAME_INDEX)
            return HAM_IGNORED;

    SetHamParamFloat(3, 0.0);
    return HAM_SUPERCEDE;
}

public fw_takedamage_pre(victim, inflictor, attacker, Float:damage, dmgbits)
{
    if(!IsPlayer(attacker) || victim == attacker) return HAM_IGNORED;

    if((jb_is_user_inminigame(victim) != MINIGAME_INDEX ||
        jb_is_user_inminigame(attacker) != MINIGAME_INDEX))
            return HAM_IGNORED;

    set_pev(victim, pev_punchangle, Float:{0.0,0.0,0.0});
    SetHamParamFloat(4, 0.0);
    return HAM_SUPERCEDE;
}

public minigame_spare_knuckles( minigame_index, minigame_mode, minigame_players[MAX_PLAYERS+1], teams[MAX_MINIGAMES_TEAMS], maxteams, players_num, bits_players )
{
    EnableHamForward(g_fw_ham_player_traceattack_post);
    EnableHamForward(g_fw_HamTraceAttack);
    EnableHamForward(g_fw_HamTakeDamage);

    new Float:fOrigin[3], players[MAX_PLAYERS], pnum;
    get_players(players, pnum, "che", "TERRORIST");

    for(new i, player; i < pnum; i++)
    {
        player = players[i];
        if(check_flag(bits_players, player))
        {
            pev(player, pev_origin, fOrigin);
            find_location_around_origin(fOrigin, g_fMaxS, g_fMinS, 300.0, .bRandom =  true);
            set_pev(spawn_knuckle(fOrigin, player), pev_owner, 0);
        }
    }
}

public jb_minigame_ended(const Minigame_Index, const MINIGAMES_MODES:Minigame_Mode, const Winner, bits_players)
{
    if(Minigame_Index == MINIGAME_INDEX)
    {
        DisableHamForward(g_fw_ham_player_traceattack_post);
        DisableHamForward(g_fw_HamTraceAttack);
        DisableHamForward(g_fw_HamTakeDamage);

        destroy_knuckles();
    }
}

destroy_knuckles()
{
    new ent;
    while( (ent = find_ent_by_class(ent, KNUCKLE_CLASSNAME)) > 0 )
    {
        set_pev(ent, PEV_TASK, NPC_KILLSELF);
        dllfunc(DLLFunc_Think, ent);
    }
}

public knuckle_touch(id, other)
{
    static ground; ground = pev(other, pev_groundentity);

    if(ground == id)
    {
        ExecuteHamB(Ham_Killed, id, other, GIB_ALWAYS);
    }
}

public knuckle_killed(id, killer, gibs)
{
    new szClass[32], Float:fOrigin[3];
    pev(id, pev_origin, fOrigin);
    gib(fOrigin);

    pev(id, PEV_WEAPON_INFLICTOR, szClass, charsmax(szClass));
    Initiate_NPC_DEATHMSG(id, killer, false, szClass);

    set_rendering(id, .render = kRenderTransAlpha, .amount = 000);

    if(IsPlayer(killer))
    {
        new knuckle;
        // Double Spawn
        find_location_around_origin(fOrigin, g_fMaxS, g_fMinS, 300.0, .bRandom =  true);
        knuckle = spawn_knuckle(fOrigin, .pOwner = killer);
        set_pev(knuckle, pev_owner, 0);
        set_pev(knuckle, pev_takedamage, DAMAGE_NO);
        set_task(0.5, "task_set_entity_killable", knuckle);

        pev(id, pev_origin, fOrigin);
        find_location_around_origin(fOrigin, g_fMaxS, g_fMinS, 300.0, .bRandom =  true);
        knuckle = spawn_knuckle(fOrigin, .pOwner = killer);
        set_pev(knuckle, pev_owner, 0);
        set_pev(knuckle, pev_takedamage, DAMAGE_NO);
        set_task(0.5, "task_set_entity_killable", knuckle);

        // Kill/Damage the killer
        ExecuteHamB(Ham_TakeDamage, killer, id, id, 100.0, DMG_POISON);
    }
}

public task_set_entity_killable(const ent)
{
    if(pev_valid(ent))
    {
        new szClass[32];
        pev(ent, pev_classname, szClass, 31);

        if(equal(szClass, KNUCKLE_CLASSNAME))
        {
            set_pev(ent, pev_takedamage, DAMAGE_YES);
        }
    }
}

public cmd_curse(id, level, cid)
{
    if(!(get_user_flags(id) & level))
    {
        console_print(id, "Access denied!");
        return PLUGIN_HANDLED;
    }

    new szTarget[34];
    read_argv(1, szTarget, charsmax(szTarget));
    remove_quotes(szTarget);

    new player = cmd_target(id, szTarget, .flags = CMDTARGET_ALLOW_SELF|CMDTARGET_ONLY_ALIVE|CMDTARGET_NO_BOTS)

    if(!player)
    {
        return PLUGIN_HANDLED;
    }

    new Float:fOrigin[3];
    pev(player, pev_origin, fOrigin);
    find_location_around_origin(fOrigin, g_fMaxS, g_fMinS, 300.0, .bRandom =  true);
    set_pev(spawn_knuckle(fOrigin), PEV_OWNER, player);
    console_print(id, "Command successful!");

    return PLUGIN_HANDLED;
}

spawn_knuckle(const Float:fOrigin[3], const pOwner = 0)
{
    return NPC_SPAWN(KNUCKLE_CLASSNAME, "ugandan knuckle", KNUCKLE_MODEL, fOrigin, Float:{0.0,0.0,16.0}, 400.0, 100.0, pOwner, .task=NPC_SEEK_TARGET, .NPC_MOVETYPE=MOVETYPE_PUSHSTEP, .fMaxS = g_fMaxS, .fMinS = g_fMinS);
}

public knuckle_thinks(id)
{
    if(!pev_valid(id)) return;

    static Float:fGtime, Float:fViewOffset[3], Float:fVelocity[3], Float:fNPCViewAngles[3], Float:fOrigin[3],
        Float:fTraceAttackOrigin[3], iOwner, Float:fNPCspeed = 250.0, Float:fMAX_SIZE[3], Float:fMIN_SIZE[3],
        Float:fNPCJspeed = 380.0, iTask;

    fGtime = get_gametime();
    iTask = pev(id, PEV_TASK);
    pev(id, pev_velocity, fVelocity);
    pev(id, pev_angles, fNPCViewAngles);
    pev(id, pev_origin, fOrigin);
    pev(id, pev_view_ofs, fViewOffset);
    pev(id, pev_maxs, fMAX_SIZE);
    pev(id, pev_mins, fMIN_SIZE);
    iOwner = pev(id, PEV_OWNER);
    xs_vec_add(fOrigin, fViewOffset, fTraceAttackOrigin);

    switch( iTask )
    {
        case NPC_KILLSELF:
        {
            set_pev(id, pev_flags, FL_KILLME);
            dllfunc(DLLFunc_Think, id);
        }
        case NPC_DEATH:
        {
            set_pev(id, pev_deadflag, DEAD_DYING);
            set_pev(id, pev_solid, SOLID_NOT);
            set_pev(id, pev_movetype, MOVETYPE_TOSS);
            set_pev(id, pev_takedamage, DAMAGE_NO);
            set_pev(id, PEV_TASK, NPC_KILLSELF);

            NPC_animation(id, g_animArrays, g_sizeAnimArrays);

            set_pev(id, pev_nextthink, fGtime + NPC_KILLSELF_THINK_LEN);
        }
        case NPC_SEEK_TARGET:
        {
            static ent, iTarget, Float:fMaxDistance, Float:fDist, Float:fOriginDest[3];
            ent = iTarget = 0;
            fMaxDistance = 1000.0;

            while( (ent=find_ent_in_sphere(ent, fTraceAttackOrigin, fMaxDistance)) > 0)
            {
                if(
                    IsPlayer(ent) &&
                    entity_takedamage_type(ent) != DAMAGE_NO &&
                    IsEntityVisible(fTraceAttackOrigin, fOriginDest, ent, id) &&
                    fMaxDistance > (fDist = get_distance_f(fTraceAttackOrigin,fOriginDest)) )
                {
                    fMaxDistance = fDist;
                    iTarget = ent;
                }
            }

            static Float:fRoamingDelay, Float:fTeleportDelay;
            pev(id, PEV_NPC_ACTION_DELAY, fRoamingDelay);
            pev(id, PEV_TELEPORTING_COOLDOWN, fTeleportDelay);

            if(iTarget) // We Found a target? engage !
            {
                set_pev(id, PEV_TARGET_LAST_TIME_SEEN, fGtime);
                set_pev(id, PEV_PREVIOUS_TASK, NPC_SEEK_TARGET);
                set_pev(id, NPC_TARGET, iTarget);
                set_pev(id, PEV_TASK, NPC_ATTACK);
            }
            else if( fRoamingDelay < fGtime ) // lets roam and find us a target.
            {
                static i, Float:vfTemp[3] = { 0.0, 0.0, 0.0 }, Float:fChosenAngle, Float:fCurrAngle;
                fMaxDistance = fChosenAngle = 0.0; // 1k unit should be enf for us to find the longest path.
                fOriginDest[2] = fTraceAttackOrigin[2];

                for ( i = 0, fCurrAngle = -45.0;  i < 3; i ++ )
                {
                    fDist = 9999.0;
                    xs_vec_set(vfTemp, 0.0, fNPCViewAngles[1] + fCurrAngle, 0.0);
                    angle_vector(vfTemp, ANGLEVECTOR_FORWARD, vfTemp);
                    xs_vec_mul_scalar(vfTemp, fDist, vfTemp);

                    fOriginDest[0] = fOrigin[0] + vfTemp[0];
                    fOriginDest[1] = fOrigin[1] + vfTemp[1];
                    NPC_traceattack(id, fTraceAttackOrigin, fOriginDest, fDist, .HullType=HULL_POINT);

                    if(fDist > fMaxDistance)
                    {
                        fMaxDistance = fDist;
                        fChosenAngle = fNPCViewAngles[1] + fCurrAngle;
                    }

                    fCurrAngle += 45.0;
                }

                if( fMaxDistance > ((xs_vec_len(fMAX_SIZE) + xs_vec_len(fMIN_SIZE)) * 0.5) )
                {
                    vfTemp[ 0 ] = vfTemp[ 2 ] = 0.0;
                    vfTemp[ 1 ] = fChosenAngle;
                    angle_vector(vfTemp, ANGLEVECTOR_FORWARD, vfTemp);
                    xs_vec_mul_scalar(vfTemp, fMaxDistance, vfTemp);
                    fOriginDest[0] = fOrigin[0] + vfTemp[0];
                    fOriginDest[1] = fOrigin[1] + vfTemp[1];
                    LookAtOrigin(id, fOriginDest);
                    set_pev(id, PEV_NPC_ACTION_DELAY, fGtime + NPC_THINK_LEN);
                    MoveToOrigin(id, fOriginDest, fNPCspeed, fNPCJspeed, fVelocity)
                }
                else // no way to go ? lets turn 45 degrees to the right.
                {
                    xs_vec_set(vfTemp, 0.0, fNPCViewAngles[1] + 45.0, 0.0);
                    angle_vector(vfTemp, ANGLEVECTOR_FORWARD, vfTemp);
                    fOriginDest[0] = fOrigin[0] + vfTemp[0];
                    fOriginDest[1] = fOrigin[1] + vfTemp[1];
                    LookAtOrigin(id, fOriginDest);
                    set_pev(id, PEV_NPC_ACTION_DELAY, fGtime + 0.5); // turning right takes time.
                }
            }

            NPC_animation(id, g_animArrays, g_sizeAnimArrays);
            set_pev(id, pev_nextthink, fGtime + NPC_THINK_LEN);
        }
        case NPC_ATTACK:
        {
            static iVictim, Float:fHealth; fHealth = 0.0;

            if(pev_valid((iVictim = pev(id, NPC_TARGET))))
            {
                static Float:fvEndSight[3];
                // Has vision of the official target...
                if( iOwner > 0 && iOwner != iVictim && IsEntityVisible(fTraceAttackOrigin, fvEndSight, iOwner, id) )
                {
                    set_pev(id, NPC_TARGET, iOwner);
                    iVictim = iOwner;
                }

                pev(iVictim, pev_health, fHealth);
            }

            if(fHealth > 0.0 && entity_takedamage_type(iVictim) != DAMAGE_NO)
            {
                static Float:fOriginDest[3], Float:fDelay = -1.0, Float:fVicViewOfs[3], Float:fVicVelocity[3], Float:fTraceAttack;
                pev(iVictim, pev_origin, fOriginDest);
                pev(iVictim, pev_view_ofs, fVicViewOfs);
                fOriginDest[2] += fVicViewOfs[2];
                xs_vec_copy(fOriginDest, fVicVelocity);
                fTraceAttack = get_pcvar_float(g_iCvars[CVAR_KNUCKLE_TRACE_ATTACK]);

                pev(id, PEV_NPC_ACTION_DELAY, fDelay);

                // NPC has no visual of the target.
                if( !IsEntityVisible(fTraceAttackOrigin, fVicVelocity, iVictim, id) )
                {
                    /* npc cannot see the target. */
                    static Float:fLastSeen;
                    pev(id, PEV_TARGET_LAST_TIME_SEEN, fLastSeen);
                    if(fGtime > (fLastSeen + 3.0) && !IsEntityVisible(fTraceAttackOrigin, fVicVelocity, iVictim, id))
                    {
                        set_pev(id, NPC_TARGET, 0);
                    }

                    fDelay = -1.0;
                    NPC_animation(id, g_animArrays, g_sizeAnimArrays);
                }
                else // Enemy is visible
                {
                    set_pev(id, PEV_TARGET_LAST_TIME_SEEN, fGtime);

                    static Float:fAttackDelay, Float:fVicSpeed, Float:fDirection[3];
                    fAttackDelay = get_pcvar_float(g_iCvars[CVAR_KNUCKLE_ATTACK_DELAY]);
                    if(fAttackDelay <= 0.0) fAttackDelay = 1.0;
                    pev(iVictim, pev_velocity, fVicVelocity);

                    if((fVicSpeed=xs_vec_len_2d(fVicVelocity)) > 0.0)
                    {
                        xs_vec_sub(fOriginDest, fTraceAttackOrigin, fDirection);
                        xs_vec_normalize(fDirection, fDirection);
                        xs_vec_normalize(fVicVelocity, fVicVelocity);
                        fVicSpeed *= xs_vec_dot(fDirection, fVicVelocity);

                        if(fVicSpeed < 0.0)
                        {
                            fVicSpeed *= -1.0;
                        }
                    }

                    LookAtOrigin(id, fOriginDest);

                    if((get_distance_f(fTraceAttackOrigin, fOriginDest) + (fVicSpeed * fAttackDelay)) <= fTraceAttack)
                    {
                        if(fDelay < fGtime)
                        {
                            fDelay = fGtime + fAttackDelay;

                            emit_sound(id, CHAN_AUTO, KNUCKLE_SOUNDS[random(sizeof KNUCKLE_SOUNDS)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

                            if(g_sizeAnimArrays[ACT_MELEE_ATTACK1] > 0)
                            {
                                static xArray[ANIMATION_DATA], Float:fFrameRate;
                                ArrayGetArray(Array:g_animArrays[ACT_MELEE_ATTACK1], random(g_sizeAnimArrays[ACT_MELEE_ATTACK1]), xArray);
                                fFrameRate = ( xArray[ANIMATION_FRAMES] / xArray[ANIMATION_FPS] ) / fAttackDelay;
                                PlayAnimation(id, xArray[ANIMATION_SEQUENCE],
                                    xArray[ANIMATION_FPS], fFrameRate, xArray[ANIMATION_FRAMES], ACT_MELEE_ATTACK1,
                                    .bInLOOP=false,
                                    .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                                    .pArrayEventSize=xArray[ANIMATION_EVENTS]);
                            }


                        }
                    }
                    else // Target is out of range, order to go to.
                    {
                        xs_vec_sub(fOriginDest, fVicViewOfs, fOriginDest);

                        MoveToOrigin(id, fOriginDest, fNPCspeed, fNPCJspeed, fVelocity);
                        NPC_animation(id, g_animArrays, g_sizeAnimArrays);
                        fDelay = -1.0;
                    }
                }
                set_pev(id, PEV_NPC_ACTION_DELAY, fDelay);
            }
            else
            {
                if(!iVictim && pev(id, PEV_PREVIOUS_TASK) == NPC_FOLLOW_PLAYER)
                {
                    set_pev(id, PEV_PREVIOUS_TASK, NPC_IDLE);
                }

                set_pev(id, PEV_TASK, pev(id, PEV_PREVIOUS_TASK));
                set_pev(id, NPC_TARGET, 0);
            }

            set_pev(id, pev_nextthink, fGtime + NPC_THINK_LEN);
        }
    }
}

gib(const Float:f_v_Origin[3])
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, f_v_Origin, 0);
    write_byte(TE_BREAKMODEL);

    engfunc(EngFunc_WriteCoord, f_v_Origin[0]);
    engfunc(EngFunc_WriteCoord, f_v_Origin[1]);
    engfunc(EngFunc_WriteCoord, f_v_Origin[2]);

    write_coord(32);
    write_coord(32);
    write_coord(32);

    write_coord(0);
    write_coord(0);
    write_coord(15);

    write_byte(20);

    write_short(g_Flesh_gibs);

    write_byte(8);
    write_byte(30);
    const BREAK_FLESH   =    0x04;
    write_byte(BREAK_FLESH);
    message_end();
}
