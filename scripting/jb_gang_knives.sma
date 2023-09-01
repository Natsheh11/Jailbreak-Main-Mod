/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <amxmisc>
#include <jailbreak_core>
#include <jailbreak_gangs>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <nvault>

#define PLUGIN  "[JB] GANG : Knives"
#define AUTHOR  "Natsheh"

#define NO_ACCESS (1<<26)

new g_szGangKnivesViewSkins[MAX_RESOURCE_PATH_LENGTH] = "models/jailbreak/v_knives_packv1.mdl";
new g_szGangKnivesPlayerSkins[MAX_RESOURCE_PATH_LENGTH] = "models/jailbreak/p_knives_packv1.mdl";

new g_user_knife[MAX_PLAYERS+1] = { -1, -1, ... }, g_user_pmodel[MAX_PLAYERS+1], g_nVaultKnife = INVALID_HANDLE;

// CBasePlayerItem
stock const m_pPlayer = 41 // CBasePlayer *
stock const m_iId = 43 // CBasePlayer *
// CBasePlayerWeapon
stock const m_flNextPrimaryAttack = 46 // float
stock const m_flNextSecondaryAttack = 47 // float
stock const m_flTimeWeaponIdle = 48 // float
// CBaseMonster
stock const m_flNextAttack = 83 // float
// CBasePlayer
stock const m_pActiveItem = 373 // CBasePlayerItem *

const PEV_OBSERVER_MODE = pev_iuser1;
const PEV_SPECTATOR_TARGET = pev_iuser2;

#define PEV_KNIFE_TYPE pev_impulse
#define PLAYER_KNIFE_GET_TYPE(%1) g_user_knife[%1]
#define PLAYER_KNIFE_SET_TYPE(%1,%2) g_user_knife[%1] = %2
#define XO_PLAYER_DIFFERENT 5
#define XO_WEAPON_DIFFERENT 4
#define IsPlayer(%1) (1 <= %1 <= MAX_PLAYERS)

new const g_GangKillsKnifeAccessing[] = {
    1000,
    2500,
    5000,
    6500,
    8000,
    10000
}

enum any:KNIVES_TYPES (+=1)
{
    KNIFE_NONE = -1,
    KNIFE_HUNTER,
    KNIFE_DIAMOND_SWORD,
    KNIFE_ARMY,
    KNIFE_FROZEN_NAILED_BAT,
    KNIFE_DEVIL,
    KNIFE_MAJESTIC
}

new const g_szKnivesNames[][] = {
    "Hunter Knife",
    "Diamond Sword",
    "Army Knife",
    "Frozen Nailed Bat",
    "Devil Knife",
    "Majestic Knife"
}

public plugin_precache()
{
    precache_model(g_szGangKnivesViewSkins);
    precache_model(g_szGangKnivesPlayerSkins);
}

public plugin_end()
{
    nvault_close(g_nVaultKnife);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    jb_gang_menu_additem("GANG_MENU_KNIVES", "", "gang_menu_knives_select");

    register_forward(FM_UpdateClientData, "Forward_UpdateClientData_Post", 1);
    RegisterHam(Ham_Item_AddToPlayer, "weapon_knife", "HamF_Item_AddToPlayer_Post", 1);
    RegisterHam(Ham_Item_Deploy, "weapon_knife", "HamF_Item_Deploy");
    RegisterHam(Ham_Item_Deploy, "weapon_knife", "HamF_Item_Deploy_Post", 1);
    RegisterHam(Ham_Item_Holster, "weapon_knife", "HamF_Item_Holster_Post", 1);
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "HamF_Weapon_PrimaryAttack");
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "HamF_Weapon_PrimaryAttack_Post", 1);
    RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "HamF_Weapon_SecondaryAttack");
    RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "HamF_Weapon_SecondaryAttack_Post", 1);
    RegisterHam(Ham_Weapon_WeaponIdle, "weapon_knife", "HamF_Weapon_WeaponIdle");
    RegisterHam(Ham_Weapon_WeaponIdle, "weapon_knife", "HamF_Weapon_WeaponIdle_Post", 1);

    register_event("CurWeapon", "event_curweapon_knife", "b", "1=1", "2=29", "3=0");

    g_nVaultKnife = nvault_open("jb_gang_knives");
}

