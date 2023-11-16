/* Sublime AMXX Editor v2.2 */

#if defined _NPC_LIBRARY
    #endinput
#endif
#define _NPC_LIBRARY

#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <xs>

enum any:NPC_ACTIVITY (+=1) {
    ACT_INVALID = -1,
    ACT_RESET,      // Set m_Activity to this invalid value to force a reset to m_IdealActivity
    ACT_IDLE,
    ACT_GUARD,
    ACT_WALK,
    ACT_RUN,
    ACT_FLY,                // Fly (and flap if appropriate)
    ACT_SWIM,
    ACT_HOP,                // vertical jump
    ACT_LEAP,               // long forward jump
    ACT_FALL,
    ACT_LAND,
    ACT_STRAFE_LEFT,
    ACT_STRAFE_RIGHT,
    ACT_ROLL_LEFT,          // tuck and roll, left
    ACT_ROLL_RIGHT,         // tuck and roll, right
    ACT_TURN_LEFT,          // turn quickly left (stationary)
    ACT_TURN_RIGHT,         // turn quickly right (stationary)
    ACT_CROUCH,             // the act of crouching down from a standing position
    ACT_CROUCHIDLE,         // holding body in crouched position (loops)
    ACT_STAND,              // the act of standing from a crouched position
    ACT_USE,
    ACT_SIGNAL1,
    ACT_SIGNAL2,
    ACT_SIGNAL3,
    ACT_TWITCH,
    ACT_COWER,
    ACT_SMALL_FLINCH,
    ACT_BIG_FLINCH,
    ACT_RANGE_ATTACK1,
    ACT_RANGE_ATTACK2,
    ACT_MELEE_ATTACK1,
    ACT_MELEE_ATTACK2,
    ACT_RELOAD,
    ACT_ARM,                // pull out gun, for instance
    ACT_DISARM,             // reholster gun
    ACT_EAT,                // monster chowing on a large food item (loop)
    ACT_DIESIMPLE,
    ACT_DIEBACKWARD,
    ACT_DIEFORWARD,
    ACT_DIEVIOLENT,
    ACT_BARNACLE_HIT,       // barnacle tongue hits a monster
    ACT_BARNACLE_PULL,      // barnacle is lifting the monster ( loop )
    ACT_BARNACLE_CHOMP,     // barnacle latches on to the monster
    ACT_BARNACLE_CHEW,      // barnacle is holding the monster in its mouth ( loop )
    ACT_SLEEP,
    ACT_INSPECT_FLOOR,      // for active idles, look at something on or near the floor
    ACT_INSPECT_WALL,       // for active idles, look at something directly ahead of you ( doesn't HAVE to be a wall or on a wall )
    ACT_IDLE_ANGRY,         // alternate idle animation in which the monster is clearly agitated. (loop)
    ACT_WALK_HURT,          // limp  (loop)
    ACT_RUN_HURT,           // limp  (loop)
    ACT_HOVER,              // Idle while in flight
    ACT_GLIDE,              // Fly (don't flap)
    ACT_FLY_LEFT,           // Turn left in flight
    ACT_FLY_RIGHT,          // Turn right in flight
    ACT_DETECT_SCENT,       // this means the monster smells a scent carried by the air
    ACT_SNIFF,              // this is the act of actually sniffing an item in front of the monster
    ACT_BITE,               // some large monsters can eat small things in one bite. This plays one time, EAT loops.
    ACT_THREAT_DISPLAY,     // without attacking, monster demonstrates that it is angry. (Yell, stick out chest, etc )
    ACT_FEAR_DISPLAY,       // monster just saw something that it is afraid of
    ACT_EXCITED,            // for some reason, monster is excited. Sees something he really likes to eat, or whatever.
    ACT_SPECIAL_ATTACK1,    // very monster specific special attacks.
    ACT_SPECIAL_ATTACK2,
    ACT_COMBAT_IDLE,        // agitated idle.
    ACT_WALK_SCARED,
    ACT_RUN_SCARED,
    ACT_VICTORY_DANCE,      // killed a player, do a victory dance.
    ACT_DIE_HEADSHOT,       // die, hit in head.
    ACT_DIE_CHESTSHOT,      // die, hit in chest
    ACT_DIE_GUTSHOT,        // die, hit in gut
    ACT_DIE_BACKSHOT,       // die, hit in back
    ACT_FLINCH_HEAD,
    ACT_FLINCH_CHEST,
    ACT_FLINCH_STOMACH,
    ACT_FLINCH_LEFTARM,
    ACT_FLINCH_RIGHTARM,
    ACT_FLINCH_LEFTLEG,
    ACT_FLINCH_RIGHTLEG,
    ACT_OTHER
} // Activity;

enum HitBoxGroup
{
    HITGROUP_GENERIC = 0,
    HITGROUP_HEAD,
    HITGROUP_CHEST,
    HITGROUP_STOMACH,
    HITGROUP_LEFTARM,
    HITGROUP_RIGHTARM,
    HITGROUP_LEFTLEG,
    HITGROUP_RIGHTLEG,
    HITGROUP_SHIELD,
    NUM_HITGROUPS,
};

enum any:NPC_EVENTS
{
    NPC_EVENT_TRACEATTACK,
    NPC_EVENT_TAKEDAMAGE,
    NPC_EVENT_DEATH
}

enum any:FUNCTION_DATA
{
    FUNC_NAME[32]
}

#define NPC_CLASSNAME "info_target"
#define PEV_IDENTITY pev_iuser4
#define PEV_NPC_SERIAL_KEY pev_playerclass
#define PEV_TASK pev_iuser3
#define PEV_PREVIOUS_TASK pev_euser2
#define PEV_ANIM_TASK pev_iuser1
#define PEV_OWNER pev_euser4
#define NPC_TARGET pev_euser1
#define PEV_NPC_3RDCAMERA_ENT pev_euser3
#define PEV_WEAPON_INFLICTOR pev_targetname
#define PEV_TELEPORTING_COOLDOWN pev_fuser4
#define PEV_TARGET_LAST_TIME_SEEN pev_fuser3
#define PEV_ANIMATION_COOLDOWN pev_fuser2
#define PEV_NPC_ACTION_DELAY pev_fuser1
#define PEV_ATTACK_DIRECTION pev_vuser1
#define PEV_TARGET_ANGLE_DIRECTION pev_vuser2
#define NPC_ID 85475
#define NPC_THINK_LEN 0.1
#define NPC_KILLSELF_THINK_LEN 5.0
#define TASK_NPC_DEATHMSG 11030

#if !defined IsPlayer
#define IsPlayer(%1) (1 <= %1 <= 32)
#endif

enum any:NPC_TASKS (+=1)
{
    NPC_IDLE = 0,
    NPC_FOLLOW_PLAYER,
    NPC_MANUAL_CONTROL,
    NPC_ATTACK,
    NPC_SEEK_TARGET,
    NPC_SEEK_DESTINATION,
    NPC_DEATH,
    NPC_KILLSELF
}

enum any:NPC_ABILITIES (<<= 1)
{
    NPC_ABILITY_FLOATING = 1,
    NPC_ABILITY_TELEPORT,
    NPC_ABILITY_JUMPER,
    NPC_ABILITY_SWIMMING,
    NPC_ABILITY_NO_BREATHING,
    NPC_ABILITY_NO_THIRST,
    NPC_ABILITY_NO_HUNGER
}

enum any:ANIMATION_DATA (+=1)
{
    ANIMATION_NAME[32] = 0,
    ANIMATION_SEQUENCE,
    ANIMATION_FRAMES,
    Float:ANIMATION_FPS,
    ANIMATION_FLAGS,
    NPC_ACTIVITY:ANIMATION_ACTIVITY,
    ANIMATION_ACTIVITY_WEIGHT,
    ANIMATION_EVENTS,
    ANIMATION_EVENT_ID,
    ANIMATION_EVENT_ARRAY
}

enum _:ANIMATION_EVENTS_DATA (+=1)
{
    EVENT_FRAMES,
    EVENT_NUMBER,
    EVENT_TYPE,
    EVENT_OPTION[64]
}

enum any:NPC_SIZES (+=1)
{
    HUMAN_SIZE,
    HUMAN_TEEN_SIZE,
    HUMAN_CHILD_SIZE,
    MONSTER_HEADCRAB_SIZE
}

enum any:DEATHMSG_DATA (+=1) {
    DEATHMSG_VICTIM_ID = 0,
    DEATHMSG_KILLER_ID,
    bool:DEATHMSG_bHEADSHOT,
    DEATHMSG_WEAPON_NAME[24],
    DEATHMSG_VIC_NAME[32],
    DEATHMSG_KILLER_NAME[32]
}

stock static Trie:g_trie_MDL_EVENTS;
stock static Trie:g_trie_CLASS_TRACEATTK_CALLBACK;
stock static Trie:g_trie_CLASS_TAKEDMG_CALLBACK;
stock static Trie:g_trie_NPC_CLASS_DEATH_CALLBACK;

stock NPC_FREE_HOOKS(const class[])
{
    if(g_trie_CLASS_TRACEATTK_CALLBACK != Invalid_Trie)
    {
        new xFuncID;
        TrieGetCell(g_trie_CLASS_TRACEATTK_CALLBACK, class, xFuncID);

        if(xFuncID != INVALID_HANDLE)
            DestroyForward(xFuncID);

        TrieDestroy(g_trie_CLASS_TRACEATTK_CALLBACK);
    }

    if(g_trie_CLASS_TAKEDMG_CALLBACK != Invalid_Trie)
    {
        new xFuncID;
        TrieGetCell(g_trie_CLASS_TAKEDMG_CALLBACK, class, xFuncID);

        if(xFuncID != INVALID_HANDLE)
            DestroyForward(xFuncID);

        TrieDestroy(g_trie_CLASS_TAKEDMG_CALLBACK);
    }

    if(g_trie_NPC_CLASS_DEATH_CALLBACK != Invalid_Trie)
    {
        new xFuncID;
        TrieGetCell(g_trie_NPC_CLASS_DEATH_CALLBACK, class, xFuncID);

        if(xFuncID != INVALID_HANDLE)
            DestroyForward(xFuncID);

        TrieDestroy(g_trie_NPC_CLASS_DEATH_CALLBACK);
    }
}

stock NPC_Hook_Event(const NPC_CUSTOM_CLASS[], const NPC_EVENTS:iEventType, const CallBackfunction[], const PluginID)
{
    static HamHook:iHookID[NPC_EVENTS];

    switch( iEventType )
    {
        case NPC_EVENT_TRACEATTACK:
        {
            if( g_trie_CLASS_TRACEATTK_CALLBACK == Invalid_Trie )
            {
                g_trie_CLASS_TRACEATTK_CALLBACK = TrieCreate();
            }

            if( !iHookID[NPC_EVENT_TRACEATTACK] )
            {
                iHookID[NPC_EVENT_TRACEATTACK] = RegisterHam(Ham_TraceAttack, NPC_CLASSNAME, "NPC_TRACEATTACK_POST", .Post=true);
            }

            TrieSetCell(g_trie_CLASS_TRACEATTK_CALLBACK, NPC_CUSTOM_CLASS,
                CreateOneForward(PluginID, CallBackfunction, FP_CELL, FP_CELL, FP_FLOAT, FP_ARRAY, FP_CELL, FP_CELL)
                );
        }
        case NPC_EVENT_TAKEDAMAGE:
        {
            if( g_trie_CLASS_TAKEDMG_CALLBACK == Invalid_Trie )
            {
                g_trie_CLASS_TAKEDMG_CALLBACK = TrieCreate();
            }

            if( !iHookID[NPC_EVENT_TAKEDAMAGE] )
            {
                iHookID[NPC_EVENT_TAKEDAMAGE] = RegisterHam(Ham_TakeDamage, NPC_CLASSNAME, "NPC_TAKEDAMAGE_PRE", .Post=false);
            }

            TrieSetCell(g_trie_CLASS_TAKEDMG_CALLBACK, NPC_CUSTOM_CLASS,
                CreateOneForward(PluginID, CallBackfunction, FP_CELL, FP_CELL, FP_CELL, FP_FLOAT, FP_CELL)
                );
        }
        case NPC_EVENT_DEATH:
        {
            if( g_trie_NPC_CLASS_DEATH_CALLBACK == Invalid_Trie )
            {
                g_trie_NPC_CLASS_DEATH_CALLBACK = TrieCreate();
            }

            if( !iHookID[NPC_EVENT_TAKEDAMAGE] )
            {
                iHookID[NPC_EVENT_TAKEDAMAGE] = RegisterHam(Ham_TakeDamage, NPC_CLASSNAME, "NPC_TAKEDAMAGE_PRE", .Post=false);
            }

            if( !iHookID[NPC_EVENT_DEATH] )
            {
                iHookID[NPC_EVENT_DEATH] = RegisterHam(Ham_Killed, NPC_CLASSNAME, "NPC_ENTITY_KILLED_PRE", .Post=false);
            }

            TrieSetCell(g_trie_NPC_CLASS_DEATH_CALLBACK, NPC_CUSTOM_CLASS,
                CreateOneForward(PluginID, CallBackfunction, FP_CELL, FP_CELL, FP_CELL)
                );
        }
    }
}

