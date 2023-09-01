/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <jailbreak_core>
#include <npc_library>
#include <vip_core>
#include <reapi>

#define PLUGIN  "[JB] SHOP: Turret"
#define AUTHOR  "Natsheh"

new const TURRET_CLASSNAME[] = "Turret";
new const TURRETS_BULLETS_CLASSNAME[][] = { "Beam", "Bullet", "Rocket" };

#define IsPlayer(%1) (1 <= %1 <= 32)

#define BONE_CONTROL_ROTATION_YAW pev_controller_0
#define BONE_CONTROL_ROTATION_PITCH pev_controller_1
#define MAX_BONE_CONTROLLERS 4

#define TURRET_L_GUN_ATTACHMENT 0
#define TURRET_R_GUN_ATTACHMENT 1

#define EVENT_FIRE_WEAPON_RIGHT 5001
#define EVENT_FIRE_WEAPON_LEFT 5011

#define TURRET_CONTROL_BUTTON_ID 39626

#define PEV_TARGET_FLAGS pev_enemy
#define PEV_TURRET_TYPE pev_iuser2

enum (+=1)
{
    STATIONARY_GUARDIAN = 0,
    STATIONARY_SENTRY,
    MOBILE_WILLY,
    MAX_TURRETS
}

new const g_szTurretNames[][MAX_NAME_LENGTH] = {
    "Guardian",
    "Sentry",
    "Willy"
}

new g_szTurretModels[][MAX_RESOURCE_PATH_LENGTH] = {
        "models/jailbreak/stationary_turret.mdl",
        "models/jailbreak/stationary_sentry_v4.mdl",
        "models/jailbreak/stationary_sentry_v4.mdl" // here should be little willy
    },
    g_pCvar_rounds_per_m[MAX_TURRETS], g_pCvar_rotation_speed[MAX_TURRETS], g_pCvar_projectile_speed[MAX_TURRETS],
    g_iJBShopItemTurret[MAX_TURRETS], g_iJBVIPShopItemTurret[MAX_TURRETS];

enum any:TURRET_DATA
{
    TURRET_FIRE_RPM[8],
    TURRET_ROT_SPEED[8],
    TURRET_PROJ_SPEED[8],
    TURRET_BULLET_SPRITE[64],
    TURRET_BULLET_DAMAGE,
    Float:TURRET_BULLET_GRAVITY
}

new const any:g_aTurretData[][TURRET_DATA] = {
    { "240", "5", "1200.0", "sprites/bluebeam1.spr", DMG_BURN, 0.01 },
    { "360", "5", "2000.0", "sprites/s.spr", DMG_BULLET, 0.01 },
    { "360", "5", "2000.0", "sprites/s.spr", DMG_BULLET, 0.01 }
}

new const g_szTurretDeathSounds[][] = {
    "turret/tu_die.wav",
    "turret/tu_die2.wav",
    "turret/tu_die3.wav"
}

new const g_szTurretFireSounds[][][] = {
    { "debris/beamstart4.wav", "debris/beamstart8.wav" },
    { "weapons/m79-1.wav", "weapons/m249-1.wav" },
    { "weapons/m79-1.wav", "weapons/m249-1.wav" }
}

new const Float:g_flMAXS[MAX_TURRETS][3] =
{
    { 20.0, 20.0, 80.0 },
    { 20.0, 20.0, 24.0 },
    { 20.0, 20.0, 24.0 }
}
new const Float:g_flMINS[MAX_TURRETS][3] =
{
    { -20.0, -20.0, 0.0 },
    { -20.0, -20.0, 0.0 },
    { -20.0, -20.0, 0.0 }
}
new const Float:g_flViewOFS[MAX_TURRETS][3] =
{
    { 0.0, 0.0, 80.0 },
    { 0.0, 0.0, 24.0 },
    { 0.0, 0.0, 24.0 }
}

enum TURRET_STATES (+=1)
{
    STATE_TURRET_OFFLINE = 500,
    STATE_TURRET_ACTIVE,
    STATE_TURRET_DEPLOY,
    STATE_TURRET_HOLSTER,
    STATE_TARGET_ENGAGE
}

enum BONE_CONTROLLERS_DATA(+=1)
{
    BONE_CONTROLLER_BONE_ID,
    BONE_CONTROLLER_TYPE,
    Float:BONE_CONTROLLER_START,
    Float:BONE_CONTROLLER_END,
    BONE_CONTROLLER_REST,
    BONE_CONTROLLER_INDEX,
    BONE_CONTROLLER_REVERSED
}

enum any:TURRET_TARGET_FLAGS ( <<= 1 )
{
    TURRET_TARGET_ENEMIES = 1,
    TURRET_TARGET_TEAMMATES,
    TURRET_TARGET_MONSTERS,
    TURRET_TARGET_TURRETS,
    TURRET_TARGET_OWNER
}

new Array:g_animArrays[MAX_TURRETS][NPC_ACTIVITY], g_sizeAnimArrays[MAX_TURRETS][NPC_ACTIVITY],
    g_aBoneControllersData[MAX_TURRETS][MAX_BONE_CONTROLLERS][BONE_CONTROLLERS_DATA],
    g_Sprite_Exp, g_pSprite_S, g_iController_1_OFFSet = 256, g_iController_0_OFFSet = 256;

#define TURRET_MAX_GUNS 2
new Float:g_fvTurretGunPoint[MAX_TURRETS][TURRET_MAX_GUNS][3];

public plugin_precache()
{
    for(new i; i < MAX_TURRETS; i++)
        PRECACHE_WORLD_ITEM(g_szTurretModels[i]);

    g_Sprite_Exp = PRECACHE_SPRITE_I("sprites/fexplo.spr");
    PRECACHE_SPRITE("sprites/bluebeam1.spr");
    g_pSprite_S = PRECACHE_SPRITE("sprites/s.spr");

    for( new i; i < sizeof g_szTurretDeathSounds; i++)
    {
        PRECACHE_SOUND(g_szTurretDeathSounds[i]);
    }

    for(new i, j; j < sizeof g_szTurretFireSounds; j++)
    {
        for( i = 0; i < sizeof g_szTurretFireSounds[]; i++ )
        {
            PRECACHE_SOUND(g_szTurretFireSounds[j][i]);
        }
    }
}