public event_curweapon_knife(id)
{
    if(pev(id, PEV_OBSERVER_MODE) != OBS_IN_EYE)
    {
        return;
    }

    static iTarget; iTarget = pev(id, PEV_SPECTATOR_TARGET);

    if( IsPlayer(iTarget) && PLAYER_KNIFE_GET_TYPE(iTarget) != KNIFE_NONE)
    {
        message_begin(MSG_ONE, SVC_WEAPONANIM, _, id);
        write_byte(pev(iTarget, pev_weaponanim));
        write_byte(PLAYER_KNIFE_GET_TYPE(iTarget));
        message_end();
    }
}

public client_authorized(id)
{
    LoadKnife(id);
}

public client_disconnected(id)
{
    PLAYER_KNIFE_SET_TYPE(id, KNIFE_NONE);

    if( g_user_pmodel[id] && pev_valid(g_user_pmodel[id]) )
    {
        new pModel = g_user_pmodel[id];
        set_pev(pModel, pev_flags, FL_KILLME);
        dllfunc(DLLFunc_Think, pModel);
    }

    g_user_pmodel[id] = 0;
}

public Forward_UpdateClientData_Post( id, SendWeapons, CD_Handle )
{
    if( SendWeapons )
    {
        if( !is_user_alive(id) )
        {
            if( pev(id, PEV_OBSERVER_MODE) != OBS_IN_EYE )
            {
                return FMRES_IGNORED;
            }

            id = pev(id, PEV_SPECTATOR_TARGET);

            if( !is_user_alive(id) )
            {
                return FMRES_IGNORED;
            }
        }

        static iEnt;
        iEnt = get_pdata_cbase(id, m_pActiveItem, XO_PLAYER_DIFFERENT);

        if( pev_valid(iEnt) )
        {
            static szClass[24];
            pev(iEnt, pev_classname, szClass, charsmax(szClass));
            if( equal(szClass, "weapon_knife") && pev(iEnt, PEV_KNIFE_TYPE) != KNIFE_NONE)
            {
                set_cd(CD_Handle, CD_ID, 0);
                return FMRES_HANDLED;
            }
        }
    }
    return FMRES_IGNORED;
}

public gang_menu_knives_select( id, gang_index, const gang_name[], item_name[] )
{
    new szText[128], menu = menu_create("Knives menu ^n Select a knife", "mhandler");

    menu_additem( menu, "\yDefault" );

    new gangkills = jb_get_user_gang_kills(id);

    for(new i, maxloop = sizeof g_szKnivesNames; i < maxloop; i++)
    {
        formatex(szText, charsmax(szText), "%s %d \rkills", g_szKnivesNames[ i ], g_GangKillsKnifeAccessing[ i ]);
        menu_additem(menu, szText, .paccess = (g_GangKillsKnifeAccessing[ i ] > gangkills) ? NO_ACCESS : 0);
    }

    menu_display(id, menu);
    return PLUGIN_HANDLED;
}

public mhandler(id, menu, item)
{
    if( item == MENU_EXIT || !is_user_connected(id) || item < 0 )
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    // Always destroy the fucking menus...
    menu_destroy(menu);

    if( item == 0)
    {
        PLAYER_KNIFE_SET_TYPE(id, KNIFE_NONE);
        SaveKnife(id);

        new eKnife = find_ent_by_owner(-1, "weapon_knife", id);

        if(pev_valid(eKnife))
        {
            set_pev(eKnife, PEV_KNIFE_TYPE, KNIFE_NONE);
            client_cmd(id, "weapon_knife");
            ExecuteHamB(Ham_Item_Deploy, eKnife);
        }

        new pModel;
        if(g_user_pmodel[id] && pev_valid((pModel=g_user_pmodel[id])))
        {
            set_pev(pModel, pev_flags, FL_KILLME);
            dllfunc(DLLFunc_Think, pModel);
            g_user_pmodel[id] = 0;
        }

        return PLUGIN_HANDLED;
    }

    client_cmd(id, "weapon_knife");
    KnifeSelect(id, item - 1);
    SaveKnife(id);
    return PLUGIN_HANDLED;
}