public NPC_TRACEATTACK_POST(id, attacker, Float:fDamage, const Float:fDirection[3], trace_handle, damagebits)
{
    if( !pev_valid(id)                  ||
        pev(id, PEV_NPC_SERIAL_KEY) != NPC_ID ) return;

    set_pev(id, PEV_ATTACK_DIRECTION, fDirection);

    static szClass[32];
    pev(id, pev_classname, szClass, charsmax(szClass));
    if(g_trie_CLASS_TRACEATTK_CALLBACK == Invalid_Trie || !TrieKeyExists(g_trie_CLASS_TRACEATTK_CALLBACK, szClass))
    {
        return;
    }

    static xFuncID, iReturnVal;
    TrieGetCell(g_trie_CLASS_TRACEATTK_CALLBACK, szClass, xFuncID);
    if( xFuncID != INVALID_HANDLE )
    {
        ExecuteForward(xFuncID, iReturnVal, id, attacker, fDamage, PrepareArray(any:fDirection, 3), trace_handle, damagebits);
    }

    return;
}

public NPC_TAKEDAMAGE_PRE(id, inflictor, attacker, Float:fDamage, damagebits)
{
    if( !pev_valid(id)                  ||
        pev(id, PEV_NPC_SERIAL_KEY) != NPC_ID ||
        entity_takedamage_type(id) == DAMAGE_NO) return HAM_IGNORED;

    static szClass[32], Float:fDirection[3], iOrigin[3], Float:fOrigin[3], Float:fMaxS[3], Float:fMinS[3];
    pev(id, pev_classname, szClass, charsmax(szClass));
    pev(id, pev_maxs, fMaxS);
    pev(id, pev_mins, fMinS);
    pev(id, pev_origin, fOrigin);
    xs_vec_sub(fMaxS, fMinS, fDirection);
    xs_vec_add(fDirection, fOrigin, fDirection);

    if( IsPlayer(inflictor) )
    {
        static iWeaponID;
        if((iWeaponID=get_user_weapon(inflictor)) > 0)
        {
            get_weaponname(iWeaponID, szClass, charsmax(szClass));
            format(szClass, charsmax(szClass), szClass[7]); // Gettimg rid of weapon_
        }

        get_user_origin(inflictor, iOrigin, Origin_CS_LastBullet);
        IVecFVec(iOrigin, fOrigin);
    }
    else if( inflictor )
    {
        pev(inflictor, pev_classname, szClass, charsmax(szClass));
        pev(inflictor, pev_origin, fOrigin);
    }
    else
    {
        copy(szClass, charsmax(szClass), "World");
        xs_vec_copy(fDirection, fOrigin);
    }

    xs_vec_sub(fOrigin, fDirection, fDirection);
    set_pev(id, PEV_ATTACK_DIRECTION, fDirection);

    set_pev(id, PEV_WEAPON_INFLICTOR, szClass);

    pev(id, pev_classname, szClass, charsmax(szClass));
    if(g_trie_CLASS_TAKEDMG_CALLBACK == Invalid_Trie || !TrieKeyExists(g_trie_CLASS_TAKEDMG_CALLBACK, szClass))
    {
        return HAM_IGNORED;
    }

    static xFuncID, iReturnVal;
    TrieGetCell(g_trie_CLASS_TAKEDMG_CALLBACK, szClass, xFuncID);
    if( xFuncID != INVALID_HANDLE )
    {
        ExecuteForward(xFuncID, iReturnVal, id, inflictor, attacker, fDamage, damagebits);
    }

    return HAM_IGNORED;
}

public NPC_ENTITY_KILLED_PRE(const id, const killer, const gibs)
{
    static szClass[32];
    pev(id, pev_classname, szClass, charsmax(szClass));

    if(g_trie_NPC_CLASS_DEATH_CALLBACK == Invalid_Trie || !TrieKeyExists(g_trie_NPC_CLASS_DEATH_CALLBACK, szClass))
    {
        return HAM_IGNORED;
    }

    set_pev(id, pev_deadflag, DEAD_DYING);
    set_pev(id, pev_takedamage, DAMAGE_NO);
    set_pev(id, pev_solid, SOLID_NOT);
    set_pev(id, PEV_TASK, NPC_DEATH);

    static xFuncID, iReturnVal;
    pev(id, pev_classname, szClass, charsmax(szClass));
    TrieGetCell(g_trie_NPC_CLASS_DEATH_CALLBACK, szClass, xFuncID);
    if( xFuncID != INVALID_HANDLE )
    {
        ExecuteForward(xFuncID, iReturnVal, id, killer, gibs);
    }

    // Lets call think
    set_pev(id, pev_nextthink, get_gametime() + NPC_THINK_LEN);
    call_think(id);

    return HAM_SUPERCEDE;
}

stock MDL_STUDIO_FREE_DATA(Array:retArrays[NPC_ACTIVITY], retSizeArrays[NPC_ACTIVITY])
{
    for(new NPC_ACTIVITY:i = ACT_IDLE; i <= ACT_OTHER; i++)
    {
        if(retSizeArrays[i] > 0)
        {
            ArrayDestroy(retArrays[i]);
            retSizeArrays[i] = 0;
        }
    }
}

stock MDL_STUDIO_DESTROY_HOOKS(const pModel)
{
    if(g_trie_MDL_EVENTS != Invalid_Trie)
    {
        new Array:tArray = Invalid_Array, sz_pModel[32];
        num_to_str(pModel, sz_pModel, charsmax(sz_pModel));
        TrieGetCell(g_trie_MDL_EVENTS, sz_pModel, tArray);

        if(tArray != Invalid_Array)
        {
            ArrayDestroy(tArray);
        }

        TrieDestroy(g_trie_MDL_EVENTS);
    }
}

stock MDL_STUDIO_HOOK_EVENT(const pModel, const FunctionCallback[])
{
    if( g_trie_MDL_EVENTS == Invalid_Trie )
    {
        g_trie_MDL_EVENTS = TrieCreate();
    }

    new Array:tArray = Invalid_Array, sz_pModel[32], iArray[FUNCTION_DATA];
    num_to_str(pModel, sz_pModel, charsmax(sz_pModel));
    TrieGetCell(g_trie_MDL_EVENTS, sz_pModel, tArray);

    if(tArray == Invalid_Array)
    {
        tArray = ArrayCreate(FUNCTION_DATA, 1);
        TrieSetCell(g_trie_MDL_EVENTS, sz_pModel, tArray);
    }

    if( tArray != Invalid_Array )
    {
        copy(iArray[FUNC_NAME], charsmax(iArray[FUNC_NAME]), FunctionCallback);
        ArrayPushArray(tArray, iArray);
        return ArraySize(tArray) - 1;
    }

    return -1;
}

stock MDL_STUDIO_LOAD_ANIMATIONS(const model[], Array:retArrays[NPC_ACTIVITY], retSizeArrays[NPC_ACTIVITY])
{
    new i, any:xArray[ANIMATION_DATA], any:iActivity;

    while( getSequenceData(model, i++, xArray) == 1 )
    {
        iActivity = NPC_ACTIVITY:xArray[ANIMATION_ACTIVITY];

        if(iActivity <= 0)
        {
            continue;
        }

        if(retArrays[iActivity] == Invalid_Array)
        {
            retArrays[iActivity] = ArrayCreate(ANIMATION_DATA, 1);
        }

        ArrayPushArray(retArrays[iActivity], xArray);
        retSizeArrays[iActivity] += 1;
    }

    return 0;
}

stock NPC_SPAWN( const class[], const name[], const szModel[],
                const Float:fOrigin[3], const Float:fViewOFS[3], const Float:fMaxSpeed, const Float:fMaxHealth,
                const owner=0, const task=NPC_IDLE, const NPC_MOVETYPE=MOVETYPE_PUSHSTEP,
                const Float:fMaxS[3]={1.0,1.0,1.0}, const Float:fMinS[3]={-1.0,-1.0,-1.0} )
{
    new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, NPC_CLASSNAME));

    if(!ent) return 0;

    set_pev(ent, pev_classname, class);
    set_pev(ent, pev_netname, name);
    set_pev(ent, pev_max_health, fMaxHealth);
    set_pev(ent, pev_health, fMaxHealth);
    set_pev(ent, pev_takedamage, DAMAGE_AIM);
    set_pev(ent, pev_solid, SOLID_SLIDEBOX);
    set_pev(ent, pev_movetype, NPC_MOVETYPE);
    set_pev(ent, pev_gravity, 1.0);
    set_pev(ent, pev_friction, 0.0);
    set_pev(ent, pev_maxspeed, fMaxSpeed);
    set_pev(ent, PEV_NPC_ACTION_DELAY, -1.0);
    set_pev(ent, NPC_TARGET, 0);
    set_pev(ent, PEV_NPC_SERIAL_KEY, NPC_ID);
    set_pev(ent, PEV_IDENTITY, NPC_ID);
    set_pev(ent, PEV_TARGET_LAST_TIME_SEEN, 0.0);
    set_pev(ent, PEV_PREVIOUS_TASK, task);
    set_pev(ent, PEV_TASK, task);
    set_pev(ent, PEV_OWNER, owner);
    set_pev(ent, pev_controller_0, 127);
    set_pev(ent, pev_controller_1, 127);
    set_pev(ent, pev_controller_2, 127);
    set_pev(ent, pev_controller_3, 127);
    set_pev(ent, pev_owner, owner);
    set_pev(ent, pev_flags, (FL_MONSTER|FL_ALWAYSTHINK));
    set_pev(ent, pev_deadflag, DEAD_NO);

    if( szModel[0] != EOS )
    {
        set_pev(ent, pev_modelindex, engfunc(EngFunc_ModelIndex, szModel));
        engfunc(EngFunc_SetModel, ent, szModel);
    }

    engfunc(EngFunc_SetSize, ent, fMinS, fMaxS);
    set_pev(ent, pev_view_ofs, fViewOFS );

    engfunc(EngFunc_SetOrigin, ent, fOrigin);

    set_pev(ent, pev_nextthink, get_gametime() + 0.1);

    return ent;
}

