/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <jailbreak_core>

#define PLUGIN  "[JB] SHOP: BOOMBOX"
#define AUTHOR  "Natsheh"

#define MAX_SONG_NAME_LEN 32
#define MAX_SONG_DIRECTORY_LEN 64

#define PEV_TYPE pev_iuser4
#define TYPE_BOOMBOX 5000

enum _:SONG_DATA
{
    SONG_NAME[MAX_SONG_NAME_LEN],
    SONG_DIRECTORY[MAX_SONG_DIRECTORY_LEN]
}

new const ITEM_NAME[] = "BoomBox",
          ITEM_INFO[] = "a loud music box",
          g_boombox_classname[] = "weapon_hegrenade";
 const ITEM_COST = 5000;
 const ITEM_TEAM = TEAM_ANY;

const m_pPlayer = 41;

new g_BOOMBOX_PMODEL[MAX_FILE_DIRECTORY_LEN] = "models/jailbreak/p_boombox.mdl",
    g_pShopItem_BoomBox,
    g_has_boombox,
    g_last_track = -1,
    g_user_track[MAX_PLAYERS+1],
    Array:g_pSongs_data_array;

public plugin_precache()
{
    g_pSongs_data_array = ArrayCreate(SONG_DATA,1);

    if(g_pSongs_data_array == Invalid_Array)
    {
        set_fail_state("Cannot create dynamic array!");
        return;
    }

    jb_ini_get_keyvalue("BOOMBOX", "BOOMBOX_P_MDL", g_BOOMBOX_PMODEL, charsmax(g_BOOMBOX_PMODEL));
    PRECACHE_WEAPON_PLAYER_MODEL(g_BOOMBOX_PMODEL);

    new xArray[ SONG_DATA ], szKey[64], iNum = 1;
    formatex(szKey, charsmax(szKey), "TRACK#1");

    while ( (jb_ini_get_keyvalue("BOOMBOX", szKey, xArray[ SONG_DIRECTORY ], charsmax(xArray[ SONG_DIRECTORY ])) == FILE_KEYVALUE_BUFFERED) )
    {
        formatex(szKey, charsmax(szKey), "TRACK#%d_NAME", iNum);
        jb_ini_get_keyvalue("BOOMBOX", szKey, xArray[ SONG_NAME ], charsmax(xArray[ SONG_NAME ]));
        precache_sound(xArray[ SONG_DIRECTORY ][6]);
        ArrayPushArray(g_pSongs_data_array, xArray);
        g_last_track ++;

        formatex(szKey, charsmax(szKey), "TRACK#%d", ++iNum);
        xArray[ SONG_DIRECTORY ][0] = xArray[ SONG_NAME ][0] = EOS;
    }

    if(g_last_track == -1)
    {
        set_fail_state("There're no tracks in the boombox!?");
    }
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    g_pShopItem_BoomBox = register_jailbreak_shopitem(ITEM_NAME, ITEM_INFO, ITEM_COST, ITEM_TEAM);

    RegisterHam(Ham_Weapon_PrimaryAttack,  g_boombox_classname, "fw_boombox_primary_attack_pre");
    RegisterHam(Ham_Weapon_SecondaryAttack, g_boombox_classname, "fw_boombox_secondary_attack_pre");
    RegisterHam(Ham_Item_Deploy, g_boombox_classname, "fw_item_deploy_post_boombox", true);
    RegisterHam(Ham_Item_Holster, g_boombox_classname, "fw_item_holster_post_boombox", true);

    register_menu("BOOMBOX", MENU_KEY_1|MENU_KEY_2, "menu_handler");

    register_concmd("jb_give_boombox", "concmd_give_boombox");
}

public concmd_give_boombox(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    new szArg1[32];
    read_argv(1, szArg1, charsmax(szArg1));
    remove_quotes(szArg1);

    new target = cmd_target(id, szArg1, CMDTARGET_ALLOW_SELF|CMDTARGET_ONLY_ALIVE);

    if(target)
    {
        give_player_boombox(target);
    }
    else if(szArg1[0] == '@')
    {
        new players[32], pnum;

        switch( szArg1[1] )
        {
            case 'T', 't', 'P', 'p': get_players(players, pnum, "ahe", "TERRORIST");
            case 'C', 'c', 'G', 'g': get_players(players, pnum, "ahe", "CT");
            default: get_players(players, pnum, "ah");
        }

        for(new i; i < pnum; i++)
        {
            give_player_boombox(players[i]);
        }
    }

    return PLUGIN_HANDLED;
}

public jb_shop_item_preselect(id, itemid)
{
    if(itemid == g_pShopItem_BoomBox)
    {
        if(has_boombox(id))
        {
            return JB_MENU_ITEM_DONT_SHOW;
        }
    }

    return JB_IGNORED;
}

public jb_shop_item_bought(id, itemid)
{
    if(itemid == g_pShopItem_BoomBox)
    {
        give_player_boombox(id);
    }
}

public fw_item_holster_post_boombox(const ent)
{
    if( pev(ent, PEV_TYPE) == TYPE_BOOMBOX )
    {
        new id = get_pdata_cbase(ent, m_pPlayer, 4);
        if(!is_user_connected(id)) return;

        new xArray[SONG_DATA];
        ArrayGetArray(g_pSongs_data_array, g_user_track[id], xArray);
        emit_sound(id, CHAN_ITEM, xArray[SONG_DIRECTORY][6], 0.0, ATTN_NORM, SND_STOP, PITCH_NORM);
        menu_cancel(id);
        show_menu(id, 0, " ^n ");
    }
}