LoadKnife(id)
{
    if(g_nVaultKnife != INVALID_HANDLE)
    {
        new szKey[32], szValue[4], iTimeStamp;
        get_user_authid(id, szKey, charsmax(szKey));

        if(nvault_lookup(g_nVaultKnife, szKey, szValue, charsmax(szValue), iTimeStamp))
        {
            PLAYER_KNIFE_SET_TYPE(id,str_to_num(szValue));
        }
        return 1;
    }
    return 0;
}

SaveKnife(id)
{
    if(g_nVaultKnife != INVALID_HANDLE)
    {
        new szType[4], szKey[32];
        get_user_authid(id, szKey, charsmax(szKey));
        num_to_str(PLAYER_KNIFE_GET_TYPE(id), szType, charsmax(szType));
        nvault_set(g_nVaultKnife, szKey, szType);
        return 1;
    }
    return 0;
}

KnifeSelect(id, KnifeType)
{
    PLAYER_KNIFE_SET_TYPE(id, KnifeType);

    new eKnife;
    if( !(eKnife = find_ent_by_owner(-1, "weapon_knife", id)) ) return;
    set_pev(eKnife, PEV_KNIFE_TYPE, KnifeType);

    new pActiveItem = get_pdata_cbase(id, m_pActiveItem, XO_PLAYER_DIFFERENT);
    if( pActiveItem <= 0 || get_pdata_int(pActiveItem, m_iId, XO_WEAPON_DIFFERENT) != CSW_KNIFE ) return;

    set_pev(id, pev_viewmodel2, g_szGangKnivesViewSkins);
    set_pev(id, pev_weaponmodel, 0);
    set_pev(id, pev_weaponmodel2, "");

    UTIL_SendWeaponAnim(id, pev(id, pev_weaponanim), KnifeType);

    new Float:fOrigin[3];
    pev(id, pev_origin, fOrigin);

    if( !g_user_pmodel[id] )
    {
        new p_model = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));

        if( p_model > 0 )
        {
            g_user_pmodel[id] = p_model;

            set_pev(p_model, pev_solid, SOLID_NOT);
            set_pev(p_model, pev_movetype, MOVETYPE_FOLLOW);
            set_pev(p_model, pev_aiment, id);
            set_pev(p_model, pev_owner, id);
            set_pev(p_model, pev_body, KnifeType);

            engfunc(EngFunc_SetModel, p_model, g_szGangKnivesPlayerSkins);
        }
    }
    else
    {
        set_pev(g_user_pmodel[id], pev_body, KnifeType);
    }
}

public HamF_Item_AddToPlayer_Post(iEnt, pPlayer)
{
    set_pev(iEnt, PEV_KNIFE_TYPE, PLAYER_KNIFE_GET_TYPE(pPlayer));
}

public HamF_Item_Deploy(iEnt)
{
    if(pev(iEnt, PEV_KNIFE_TYPE) == KNIFE_NONE) return HAM_IGNORED;

    set_msg_block(SVC_WEAPONANIM, BLOCK_ONCE);
    return HAM_IGNORED;
}

public HamF_Item_Deploy_Post(iEnt)
{
    if(pev(iEnt, PEV_KNIFE_TYPE) == KNIFE_NONE) return;
    static id; id = get_pdata_cbase(iEnt, m_pPlayer, XO_WEAPON_DIFFERENT);

    if(!IsPlayer(id) || PLAYER_KNIFE_GET_TYPE(id) == KNIFE_NONE) return;

    get_pdata_cbase(id, m_pActiveItem, XO_PLAYER_DIFFERENT)

    set_msg_block(SVC_WEAPONANIM, BLOCK_NOT);
    KnifeSelect(id, pev(iEnt, PEV_KNIFE_TYPE));
}