stock EFF_SPILL_BLOOD(const Float:fOrigin[3], const Float:fDirection[3], const pBloodSpraySprite, const pBleedSprite)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, fOrigin, 0);
    write_byte(TE_BLOOD);
    engfunc(EngFunc_WriteCoord, fOrigin[0]);
    engfunc(EngFunc_WriteCoord, fOrigin[1]);
    engfunc(EngFunc_WriteCoord, fOrigin[2]);
    engfunc(EngFunc_WriteCoord, fDirection[0]);
    engfunc(EngFunc_WriteCoord, fDirection[1]);
    engfunc(EngFunc_WriteCoord, fDirection[2]);
    write_byte(225);
    write_byte(20);
    message_end();

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, fOrigin, 0);
    write_byte(TE_BLOODSTREAM);
    engfunc(EngFunc_WriteCoord, fOrigin[0]);
    engfunc(EngFunc_WriteCoord, fOrigin[1]);
    engfunc(EngFunc_WriteCoord, fOrigin[2]);
    engfunc(EngFunc_WriteCoord, fDirection[0] + random_float(-3.0,3.0));
    engfunc(EngFunc_WriteCoord, fDirection[1] + random_float(-3.0,3.0));
    engfunc(EngFunc_WriteCoord, fDirection[2]);
    write_byte(225);
    write_byte(20);
    message_end();

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, fOrigin, 0);
    write_byte(TE_BLOODSPRITE);
    engfunc(EngFunc_WriteCoord, fOrigin[0]);
    engfunc(EngFunc_WriteCoord, fOrigin[1]);
    engfunc(EngFunc_WriteCoord, fOrigin[2]);
    write_short(pBloodSpraySprite);
    write_short(pBleedSprite);
    write_byte(247); // color index
    write_byte(random_num(15, 25)); // size
    message_end();
}

stock bool:IsEntityVisible(const Float:fPointView[3], Float:fPOVEndSight[3], const id, const ignore_ent, const bool:bClosestEndSight=false)
{
    static const Float:fShiftVector[][3] = {
        { 0.0, 0.0, 0.0 },  { 1.0, 0.0, 0.0 },  { 0.0, 1.0, 0.0 },
        { 0.0, 0.0, 1.0 },  { 1.0, 0.0, 1.0 },  { 0.0, 1.0, 1.0 },
        { 0.0, 0.0, -1.0 }, { 1.0, 0.0, -1.0 }, { 0.0, 1.0, -1.0 },
        { 0.0, 0.0, 0.8 },  { 1.0, 0.0, 0.8 },  { 0.0, 1.0, 0.8 },
        { 0.0, 0.0, -0.8 }, { 1.0, 0.0, -0.8 }, { 0.0, 1.0, -0.8 },
        { 0.0, 0.0, 0.6 },  { 1.0, 0.0, 0.6 },  { 0.0, 1.0, 0.6 },
        { 0.0, 0.0, -0.6 }, { 1.0, 0.0, -0.6 }, { 0.0, 1.0, -0.6 },
        { 0.0, 0.0, 0.4 },  { 1.0, 0.0, 0.4 },  { 0.0, 1.0, 0.4 },
        { 0.0, 0.0, -0.4 }, { 1.0, 0.0, -0.4 }, { 0.0, 1.0, -0.4 },
        { 0.0, 0.0, 0.2 },  { 1.0, 0.0, 0.2 },  { 0.0, 1.0, 0.2 },
        { 0.0, 0.0, -0.2 }, { 1.0, 0.0, -0.2 }, { 0.0, 1.0, -0.2 }
    }

    static tr2, Float:fEntOrigin[3], Float:fEndTrace[3], Float:fAngles[3], Float:fMaxS[3], Float:fMinS[3], pHit, Float:fHitPoint[3], bool:bVisible;
    tr2 = create_tr2();

    pev(id, pev_origin, fEntOrigin);
    pev(id, pev_maxs, fMaxS);
    pev(id, pev_mins, fMinS);
    xs_vec_sub(fEntOrigin, fPointView, fAngles);
    xs_vec_normalize(fAngles, fAngles);
    vector_to_angle(fAngles, fAngles);
    xs_vec_copy(fHitPoint, Float:{0.0, 0.0, 0.0});

    bVisible = false;
    fAngles[0] = 0.0;

    const iMaxShifting = sizeof fShiftVector;

    for(new i, Float:fDist, Float:fMaxDist = 9999.0; i < iMaxShifting; i++)
    {
        fEndTrace[0] = fEntOrigin[0] + floatcos(fAngles[1],degrees) * fShiftVector[i][0] * (fMaxS[0] - fMinS[0]) * 0.5;
        fEndTrace[1] = fEntOrigin[1] + floatsin(fAngles[1],degrees) * fShiftVector[i][1] * (fMaxS[1] - fMinS[1]) * 0.5;
        fEndTrace[2] = fEntOrigin[2] + fShiftVector[i][2] * (fMaxS[2] - fMinS[2]) * 0.5;

        engfunc(EngFunc_TraceLine, fPointView, fEndTrace, DONT_IGNORE_MONSTERS, ignore_ent, tr2);

        pHit = get_tr2(tr2, TR_pHit);

        if(pHit == id)
        {
            bVisible = true;

            if(bClosestEndSight != true)
            {
                fHitPoint[0] = fEndTrace[0];
                fHitPoint[1] = fEndTrace[1];
                fHitPoint[2] = fEndTrace[2];
                break;
            }

            get_tr2(tr2, TR_vecEndPos, fEndTrace);
            fDist = get_distance_f(fPointView, fEndTrace);

            if(fDist < fMaxDist)
            {
                fMaxDist = fDist;
                fHitPoint[0] = fEndTrace[0];
                fHitPoint[1] = fEndTrace[1];
                fHitPoint[2] = fEndTrace[2];
            }
        }
    }

    fPOVEndSight[0] = fHitPoint[0];
    fPOVEndSight[1] = fHitPoint[1];
    fPOVEndSight[2] = fHitPoint[2];

    free_tr2(tr2);

    return bVisible;
}

stock NPC_takedamage(id, victim, Float:fDamage=25.0, const damagetype=DMG_SLASH, const Float:fPunch[3], const szWeapon[] = "Claws", const bool:bHShot = false)
{
    if(IsPlayer(id))
    {
        return 0;
    }

    static Float:fHealth;
    pev(victim, pev_health, fHealth);
    if(pev(victim, pev_flags) & (FL_GODMODE|FL_KILLME) || pev(victim, pev_deadflag) != DEAD_NO || fHealth <= 0.0 || entity_takedamage_type(victim) == DAMAGE_NO) return 0;

    static iMsg_DeathMsg = 0, iOldValue; iMsg_DeathMsg = !iMsg_DeathMsg ? get_user_msgid("DeathMsg") : iMsg_DeathMsg;
    iOldValue = get_msg_block(iMsg_DeathMsg);
    set_msg_block(iMsg_DeathMsg, BLOCK_SET);

    if( ExecuteHamB(Ham_TakeDamage, victim, id, id, fDamage, damagetype) )
    {
        set_msg_block(iMsg_DeathMsg, iOldValue);

        if(IsPlayer(victim))
        {
            set_pev(victim, pev_punchangle, fPunch);
        }
    }
    else
    {
        set_msg_block(iMsg_DeathMsg, iOldValue);

        pev(victim, pev_health, fHealth);

        if( fHealth <= 0.0 )
        {
            Initiate_NPC_DEATHMSG(victim, id, bHShot, szWeapon);
        }
    }

    return 1;
}

stock NPC_MeleeAttack1( const id, const Float:fDamage, const Float:fDistance, const iBitsDamage )
{
    new Float:fOrigin[3], Float:fAngles[3], Float:fTraceAttackOrigin[3], Float:fViewOffset[3], Float:fOriginDest[3], Float:fTraceDist;
    pev(id, pev_origin, fOrigin);
    pev(id, PEV_TARGET_ANGLE_DIRECTION, fAngles);
    pev(id, pev_view_ofs, fViewOffset);
    xs_vec_add(fOrigin, fViewOffset, fTraceAttackOrigin);
    fTraceDist = fDistance;
    angle_vector(fAngles, ANGLEVECTOR_FORWARD, fOriginDest);

    xs_vec_mul_scalar(fOriginDest, fTraceDist, fOriginDest);
    xs_vec_add(fTraceAttackOrigin, fOriginDest, fOriginDest);

    new iHit = NPC_traceattack(id, fTraceAttackOrigin, fOriginDest, fTraceDist, .HullType=HULL_POINT);

    if( iHit > 0 && entity_takedamage_type(iHit) != DAMAGE_NO && (!pev(id, pev_team) || pev(iHit, pev_team) != pev(id, pev_team)) )
    {
        new Float:fPunch[3], Float:vNormal[3];
        pev(iHit, pev_angles, vNormal);
        angle_vector(vNormal, ANGLEVECTOR_FORWARD, vNormal);
        angle_vector(fAngles, ANGLEVECTOR_FORWARD, fPunch);
        xs_vec_reflect(fPunch, vNormal, fPunch);
        xs_vec_mul_scalar(fPunch, fDamage, fPunch);
        return NPC_takedamage(id, iHit, fDamage, iBitsDamage, fPunch);
    }
    return 0;
}

stock NPC_RangeAttack1( const id, Float:fAttackOFS[3], const Float:fDamage, const ProjectileClass[],const Float:fProjectileSpeed,
    const iBitsDamage, const szProjectileModel[]="", const Float:fProjectileSize[6] = {-1.0,-1.0,-1.0,1.0,1.0,1.0} )
{
    new Float:fTraceAttackOrigin[3], Float:fDirection[3], iProjectile, Float:fMaxS[3], Float:fMinS[3];
    pev(id, pev_origin, fTraceAttackOrigin);
    pev(id, PEV_TARGET_ANGLE_DIRECTION, fDirection);
    xs_vec_add(fTraceAttackOrigin, fAttackOFS, fTraceAttackOrigin);
    angle_vector(fDirection, ANGLEVECTOR_FORWARD, fDirection);
    xs_vec_set(fMinS, fProjectileSize[0], fProjectileSize[1], fProjectileSize[2]);
    xs_vec_set(fMaxS, fProjectileSize[3], fProjectileSize[4], fProjectileSize[5]);

    iProjectile = CreateProjectile( ProjectileClass, fTraceAttackOrigin, fProjectileSpeed, fDamage, iBitsDamage, id, szProjectileModel, fMaxS, fMinS );
    FireProjectile( iProjectile, fDirection, fProjectileSpeed );

    return iProjectile;
}

stock CreateProjectile( const szClass[], const Float:fStartOrigin[3], Float:fProjectileMaxSpeed,
    const Float:fDamage, const iBitsDamage, const owner=0, const szProjectileModel[]="",
    const Float:fMaxS[3]={1.0,1.0,1.0}, const Float:fMinS[3]={-1.0,-1.0,-1.0} )
{
    new bool:bMDLSprite = (contain(szProjectileModel, ".spr") != -1),
        ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, bMDLSprite ? "env_sprite" : "info_target"));

    if(!ent)
    {
        return 0;
    }

    set_pev(ent, pev_classname, szClass);
    set_pev(ent, pev_netname, szClass);
    set_pev(ent, pev_max_health, 1.0);
    set_pev(ent, pev_health, 1.0);
    set_pev(ent, pev_takedamage, DAMAGE_NO);
    set_pev(ent, pev_solid, SOLID_TRIGGER);
    set_pev(ent, pev_movetype, MOVETYPE_TOSS);
    set_pev(ent, pev_gravity, 1.0);
    set_pev(ent, pev_friction, 0.0);
    set_pev(ent, pev_maxspeed, fProjectileMaxSpeed);
    set_pev(ent, pev_owner, owner);
    set_pev(ent, PEV_OWNER, owner);
    set_pev(ent, pev_dmg, iBitsDamage);
    set_pev(ent, pev_dmg_save, fDamage);
    set_pev(ent, pev_flags, FL_ALWAYSTHINK);

    if(szProjectileModel[0] != EOS)
    {
        set_pev(ent, pev_model, szProjectileModel);

        if( !bMDLSprite )
        {
            engfunc(EngFunc_SetModel, ent, szProjectileModel);
        }
    }

    engfunc(EngFunc_SetOrigin, ent, fStartOrigin);

    if(bMDLSprite)
        {
            set_pev(ent, pev_scale, 1.0);
            set_pev(ent, pev_framerate, 1.0);
            set_pev(ent, pev_animtime, get_gametime());
            set_pev(ent, pev_spawnflags, SF_SPRITE_STARTON);
            dllfunc(DLLFunc_Spawn, ent);

            set_pev(ent, pev_solid, SOLID_TRIGGER);
            set_pev(ent, pev_movetype, MOVETYPE_TOSS);
            engfunc(EngFunc_SetSize, ent, fMinS, fMaxS);
        }
    else
    {
        engfunc(EngFunc_SetSize, ent, fMinS, fMaxS);
    }


    return ent;
}

