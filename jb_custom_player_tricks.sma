/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <fakemeta>
#include <reapi>

#define PLUGIN  "[JB] Player Custom Animation Tricks"
#define VERSION "1.0"
#define AUTHOR  "Natsheh"

#define VIEW_BACK_100_UNITS -100.0
#define VIEW_FIRST_PERSON 0.0
forward OnSetAnimation(id, anim);
native set_player_camera(const id, const VIEW_CAMERA_OFFSETS:flViewOffset);

enum
{
    PLAYER_IDLE
}

enum any:anims_data(+=1)
{
    anim_chestpound = 111,
    anim_danceB,
    anim_fistpump,
    anim_flip,
    anim_lay,
    anim_meditate,
    anim_mjbeatit,
    anim_pushup,
    anim_sit2,
    anim_wave
}

new const g_szSequences[][] =
{
    "anim_chestpound",
    "anim_danceB",
    "anim_fistpump",
    "anim_flip",
    "anim_lay",
    "anim_meditate",
    "anim_mjbeatit",
    "anim_pushup",
    "anim_sit2",
    "anim_wave",
    "npc_run",
    "npc_walk"
}

new const g_szTricksNames[][] = {
    "Chest Pound",
    "Dance",
    "Fistpump",
    "Back flip",
    "Lay down",
    "Meditate",
    "Beat it",
    "Pushups",
    "Sit",
    "Wave"
}

new g_iTricksMenuID = INVALID_HANDLE, any:g_UserCustomAnimation[MAX_PLAYERS+1], bool:g_bReGameDLL;

public plugin_end()
{
    if(g_iTricksMenuID != INVALID_HANDLE)
    {
        menu_destroy(g_iTricksMenuID);
    }
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    g_iTricksMenuID = CreateTricksMenu();

    register_clcmd("say /tricks", "clcmd_tricks");

    if(is_regamedll())
    {
        g_bReGameDLL = true;
        RegisterHookChain(RG_CBasePlayer_SetAnimation, "OnSetAnimation", .post = 0);
    }
}

public client_putinserver(id)
{
    g_UserCustomAnimation[id] = PLAYER_IDLE;
}

public OnSetAnimation( player,  Animation )
{
    if(any:Animation == PLAYER_IDLE)
    {
        if(g_UserCustomAnimation[player] != PLAYER_IDLE)
        {
            return g_bReGameDLL ? HC_SUPERCEDE : PLUGIN_HANDLED;
        }
    }
    else if(g_UserCustomAnimation[player] != PLAYER_IDLE)
    {
        g_UserCustomAnimation[player] = PLAYER_IDLE;
        set_player_camera(player, VIEW_FIRST_PERSON);
    }

    return g_bReGameDLL ? HC_CONTINUE : PLUGIN_CONTINUE;
}

public clcmd_tricks(id)
{
    if(!is_user_alive(id))
    {
        return PLUGIN_HANDLED;
    }

    if(g_iTricksMenuID != INVALID_HANDLE)
    {
        menu_display(id, g_iTricksMenuID);
    }

    return PLUGIN_HANDLED;
}

PlayAnimation(const id, const szSequence[], Float:fFrameRate = 1.0)
{
    static Float:fGroundSpeed, bool:bLoops;
    set_pev(id,
        pev_sequence,
        lookup_sequence(id, szSequence, fFrameRate, bLoops, fGroundSpeed)
        );
    set_ent_data(id, "CBaseAnimating", "m_fSequenceLoops", bLoops);
    set_ent_data_float(id, "CBaseAnimating", "m_flFrameRate", fFrameRate);
    set_ent_data_float(id, "CBaseAnimating", "m_flGroundSpeed", fGroundSpeed);
}

CreateTricksMenu()
{
    new iMenu = menu_create("Animation tricks^nPlay a trick!", "mhandler_tricks");

    new szData[8];
    num_to_str(any:PLAYER_IDLE, szData, charsmax(szData));
    menu_additem(iMenu, "Idle", szData);

    const maxloop = sizeof g_szTricksNames;

    for( new i; i < maxloop; i++ )
    {
        num_to_str(i + anim_chestpound, szData, charsmax(szData));
        menu_additem(iMenu, g_szTricksNames[ i ], szData);
    }

    return iMenu;
}

public mhandler_tricks(id, menu, item)
{
    switch( item )
    {
        case MENU_EXIT, MENU_TIMEOUT, MENU_BACK, MENU_MORE: return PLUGIN_HANDLED;
        default:
        {
            if(!is_user_alive(id))
            {
                return PLUGIN_HANDLED;
            }

            new szData[8];
            menu_item_getinfo(menu, item, .info = szData, .infolen = charsmax(szData));
            g_UserCustomAnimation[id] = str_to_num(szData);

            if(g_UserCustomAnimation[id] == PLAYER_IDLE)
            {
                return PLUGIN_HANDLED;
            }

            set_player_camera(id, VIEW_BACK_100_UNITS);
            PlayAnimation(id, g_szSequences[g_UserCustomAnimation[id] - anim_chestpound]);
        }
    }

    return PLUGIN_HANDLED;
}