public fw_item_deploy_post_boombox(const ent)
{
    if( pev(ent, PEV_TYPE) == TYPE_BOOMBOX )
    {
        new id = get_pdata_cbase(ent, m_pPlayer, 4);
        set_pev(id, pev_viewmodel2, "");
        set_pev(id, pev_weaponmodel2, g_BOOMBOX_PMODEL);
        set_task(1.0, "display_track_menu", id);
    }
}

public display_track_menu(id)
{
    if(is_user_connected(id) && has_boombox_deployed(id))
    {
        boombox_track_menu(id, g_user_track[id]);
    }
}

public fw_boombox_primary_attack_pre(wEnt)
{
    static id; id = get_pdata_cbase(wEnt, m_pPlayer, 4);

    if(!has_boombox_deployed(id)) return HAM_IGNORED;

    static Float:fLastCall[ MAX_PLAYERS + 1 ] = { 0.0, 0.0, ... };

    if(get_gametime() <= fLastCall[id] || g_user_track[id] >= g_last_track)
    {
        return HAM_SUPERCEDE;
    }

    fLastCall[id] = get_gametime() + 0.5;
    boombox_track_menu(id, ++g_user_track[id]);
    return HAM_SUPERCEDE;
}

public fw_boombox_secondary_attack_pre(wEnt)
{
    static id; id = get_pdata_cbase(wEnt, m_pPlayer, 4);

    if(!has_boombox_deployed(id)) return HAM_IGNORED;

    static Float:fLastCall[ MAX_PLAYERS + 1 ] = { 0.0, 0.0, ... };

    if(get_gametime() <= fLastCall[id] || g_user_track[id] <= 0)
    {
        return HAM_SUPERCEDE;
    }

    fLastCall[id] = get_gametime() + 0.5;
    boombox_track_menu(id, --g_user_track[id]);
    return HAM_SUPERCEDE;
}

bool:has_boombox(id)
{
    new ent;
    while( (ent = engfunc(EngFunc_FindEntityByString, ent, "classname", g_boombox_classname)) > 0 && pev(ent, pev_owner) != id ) { }
    if(ent > 0)
    {
        if(pev(ent, PEV_TYPE) == TYPE_BOOMBOX)
        {
            return true;
        }
    }

    return false;
}

bool:has_boombox_deployed(id)
{
    if(!check_flag(g_has_boombox,id)) return false;

    static szWpnPModel[MAX_FILE_DIRECTORY_LEN];
    pev(id, pev_weaponmodel2, szWpnPModel, charsmax(szWpnPModel));
    if(!equal(szWpnPModel, g_BOOMBOX_PMODEL)) return false;

    return true;
}

give_player_boombox(id)
{
    set_flag(g_has_boombox,id);
    g_user_track[id] = 0;

    new ent;
    if((ent=give_item(id, g_boombox_classname)) > 0)
    {
        client_cmd(id, g_boombox_classname);
        set_pev(ent, PEV_TYPE, TYPE_BOOMBOX);
        ExecuteHamB(Ham_Item_Deploy, ent);
    }
    else
    {
        ent = -1;
        while( (ent = engfunc(EngFunc_FindEntityByString, ent, "classname", g_boombox_classname)) > 0 && pev(ent, pev_owner) != id ) { }
        if(ent > 0)
        {
            client_cmd(id, g_boombox_classname);
            set_pev(ent, PEV_TYPE, TYPE_BOOMBOX);
            ExecuteHamB(Ham_Item_Deploy, ent)
        }
    }
}

boombox_track_menu(const id, const track=0, bool:bPlayTrack=true)
{
    static szText[MAX_MENU_LENGTH], xArray[ SONG_DATA ];
    new iLen = formatex(szText, charsmax(szText), "\rBOOMBOX TRACK #%d/%d: ^n^n", track+1, g_last_track+1);

    ArrayGetArray(g_pSongs_data_array, track, xArray);
    iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "\r* \yCurrent song [ %16s ] ^n^n", xArray[SONG_NAME]);

    iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "\w1. REPLAY^n");
    iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "\r2. STOP^n^n");

    iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "\w[\rLMB\w] \rNext track!^n");
    iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "\w[\rRMB\w] \yPrevious track!^n");

    show_menu(id, MENU_KEY_1|MENU_KEY_2, szText, _, "BOOMBOX");

    if ( bPlayTrack ) emit_sound(id, CHAN_ITEM, xArray[SONG_DIRECTORY][6], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    return PLUGIN_HANDLED;
}

public menu_handler(id, key)
{
    switch( key )
    {
        case 0: boombox_track_menu(id, g_user_track[id]);
        case 1: {
            new iTrack = g_user_track[id], xArray[SONG_DATA];

            boombox_track_menu(id, iTrack, false);
            ArrayGetArray(g_pSongs_data_array, iTrack, xArray);
            emit_sound(id, CHAN_ITEM, xArray[SONG_DIRECTORY][6], 0.0, ATTN_NORM, SND_STOP, PITCH_NORM);
        }
    }

    return PLUGIN_HANDLED;
}