stock FireProjectile( const ent, const Float:fDirection[3], const Float:fProjectileSpeed )
{
    new Float:fVelocity[3], Float:fProjectileMaxSpeed;
    pev(ent, pev_maxspeed, fProjectileMaxSpeed);
    xs_vec_mul_scalar(fDirection, floatmin(fProjectileSpeed, fProjectileMaxSpeed), fVelocity);
    set_pev(ent, pev_velocity, fVelocity);
}

stock NPC_traceattack(id, const Float:fStartOrigin[3], Float:fOriginDest[3], &Float:fTraceDistance=100.0,
    const bitFlags = DONT_IGNORE_MONSTERS, HullType=HULL_POINT, &Float:flRetFraction=-1.0)
{
    static Float:fvTemp[3], Float:fOrigin[3], Float:fvUP[3], Float:fvForward[3], Float:fvRight[3];
    xs_vec_copy(fStartOrigin, fOrigin);

    xs_vec_sub(fOriginDest, fOrigin, fvTemp);
    xs_vec_normalize(fvTemp, fvForward);

    xs_vec_mul_scalar(fvForward, fTraceDistance, fvTemp);
    xs_vec_add(fOrigin, fvTemp, fvTemp);

    static tr2, iHit, Float:flFraction, pHit, arrEntityIndex[32], arrEntityOldSolid[32], iEntCount = 0;
    tr2 = create_tr2(); pHit = 0;

    switch( HullType )
    {
        case HULL_POINT:
        {
            do
            {
                engfunc(EngFunc_TraceLine, fOrigin, fvTemp, bitFlags, id, tr2);

                if( (pHit = get_tr2(tr2, TR_pHit)) > 0 )
                {
                    if(entity_takedamage_type(pHit) != DAMAGE_NO)
                    {
                        break;
                    }
                    else if( iEntCount < 32 )
                    {
                        arrEntityIndex[ iEntCount ] = pHit;
                        arrEntityOldSolid[ iEntCount++ ] = pev(pHit, pev_solid);
                        set_pev(pHit, pev_solid, SOLID_NOT);
                    }
                    else
                    {
                        break;
                    }
                }
            }
            while ( pHit > 0 )

            if( iEntCount > 0 )
            {
                while( iEntCount > 0 )
                {
                    iEntCount--;
                    set_pev(arrEntityIndex[iEntCount], pev_solid, arrEntityOldSolid[iEntCount]);
                }
            }
        }
        case HULL_HUMAN:
        {
            engfunc(EngFunc_TraceHull, fOrigin, fvTemp, bitFlags, HullType, id, tr2);
        }
        default:
        {
            engfunc(EngFunc_TraceHull, fOrigin, fvTemp, bitFlags, HullType, id, tr2);
        }
    }

    get_tr2(tr2, TR_flFraction, flFraction);

    if(flFraction != 1.0)
    {
        if(HullType != HULL_POINT)
        {
            engfunc(EngFunc_TraceLine, fOrigin, fvTemp, bitFlags, id, tr2);
            get_tr2(tr2, TR_vecEndPos, fvTemp);
        }

        get_tr2(tr2, TR_vecPlaneNormal, fvUP);

        if( (fvUP[2] >= 0.7) )
        {
            // The cross product (aka vector product) will give us a vector, which is in essence our ANGLEVECTOR_RIGHT.
            xs_vec_cross(fvForward, fvUP, fvRight);
            xs_vec_normalize(fvRight, fvRight);
            // And this cross product will give us our new ANGLEVECTOR_FORWARD.
            xs_vec_cross(fvUP, fvRight, fvForward);
            xs_vec_normalize(fvForward, fvForward);
            xs_vec_mul_scalar(fvForward, fTraceDistance, fvForward);
            xs_vec_add(fOrigin, fvForward, fvForward);

            switch( HullType )
            {
                case HULL_POINT:
                {
                    engfunc(EngFunc_TraceLine, fOrigin, fvForward, bitFlags, id, tr2);
                }
                case HULL_HUMAN:
                {
                    engfunc(EngFunc_TraceHull, fOrigin, fvForward, bitFlags, HullType, id, tr2);
                }
                default:
                {
                    engfunc(EngFunc_TraceHull, fOrigin, fvForward, bitFlags, HullType, id, tr2);
                }
            }
        }
    }

    if(flRetFraction >= 0.0)
    {
        get_tr2(tr2, TR_flFraction, flRetFraction);
    }

    get_tr2(tr2, TR_vecEndPos, fOriginDest);

    if( pHit <= 0 )
    {
        iHit = get_tr2(tr2, TR_pHit);
    }
    else
    {
        iHit = pHit;
    }

    if(get_tr2(tr2, TR_InOpen) && !get_tr2(tr2, TR_StartSolid) && !get_tr2(tr2, TR_AllSolid))
    {
        fTraceDistance = get_distance_f(fOrigin, fOriginDest);

    }
    else
    {
        fTraceDistance = -1.0;
    }

    free_tr2(tr2);

    return iHit;
}

stock Float:NPC_animation(const iNPC, const Array:arrActivity[NPC_ACTIVITY], const arrSizeActivity[NPC_ACTIVITY])
{
    static Float:fHealth;
    pev(iNPC, pev_health, fHealth);

    if(entity_takedamage_type(iNPC) == DAMAGE_NO && (fHealth <= 0.0 || pev(iNPC, pev_deadflag) == DEAD_DYING))
    {
        static any:iActivity;
        iActivity = NPC_GetDeathActivity(iNPC, arrSizeActivity);

        if(arrSizeActivity[iActivity] > 0)
        {
            static any:xArray[ANIMATION_DATA];
            ArrayGetArray(arrActivity[iActivity], random(arrSizeActivity[iActivity]), xArray);
            PlayAnimation(iNPC, xArray[ANIMATION_SEQUENCE],
                xArray[ANIMATION_FPS], 1.0, xArray[ANIMATION_FRAMES], iActivity,
                .bInLOOP=false,
                .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                .pArrayEventSize=xArray[ANIMATION_EVENTS]);

            return ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS], 1.0) );
        }

        return 0.0;
    }

    static Float:fVelocity[3], Float:fSpeed, Float:fMaxSpeed, Float:fFrameRate = 1.0, iFlags;
    pev(iNPC, pev_velocity, fVelocity);
    pev(iNPC, pev_maxspeed, fMaxSpeed);
    fSpeed = floatmax(xs_vec_len(fVelocity), 1.0);
    fMaxSpeed = floatmax(fMaxSpeed, 1.0);
    iFlags = pev(iNPC, pev_flags);

    if(iFlags & FL_ONGROUND)
    {
        switch( floatround(xs_vec_len_2d(fVelocity)) )
        {
            case 0:
            {
                fFrameRate = 1.0;

                if(arrSizeActivity[ACT_CROUCHIDLE] > 0 && (iFlags & FL_DUCKING))
                {
                    static xArray[ANIMATION_DATA];
                    ArrayGetArray(Array:arrActivity[ACT_CROUCHIDLE], random(arrSizeActivity[ACT_CROUCHIDLE]), xArray);
                    PlayAnimation(iNPC, xArray[ANIMATION_SEQUENCE],
                        xArray[ANIMATION_FPS], fFrameRate, xArray[ANIMATION_FRAMES], ACT_CROUCHIDLE,
                        .bInLOOP=true,
                        .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                        .pArrayEventSize=xArray[ANIMATION_EVENTS]);

                    return ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS] * fFrameRate, 1.0) );
                }
                else if(arrSizeActivity[ACT_IDLE] > 0)
                {
                    static xArray[ANIMATION_DATA];
                    ArrayGetArray(Array:arrActivity[ACT_IDLE], random(arrSizeActivity[ACT_IDLE]), xArray);
                    PlayAnimation(iNPC, xArray[ANIMATION_SEQUENCE],
                        xArray[ANIMATION_FPS], fFrameRate, xArray[ANIMATION_FRAMES], ACT_IDLE,
                        .bInLOOP=true,
                        .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                        .pArrayEventSize=xArray[ANIMATION_EVENTS]);

                    return ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS] * fFrameRate, 1.0) );
                }
            }
            case 1..100:
            {
                fMaxSpeed = 100.0;
                fFrameRate = floatmax(fSpeed / fMaxSpeed, 1.0);

                if(arrSizeActivity[ACT_CROUCH] > 0 && (iFlags & FL_DUCKING))
                {
                    static xArray[ANIMATION_DATA];
                    ArrayGetArray(Array:arrActivity[ACT_CROUCH], random(arrSizeActivity[ACT_CROUCH]), xArray);
                    PlayAnimation(iNPC, xArray[ANIMATION_SEQUENCE],
                        xArray[ANIMATION_FPS], fFrameRate, xArray[ANIMATION_FRAMES], ACT_CROUCH,
                        .bInLOOP=true,
                        .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                        .pArrayEventSize=xArray[ANIMATION_EVENTS]);

                    return ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS] * fFrameRate, 1.0) );
                }
                else if(arrSizeActivity[ACT_WALK] > 0)
                {
                    static xArray[ANIMATION_DATA];
                    ArrayGetArray(Array:arrActivity[ACT_WALK], random(arrSizeActivity[ACT_WALK]), xArray);
                    PlayAnimation(iNPC, xArray[ANIMATION_SEQUENCE],
                        xArray[ANIMATION_FPS], fFrameRate, xArray[ANIMATION_FRAMES], ACT_WALK,
                        .bInLOOP=true,
                        .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                        .pArrayEventSize=xArray[ANIMATION_EVENTS]);

                    return ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS] * fFrameRate, 1.0) );
                }
                else if(arrSizeActivity[ACT_RUN] > 0)
                {
                    fMaxSpeed = 200.0;
                    fFrameRate = floatmax(fSpeed / fMaxSpeed, 1.0);
                    static xArray[ANIMATION_DATA];
                    ArrayGetArray(Array:arrActivity[ACT_RUN], random(arrSizeActivity[ACT_RUN]), xArray);
                    PlayAnimation(iNPC, xArray[ANIMATION_SEQUENCE],
                        xArray[ANIMATION_FPS], fFrameRate, xArray[ANIMATION_FRAMES], ACT_RUN,
                        .bInLOOP=true,
                        .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                        .pArrayEventSize=xArray[ANIMATION_EVENTS]);

                    return ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS] * fFrameRate, 1.0) );
                }
            }
            default:
            {
                fFrameRate = floatmax(fSpeed / fMaxSpeed, 1.0);

                if(arrSizeActivity[ACT_CROUCH] > 0 && (iFlags & FL_DUCKING))
                {
                    static xArray[ANIMATION_DATA];
                    ArrayGetArray(Array:arrActivity[ACT_CROUCH], random(arrSizeActivity[ACT_CROUCH]), xArray);
                    PlayAnimation(iNPC, xArray[ANIMATION_SEQUENCE],
                        xArray[ANIMATION_FPS], fFrameRate, xArray[ANIMATION_FRAMES], ACT_CROUCH,
                        .bInLOOP=true,
                        .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                        .pArrayEventSize=xArray[ANIMATION_EVENTS]);

                    return ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS] * fFrameRate, 1.0) );
                }
                else if(arrSizeActivity[ACT_RUN] > 0)
                {
                    static xArray[ANIMATION_DATA];
                    ArrayGetArray(Array:arrActivity[ACT_RUN], random(arrSizeActivity[ACT_RUN]), xArray);
                    PlayAnimation(iNPC, xArray[ANIMATION_SEQUENCE],
                        xArray[ANIMATION_FPS], fFrameRate, xArray[ANIMATION_FRAMES], ACT_RUN,
                        .bInLOOP=true,
                        .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                        .pArrayEventSize=xArray[ANIMATION_EVENTS]);

                    return ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS] * fFrameRate, 1.0) );
                }
                else if(arrSizeActivity[ACT_WALK] > 0)
                {
                    fMaxSpeed = 100.0;
                    fFrameRate = floatmax(fSpeed / fMaxSpeed, 1.0);

                    static xArray[ANIMATION_DATA];
                    ArrayGetArray(Array:arrActivity[ACT_WALK], random(arrSizeActivity[ACT_WALK]), xArray);
                    PlayAnimation(iNPC, xArray[ANIMATION_SEQUENCE],
                        xArray[ANIMATION_FPS], fFrameRate, xArray[ANIMATION_FRAMES], ACT_WALK,
                        .bInLOOP=true,
                        .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                        .pArrayEventSize=xArray[ANIMATION_EVENTS]);

                    return ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS] * fFrameRate, 1.0) );
                }
            }
        }
    }
    else if(fVelocity[2] >= 50.0)
    {
        if(arrSizeActivity[ACT_HOP] > 0)
        {
            fMaxSpeed = 100.0;
            fFrameRate = fSpeed / fMaxSpeed;

            static any:xArray[ANIMATION_DATA];
            ArrayGetArray(Array:arrActivity[ACT_HOP], random(arrSizeActivity[ACT_HOP]), xArray);
            PlayAnimation(iNPC, xArray[ANIMATION_SEQUENCE],
                xArray[ANIMATION_FPS], fFrameRate, xArray[ANIMATION_FRAMES], ACT_HOP,
                .bInLOOP=true,
                .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                .pArrayEventSize=xArray[ANIMATION_EVENTS]);

            return ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS] * fFrameRate, 1.0) );
        }
    }

    return 0.0;
}