public plugin_init()
{
    new iPluginID = register_plugin(PLUGIN, VERSION, AUTHOR);

    for(new i; i < MAX_TURRETS; i++)
    {
        MDL_STUDIO_LOAD_ANIMATIONS(g_szTurretModels[i], g_animArrays[i], g_sizeAnimArrays[i]);
        MDL_STUDIO_HOOK_EVENT(engfunc(EngFunc_ModelIndex, g_szTurretModels[i]), "turret_event");

        GetModelBoneControllersData(g_szTurretModels[i], g_aBoneControllersData[i]);
    }

    NPC_Hook_Event(TURRET_CLASSNAME, NPC_EVENT_DEATH, "turret_killed", iPluginID);
    NPC_Hook_Event(TURRET_CLASSNAME, NPC_EVENT_TRACEATTACK, "turret_traceattack", iPluginID);

    for(new i, szCvar[64], szName[MAX_NAME_LENGTH]; i < MAX_TURRETS; i++)
    {
        formatex(szCvar, charsmax(szCvar), "jb_%s_turret_fire_rpm", g_szTurretNames[i]);
        g_pCvar_rounds_per_m[i] = register_cvar(szCvar, g_aTurretData[i][TURRET_FIRE_RPM]);
        formatex(szCvar, charsmax(szCvar), "jb_%s_turret_rotation_speed", g_szTurretNames[i]);
        g_pCvar_rotation_speed[i] = register_cvar(szCvar, g_aTurretData[i][TURRET_ROT_SPEED]);
        formatex(szCvar, charsmax(szCvar), "jb_%s_turret_projectile_speed", g_szTurretNames[i]);
        g_pCvar_projectile_speed[i] = register_cvar(szCvar, g_aTurretData[i][TURRET_PROJ_SPEED]);

        g_iJBShopItemTurret[i] = register_jailbreak_shopitem(g_szTurretNames[i], "Stationary sentry", 65000, TEAM_GUARDS);

        formatex(szName, charsmax(szName), "(VIP) %s", g_szTurretNames[i]);
        g_iJBVIPShopItemTurret[i] = register_jailbreak_shopitem(szName, "Stationary sentry", 10000, TEAM_GUARDS);
    }

    register_think(TURRET_CLASSNAME, "turret_brain");
    register_touch(TURRETS_BULLETS_CLASSNAME[STATIONARY_GUARDIAN], "*", "turret_bullet_hit");
    register_touch(TURRETS_BULLETS_CLASSNAME[STATIONARY_SENTRY], "*", "turret_bullet_hit");
    register_think(TURRETS_BULLETS_CLASSNAME[STATIONARY_GUARDIAN], "turret_beam_think");
    register_think(TURRETS_BULLETS_CLASSNAME[STATIONARY_SENTRY], "turret_bullet_think");

    register_clcmd("turret", "clcmd_turret", ADMIN_IMMUNITY);

    RegisterHam(Ham_Use, "func_button", "turret_use_pre", .Post=false);

    if(is_linux_server())
    {
        g_iController_0_OFFSet = g_iController_1_OFFSet = 0;
    }

    RetrieveTurretGunPointOffsets(STATIONARY_GUARDIAN, TURRET_R_GUN_ATTACHMENT);
    RetrieveTurretGunPointOffsets(STATIONARY_GUARDIAN, TURRET_L_GUN_ATTACHMENT);

    RetrieveTurretGunPointOffsets(STATIONARY_SENTRY, TURRET_R_GUN_ATTACHMENT);
    RetrieveTurretGunPointOffsets(STATIONARY_SENTRY, TURRET_L_GUN_ATTACHMENT);
}

#if AMXX_VERSION_NUM <= 182
public client_disconnect(id)
#else
public client_disconnected(id)
#endif
{
    RemovePlayerTurrets(id);
}

public jb_round_end()
{
    DisablePlayersTurrets();
}

DisablePlayersTurrets()
{
    new ent, Float:fHealth;
    while( (ent = find_ent_by_class(ent, TURRET_CLASSNAME)) > 0)
    {
        pev(ent, pev_health, fHealth);

        if(fHealth <= 0.0)
        {
            continue;
        }

        if(pev(ent, PEV_TASK) == any:STATE_TURRET_OFFLINE)
        {
            continue;
        }

        set_pev(ent, PEV_TASK, STATE_TURRET_HOLSTER);
        dllfunc(DLLFunc_Think, ent);
    }
}

RemovePlayerTurrets(id)
{
    new ent;
    while( (ent = find_ent_by_owner(ent, TURRET_CLASSNAME, id)) > 0)
    {
        if(pev(ent, PEV_OWNER) == id)
        {
            set_pev(ent, PEV_OWNER, 0);
        }
    }
}

public turret_traceattack(id, attacker, Float:Damage, Float:fDirection[3], trace_handle, damagebits)
{
    if(damagebits > 0)
    {
        fDirection[0] *= Damage;
        fDirection[1] *= Damage;
        fDirection[2] *= Damage;

        static Float:fHit[3];
        get_tr2(trace_handle, TR_vecEndPos, fHit);
        draw_spark(fHit);
    }
}

public vip_flag_creation()
{
    register_vip_flag('d', "Access to purchase a turret!");
}

public jb_shop_item_bought(id, itemid)
{
    for(new i = 0; i < MAX_TURRETS; i++)
    {
        if(itemid == g_iJBShopItemTurret[i] || itemid == g_iJBVIPShopItemTurret[i])
        {
            new Float:fOrigin[3], Float:fAngles[3], Float:fVelo[3];
            pev(id, pev_origin, fOrigin);
            pev(id, pev_v_angle, fAngles);
            fAngles[0] = fAngles[2] = 0.0;
            velocity_by_aim(id, 80, fVelo);
            fVelo[2] = 0.0;
            xs_vec_add(fOrigin, fVelo, fOrigin);

            new iTurret = CreateTurret(fOrigin, g_flViewOFS[i], .iOwner = id, .iSkin = max( get_user_team(id) - 1, 0 ), .iType = i);
            set_pev(iTurret, pev_angles, fAngles);
            return;
        }
    }
}

public jb_shop_item_preselect(id, itemid)
{
    for(new i = 0; i < MAX_TURRETS; i++)
    {
        if(itemid == g_iJBVIPShopItemTurret[i])
        {
            if(get_user_vip(id) & read_flags("d"))
            {
                return JB_IGNORED;
            }

            return JB_MENU_ITEM_UNAVAILABLE;
        }
    }

    return JB_IGNORED;
}

public turret_use_pre(id, caller, activator, use_type, Float:value)
{
    if(pev(id, PEV_IDENTITY) != TURRET_CONTROL_BUTTON_ID)
    {
        return HAM_IGNORED;
    }

    new NPCIndex = pev(id, pev_owner);

    if(pev(NPCIndex, PEV_IDENTITY) != NPC_ID)
    {
        return HAM_IGNORED;
    }

    turret_control_menu(caller, NPCIndex);
    return HAM_SUPERCEDE;
}

NPC_DestroyControlButton( const iNPC )
{
    new ent = -1;
    while( (ent = find_ent_by_class(ent, "func_button")) > 0 )
    {
        if(pev(ent, pev_owner) == iNPC && pev(ent, PEV_IDENTITY) == TURRET_CONTROL_BUTTON_ID)
        {
            set_pev(ent, pev_flags, FL_KILLME);
            dllfunc(DLLFunc_Think, ent);
            break;
        }
    }
}

NPC_CreateControlButton( const iNPC_index )
{
    new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_button"));

    if( !ent )
    {
        return 0;
    }

    new szName[32];
    pev(iNPC_index, pev_netname, szName, charsmax(szName));

    set_pev(ent, pev_target, szName);
    set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_aiment, iNPC_index);
    set_pev(ent, pev_owner, iNPC_index);
    set_pev(ent, PEV_IDENTITY, TURRET_CONTROL_BUTTON_ID);
    set_rendering(ent, .render=kRenderTransAlpha, .amount=255);

    new iType = pev(ent, PEV_TURRET_TYPE);
    engfunc(EngFunc_SetModel, ent, g_szTurretModels[iType]);
    engfunc(EngFunc_SetSize, ent, g_flMINS[iType], g_flMAXS[iType]);

    set_pev(ent, pev_spawnflags, SF_BUTTON_TOGGLE);

    return ent;
}

