/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <jailbreak_core>

#define PLUGIN  "[JB] DAY: TTT - Truth Gun"
#define AUTHOR  "Natsheh"

#define WEAPON_TYPE_TRUTH_GUN 9200
#define PEV_WEAPON_TYPE pev_iuser4
#define CBASE_PLAYER_WEAPON_LINUX_DIFF 4
#define CBASE_PLAYER_LINUX_DIFF 5

#define IsPlayer(%1) ( 1 <= %1 <= MAX_PLAYERS )

const OFFSET_PDATA_SAFE = 2;

new g_bHasTruthGun, TRUTH_GUN_V_MDL[64] = "models/v_deagle.mdl", TRUTH_GUN_P_MDL[64] = "models/p_deagle.mdl";

const m_iClip = 51;
const m_pActiveItem = 373;

public plugin_precache()
{
    jb_ini_get_keyvalue("TROUBLE_IN_TERRORIST_TOWN", "TRUTH_GUN_V_MDL", TRUTH_GUN_V_MDL, charsmax(TRUTH_GUN_V_MDL));
    jb_ini_get_keyvalue("TROUBLE_IN_TERRORIST_TOWN", "TRUTH_GUN_P_MDL", TRUTH_GUN_P_MDL, charsmax(TRUTH_GUN_P_MDL));
    PRECACHE_WEAPON_VIEW_MODEL(TRUTH_GUN_V_MDL);
    PRECACHE_WEAPON_PLAYER_MODEL(TRUTH_GUN_P_MDL);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    RegisterHam(Ham_Item_AttachToPlayer, "weapon_deagle", "TruthGun_AttachToPlayer_Post", .Post=true);

    RegisterHam(Ham_TakeDamage, "player", "fw_PlayerTakeDamage_pre", .Post = false);

    register_concmd("jb_give_truthgun", "concmd_give_truthgun", ADMIN_LEVEL_A, "gives a truth gun to a player");
}

public concmd_give_truthgun(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    new sTarget[32];
    read_argv(1, sTarget, 31);

    if(sTarget[0] == '@')
    {
        new players[32], pnum;
        switch( sTarget[1] )
        {
            case 'C', 'c': get_players(players, pnum, "ae", "CT");
            case 'T', 't': get_players(players, pnum, "ae", "TERRORIST");
            default: get_players(players, pnum, "a");
        }

        for(new i = 0, player; i < pnum; i++)
        {
            player = players[i];
            GiveTruthGun(player);
        }

        console_print(id, "You have given %c%c Truth Guns!", sTarget[0], sTarget[1]);
        return PLUGIN_HANDLED;
    }

    new target = cmd_target(id, sTarget, CMDTARGET_ALLOW_SELF|CMDTARGET_ONLY_ALIVE);
    if(!target) return PLUGIN_HANDLED;

    get_user_name(target, sTarget, 31);
    GiveTruthGun(target);
    cprint_chat(id, _, "you gave ^3%s ^1a ^4Truth Gun!", sTarget);
    console_print(id, "You gave %s a Truth Gun!", sTarget);

    return PLUGIN_HANDLED;
}

public TruthGun_AttachToPlayer_Post(iEnt, id)
{
    if(!check_flag(g_bHasTruthGun, id))
    {
        return;
    }

    set_pev(iEnt, PEV_WEAPON_TYPE, WEAPON_TYPE_TRUTH_GUN);
    remove_flag(g_bHasTruthGun,id);
    set_pdata_int(iEnt, m_iClip, 1, CBASE_PLAYER_WEAPON_LINUX_DIFF);
}

public fw_PlayerTakeDamage_pre(victim, inflictor, attacker, Float:fDamage, iDmgBits)
{
    if(IsPlayer(attacker) && attacker != victim && IsUserHoldingTruthGun(attacker))
    {
        if(check_flag( get_xvar_num(get_xvar_id("g_iTraitors")) ,victim))
        {
            // Instant kill!!!
            SetHamParamFloat(4, 9999.0);
            SetHamParamInteger(5, iDmgBits|DMG_ALWAYSGIB);
            return HAM_HANDLED;
        }
        else if(check_flag( get_xvar_num(get_xvar_id("g_iInnocents")) ,victim))
        {
            SetHamParamFloat(4, 0.0);

            new pTruthGun = GetPlayerTruthGun(attacker);

            if( pTruthGun > 0 )
            {
                set_pev(pTruthGun, pev_classname, "Truth Gun");
            }

            ExecuteHamB(Ham_TakeDamage, attacker, pTruthGun, attacker, 9999.0, DMG_BULLET);
            return HAM_HANDLED;
        }
    }

    return HAM_IGNORED;
}

new const g_szDayName_TTT[] = "Trouble In the Terrorist Town";

public jb_day_started(iDayid)
{
    static iTTTDayID = 0; if(!iTTTDayID) iTTTDayID = jb_get_dayid_byname(g_szDayName_TTT);

    if(iDayid == iTTTDayID)
    {
        new players[32], pnum;
        get_players(players, pnum, "ah")

        for(new i, BitsDetectives = get_xvar_num(get_xvar_id("g_iDetectives")); i < pnum ; i++ )
        {
            if(check_flag(BitsDetectives, players[i]))
            {
                GiveTruthGun(players[i]);
            }
        }
    }
}

GiveTruthGun(id)
{
    set_flag(g_bHasTruthGun,id);

    if(pev(id, pev_weapons) & (1<<CSW_DEAGLE))
    {
        new ent;
        while( (ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "weapon_deagle")) && pev(ent, pev_owner) != id ) { }

        if( pev_valid(ent) )
        {
            ExecuteHamB(Ham_Item_AttachToPlayer, ent, id);
        }
    }
    else
    {
        give_item(id, "weapon_deagle");
    }

    cs_set_user_bpammo(id, CSW_DEAGLE, 0);
}


bool:IsUserHoldingTruthGun(id)
{
    if(pev_valid(id) != OFFSET_PDATA_SAFE)
    {
        return false;
    }

    static ent; ent = get_pdata_cbase(id, m_pActiveItem, CBASE_PLAYER_LINUX_DIFF);

    if(pev_valid(ent) == OFFSET_PDATA_SAFE && pev(ent, PEV_WEAPON_TYPE) == WEAPON_TYPE_TRUTH_GUN)
    {
        return true;
    }

    return false;
}

GetPlayerTruthGun(id)
{
    static entWeapon, aWeapons[32], WCount;
    get_user_weapons(id, aWeapons, WCount);

    if( WCount > 0 )
    {
        while( WCount-- > 0 )
        {
            entWeapon = aWeapons[ WCount ];

            if(pev(entWeapon, PEV_WEAPON_TYPE) == WEAPON_TYPE_TRUTH_GUN)
            {
                return entWeapon;
            }
        }
    }

    return 0;
}