// GetDeathActivity - determines the best type of death
// anim to play.
stock NPC_ACTIVITY:NPC_GetDeathActivity(const iNPC, const arrSizeActivity[NPC_ACTIVITY])
{
    new NPC_ACTIVITY:deathActivity,
        bool:bTriedDirection,
        Float:flDot,
        Float:vecSrc[3],
        Float:fvForward[3],
        Float:fAngles[3],
        tr;

    pev(iNPC, pev_angles, fAngles);
    pev(iNPC, pev_origin, vecSrc);
    angle_vector(fAngles, ANGLEVECTOR_FORWARD, fvForward);

    if (pev(iNPC, pev_deadflag) != DEAD_DYING)
    {
        // don't run this while dying.
        return get_ent_data(iNPC, "CBaseMonster", "m_IdealActivity");
    }

    bTriedDirection = false;

    // in case we can't find any special deaths to do.
    deathActivity = ACT_DIESIMPLE;

    new Float:fMaxS[3], Float:fMinS[3], Float:fVector[3], Float:vecDest[3], Float:fvAttackDirection[3];
    pev(iNPC, pev_maxs, fMaxS);
    pev(iNPC, pev_mins, fMinS);
    pev(iNPC, PEV_ATTACK_DIRECTION, fvAttackDirection);
    xs_vec_sub(fMaxS, fMinS, fVector);
    xs_vec_mul_scalar(fVector, 0.5, fVector);
    vecSrc[2] += xs_vec_len_2d(fVector);
    xs_vec_neg(fvAttackDirection, fvAttackDirection);
    flDot = xs_vec_dot(fvForward, fvAttackDirection);
    xs_vec_mul_scalar(fvForward, (fMaxS[2] - fMinS[2]), fvForward);

    switch (get_ent_data(iNPC, "CBaseMonster", "m_LastHitGroup"))
    {
        case HITGROUP_HEAD:
        {
            // try to pick a region-specific death.
            deathActivity = ACT_DIE_HEADSHOT;
        }
        case HITGROUP_STOMACH:
        {
            deathActivity = ACT_DIE_GUTSHOT;
        }
        case HITGROUP_GENERIC:
        {
            // try to pick a death based on attack direction
            bTriedDirection = true;

            if (flDot > 0.3)
            {
                deathActivity = ACT_DIEFORWARD;
            }
            else if (flDot <= -0.3)
            {
                deathActivity = ACT_DIEBACKWARD;
            }
        }
        default:
        {
            // try to pick a death based on attack direction
            bTriedDirection = true;

            if (flDot > 0.3)
            {
                deathActivity = ACT_DIEFORWARD;
            }
            else if (flDot <= -0.3)
            {
                deathActivity = ACT_DIEBACKWARD;
            }
        }
    }

    // can we perform the prescribed death?
    if (NPC_LOOKUP_ACTIVITY(deathActivity, arrSizeActivity) == ACT_INVALID)
    {
        // no! did we fail to perform a directional death?
        if (bTriedDirection)
        {
            // if yes, we're out of options. Go simple.
            deathActivity = ACT_DIESIMPLE;
        }
        else
        {
            // cannot perform the ideal region-specific death, so try a direction.
            if (flDot > 0.3)
            {
                deathActivity = ACT_DIEFORWARD;
            }
            else if (flDot <= -0.3)
            {
                deathActivity = ACT_DIEBACKWARD;
            }
        }
    }

    if (NPC_LOOKUP_ACTIVITY(deathActivity, arrSizeActivity) == ACT_INVALID)
    {
        // if we're still invalid, simple is our only option.
        deathActivity = ACT_DIESIMPLE;
    }
    else if (deathActivity == ACT_DIEFORWARD)
    {
        tr = create_tr2();

        // make sure there's room to fall forward
        xs_vec_add(vecSrc, fvForward, vecDest);
        engfunc(EngFunc_TraceHull, vecSrc, vecDest, DONT_IGNORE_MONSTERS, HULL_HEAD, iNPC, tr);

        new Float:flFraction;
        get_tr2(tr, TR_flFraction, flFraction);

        if (flFraction != 1.0)
        {
            deathActivity = ACT_DIESIMPLE;
        }

        free_tr2(tr);
    }
    else if (deathActivity == ACT_DIEBACKWARD)
    {
        tr = create_tr2();

        // make sure there's room to fall backward
        xs_vec_sub(vecSrc, fvForward, vecDest);
        engfunc(EngFunc_TraceHull, vecSrc, vecDest, DONT_IGNORE_MONSTERS, HULL_HEAD, iNPC, tr);

        new Float:flFraction;
        get_tr2(tr, TR_flFraction, flFraction);

        if (flFraction != 1.0)
        {
            deathActivity = ACT_DIESIMPLE;
        }

        free_tr2(tr);
    }

    return deathActivity;
}

stock NPC_ACTIVITY:NPC_LOOKUP_ACTIVITY(const NPC_ACTIVITY:iActivity, const arrSizeActivity[NPC_ACTIVITY])
{
    if(iActivity > ACT_RESET && iActivity <= ACT_OTHER)
    {
        if(arrSizeActivity[iActivity] > 0)
            return iActivity;
    }
    return ACT_INVALID;
}

stock bool:NPC_NearPlayer(const iPlayer, const iNPC, const Float:fDistance=300.0)
{
    static Float:fOrigin[3], Float:fOrigin2[3];
    pev(iPlayer, pev_origin, fOrigin);
    pev(iNPC, pev_origin, fOrigin2);

    if(get_distance_f(fOrigin, fOrigin2) <= fDistance)
    {
        return true;
    }

    return false;
}

stock NPC_NearestPlayerTarget(const iNPC)
{
    static players[MAX_PLAYERS], pnum, xnum, i, next;
    get_players(players, pnum, "ah");

    for( i = xnum = 0; i < pnum; i++ )
    {
        next = engfunc(EngFunc_EntitiesInPVS, players[ i ]);

        while( next )
        {
            if(next <= iNPC)
            {
                if( iNPC == next )
                {
                    players[ xnum++ ] = players[ i ];
                }

                break;
            }

            next = pev(next, pev_chain);
        }
    }

    if( xnum <= 1 )
    {
        return xnum ? players[ 0 ] : 0 ;
    }

    static Float:fOrigin[3], Float:fTargetOrigin[3], Float:flDist, Float:fChosenDist, iTarget;
    pev(iNPC, pev_origin, fOrigin);

    for( i = iTarget = 0, flDist = 9999.0; i < xnum; i++ )
    {
        pev(players[ i ], pev_origin, fTargetOrigin);
        fChosenDist = get_distance_f(fTargetOrigin, fOrigin);

        if(flDist > fChosenDist)
        {
            flDist = fChosenDist;
            iTarget = players[ i ];
        }
    }

    return iTarget;
}

stock NPC_Pathfinding(iNPC, const Float:fStartOrigin[3], const Float:fEndOrigin[3])
{
    new Float:fOrigin[3], Float:fDirection[3], Float:fAngles[3], Float:fDistance2D;
    pev(iNPC, pev_origin, fOrigin);

    xs_vec_sub(fOrigin, fEndOrigin, fDirection);
    xs_vec_normalize(fDirection, fDirection);
    vector_to_angle(fDirection, fAngles);

    fDistance2D = xs_vec_distance_2d(fStartOrigin, fEndOrigin);

    static Float:fTraceDirections[] = { -90.0, -45.0, 0.0, 45.0, 90.0 };

    for(new iNode; iNode < iMaxNodes; iNode++)
    {
        for(new i, fYaw = fAngles[1]; i < 5; i++)
        {
            fAngles[1] = fYaw + fTraceDirections[i];
            angle_vector(fAngles, ANGLEVECTOR_FORWARD, fDirection);
            xs_vec_mul_scalar(fDirection, 9999.0, fDirection);
            xs_vec_add(fOrigin, fDirection, fDirection);
            engfunc(EngFunc_TraceHull, fStartOrigin, fDirection, bitFlags, HullType, id, iTr2);

            engfunc(EngFunc_TraceLine, fDirection, fEndOrigin, IGNORE_MONSTERS, -1, iTr2);

            if( get_tr2(iTr2, TR_flFraction) >= 1.0 )
            {

            }
        }
    }
}

stock LookAtOrigin(const id, const Float:fOrigin_dest[3])
{
    static Float:fOrigin[3], Float:fViewOFS[3];
    pev(id, pev_origin, fOrigin);
    pev(id, pev_view_ofs, fViewOFS);
    xs_vec_add(fOrigin, fViewOFS, fOrigin);

    // Dest is in the Center
    if( fOrigin[0] == fOrigin_dest[0] && fOrigin[1] == fOrigin_dest[1] )
    {
        return;
    }

    static Float:fLook[3];
    xs_vec_sub(fOrigin_dest, fOrigin, fOrigin);
    xs_vec_normalize(fOrigin, fOrigin);
    vector_to_angle(fOrigin, fViewOFS);
    fViewOFS[0] *= -1.0;
    xs_vec_copy(fViewOFS, fLook);
    fLook[0] = 0.0;

    set_pev(id, pev_angles, fLook);
    set_pev(id, pev_idealpitch, fLook[0]);
    set_pev(id, pev_ideal_yaw, fLook[1]);
    set_pev(id, PEV_TARGET_ANGLE_DIRECTION, fViewOFS);
    set_pev(id, pev_fixangle, 1);
}