turret_control_menu(const id, const turret)
{
    new szText[128], szName[32], Float:fHealth;
    pev(turret, pev_netname, szName, charsmax(szName))
    pev(turret, pev_health, fHealth);
    formatex(szText, charsmax(szText), "\yStatus \r'%s' ^n \wHealth: \r%.2f", szName, fHealth);
    new menu = menu_create(szText, "turret_control_m_handle");

    new szInfo[5], iTargetFlags = pev(turret, PEV_TARGET_FLAGS);
    num_to_str(turret, szInfo, charsmax(szInfo));

    new iTask = pev(turret, PEV_TASK);

    const NO_ACCESS = ( 1 << 26 );

    switch( iTask )
    {
        case STATE_TARGET_ENGAGE, STATE_TURRET_ACTIVE:
        {
            menu_additem(menu, "Deactivate the turret!", szInfo);
        }
        case STATE_TURRET_OFFLINE:
        {
            menu_additem(menu, "Activate the turret!", szInfo);
        }
        default:
        {
            menu_additem(menu, "Turret undefined state!", szInfo, .paccess = NO_ACCESS);
        }
    }

    if(!(iTargetFlags & TURRET_TARGET_ENEMIES))
    {
        menu_additem(menu, "Set turret to attack enemies!", szInfo, 0);
    }
    else
    {
        menu_additem(menu, "Disable turret attacking enemies!", szInfo, 0);
    }

    if(!(iTargetFlags & TURRET_TARGET_TEAMMATES))
    {
        menu_additem(menu, "Set turret to attack teammates!", szInfo, 0);
    }
    else
    {
        menu_additem(menu, "Disable turret attacking teammates!", szInfo, 0);
    }

    if(!(iTargetFlags & TURRET_TARGET_MONSTERS))
    {
        menu_additem(menu, "Set turret to attack monsters!", szInfo, 0);
    }
    else
    {
        menu_additem(menu, "Disable turret attacking monsters!", szInfo, 0);
    }

    if(!(iTargetFlags & TURRET_TARGET_TURRETS))
    {
        menu_additem(menu, "Set turret to attack turrets!", szInfo, 0);
    }
    else
    {
        menu_additem(menu, "Disable turret attacking turrets!", szInfo, 0);
    }

    if(!(iTargetFlags & TURRET_TARGET_OWNER))
    {
        menu_additem(menu, "Set turret to attack the owner!", szInfo, 0);
    }
    else
    {
        menu_additem(menu, "Disable turret attacking the owner!", szInfo, 0);
    }

    menu_display(id, menu);
}

public turret_control_m_handle(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new null, sData[5];
    menu_item_getinfo(menu, item, null, sData, charsmax(sData), "", _, null);

    menu_destroy(menu);

    new turret = str_to_num(sData);

    if(!pev_valid(turret) || pev(turret, PEV_OWNER) != id || pev(turret, PEV_IDENTITY) != NPC_ID)
    {
        return PLUGIN_HANDLED;
    }

    new Float:fHealth;
    pev(turret, pev_health, fHealth);

    if(fHealth <= 0.0)
    {
        return PLUGIN_HANDLED;
    }

    new szName[32], iTargetFlags = pev(turret, PEV_TARGET_FLAGS);
    pev(turret, pev_netname, szName, charsmax(szName));

    switch( item )
    {
        case 0:
        {
            new iTask = pev(turret, PEV_TASK);

            switch( iTask )
            {
                case STATE_TARGET_ENGAGE, STATE_TURRET_ACTIVE:
                {
                    set_pev(turret, PEV_TASK, STATE_TURRET_HOLSTER);
                    dllfunc(DLLFunc_Think, turret);

                    cprint_chat(id, _, "You deactivated the turret!");
                }
                case STATE_TURRET_OFFLINE:
                {
                    set_pev(turret, PEV_TASK, STATE_TURRET_DEPLOY);
                    dllfunc(DLLFunc_Think, turret);

                    cprint_chat(id, _, "You activated the turret!");
                }
            }
        }
        case 1:
        {
            if(!(iTargetFlags & TURRET_TARGET_ENEMIES))
            {
                cprint_chat(id, _, "You set the !g'%s' !tto target enemies!", szName);
                set_pev(turret, PEV_TARGET_FLAGS, (iTargetFlags | TURRET_TARGET_ENEMIES));
            }
            else
            {
                cprint_chat(id, _, "You set the !g'%s' !tto avoid enemies!", szName);
                set_pev(turret, PEV_TARGET_FLAGS, (iTargetFlags & ~TURRET_TARGET_ENEMIES));
            }
        }
        case 2:
        {
            if(!(iTargetFlags & TURRET_TARGET_TEAMMATES))
            {
                cprint_chat(id, _, "You set the !g'%s' !tto target teammates!", szName);
                set_pev(turret, PEV_TARGET_FLAGS, (iTargetFlags | TURRET_TARGET_TEAMMATES));
            }
            else
            {
                cprint_chat(id, _, "You set the !g'%s' !tto avoid teammates!", szName);
                set_pev(turret, PEV_TARGET_FLAGS, (iTargetFlags & ~TURRET_TARGET_TEAMMATES));
            }
        }
        case 3:
        {
            if(!(iTargetFlags & TURRET_TARGET_MONSTERS))
            {
                cprint_chat(id, _, "You set the !g'%s' !tto target monsters!", szName);
                set_pev(turret, PEV_TARGET_FLAGS, (iTargetFlags | TURRET_TARGET_MONSTERS));
            }
            else
            {
                cprint_chat(id, _, "You set the !g'%s' !tto avoid monsters!", szName);
                set_pev(turret, PEV_TARGET_FLAGS, (iTargetFlags & ~TURRET_TARGET_MONSTERS));
            }
        }
        case 4:
        {
            if(!(iTargetFlags & TURRET_TARGET_TURRETS))
            {
                cprint_chat(id, _, "You set the !g'%s' !tto target turrets!", szName);
                set_pev(turret, PEV_TARGET_FLAGS, (iTargetFlags | TURRET_TARGET_TURRETS));
            }
            else
            {
                cprint_chat(id, _, "You set the !g'%s' !tto avoid turrets!", szName);
                set_pev(turret, PEV_TARGET_FLAGS, (iTargetFlags & ~TURRET_TARGET_TURRETS));
            }
        }
        case 5:
        {
            if(!(iTargetFlags & TURRET_TARGET_OWNER))
            {
                cprint_chat(id, _, "You set the !g'%s' !tto target owner!", szName);
                set_pev(turret, PEV_TARGET_FLAGS, (iTargetFlags | TURRET_TARGET_OWNER));
            }
            else
            {
                cprint_chat(id, _, "You set the !g'%s' !tto avoid owner!", szName);
                set_pev(turret, PEV_TARGET_FLAGS, (iTargetFlags & ~TURRET_TARGET_OWNER));
            }
        }
    }

    return PLUGIN_HANDLED;
}

