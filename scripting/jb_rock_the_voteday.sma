/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <jailbreak_core>

#define PLUGIN  "[JB] Rock the voteday"
#define AUTHOR  "Natsheh"

new g_pCvar_RTDPercentage, g_iPlayerRTD, g_iTotalRTD, any:g_Cells_State = JB_CELLS_CLOSE;

new const g_szCellsOpenLogMSG[] = "The cells are opened!";

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    register_clcmd("say /rtvd", "clcmd_rtd");
    register_clcmd("say /rtd", "clcmd_rtd");
    register_clcmd("say rtd", "clcmd_rtd");
    register_clcmd("say rtvd", "clcmd_rtd");

    g_pCvar_RTDPercentage = register_cvar("jb_rtvd_start_vote_percentage", "60");

    register_jailbreak_logmessages("logmessage_cells_opened", g_szCellsOpenLogMSG);
}

public client_disconnected(id)
{
    if(check_flag(g_iPlayerRTD,id))
    {
        remove_flag(g_iPlayerRTD, id);
        g_iTotalRTD--;
    }
}

public jb_round_start()
{
    g_Cells_State = JB_CELLS_CLOSE;
    g_iPlayerRTD = g_iTotalRTD = 0;
}

public logmessage_cells_opened()
{
    g_Cells_State = JB_CELLS_OPEN;
}

public clcmd_rtd(id)
{
    if(jb_get_current_duel() != JB_LR_DEACTIVATED || jb_get_current_day() != JB_DAY_CAGEDAY)
    {
        return PLUGIN_CONTINUE;
    }

    if(g_Cells_State == JB_CELLS_OPEN)
    {
        cprint_chat(id, _, "Cannot rock the voteday after opening the cells!");
        return PLUGIN_HANDLED;
    }

    new iTotalPlayers = get_playersnum( .flag = 0 );

    if(check_flag(g_iPlayerRTD, id))
    {
        cprint_chat(id, _, "!g%d%%%% !yof the players have rocked the voteday needed !t%d%%%% !yatleast!", floatround((float(g_iTotalRTD) / float(iTotalPlayers)) * 100.0), get_pcvar_num(g_pCvar_RTDPercentage));
        return PLUGIN_HANDLED;
    }

    g_iTotalRTD ++;
    set_flag(g_iPlayerRTD,id);

    new szName[32];
    get_user_name(id, szName, charsmax(szName));
    cprint_chat(0, _, "!g* !t%s !yhas rocked the voteday!", szName);

    if(floatround((float(g_iTotalRTD) / float(iTotalPlayers)) * 100.0) >= get_pcvar_float(g_pCvar_RTDPercentage))
    {
        jb_start_theday(JB_DAY_VOTEDAY);
    }

    return PLUGIN_HANDLED;
}