stock Float:MoveToOrigin(const id, const Float:fOrigin_dest[3], const Float:fSpeed=250.0, const Float:fJumpSpeed=350.0, Float:fRetVelocity[3]={0.0,0.0,0.0})
{
    static Float:fOrigin[3];
    pev(id, pev_origin, fOrigin);

    static Float:fDistance, Float:fAngle[3], Float:fDestination[3], Float:fMAX_SIZE[3], Float:fMIN_SIZE[3];
    pev(id, pev_maxs, fMAX_SIZE);
    pev(id, pev_mins, fMIN_SIZE);
    fDistance = get_distance_f(fOrigin, fOrigin_dest);
    pev(id, pev_angles, fAngle);

    fDestination[0] = ((fMAX_SIZE[0] - fMIN_SIZE[0]) * 0.5) * floatcos(fAngle[1],degrees);
    fDestination[1] = ((fMAX_SIZE[1] - fMIN_SIZE[1]) * 0.5) * floatsin(fAngle[1],degrees);
    fDestination[2] = ((fMAX_SIZE[2] - fMIN_SIZE[2]) * 0.5);

    if(fDistance <= xs_vec_len(fDestination))
    {
        return 0.0;
    }
    
    static Float:fDistance2D;
    xs_vec_set(fDestination, fOrigin_dest[0], fOrigin_dest[1], fOrigin_dest[2]);
    
    static Float:fVelocity[3], Float:fDirection[3], Float:fVector[3], iHit;
    xs_vec_sub(fDestination, fOrigin, fVector);
    fDistance2D = xs_vec_len_2d(fVector);


    pev(id, pev_velocity, fVelocity);
    xs_vec_normalize(fVector, fDirection);
    vector_to_angle(fDirection, fAngle);

    if(fJumpSpeed > 0.0 && fVector[2] >= fJumpSpeed && (pev(id, pev_flags) & FL_ONGROUND))
    {
        fVelocity[2] = fDirection[2] * fJumpSpeed;
    }

    if(fDistance2D != 0.0)
    {
        fVelocity[0] = fDirection[0] * fSpeed;
        fVelocity[1] = fDirection[1] * fSpeed;
    }

    static Float:fTraceDest[3], Float:flFraction = 0.0;
    xs_vec_set(fTraceDest, fOrigin_dest[0], fOrigin_dest[1], fOrigin[2]);
    iHit = NPC_traceattack(id, fOrigin, fTraceDest, fDistance, .bitFlags=DONT_IGNORE_MONSTERS, .HullType=HULL_POINT, .flRetFraction=flFraction);

    // Jumping over an obstacle !
    // engfunc(EngFunc_WalkMove /* Target, Yaw Angle, fDistance Trace, MOVETYPE */
    if( engfunc(EngFunc_WalkMove, id, fAngle[1], 1.0, WALKMOVE_NORMAL) <= 0
        && flFraction != 1.0 && (iHit <= 0 || (entity_takedamage_type(iHit) == DAMAGE_NO))
    ) // Is NPC STUCK?
    {
        // Can Jump?
        static iTr2;
        iTr2 = create_tr2();

        xs_vec_copy(fOrigin, fDestination);
        fDestination[0] += fSpeed * fDirection[0];
        fDestination[1] += fSpeed * fDirection[1];
        fDestination[2] += fJumpSpeed;
        fOrigin[2] += fJumpSpeed;

        engfunc(EngFunc_TraceLine, fOrigin, fDestination, DONT_IGNORE_MONSTERS, id, iTr2);

        get_tr2(iTr2, TR_flFraction, flFraction);

        if(get_tr2(iTr2, TR_pHit) <= 0 && flFraction == 1.0)
        {
            if(pev(id, pev_flags) & FL_ONGROUND)
            {
                fVelocity[2] =  fJumpSpeed;
            }
        }

        free_tr2(iTr2);
    }

    if(xs_vec_len_2d(fVelocity) > fSpeed)
    {
        static Float:fLen;
        fLen = xs_rsqrt(fVelocity[0] * fVelocity[0] + fVelocity[1] * fVelocity[1]);
        fVelocity[0] = (fVelocity[0] * fLen) * fSpeed;
        fVelocity[1] = (fVelocity[1] * fLen) * fSpeed;
    }

    xs_vec_copy(fVelocity, fRetVelocity);
    engfunc(EngFunc_MoveToOrigin, id, fOrigin_dest, 1.0, MOVE_NORMAL);
    set_pev(id, pev_velocity, fVelocity);

    static Float:fConsumedTime;
    fConsumedTime = floatdiv(fDistance, floatmax(xs_vec_len_2d(fVelocity), 1.0));
    return fConsumedTime;
}

stock floor_origin(const Float:fOrigin[3], Float:fFloorOrigin[3])
{
    static iTL;
    iTL = create_tr2();
    
    static Float:flStart[3], Float:flDest[3];
    xs_vec_copy(fOrigin, flStart);
    flDest[0] = flStart[0];
    flDest[1] = flStart[1];
    flDest[2] = -1000.0;
    
    // maximum solid entities count that will be under an entity?
    const iMaxEntitiesBelow = 40;

    static aSolidsPlayerIndex[iMaxEntitiesBelow], aSolids[iMaxEntitiesBelow], iSolids_c = 0;
    
    new bool:bKeepGoing = true, target;
    while ( bKeepGoing )
    {
        engfunc(EngFunc_TraceLine, flStart, flDest, IGNORE_MONSTERS, -1, iTL);
        target = get_tr2(iTL, TR_pHit);

        if(target == -1) // -1 is the world? ? ? ? ? ??
        {
            #if defined DEBUG_FOLLOWING
            client_print(0, print_chat, "finally we found the ground!");
            #endif
            bKeepGoing = false;
        }
        else if( target > 0 )
        {
            if(pev(target, pev_solid) == SOLID_BSP)
            {
                bKeepGoing = false;
                break;
            }

            #if defined DEBUG_FOLLOWING
            client_print(0, print_chat, "ignoring entity #id %d", target);
            #endif

            // we hit a player or an entity.
            if( iSolids_c == sizeof aSolids )
            {
                #if defined DEBUG_FOLLOWING
                client_print(0, print_chat, "iSolids_c has reached its maximum value!");
                #endif
                bKeepGoing = false;
            }

            if( pev_valid(target) )
            {
                aSolidsPlayerIndex[iSolids_c] = target;
                aSolids[iSolids_c] = pev(target, pev_solid);
                iSolids_c ++;
                set_pev(target, pev_solid, SOLID_NOT);
            }
        }
        else if(!get_tr2(iTL, TR_StartSolid) || !get_tr2(iTL, TR_AllSolid) || bool:get_tr2(iTL, TR_InOpen))
        {
            #if defined DEBUG_FOLLOWING
            client_print(0, print_chat, "lets try to get out...!!! ( %d %d %d )", get_tr2(iTL, TR_StartSolid), get_tr2(iTL, TR_AllSolid), get_tr2(iTL, TR_InOpen));
            #endif
            flStart[2] += 10.0; //lets try to get out...!!!
        }

        #if defined DEBUG_FOLLOWING
        beam_bet_2origin(flStart, fFloorOrigin)
        #endif
    }
    
    get_tr2(iTL, TR_vecEndPos, fFloorOrigin);

    free_tr2(iTL);
    
    if(iSolids_c > 0)
    {
        for(new i; i < iSolids_c; i++)
        {
            set_pev(aSolidsPlayerIndex[i], pev_solid, aSolids[i]);
        }
    }
    
    iSolids_c = 0;
}

stock PlayAnimation(const id, const iSeq=0, Float:fFPS, Float:fFrameRate, const iMaxFrames, const NPC_ACTIVITY:ACT_TYPE=ACT_INVALID, const Float:fDelay=0.0, bool:bInLOOP=false, const Array:pArrayEvent=Invalid_Array, const pArrayEventSize=0)
{
    if(fFPS <= 0.0)
    {
        fFPS = 1.0;
    }

    if(fFrameRate <= 0.0)
    {
        fFrameRate = 1.0;
    }

    static Float:fAnimLength, Float:fGametime;
    pev(id, PEV_ANIMATION_COOLDOWN, fAnimLength);
    fGametime = get_gametime();
    
    if(NPC_ACTIVITY:pev(id, PEV_ANIM_TASK) == ACT_TYPE)
    {
        if(fAnimLength > fGametime) return;
    }
    
    if(NPC_ACTIVITY:pev(id, PEV_ANIM_TASK) != ACT_TYPE || ACT_TYPE == ACT_INVALID || !bInLOOP)
    {
        set_pev(id, pev_sequence, iSeq);
        set_pev(id, pev_gaitsequence, iSeq);
        set_pev(id, pev_animtime, fGametime + fDelay);
        set_pev(id, pev_framerate, fFrameRate);
        
        set_pev(id, PEV_ANIMATION_COOLDOWN, fGametime + (iMaxFrames / (fFPS * fFrameRate)));
        set_pev(id, PEV_ANIM_TASK, ACT_TYPE);

        if( g_trie_MDL_EVENTS != Invalid_Trie && pArrayEvent != Invalid_Array )
        {
            // Lets Remove old tasks !!!
            remove_task(id);

            static sz_pModel[32], pModel, Array:tArray;
            pModel = pev(id, pev_modelindex);
            num_to_str(pModel, sz_pModel, charsmax(sz_pModel));
            TrieGetCell(g_trie_MDL_EVENTS, sz_pModel, tArray);

            if(tArray != Invalid_Array)
            {
                static any:xArray[FUNCTION_DATA], eventArray[ANIMATION_EVENTS_DATA], iEvent, iItem;
                iItem = ArraySize(tArray);

                while( iItem-- > 0 )
                {
                    ArrayGetArray(tArray, iItem, xArray);

                    if(get_func_id(xArray[FUNC_NAME]) == INVALID_PLUGIN_ID)
                    {
                        continue;
                    }

                    iEvent = pArrayEventSize;

                    while( iEvent-- > 0 )
                    {
                        ArrayGetArray(pArrayEvent, iEvent, eventArray);
                        set_task( (eventArray[EVENT_FRAMES] / (fFPS * fFrameRate)), xArray[FUNC_NAME], id, eventArray, sizeof eventArray);

                        if( bInLOOP )
                        {
                            set_task( ((iMaxFrames + eventArray[EVENT_FRAMES]) / (fFPS * fFrameRate)), xArray[FUNC_NAME], id, eventArray, sizeof eventArray, .flags="b");
                        }
                    }
                }
            }
        }
    }
}

stock getSequenceData( const model[], const sequence, any:xArray[ANIMATION_DATA] )
{
    static sequencesNameCached, szCachedModel[64];
    static sequenceCount;
    static Array:arraySequencesName;
    
    if(!equal(szCachedModel, model))
    {
        sequencesNameCached = 0;
    }

    if( !sequencesNameCached )
    {
        copy(szCachedModel, charsmax(szCachedModel), model);

        new f = fopen( model, "rb" );
        
        if( f )
        {
            const studioHeader_NumSeq = 164;
            const mstudioseqdescSize  = 176;
            const sequenceNameLength  = 32;
        
            new sequenceIndex, tempArray[ANIMATION_DATA], EventArray[ANIMATION_EVENTS_DATA];
            
            fseek( f, studioHeader_NumSeq, SEEK_SET );
            {
                fread( f, sequenceCount, BLOCK_INT );
                fread( f, sequenceIndex, BLOCK_INT );
            }
            fseek( f, sequenceIndex, SEEK_SET );
        
            arraySequencesName = ArrayCreate( ANIMATION_DATA, sequenceCount );
            
            for( new i = 0, j, numframes, fileLine, Float:fps, seqflags, NPC_ACTIVITY:iActivity, iACTweight, numEvents, EventIndex; i < sequenceCount; i++ )
            {
                fread_blocks( f, tempArray[ANIMATION_NAME], sequenceNameLength, BLOCK_CHAR );
                
                fread(f, _:fps            , BLOCK_INT);
                fread(f, seqflags         , BLOCK_INT);
                fread(f, iActivity        , BLOCK_INT);
                fread(f, iACTweight       , BLOCK_INT);
                fread(f, numEvents        , BLOCK_INT);
                fread(f, EventIndex       , BLOCK_INT);
                fread(f, numframes        , BLOCK_INT);

                tempArray[ANIMATION_FRAMES] = numframes;
                tempArray[ANIMATION_FPS] = floatmax(fps,1.0);
                tempArray[ANIMATION_FLAGS] = seqflags;
                tempArray[ANIMATION_ACTIVITY] = iActivity;
                tempArray[ANIMATION_ACTIVITY_WEIGHT] = iACTweight;
                tempArray[ANIMATION_EVENTS] = numEvents;
                tempArray[ANIMATION_EVENT_ID] = EventIndex;
                tempArray[ANIMATION_EVENT_ARRAY] = _:Invalid_Array;
                
                if( numEvents > 0 )
                {
                    fileLine = ftell(f);

                    fseek( f, EventIndex, SEEK_SET );
                    tempArray[ANIMATION_EVENT_ARRAY] = _:ArrayCreate(ANIMATION_EVENTS_DATA, 1);

                    for( j = 0; j < numEvents; j++ )
                    {
                        fread(f, EventArray[EVENT_FRAMES]      , BLOCK_INT);
                        fread(f, EventArray[EVENT_NUMBER]      , BLOCK_INT);
                        fread(f, EventArray[EVENT_TYPE]        , BLOCK_INT);
                        fread_blocks(f, EventArray[EVENT_OPTION], sequenceNameLength * 2, BLOCK_CHAR );

                        //log_to_file("test_read2.txt", "Seq #%d Event #%d EVENT FRAMES: %d EVENT NUM: %d EVENT TYPE: %d EVENT EVENT_OPTION: %s", i, j, EventArray[EVENT_FRAMES], EventArray[EVENT_NUMBER], EventArray[EVENT_TYPE], EventArray[EVENT_OPTION]);
                        ArrayPushArray( Array:tempArray[ANIMATION_EVENT_ARRAY], EventArray );
                    }

                    fseek(f, fileLine + (mstudioseqdescSize - 60), SEEK_SET );
                }
                else
                {
                    fseek(f, mstudioseqdescSize - 60, SEEK_CUR );
                }
                
                tempArray[ANIMATION_SEQUENCE] = i;
                //log_to_file("test_read.txt", "AnimName: %s Sequence: %d/%d Frames: %d FPS: %.2f ACTION: %d EVENTS: %d", tempArray[ANIMATION_NAME], i, sequenceCount, numframes, fps, iActivity, numEvents);
                ArrayPushArray( arraySequencesName, tempArray );
            }


                
            fclose( f );
            
            if( Array:tempArray[ANIMATION_EVENT_ARRAY] != Invalid_Array && !ArraySize(Array:tempArray[ANIMATION_EVENT_ARRAY]) )
            {
                ArrayDestroy( Array:tempArray[ANIMATION_EVENT_ARRAY] );
            }

            if( !( sequencesNameCached = !!ArraySize( arraySequencesName ) ) )
            {
                ArrayDestroy( arraySequencesName );
                return 0;
            }
        }
    }
    
    if( sequencesNameCached && (0 <= sequence < sequenceCount) )
    {
        ArrayGetArray(arraySequencesName, sequence, _:xArray)
        return 1;
    }
    
    return 0;
}