public turret_beam_think(ent)
{
    static Float:fEventOrigin[3], iTarget = 0, iNPC, iDamageBits, Float:fDamage;
    pev(ent, pev_origin, fEventOrigin);
    iNPC = pev(ent, pev_owner);

    static iTargetFlags, iOwner, iOwnerTeam, szClass[sizeof TURRET_CLASSNAME];
    iOwner = pev(iNPC, PEV_OWNER);
    iOwnerTeam = get_user_team(iOwner);
    iTargetFlags = pev(iNPC, PEV_TARGET_FLAGS);

    while( (iTarget = find_ent_in_sphere(iTarget, fEventOrigin, 90.0)) > 0)
    {
        if(iTarget != iNPC && entity_takedamage_type(iTarget) != DAMAGE_NO)
        {
            pev(iTarget, pev_classname, szClass, charsmax(szClass));

            if( (IsPlayer(iTarget) && (
                ((iTargetFlags & TURRET_TARGET_ENEMIES)   && iOwnerTeam != get_user_team(iTarget)) ||
                ((iTargetFlags & TURRET_TARGET_TEAMMATES) && iOwnerTeam == get_user_team(iTarget)) )) ||
                ( ((iTargetFlags & TURRET_TARGET_MONSTERS) && pev(iTarget, pev_flags) & FL_MONSTER) &&
                    (!equal(szClass, TURRET_CLASSNAME) ||
                    ((iTargetFlags & TURRET_TARGET_TURRETS) && pev(iTarget, pev_team) != pev(iNPC, pev_team)))) )
            {
                pev(ent, pev_dmg, iDamageBits);
                pev(ent, pev_dmg_save, fDamage);
                ExecuteHamB(Ham_TakeDamage, iTarget, ent, iNPC ? iNPC : ent, fDamage, iDamageBits);
            }
        }
    }

    static Float:fVelo[3];
    pev(ent, pev_velocity, fVelo);

    if(xs_vec_len(fVelo) == 0.0)
    {
        set_pev(ent, pev_flags, FL_KILLME);
        dllfunc(DLLFunc_Think, ent);
        return;
    }

    set_pev(ent, pev_nextthink, get_gametime() + 0.1);
}

public turret_bullet_think(ent)
{
    static Float:fVelo[3];
    pev(ent, pev_velocity, fVelo);

    if(xs_vec_len(fVelo) == 0.0)
    {
        set_pev(ent, pev_flags, FL_KILLME);
        dllfunc(DLLFunc_Think, ent);
        return;
    }

    set_pev(ent, pev_nextthink, get_gametime() + 1.0);
}

public turret_bullet_hit(ent, other)
{
    if( (pev(ent, pev_flags) & FL_KILLME) )
    {
        return;
    }

    if( other > 0 )
    {
        // lets prevent from bullets hitting each other.
        if(pev(other, pev_solid) == SOLID_TRIGGER)
            return;

        if(pev(other, pev_takedamage) != DAMAGE_NO)
        {
            static iTargetFlags, iOwner, iTurret, iOwnerTeam, szClass[sizeof TURRET_CLASSNAME];
            iTurret = pev(ent, PEV_OWNER);
            iOwner = pev(iTurret, PEV_OWNER);
            iOwnerTeam = get_user_team(iOwner);
            iTargetFlags = pev(iTurret, PEV_TARGET_FLAGS);
            pev(other, pev_classname, szClass, charsmax(szClass));

            if( (IsPlayer(other) && (
                ((iTargetFlags & TURRET_TARGET_ENEMIES)   && iOwnerTeam != get_user_team(other)) ||
                ((iTargetFlags & TURRET_TARGET_TEAMMATES) && iOwnerTeam == get_user_team(other)) )) ||
                ( ((iTargetFlags & TURRET_TARGET_MONSTERS) && pev(other, pev_flags) & FL_MONSTER) && (!equal(szClass, TURRET_CLASSNAME) ||
                  ((iTargetFlags & TURRET_TARGET_TURRETS) && pev(other, pev_team) != pev(pev(ent, PEV_OWNER), pev_team)))) )
            {
                static iDamageBits, Float:fDamage, Float:fVecStart[3], Float:fVecEnd[3], Float:fDirection[3], tr2;
                pev(ent, pev_dmg, iDamageBits);
                pev(ent, pev_dmg_save, fDamage);
                pev(ent, pev_velocity, fDirection);

                if(xs_vec_len(fDirection) != 0.0)
                {
                    pev(ent, pev_origin, fVecStart);
                    xs_vec_normalize(fDirection, fDirection);
                    xs_vec_copy(fVecStart, fVecEnd);
                    fVecEnd[0] += (fDirection[0] * 9999.0);
                    fVecEnd[1] += (fDirection[1] * 9999.0);
                    fVecEnd[2] += (fDirection[2] * 9999.0);

                    tr2 = create_tr2();

                    rg_multidmg_clear();
                    engfunc(EngFunc_TraceLine, fVecStart, fVecEnd, 0, ent, tr2);
                    ExecuteHamB(Ham_TraceAttack, other, ent, fDamage, fDirection, tr2, iDamageBits);
                    rg_multidmg_apply(ent, pev(ent, pev_owner));
                    free_tr2(tr2);
                }
            }
        }
    }

    set_pev(ent, pev_flags, FL_KILLME);
    dllfunc(DLLFunc_Think, ent);
}

public clcmd_turret(id, level, cid)
{
    if(!(get_user_flags(id) & level))
    {
        console_print(id, "No access schmuck!!!");
        return PLUGIN_HANDLED;
    }

    new szType[16], iType = -1;
    read_argv(1, szType, charsmax(szType));
    remove_quotes(szType);

    for(new i; i < MAX_TURRETS; i++)
    {
        if(containi(g_szTurretNames[i], szType) > -1)
        {
            iType = i;
            break;
        }
    }

    if(iType == -1)
    {
        console_print(id, "Turret Type is Invalid!");
        return PLUGIN_HANDLED;
    }

    new Float:fOrigin[3], Float:fAngles[3], Float:fVelo[3];
    pev(id, pev_origin, fOrigin);
    pev(id, pev_v_angle, fAngles);
    fAngles[0] = fAngles[2] = 0.0;
    velocity_by_aim(id, 80, fVelo);
    fVelo[2] = 0.0;
    xs_vec_add(fOrigin, fVelo, fOrigin);

    new iTurret = CreateTurret(fOrigin, g_flViewOFS[iType], .iOwner = id, .iSkin = max( get_user_team(id) - 1, 0 ), .iType = iType);
    set_pev(iTurret, pev_angles, fAngles);

    return PLUGIN_HANDLED;
}