public HamF_Item_Holster_Post(iEnt)
{
    if(pev(iEnt, PEV_KNIFE_TYPE) == KNIFE_NONE) return;

    static id; id = get_pdata_cbase(iEnt, m_pPlayer, XO_WEAPON_DIFFERENT);

    new pModel;
    if(IsPlayer(id) && g_user_pmodel[id] && pev_valid((pModel=g_user_pmodel[id])))
    {
        set_pev(pModel, pev_flags, FL_KILLME);
        dllfunc(DLLFunc_Think, pModel);
        g_user_pmodel[id] = 0;
    }
}

public HamF_Weapon_PrimaryAttack(iEnt)
{
    if(pev(iEnt, PEV_KNIFE_TYPE) == KNIFE_NONE) return HAM_IGNORED;

    set_msg_block(SVC_WEAPONANIM, BLOCK_ONCE);
    return HAM_IGNORED;
}

public HamF_Weapon_PrimaryAttack_Post(iEnt)
{
    if(pev(iEnt, PEV_KNIFE_TYPE) == KNIFE_NONE) return;
    static id; id = get_pdata_cbase(iEnt, m_pPlayer, XO_WEAPON_DIFFERENT);

    UTIL_SendWeaponAnim( id, pev(id, pev_weaponanim), pev(iEnt, PEV_KNIFE_TYPE));
}

public HamF_Weapon_SecondaryAttack(iEnt)
{
    if(pev(iEnt, PEV_KNIFE_TYPE) == KNIFE_NONE) return HAM_IGNORED;

    set_msg_block(SVC_WEAPONANIM, BLOCK_ONCE);
    return HAM_IGNORED;
}

public HamF_Weapon_SecondaryAttack_Post(iEnt)
{
    if(pev(iEnt, PEV_KNIFE_TYPE) == KNIFE_NONE) return;
    static id; id = get_pdata_cbase(iEnt, m_pPlayer, XO_WEAPON_DIFFERENT);

    UTIL_SendWeaponAnim( id, pev(id, pev_weaponanim), pev(iEnt, PEV_KNIFE_TYPE));
}

public HamF_Weapon_WeaponIdle(iEnt)
{
    if(pev(iEnt, PEV_KNIFE_TYPE) == KNIFE_NONE) return HAM_IGNORED;

    set_msg_block(SVC_WEAPONANIM, BLOCK_ONCE);
    return HAM_IGNORED;
}

public HamF_Weapon_WeaponIdle_Post(iEnt)
{
    if(pev(iEnt, PEV_KNIFE_TYPE) == KNIFE_NONE || (get_pdata_float(iEnt, m_flTimeWeaponIdle, XO_WEAPON_DIFFERENT) > 0.0)) return;
    static id; id = get_pdata_cbase(iEnt, m_pPlayer, XO_WEAPON_DIFFERENT);

    UTIL_SendWeaponAnim( id, pev(id, pev_weaponanim), pev(iEnt, PEV_KNIFE_TYPE));
}


UTIL_SendWeaponAnim(pPlayer, iAnim, body)
{
    if( !is_user_alive(pPlayer) )
    {
        log_error(AMX_ERR_NATIVE, "Player #%d is not alive or not connected!", pPlayer);
        return;
    }

    message_begin(MSG_ONE, SVC_WEAPONANIM, _, pPlayer);
    write_byte(iAnim);
    write_byte(body);
    message_end();

    static iPlayers[MAX_PLAYERS], pnum, i, target;
    get_players(iPlayers, pnum, "bch");

    for(i = 0; i < pnum; i++)
    {
        target = iPlayers[ i ];

        if( pev(target, PEV_OBSERVER_MODE) == OBS_IN_EYE && pev(target, PEV_SPECTATOR_TARGET) == pPlayer )
        {
            message_begin(MSG_ONE, SVC_WEAPONANIM, _, target);
            write_byte(iAnim);
            write_byte(body);
            message_end();
        }
    }
}