// I'm stuck step bro help me!
stock bool:ObjectStuck(const Float:fOrigin[3], const Float:fMaxs[3], const Float:fMins[3])
{
    static Float:fPoint[3];
    xs_vec_add(fOrigin, fMaxs, fPoint);
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    xs_vec_add(fOrigin, fMins, fPoint);
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0] + fMaxs[0];
    fPoint[1] = fOrigin[1] + fMaxs[1];
    fPoint[2] = fOrigin[2] + fMins[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0] + fMaxs[0];
    fPoint[1] = fOrigin[1] + fMins[1];
    fPoint[2] = fOrigin[2] + fMins[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0] + fMaxs[0];
    fPoint[1] = fOrigin[1] + fMins[1];
    fPoint[2] = fOrigin[2] + fMaxs[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0] + fMins[0];
    fPoint[1] = fOrigin[1] + fMins[1];
    fPoint[2] = fOrigin[2] + fMaxs[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0] + fMins[0];
    fPoint[1] = fOrigin[1] + fMaxs[1];
    fPoint[2] = fOrigin[2] + fMins[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0] + fMins[0];
    fPoint[1] = fOrigin[1] + fMaxs[1];
    fPoint[2] = fOrigin[2] + fMaxs[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0] + fMaxs[0];
    fPoint[1] = fOrigin[1];
    fPoint[2] = fOrigin[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0];
    fPoint[1] = fOrigin[1] + fMaxs[1];
    fPoint[2] = fOrigin[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0];
    fPoint[1] = fOrigin[1];
    fPoint[2] = fOrigin[2] + fMaxs[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0] + fMins[0];
    fPoint[1] = fOrigin[1];
    fPoint[2] = fOrigin[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0];
    fPoint[1] = fOrigin[1] + fMins[1];
    fPoint[2] = fOrigin[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;
    
    fPoint[0] = fOrigin[0];
    fPoint[1] = fOrigin[1];
    fPoint[2] = fOrigin[2] + fMins[2];
    if(engfunc(EngFunc_PointContents, fPoint) != CONTENTS_EMPTY) return true;

    return false;
}

stock NPC_SIZE(const NPC_SIZES:iType, Float:fMaxs[3], Float:fMins[3])
{
    switch( iType )
    {
        case HUMAN_SIZE:
        {
            fMaxs[0] = 16.0
            fMaxs[1] = 16.0
            fMaxs[2] = 72.0;
        
            fMins[0] = -16.0;
            fMins[1] = -16.0;
            fMins[2] = 0.0;
        }
        case HUMAN_TEEN_SIZE:
        {
            fMaxs[0] = 10.0
            fMaxs[1] = 10.0
            fMaxs[2] = 52.0;

            fMins[0] = -10.0;
            fMins[1] = -10.0;
            fMins[2] = 0.0;
        }
        case HUMAN_CHILD_SIZE:
        {
            fMaxs[0] = 10.0
            fMaxs[1] = 10.0
            fMaxs[2] = 32.0;

            fMins[0] = -10.0;
            fMins[1] = -10.0;
            fMins[2] = 0.0;
        }
        case MONSTER_HEADCRAB_SIZE:
        {
            fMaxs[0] = 8.0
            fMaxs[1] = 8.0
            fMaxs[2] = 12.0;
            
            fMins[0] = -8.0;
            fMins[1] = -8.0;
            fMins[2] = 0.0;
        }
    }
    
    return 0;
}

stock find_sky(Float:fOrigin[3], const ignore_ent=-1)
{
    static iTr2, Float:flFraction, Float:fEnd[3]; iTr2 = create_tr2();

    fEnd[0] = fOrigin[0];
    fEnd[1] = fOrigin[1];
    fEnd[2] = 4096.0;

    while( true )
    {
        engfunc(EngFunc_TraceLine, fOrigin, fEnd, (IGNORE_MONSTERS|IGNORE_MISSILE|IGNORE_GLASS), ignore_ent, iTr2);
        get_tr2(iTr2, TR_vecEndPos, fEnd);
        get_tr2(iTr2, TR_Fraction, flFraction);

        fEnd[2] += 1.0;

        if(flFraction == 1.0)
        {
            free_tr2(iTr2);

            if(engfunc(EngFunc_PointContents, fOrigin) == CONTENTS_SKY)
            {
                return true;
            }

            if(engfunc(EngFunc_PointContents, fEnd) == CONTENTS_SKY)
            {
                xs_vec_copy(fEnd, fOrigin);
                return true;
            }

            return false;
        }

        if(engfunc(EngFunc_PointContents, fEnd) == CONTENTS_SKY)
        {
            xs_vec_copy(fEnd, fOrigin);
            free_tr2(iTr2);
            return true;
        }

        xs_vec_copy(fEnd, fOrigin);
        fEnd[2] = 4096.0;
    }

    free_tr2(iTr2);
    return false;
}

stock find_location_around_origin(Float:fOrigin[3], const Float:fMaxs[3], const Float:fMins[3], const Float:fDistance, const bool:bRandom=false, &Array:pArrayLocations = any:-1, const bInSight=true)
{
    fOrigin[2] += floatabs(fMins[2]);

    static iTr2, Float:fTestOrigin[3], Float:fStart[3], Float:fEnd[3], Float:fYShift, Float:fXShift, i, d, iSafe;

    static iOrder[][][3] =
    {
        { {  0,  0,  1 }, {  0,  0, -1 } }, // Inner line
        { {  1,  1,  1 }, {  1,  1, -1 } }, // 4 square lines SIDES
        { { -1, -1,  1 }, { -1, -1, -1 } },
        { { -1,  1,  1 }, { -1,  1, -1 } },
        { {  1, -1,  1 }, {  1, -1, -1 } },
        { {  1,  1,  1 }, { -1,  1,  1 } }, // 4 square lines TOP
        { {  1,  1,  1 }, {  1, -1,  1 } },
        { { -1, -1,  1 }, { -1,  1,  1 } },
        { { -1, -1,  1 }, {  1, -1,  1 } },
        { {  1,  1, -1 }, { -1,  1, -1 } }, // 4 square lines BOTTOM
        { {  1,  1, -1 }, {  1, -1, -1 } },
        { { -1, -1, -1 }, { -1,  1, -1 } },
        { { -1, -1, -1 }, {  1, -1, -1 } },
        { {  1,  1,  1 }, { -1,  1, -1 } }, // front cross
        { {  1,  1, -1 }, { -1,  1,  1 } },
        { {  1, -1,  1 }, { -1, -1, -1 } }, // back cross
        { {  1, -1, -1 }, { -1, -1,  1 } },
        { {  1,  1,  1 }, {  1, -1, -1 } }, // right cross
        { {  1,  1, -1 }, {  1, -1,  1 } },
        { { -1,  1,  1 }, { -1, -1, -1 } }, // left cross
        { { -1,  1, -1 }, { -1, -1,  1 } },
        { {  1,  1,  1 }, { -1, -1,  1 } }, // up cross
        { {  1, -1,  1 }, { -1,  1,  1 } },
        { {  1,  1, -1 }, { -1, -1, -1 } }, // down cross
        { {  1, -1, -1 }, { -1,  1, -1 } }
    };

    fXShift = (fMaxs[0] - fMins[0]) ;
    fYShift = (fMaxs[1] - fMins[1]) ;

    const sizeofOrder = sizeof iOrder;

    iTr2 = create_tr2();

    fTestOrigin[1] = fOrigin[1] + fDistance;
    fTestOrigin[2] = fOrigin[2];

    static Float:flFraction, Float:fAngle, Float:fvBegin[3], Array:pTempArray=Invalid_Array;

    if(bRandom || pArrayLocations != Array:-1)
    {
        pTempArray = ArrayCreate(3, 1);
    }

    while( floatabs(fTestOrigin[1] - fOrigin[1]) <= fDistance  )
    {
        fAngle = floatasin( (fTestOrigin[1] - fOrigin[1]) / fDistance, degrees );
        fvBegin[0] = floatcos(fAngle,degrees) * fDistance;
        fvBegin[1] = floatsin(fAngle,degrees) * fDistance;
        fTestOrigin[0] = fOrigin[0] + fvBegin[0];

        while( get_distance_f(fTestOrigin, fOrigin) <= fDistance )
        {
            if( bInSight )
            {
                engfunc(EngFunc_TraceLine, fOrigin, fTestOrigin, IGNORE_MONSTERS, -1, iTr2);
                get_tr2(iTr2, TR_flFraction, flFraction);

                // Check if Test Origin is in sight and not behind a wall...
                if( flFraction < 1.0 )
                {
                    fTestOrigin[0] -= fXShift;
                    continue;
                }
            }

            for( i = iSafe = 0; i < sizeofOrder; i++ )
            {
                for( d = 0; d < 3; d++ )
                {
                    switch( iOrder[i][0][d] )
                    {
                        case -1: fStart[d] = fTestOrigin[d] + fMins[d];
                        case 0: fStart[d] = fTestOrigin[d];
                        case 1: fStart[d] = fTestOrigin[d] + fMaxs[d];
                    }

                    switch( iOrder[i][1][d] )
                    {
                        case -1: fEnd[d] = fTestOrigin[d] + fMins[d];
                        case 0: fEnd[d] = fTestOrigin[d];
                        case 1: fEnd[d] = fTestOrigin[d] + fMaxs[d];
                    }
                }

                // Traces...
                engfunc(EngFunc_TraceLine, fStart, fEnd, DONT_IGNORE_MONSTERS, -1, iTr2);
                get_tr2(iTr2, TR_flFraction, flFraction);
                if(flFraction == 1.0 && get_tr2(iTr2, TR_InOpen) && !get_tr2(iTr2, TR_StartSolid) && !get_tr2(iTr2, TR_AllSolid))
                {
                    iSafe++;
                    continue;
                }

                break;
            }

            if(iSafe >= sizeofOrder)
            {
                if(pTempArray == Invalid_Array)
                {
                    xs_vec_copy(fTestOrigin, fOrigin);
                    free_tr2(iTr2);
                    return 1;
                }

                ArrayPushArray(pTempArray, fTestOrigin);
            }

            fTestOrigin[0] -= fXShift;
        }

        fTestOrigin[1] -= fYShift;
    }

    if(pTempArray != Invalid_Array)
    {
        if((i=ArraySize(pTempArray)) && bRandom)
        {
            ArrayGetArray(pTempArray, random(i), fOrigin);
        }

        if(pArrayLocations == any:-1)
        {
            ArrayDestroy(pTempArray);
        }
        else
        {
            pArrayLocations = pTempArray;
        }

        pTempArray = Invalid_Array;
        free_tr2(iTr2);
        return i;
    }

    free_tr2(iTr2);
    return 0;
}