public turret_killed(ent, killer)
{
    emit_sound(ent, CHAN_AUTO, g_szTurretDeathSounds[ random(sizeof g_szTurretDeathSounds) ], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    new szClass[32];
    pev(ent, PEV_WEAPON_INFLICTOR, szClass, charsmax(szClass));
    Initiate_NPC_DEATHMSG(ent, killer, false, szClass);
}

public plugin_end()
{
    NPC_FREE_HOOKS(TURRET_CLASSNAME);

    for(new i; i < sizeof g_szTurretModels; i++)
    {
        MDL_STUDIO_FREE_DATA(g_animArrays[i], g_sizeAnimArrays[i]);
        MDL_STUDIO_DESTROY_HOOKS(engfunc(EngFunc_ModelIndex, g_szTurretModels[i]));
    }
}

CreateTurret(const Float:fOrigin[3], const Float:fViewOFS[3], const Float:fMaxSpeed = 100.0, const Float:fMaxHP = 2000.0, const iOwner = 0, const iBody = 0, const iSkin = 0, const iType = STATIONARY_GUARDIAN)
{
    new ent = NPC_SPAWN(TURRET_CLASSNAME, "Turret", g_szTurretModels[iType],
        fOrigin, fViewOFS, fMaxSpeed, fMaxHP, iOwner,
        .task = any:STATE_TURRET_DEPLOY, .NPC_MOVETYPE = MOVETYPE_TOSS,
        .fMaxS = g_flMAXS[iType], .fMinS = g_flMINS[iType]);
    set_pev(ent, BONE_CONTROL_ROTATION_YAW, 000);
    set_pev(ent, BONE_CONTROL_ROTATION_PITCH, 127);
    set_pev(ent, PEV_TARGET_FLAGS, TURRET_TARGET_ENEMIES | TURRET_TARGET_MONSTERS );
    set_pev(ent, pev_owner, 0);
    set_pev(ent, pev_body, iBody);
    set_pev(ent, pev_skin, iSkin);
    set_pev(ent, PEV_TURRET_TYPE, iType);


    if(IsPlayer(iOwner))
    {
        set_pev( ent, pev_team, get_user_team(iOwner) );
        set_pev( NPC_CreateControlButton(ent), PEV_OWNER, iOwner );
    }

    return ent;
}

public turret_brain(id)
{
    static Float:fGtime, iOwner, Float:fNPCViewAngles[3], Float:fOrigin[3], Float:fTraceAttackOrigin[3], Float:fViewOffset[3], iState, iType;
    fGtime = get_gametime();
    iState = pev(id, PEV_TASK);
    iOwner = pev(id, PEV_OWNER);
    GetTurretGunAngles(id, fNPCViewAngles);
    pev(id, pev_origin, fOrigin);
    pev(id, pev_view_ofs, fViewOffset);
    xs_vec_add(fOrigin, fViewOffset, fTraceAttackOrigin);

    iState = pev(id, PEV_TASK);
    iType = pev(id, PEV_TURRET_TYPE);

    switch( iState )
    {
        case NPC_DEATH:
        {
            NPC_DestroyControlButton( id );

            remove_task(id);

            new Float:fAnimLength = NPC_animation(id, g_animArrays[iType], g_sizeAnimArrays[iType]);

            set_pev(id, PEV_TASK, NPC_KILLSELF);
            set_pev(id, pev_nextthink, fGtime + fAnimLength + 1.0);
        }
        case NPC_KILLSELF:
        {
            new ent;
            EF_Explosion(fOrigin, g_Sprite_Exp, .iScale = 50);

            while( (ent = find_ent_by_owner(ent, TURRETS_BULLETS_CLASSNAME[iType], id)) > 0 )
            {
                set_pev(ent, pev_owner, 0);
            }

            set_pev(id, pev_flags, FL_KILLME);
            dllfunc(DLLFunc_Think, id);
        }
        case STATE_TURRET_OFFLINE:
        {
            static xArray[ANIMATION_DATA];
            ArrayGetArray(Array:g_animArrays[iType][ACT_SLEEP], random(g_sizeAnimArrays[iType][ACT_SLEEP]), xArray);
            PlayAnimation(id, xArray[ANIMATION_SEQUENCE],
                xArray[ANIMATION_FPS], 1.0, xArray[ANIMATION_FRAMES], ACT_SLEEP,
                .bInLOOP=false,
                .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                .pArrayEventSize=xArray[ANIMATION_EVENTS]);

            set_pev(id, pev_nextthink, fGtime + NPC_THINK_LEN);
        }
        case STATE_TURRET_ACTIVE:
        {
            static xArray[ANIMATION_DATA];
            ArrayGetArray(Array:g_animArrays[iType][ACT_IDLE], random(g_sizeAnimArrays[iType][ACT_IDLE]), xArray);
            PlayAnimation(id, xArray[ANIMATION_SEQUENCE],
                xArray[ANIMATION_FPS], 1.0, xArray[ANIMATION_FRAMES], ACT_IDLE,
                .bInLOOP=false,
                .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                .pArrayEventSize=xArray[ANIMATION_EVENTS]);

            static szClass[sizeof TURRET_CLASSNAME], ent, iTarget, iTeam, iTargetFlags, iOwnerTeam, Float:fMaxDistance, Float:fDist, Float:fOriginDest[3];
            ent = iTarget = 0;
            iTeam = pev(id, pev_team);
            fMaxDistance = 2048.0;
            iTargetFlags = pev(id, PEV_TARGET_FLAGS);
            iOwnerTeam = iOwner > 0 ? get_user_team(iOwner) : 0;

            while( (ent=find_ent_in_sphere(ent, fTraceAttackOrigin, fMaxDistance)) > 0)
            {
                pev(ent, pev_classname, szClass, charsmax(szClass));

                if( (ent != iOwner || (iTargetFlags & TURRET_TARGET_OWNER)) &&
                    ( (IsPlayer(ent) && (
                        ((iTargetFlags & TURRET_TARGET_ENEMIES)   && iOwnerTeam != get_user_team(ent)) ||
                        ((iTargetFlags & TURRET_TARGET_TEAMMATES) && iOwnerTeam == get_user_team(ent)) )) ||
                      (((iTargetFlags & TURRET_TARGET_MONSTERS) && pev(ent, pev_flags) & FL_MONSTER) && (!equal(szClass, TURRET_CLASSNAME) || ((iTargetFlags & TURRET_TARGET_TURRETS) && pev(ent, pev_team) != iTeam))) ) &&
                    entity_takedamage_type(ent) != DAMAGE_NO &&
                    IsEntityVisible(fTraceAttackOrigin, fOriginDest, ent, id) &&
                    fMaxDistance > (fDist = get_distance_f(fTraceAttackOrigin,fOriginDest))
                  )
                {
                    fMaxDistance = fDist;
                    iTarget = ent;
                }
            }

            if(iTarget > 0) // We Found a target? engage !
            {
                set_pev(id, PEV_TARGET_LAST_TIME_SEEN, fGtime);
                set_pev(id, PEV_PREVIOUS_TASK, STATE_TURRET_ACTIVE);
                set_pev(id, NPC_TARGET, iTarget);
                set_pev(id, PEV_TASK, STATE_TARGET_ENGAGE);
            }
            else // Target is not found make a rotation :)
            {
                fNPCViewAngles[1] += get_pcvar_float(g_pCvar_rotation_speed[iType]);
                SetTurretGunAngles(id, fNPCViewAngles);
            }

            set_pev(id, pev_nextthink, fGtime + NPC_THINK_LEN);
        }
        case STATE_TURRET_DEPLOY:
        {
            remove_task(id);

            static xArray[ANIMATION_DATA];
            ArrayGetArray(Array:g_animArrays[iType][ACT_ARM], random(g_sizeAnimArrays[iType][ACT_ARM]), xArray);
            PlayAnimation(id, xArray[ANIMATION_SEQUENCE],
                xArray[ANIMATION_FPS], 1.0, xArray[ANIMATION_FRAMES], ACT_ARM,
                .bInLOOP=false,
                .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                .pArrayEventSize=xArray[ANIMATION_EVENTS]);

            set_pev(id, PEV_TASK, STATE_TURRET_ACTIVE);
            set_pev(id, pev_nextthink, fGtime + (xArray[ANIMATION_FRAMES] / xArray[ANIMATION_FPS]));
        }
        case STATE_TURRET_HOLSTER:
        {
            remove_task(id);

            static xArray[ANIMATION_DATA];
            ArrayGetArray(Array:g_animArrays[iType][ACT_DISARM], random(g_sizeAnimArrays[iType][ACT_DISARM]), xArray);
            PlayAnimation(id, xArray[ANIMATION_SEQUENCE],
                xArray[ANIMATION_FPS], 1.0, xArray[ANIMATION_FRAMES], ACT_DISARM,
                .bInLOOP=false,
                .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                .pArrayEventSize=xArray[ANIMATION_EVENTS]);

            set_pev(id, PEV_TASK, STATE_TURRET_OFFLINE);
            set_pev(id, pev_nextthink, fGtime + (xArray[ANIMATION_FRAMES] / xArray[ANIMATION_FPS]));
        }
        case STATE_TARGET_ENGAGE:
        {
            static iVictim, Float:fHealth; fHealth = 0.0;
            if(pev_valid((iVictim = pev(id, NPC_TARGET))))
            {
                pev(iVictim, pev_health, fHealth);
            }

            if(fHealth > 0.0)
            {
                // NPC has no visual of the target.
                static Float:fTargetOrigin[3];
                if( !IsEntityVisible(fTraceAttackOrigin, fTargetOrigin, iVictim, id, true) || entity_takedamage_type(iVictim) == DAMAGE_NO )
                {
                    remove_task(id);

                    set_pev(id, PEV_TASK, STATE_TURRET_ACTIVE);
                    set_pev(id, pev_nextthink, fGtime + NPC_THINK_LEN);
                    return;
                }
                
                static xArray[ANIMATION_DATA], Float:fTargetAngles[3], Float:fDirection[3], Float:fNPCVecDirection[3], Float:fDiffAngle, Float:fHorizontalSpeed, Float:fVerticalSpeed, Float:fVelo[3], Float:fLength;

                static Float:fvRightGUNPoint[3], Float:fvLeftGUNPoint[3];
                GetAttachmentData(id, TURRET_R_GUN_ATTACHMENT, fvRightGUNPoint, fTargetAngles);
                GetAttachmentData(id, TURRET_L_GUN_ATTACHMENT, fvLeftGUNPoint, fTargetAngles);
                fTraceAttackOrigin[2] = (fvRightGUNPoint[2] + fvLeftGUNPoint[2]) * 0.5;

                fVerticalSpeed = get_pcvar_float(g_pCvar_projectile_speed[iType]);
                xs_vec_sub(fTargetOrigin, fTraceAttackOrigin, fDirection);
                xs_vec_normalize(fDirection, fDirection);

                fLength = xs_vec_distance_2d(fTraceAttackOrigin, fTargetOrigin) / fVerticalSpeed;
                fHorizontalSpeed = ((fTargetOrigin[2] - fTraceAttackOrigin[2]) + (0.5 * (800.0 * g_aTurretData[iType][TURRET_BULLET_GRAVITY]) * floatpower(fLength, 2.0))) / fLength;
                fVelo[0] = fDirection[0] * fVerticalSpeed;
                fVelo[1] = fDirection[1] * fVerticalSpeed;
                fVelo[2] = fHorizontalSpeed;
                xs_vec_normalize(fVelo, fDirection);
                vector_to_angle(fDirection, fTargetAngles);
                angle_vector(fNPCViewAngles, ANGLEVECTOR_FORWARD, fNPCVecDirection);
                fDirection[2] *= -1.0;

                fDiffAngle = xs_vec_angle(fNPCVecDirection, fDirection);

                if(fDiffAngle <= 30.0)
                {
                    ArrayGetArray(Array:g_animArrays[iType][ACT_RANGE_ATTACK1], random(g_sizeAnimArrays[iType][ACT_RANGE_ATTACK1]), xArray);
                    PlayAnimation(id, xArray[ANIMATION_SEQUENCE],
                        xArray[ANIMATION_FPS], (xArray[ANIMATION_FRAMES] / xArray[ANIMATION_FPS]) / (60.0 / get_pcvar_float(g_pCvar_rounds_per_m[iType])),
                        xArray[ANIMATION_FRAMES], ACT_RANGE_ATTACK1,
                        .bInLOOP=true,
                        .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                        .pArrayEventSize=xArray[ANIMATION_EVENTS]);
                }
                else
                {
                    remove_task(id);

                    ArrayGetArray(Array:g_animArrays[iType][ACT_IDLE], random(g_sizeAnimArrays[iType][ACT_IDLE]), xArray);
                    PlayAnimation(id, xArray[ANIMATION_SEQUENCE],
                        xArray[ANIMATION_FPS], 1.0, xArray[ANIMATION_FRAMES], ACT_IDLE,
                        .bInLOOP=false,
                        .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                        .pArrayEventSize=xArray[ANIMATION_EVENTS]);
                }

                static Float:fNewAngles[3], Float:flRotSpeed; flRotSpeed = get_pcvar_float(g_pCvar_rotation_speed[iType]);
                xs_vec_copy(fNPCViewAngles, fNewAngles);

                if(floatsin(fTargetAngles[0] - fNPCViewAngles[0], degrees) > 0.0)
                {
                    fNewAngles[0] += floatmin(flRotSpeed, float( floatround( floatabs(fTargetAngles[0] - fNPCViewAngles[0]) ) % 180 ));
                }
                else if(floatsin(fTargetAngles[0] - fNPCViewAngles[0], degrees) < 0.0)
                {
                    fNewAngles[0] += -floatmin(flRotSpeed, float( floatround( floatabs(fTargetAngles[0] - fNPCViewAngles[0]) ) % 180 ));
                }

                if(floatsin(fTargetAngles[1] - fNPCViewAngles[1], degrees) > 0.0)
                {
                    fNewAngles[1] += floatmin(flRotSpeed, floatabs(fTargetAngles[1] - fNPCViewAngles[1]));
                }
                else if(floatsin(fTargetAngles[1] - fNPCViewAngles[1], degrees) < 0.0)
                {
                    fNewAngles[1] += -floatmin(flRotSpeed, floatabs(fTargetAngles[1] - fNPCViewAngles[1]));
                }

                SetTurretGunAngles(id, fNewAngles);

                set_pev(id, pev_nextthink, fGtime + 0.1);
            }
            else
            {
                remove_task(id);

                set_pev(id, PEV_TASK, STATE_TURRET_ACTIVE);
                set_pev(id, pev_nextthink, fGtime + NPC_THINK_LEN);
            }
        }
    }
}

GetTurretGunAngles(id, Float:fAngles[3])
{
    static Float:fPitch, Float:fYaw, Float:fMaxPitch, Float:fMinPitch, Float:fMaxYaw, Float:fMinYaw, iType;
    pev(id, pev_angles, fAngles);
    iType = pev(id, PEV_TURRET_TYPE);

    fMaxPitch = g_aBoneControllersData[iType][1][BONE_CONTROLLER_END];
    fMinPitch = g_aBoneControllersData[iType][1][BONE_CONTROLLER_START];
    fMaxYaw = g_aBoneControllersData[iType][0][BONE_CONTROLLER_END];
    fMinYaw = g_aBoneControllersData[iType][0][BONE_CONTROLLER_START];

    fPitch = float( pev(id, BONE_CONTROL_ROTATION_PITCH) - g_iController_1_OFFSet );
    fYaw   = float( pev(id, BONE_CONTROL_ROTATION_YAW) - g_iController_0_OFFSet );

    if(g_aBoneControllersData[iType][1][BONE_CONTROLLER_REVERSED])
        fAngles[0] -= ((fPitch - 127.5) / 255.0) * (floatabs(fMaxPitch) + floatabs(fMinPitch));
    else
        fAngles[0] += ((fPitch - 127.5) / 255.0) * (floatabs(fMaxPitch) + floatabs(fMinPitch));
    fAngles[1] += (fYaw / 256.0) * (floatabs(fMaxYaw) + floatabs(fMinYaw));

    FixAngles(fAngles);
}

FixAngles(Float:fAngles[3])
{
    if(fAngles[0] >= 180.0)
    {
        fAngles[0] -= 360.0;
    }
    else if(fAngles[0] <= -180.0)
    {
        fAngles[0] += 360.0;
    }

    if(fAngles[1] >= 360.0)
    {
        fAngles[1] -= 360.0;
    }
    else if(fAngles[1] <= 0.0)
    {
        fAngles[1] += 360.0;
    }
}

SetTurretGunAngles(id, Float:fAngles[3])
{
    static Float:fPitch, Float:fYaw, Float:fMaxPitch, Float:fMinPitch, Float:fMaxYaw, Float:fMinYaw, iType, iDiff;
    iType = pev(id, PEV_TURRET_TYPE);
    fMaxPitch = g_aBoneControllersData[iType][1][BONE_CONTROLLER_END];
    fMinPitch = g_aBoneControllersData[iType][1][BONE_CONTROLLER_START];
    fMaxYaw = g_aBoneControllersData[iType][0][BONE_CONTROLLER_END];
    fMinYaw = g_aBoneControllersData[iType][0][BONE_CONTROLLER_START];

    static Float:fYawController, Float:fPitchController;
    fPitchController = float( pev(id, BONE_CONTROL_ROTATION_PITCH) - g_iController_1_OFFSet );
    fYawController   = float( pev(id, BONE_CONTROL_ROTATION_YAW) - g_iController_0_OFFSet );

    FixAngles(fAngles);

    static Float:fPrevAngles[3];
    GetTurretGunAngles(id, fPrevAngles);

    iDiff = floatround(fAngles[0] - fPrevAngles[0]);
    fPitch = float( iDiff % floatround((floatabs(fMaxPitch) + floatabs(fMinPitch))) );

    if(fMaxPitch >= fAngles[0] && fMinPitch <= fAngles[0])
    {
        if(g_aBoneControllersData[iType][1][BONE_CONTROLLER_REVERSED])
        {
            if(iDiff >= 0)
                fPitch = fPitchController - ((fPitch / (floatabs(fMaxPitch) + floatabs(fMinPitch))) * 255.0);
            else
                fPitch = fPitchController - (((fPitch / (floatabs(fMaxPitch) + floatabs(fMinPitch))) - 1.0) * 255.0);
        }
        else
        {
            if(iDiff >= 0)
                fPitch = fPitchController + ((fPitch / (floatabs(fMaxPitch) + floatabs(fMinPitch))) * 255.0);
            else
                fPitch = fPitchController + (((fPitch / (floatabs(fMaxPitch) + floatabs(fMinPitch))) - 1.0) * 255.0);
        }

        set_pev(id, BONE_CONTROL_ROTATION_PITCH, floatround(fPitch) % 255);
    }

    iDiff = floatround(fAngles[1] - fPrevAngles[1]);
    fYaw = float( iDiff % floatround((floatabs(fMaxYaw) + floatabs(fMinYaw))) );

    if(fMaxYaw >= fAngles[1] && fMinYaw <= fAngles[1])
    {
        if(iDiff >= 0)
            fYaw = (fYaw / (floatabs(fMaxYaw) + floatabs(fMinYaw))) * 255.0;
        else
            fYaw = ((fYaw / (floatabs(fMaxYaw) + floatabs(fMinYaw))) - 1.0) * 255.0;
        set_pev(id, BONE_CONTROL_ROTATION_YAW, floatround(fYawController + fYaw) % 255);
    }
}

FireBullet(const Float:fOrigin[3], const Float:fDirection[3], Float:fPower, Float:GravityRatio, Float:fDamage, iDamagebits, const szModel[], const owner = 0, const szClass[]="")
{
    new iBullet = CreateProjectile(szClass, fOrigin, fPower, fDamage, iDamagebits, owner, szModel);

    set_pev(iBullet, pev_gravity, GravityRatio);
    set_pev(iBullet, pev_nextthink, get_gametime() + 0.1);

    FireProjectile(iBullet, fDirection, fPower);

    return iBullet;
}

public turret_event(const Params[ANIMATION_EVENTS_DATA], const id)
{
    static iType; iType = pev(id, PEV_TURRET_TYPE);

    switch( Params[EVENT_NUMBER] )
    {
        case EVENT_FIRE_WEAPON_LEFT:
        {
            static Float:fOrigin[3], Float:fAngles[3], Float:fDirection[3], iBullet;
            GetAttachmentData(id, TURRET_L_GUN_ATTACHMENT, fOrigin, fAngles);
            GetTurretGunAngles(id, fAngles);
            angle_vector(fAngles, ANGLEVECTOR_FORWARD, fDirection);
            fDirection[2] *= -1.0;
            iBullet = FireBullet(fOrigin, fDirection, get_pcvar_float(g_pCvar_projectile_speed[iType]), g_aTurretData[iType][TURRET_BULLET_GRAVITY], 10.0, g_aTurretData[iType][TURRET_BULLET_DAMAGE], g_aTurretData[iType][TURRET_BULLET_SPRITE], .owner = id, .szClass = TURRETS_BULLETS_CLASSNAME[iType]);
            emit_sound(id, CHAN_WEAPON, g_szTurretFireSounds[iType][ random(sizeof g_szTurretFireSounds[]) ], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

            switch( pev(id, PEV_TURRET_TYPE) )
            {
                case STATIONARY_GUARDIAN:
                {
                    set_rendering(iBullet, .render=kRenderTransAdd, .amount=255);
                }
                case STATIONARY_SENTRY:
                {
                    set_rendering(iBullet, .render=kRenderTransAlpha, .amount=000);
                    set_pev(iBullet, pev_effects, EF_MUZZLEFLASH);
                    EF_BeamFollow(fOrigin, iBullet, g_pSprite_S, 1, 1, {175,155,096,255});
                }
            }
        }
        case EVENT_FIRE_WEAPON_RIGHT:
        {
            static Float:fOrigin[3], Float:fAngles[3], Float:fDirection[3], iBullet;
            GetAttachmentData(id, TURRET_R_GUN_ATTACHMENT, fOrigin, fAngles);
            GetTurretGunAngles(id, fAngles);
            angle_vector(fAngles, ANGLEVECTOR_FORWARD, fDirection);
            fDirection[2] *= -1.0;
            iBullet = FireBullet(fOrigin, fDirection, get_pcvar_float(g_pCvar_projectile_speed[iType]), g_aTurretData[iType][TURRET_BULLET_GRAVITY], 10.0, g_aTurretData[iType][TURRET_BULLET_DAMAGE], g_aTurretData[iType][TURRET_BULLET_SPRITE], .owner = id, .szClass = TURRETS_BULLETS_CLASSNAME[iType]);
            emit_sound(id, CHAN_WEAPON, g_szTurretFireSounds[iType][ random(sizeof g_szTurretFireSounds[]) ], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

            switch( pev(id, PEV_TURRET_TYPE) )
            {
                case STATIONARY_GUARDIAN:
                {
                    set_rendering(iBullet, .render=kRenderTransAdd, .amount=255);
                }
                case STATIONARY_SENTRY:
                {
                    set_rendering(iBullet, .render=kRenderTransAlpha, .amount=000);
                    set_pev(iBullet, pev_effects, EF_MUZZLEFLASH);
                    EF_BeamFollow(fOrigin, iBullet, g_pSprite_S, 1, 1, {175,155,096,255});
                }
            }
        }
    }
}

EF_BeamFollow(const Float:fOrigin[3], const target, const pSpriteIndex, const life, const width, const iRGBA[4])
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, fOrigin);
    write_byte(TE_BEAMFOLLOW);
    write_short(target);
    write_short(pSpriteIndex);
    write_byte(life);
    write_byte(width);
    write_byte(iRGBA[0]);
    write_byte(iRGBA[1]);
    write_byte(iRGBA[2]);
    write_byte(iRGBA[3]);
    message_end();
}

GetModelBoneControllersData(const model[], RetArray[MAX_BONE_CONTROLLERS][BONE_CONTROLLERS_DATA])
{
    new f = fopen( model, "rb" );

    if( f )
    {
        const studioHeader_NumBoneControllers = 148;

        new NumBoneControllers, BoneControllerIndex;

        fseek( f, studioHeader_NumBoneControllers, SEEK_SET );
        {
            fread( f, NumBoneControllers, BLOCK_INT );
            fread( f, BoneControllerIndex, BLOCK_INT );
        }
        fseek( f, BoneControllerIndex, SEEK_SET );

        for(new i, any:iTemp; i < NumBoneControllers; i++)
        {
            fread( f, RetArray[i][BONE_CONTROLLER_BONE_ID], BLOCK_INT );
            fread( f, RetArray[i][BONE_CONTROLLER_TYPE], BLOCK_INT );
            fread( f, RetArray[i][BONE_CONTROLLER_START], BLOCK_INT );
            fread( f, RetArray[i][BONE_CONTROLLER_END], BLOCK_INT );
            fread( f, RetArray[i][BONE_CONTROLLER_REST], BLOCK_INT );
            fread( f, RetArray[i][BONE_CONTROLLER_INDEX], BLOCK_INT );

            if(RetArray[i][BONE_CONTROLLER_START] > RetArray[i][BONE_CONTROLLER_END])
            {
                iTemp = RetArray[i][BONE_CONTROLLER_START];
                RetArray[i][BONE_CONTROLLER_START] = RetArray[i][BONE_CONTROLLER_END];
                RetArray[i][BONE_CONTROLLER_END] = iTemp;
                RetArray[i][BONE_CONTROLLER_REVERSED] = true;
            }
        }

        fclose( f );
    }
}

RetrieveTurretGunPointOffsets(const iType, const iAttachmentID)
{
    new Float:fVAngles[3];
    new ent = CreateTurret(Float:{0.0,0.0,0.0}, Float:{0.0,0.0,0.0}, .iType = iType);

    if(!ent) return 0;

    new xArray[ANIMATION_DATA];
    ArrayGetArray(Array:g_animArrays[iType][ACT_IDLE], random(g_sizeAnimArrays[iType][ACT_IDLE]), xArray);
    PlayAnimation(ent, xArray[ANIMATION_SEQUENCE],
        xArray[ANIMATION_FPS], 1.0, xArray[ANIMATION_FRAMES], ACT_IDLE,
        .bInLOOP=false,
        .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
        .pArrayEventSize=xArray[ANIMATION_EVENTS]);
    set_pev(ent, pev_frame, xArray[ANIMATION_FRAMES]);

    engfunc(EngFunc_GetAttachment, ent, iAttachmentID, g_fvTurretGunPoint[iType][iAttachmentID], fVAngles);

    set_pev(ent, pev_nextthink, get_gametime() + 0.5);
    set_pev(ent, pev_flags, FL_KILLME);
    return 1;
}

GetAttachmentData(const id, const iAttachmentID, Float:fRetOrigin[3], Float:fRetAngles[3])
{
    static Float:fVAngles[3], Float:fOrigin[3], iType, Float:cosPitch, Float:cosYaw, Float:sinPitch, Float:sinYaw,
    Float:x, Float:y, Float:z;
    GetTurretGunAngles(id, fVAngles);
    pev(id, pev_origin, fOrigin);
    iType = pev(id, PEV_TURRET_TYPE);
    cosPitch = floatcos(fVAngles[0],degrees);
    sinPitch = floatsin(fVAngles[0],degrees);
    cosYaw = floatcos(fVAngles[1],degrees);
    sinYaw = floatsin(fVAngles[1],degrees);
    x = g_fvTurretGunPoint[iType][iAttachmentID][0];
    y = g_fvTurretGunPoint[iType][iAttachmentID][1];
    z = g_fvTurretGunPoint[iType][iAttachmentID][2];
    fRetOrigin[0] = fOrigin[0] + cosYaw * x - sinYaw * cosPitch * y + sinYaw * sinPitch * z;
    fRetOrigin[1] = fOrigin[1] + sinYaw * x + cosYaw * cosPitch * y + cosYaw * sinPitch * z;
    fRetOrigin[2] = fOrigin[2] + sinPitch * xs_vec_len_2d(g_fvTurretGunPoint[iType][iAttachmentID]) + z;
    xs_vec_copy(fRetAngles, Float:{0.0, 0.0, 0.0});
}

#if 1 == 0
GetAttachmentData(const id, const iAttachmentID, Float:fRetOrigin[3], Float:fRetAngles[3])
{
    static szModel[64], xArray[ANIMATION_DATA], Float:fAnimeTime, Float:fFrame;
    pev(id, pev_model, szModel, charsmax(szModel));
    getSequenceData( szModel, pev(id, pev_sequence), xArray );
    pev( id, pev_animtime, fAnimeTime);
    pev( id, pev_frame, fFrame );
    set_pev( id, pev_frame, (get_gametime() - fAnimeTime) * xArray[ANIMATION_FPS] );

    static Float:fStart[3], Float:fVAngles[3], Float:fOrigin[3], Float:fVec[3];
    xs_vec_copy(fVAngles, Float:{0.0, 0.0, 0.0});
    engfunc(EngFunc_GetAttachment, id, iAttachmentID, fStart, fVAngles);
    set_pev( id, pev_frame, fFrame );

    pev(id, pev_origin, fOrigin);
    fOrigin[2] = fStart[2];

    xs_vec_sub(fStart, fOrigin, fVec);
    xs_vec_normalize(fVec, fVec);
    vector_to_angle(fVec, fVec);
    xs_vec_add(fVec, fVAngles, fVAngles);
    pev(id, pev_angles, fVec);
    xs_vec_add(fVAngles, fVec, fVAngles);

    xs_vec_copy(fStart, fRetOrigin);
    xs_vec_copy(fVAngles, fRetAngles);
}
#endif

EF_Explosion(Float:fOrigin[3], iSprite, iScale=10, iFrameRate=10, iFlags=0, iDest=MSG_PVS, iTarget=0)
{
    engfunc(EngFunc_MessageBegin, iDest, SVC_TEMPENTITY, fOrigin, iTarget);
    write_byte(TE_EXPLOSION)
    engfunc(EngFunc_WriteCoord, fOrigin[0]);
    engfunc(EngFunc_WriteCoord, fOrigin[1]);
    engfunc(EngFunc_WriteCoord, fOrigin[2]);
    write_short(iSprite)
    write_byte(iScale)
    write_byte(iFrameRate)
    write_byte(iFlags)
    message_end();
}

draw_spark(Float:fOrigin[3])
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, fOrigin, 0);
    write_byte(TE_SPARKS);
    engfunc(EngFunc_WriteCoord, fOrigin[0]);
    engfunc(EngFunc_WriteCoord, fOrigin[1]);
    engfunc(EngFunc_WriteCoord, fOrigin[2]);
    message_end();
}