stock Initiate_NPC_DEATHMSG(const victim, const killer, const bool:bHeadShot=false, const szWeapon[]="")
{
    static iNPC_DeathMSG_Data[DEATHMSG_DATA];

    iNPC_DeathMSG_Data[DEATHMSG_VICTIM_ID] = victim;
    iNPC_DeathMSG_Data[DEATHMSG_KILLER_ID] = killer;
    pev(victim, pev_netname, iNPC_DeathMSG_Data[DEATHMSG_VIC_NAME], charsmax(iNPC_DeathMSG_Data[DEATHMSG_VIC_NAME]));
    pev(killer, pev_netname, iNPC_DeathMSG_Data[DEATHMSG_KILLER_NAME], charsmax(iNPC_DeathMSG_Data[DEATHMSG_KILLER_NAME]));
    iNPC_DeathMSG_Data[DEATHMSG_bHEADSHOT] = bHeadShot;
    copy(iNPC_DeathMSG_Data[DEATHMSG_WEAPON_NAME], charsmax(iNPC_DeathMSG_Data[DEATHMSG_WEAPON_NAME]), szWeapon);

    static szParam[16], Array:xArray;
    ArrayPushArray((xArray = ArrayCreate(DEATHMSG_DATA, 1)), iNPC_DeathMSG_Data);
    num_to_str(_:xArray, szParam, charsmax(szParam));

    static const Float:fInterval_len = 1.0;
    static Float:finterval = 0.0, Float:fGameTime;
    fGameTime = get_gametime();

    if(finterval >= fGameTime)
        finterval += fInterval_len;
    else
        finterval = fGameTime + fInterval_len;

    set_task((finterval - fGameTime), "task_interval_NPC_DEATHMSG", iNPC_DeathMSG_Data[DEATHMSG_VICTIM_ID] + TASK_NPC_DEATHMSG, szParam, sizeof szParam);
}

public task_interval_NPC_DEATHMSG(const param[], taskid)
{
    static Array:xArray, iNPC_DeathMSG_Data[DEATHMSG_DATA];
    xArray = any:str_to_num(param);
    ArrayGetArray(xArray, 0, iNPC_DeathMSG_Data);
    ArrayDestroy(xArray);
    Make_NPC_DeathMsg(iNPC_DeathMSG_Data[DEATHMSG_VICTIM_ID], iNPC_DeathMSG_Data[DEATHMSG_KILLER_ID],
        iNPC_DeathMSG_Data[DEATHMSG_VIC_NAME], iNPC_DeathMSG_Data[DEATHMSG_KILLER_NAME],
        iNPC_DeathMSG_Data[DEATHMSG_bHEADSHOT], iNPC_DeathMSG_Data[DEATHMSG_WEAPON_NAME]);
}

stock Make_NPC_DeathMsg(id, killer, const vicName[32], const killerName[32], const bool:bHeadshot, const weapon[24])
{
    if(!id || vicName[0] == EOS)
    {
        log_error(AMX_ERR_NATIVE, "Attempting to create an NPC DeathMSG with invalid id or vicName!");
        return;
    }

    static iMsg_TeamInfo = 0;
    if(!iMsg_TeamInfo) iMsg_TeamInfo = get_user_msgid("TeamInfo");

    enum (+=1) {
        VICTIM_ID = 0,
        KILLER_ID
    }

    new iTargets[2];
    iTargets[VICTIM_ID] = id;
    iTargets[KILLER_ID] = killer;

    static szRejectReason[128], szName[2][32];

    copy(szName[VICTIM_ID], charsmax(szName[]), vicName);
    copy(szName[KILLER_ID], charsmax(szName[]), killerName);

    if(killerName[0] == EOS)
    {
        copy(szName[KILLER_ID], charsmax(szName[]), "World");
    }

    for(new i, iTarget; i < 2; i++)
    {
        if(szName[i][0] == EOS) continue;

        iTarget = iTargets[i];

        if(get_user_index(szName[i]) != iTarget)
        {
            iTarget = iTargets[i] = get_user_index(szName[i]);
        }

        if( iTarget > 0 )
        {
            if( IsPlayer(iTarget) && (is_user_connected(iTarget) || is_user_connecting(iTarget)) )
            {
                remove_task( iTarget + TASK_NPC_DEATHMSG );
                continue;
            }
        }

        if( (KILLER_ID == i && iTargets[i] == iTargets[VICTIM_ID]) )
        {
            continue;
        }

        iTargets[i] = iTarget = engfunc(EngFunc_CreateFakeClient, szName[i]);

        if(!iTarget)
            continue;

        engfunc(EngFunc_FreeEntPrivateData, iTarget);
        if(dllfunc(DLLFunc_ClientConnect, iTarget , szName[i], "127.0.0.1", szRejectReason))
        {
            dllfunc(DLLFunc_ClientPutInServer, iTarget);
            set_pev(iTarget, pev_flags, pev(iTarget, pev_flags) | FL_FAKECLIENT);
            set_pev(iTarget, pev_deadflag, DEAD_DISCARDBODY);

            message_begin(MSG_BROADCAST, iMsg_TeamInfo, {0,0,0}, 0);
            write_byte(iTarget);
            write_string("TERRORIST");
            message_end();

            set_rendering(iTarget, kRenderFxNone, 0, 0, 0, kRenderTransAlpha);
        }
    }

    new szParam[16], Array:xArray, iNPC_DeathMSG_Data[DEATHMSG_DATA];
    iNPC_DeathMSG_Data[DEATHMSG_VICTIM_ID] = get_user_userid(iTargets[VICTIM_ID]);
    iNPC_DeathMSG_Data[DEATHMSG_KILLER_ID] = get_user_userid(iTargets[KILLER_ID]);
    iNPC_DeathMSG_Data[DEATHMSG_bHEADSHOT] = _:bHeadshot;
    copy(iNPC_DeathMSG_Data[DEATHMSG_WEAPON_NAME], charsmax(iNPC_DeathMSG_Data[DEATHMSG_WEAPON_NAME]), weapon);
    copy(iNPC_DeathMSG_Data[DEATHMSG_KILLER_NAME], charsmax(iNPC_DeathMSG_Data[DEATHMSG_KILLER_NAME]), killerName);
    copy(iNPC_DeathMSG_Data[DEATHMSG_VIC_NAME], charsmax(iNPC_DeathMSG_Data[DEATHMSG_VIC_NAME]), vicName);
    ArrayPushArray((xArray = ArrayCreate(DEATHMSG_DATA,1)), iNPC_DeathMSG_Data);
    num_to_str(_:xArray, szParam, charsmax(szParam));
    set_task(0.5, "declare_npc_deathmsg", id + TASK_NPC_DEATHMSG, szParam, sizeof szParam);
}

public declare_npc_deathmsg(const szParam[16], const taskid)
{
    new Array:xArray = any:str_to_num(szParam), iNPC_DeathMSG_Data[DEATHMSG_DATA];
    ArrayGetArray(xArray, 0, iNPC_DeathMSG_Data);

    new victim = find_player("k", iNPC_DeathMSG_Data[DEATHMSG_VICTIM_ID]),
    killer = find_player("k", iNPC_DeathMSG_Data[DEATHMSG_KILLER_ID]);

    if( !is_user_connected(victim) && !is_user_connecting(victim) ||
        !is_user_connected(killer) && !is_user_connecting(killer)  )
    {
        ArrayDestroy(xArray);

        remove_task(victim + TASK_NPC_DEATHMSG);
        remove_task(killer + TASK_NPC_DEATHMSG);

        Initiate_NPC_DEATHMSG(victim, killer, iNPC_DeathMSG_Data[DEATHMSG_bHEADSHOT], iNPC_DeathMSG_Data[DEATHMSG_WEAPON_NAME]);
        return;
    }

    new szNetName[2];
    pev(victim, pev_netname, szNetName, 1);
    if(szNetName[0] == EOS)
    {
        set_task(0.1, "declare_npc_deathmsg", taskid, szParam, sizeof szParam);
        return;
    }

    ArrayDestroy(xArray);

    make_deathmsg(killer, victim,  iNPC_DeathMSG_Data[DEATHMSG_bHEADSHOT], iNPC_DeathMSG_Data[DEATHMSG_WEAPON_NAME]);

    if(killer > 0 && pev(killer, pev_flags) & FL_FAKECLIENT)
    {
        remove_task(killer + TASK_NPC_DEATHMSG);
        set_task(1.0, "task_kick_bot", killer + TASK_NPC_DEATHMSG);
    }

    if(victim > 0 && pev(victim, pev_flags) & FL_FAKECLIENT)
    {
        remove_task(victim + TASK_NPC_DEATHMSG);
        set_task(1.0, "task_kick_bot", victim + TASK_NPC_DEATHMSG);
    }
}

public task_kick_bot(id)
{
    id -= TASK_NPC_DEATHMSG;

    if(is_user_bot(id))
    {
        server_cmd("kick #%d;", get_user_userid(id));
    }
}

stock teleport_entity(ent, const Float:fOrigin[3], const Float:fMaxs[3], const Float:fMins[3], bHasTeleportTransmitter=true)
{
    new tele_sprite, Float:fOriginalOrigin[3], Float:fMidPoint[3];
    pev(ent, pev_origin, fOriginalOrigin);

    for(new i = !bHasTeleportTransmitter ? 1 : 0; i < 2; i++)
    {
        tele_sprite = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"));

        if( tele_sprite )
        {
            set_pev(tele_sprite, pev_model, "sprites/b-tele1.spr");
            set_pev(tele_sprite, pev_spawnflags, SF_SPRITE_STARTON|SF_SPRITE_ONCE|SF_SPRITE_TEMPORARY);
            set_pev(tele_sprite, pev_scale, 1.0);
            set_pev(tele_sprite, pev_framerate, 15.0);
            set_pev(tele_sprite, pev_frame, 1.0);
            set_pev(tele_sprite, pev_animtime, get_gametime());
            set_pev(tele_sprite, pev_rendermode, kRenderTransAdd);
            set_pev(tele_sprite, pev_renderamt, 255.0);

            switch( i )
            {
                case 0:
                {
                    fMidPoint[0] = fOriginalOrigin[0] + (fMaxs[0] - fMins[0]) * 0.5;
                    fMidPoint[1] = fOriginalOrigin[1] + (fMaxs[1] - fMins[1]) * 0.5;
                    fMidPoint[2] = fOriginalOrigin[2] + (fMaxs[2] - fMins[2]) * 0.5;
                }
                case 1:
                {
                    fMidPoint[0] = fOrigin[0] + (fMaxs[0] - fMins[0]) * 0.5;
                    fMidPoint[1] = fOrigin[1] + (fMaxs[1] - fMins[1]) * 0.5;
                    fMidPoint[2] = fOrigin[2] + (fMaxs[2] - fMins[2]) * 0.5;
                }
            }

            set_pev(tele_sprite, pev_origin, fMidPoint);
            dllfunc(DLLFunc_Spawn, tele_sprite);

            engfunc(EngFunc_EmitSound, tele_sprite, CHAN_BODY, "jailbreak/nc_teleport.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        }
    }

    engfunc(EngFunc_SetOrigin, ent, fOrigin);
}

stock Float:entity_takedamage_type( const ent )
{
    static Float:flTakeDamage;
    pev(ent, pev_takedamage, flTakeDamage)
    return flTakeDamage;
}
