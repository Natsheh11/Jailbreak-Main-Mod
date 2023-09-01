/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <amxmisc>
#include <nvault>
#include <jailbreak_core>
#include <jailbreak_commander>

#define PLUGIN  "[JB] TOP Warden"
#define AUTHOR  "Natsheh"

forward client_voicerecord_on(id);
forward client_voicerecord_off(id);

/* Warden valuation
** * Monitor Warden Survival time per round ( player survived time X / RoundTime * PlayedRounds )
** * Monitor Warden Microphone usage time
** * Monitor Warden Assignment count
** * Monitor Warden quitting
** * Monitor Warden Prisoners count
*/

new const g_szRecords[][] = {
    "Survival time",
    "Played rounds",
    "Microphone Usage",
    "Assignment Count",
    "Qutting Count",
    "Prisoners Control Count"
}

new const g_szRecordsFormatType[][] = {
    "%d",
    "%d",
    "%.2f",
    "%d",
    "%d",
    "%d"
}

new const g_szRecordsQuantity[][] = {
    "Minutes",
    "Rounds",
    "Minutes",
    "Times",
    "Times",
    "Prisoners"
}

enum any:Records(+=1)
{
    Warden_SurvivalTime = 0,
    Warden_PlayedRounds,
    Float:Warden_MicUsage,
    Warden_AssignmentCount,
    Warden_QuittingCount,
    Warden_PrisonersControlCount
}

new g_pCvarMPRoundTime, Float:g_fRoundTime, Float:g_fWardenAssignedTime, Float:g_fWardenFirstUsageMicTime, g_iPlayerKeysMenu[MAX_PLAYERS+1][10],
    g_iRecords[MAX_PLAYERS+1][Records], g_nVRecords = INVALID_HANDLE, g_bWardenInit, g_pWarden, g_pPrevWarden, g_iPrisonersCount, g_pJBItem_WRecords;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    g_pCvarMPRoundTime = get_cvar_pointer("mp_roundtime");

    register_jailbreak_logmessages("fw_logmessage_LR_Activated", "Last request is activated!");

    const ALL_NUM_KEYS = 1023;

    register_menu("WARDEN_STATS_MENU", MENU_KEY_1|MENU_KEY_2, "menu_handler");
    register_menu("WARDEN_PLAYERS_STATS_MENU", ALL_NUM_KEYS, "players_menu_handler");
    register_clcmd("say /wrecord", "clcmd_show_wrecord");

    Open_Record();

    g_pJBItem_WRecords = register_jailbreak_mmitem("MM_ITEM_WARDEN_RECORDS", .iAccess = 0, .team = TEAM_ANY);
}

public jb_mm_itemselected(id, itemid)
{
    if(itemid == g_pJBItem_WRecords)
    {
        DisplayWardenRecordMenu(id, .player=0);
    }
}

public clcmd_show_wrecord(id)
{
    DisplayWardenRecordMenu(id, .player=0);
}

DisplayWardenRecordMenu(id, player=0)
{
    static szText[512], szValue[32];

    if(!player)
    {
        player = id;
    }

    get_user_name(player, szValue, 31);

    new iLen = formatex(szText, charsmax(szText), "\y~ %s \r][ \wWarden Record!^n^n", szValue);
    iLen += formatex(szText[iLen], charsmax(szText)-iLen, "\y[\r 1 \y]\w. \rExit^n^n");
    for(new iRecord; iRecord < Records; iRecord++)
    {
        formatex(szValue, charsmax(szValue), g_szRecordsFormatType[iRecord], g_iRecords[player][iRecord]);
        iLen += formatex(szText[iLen], charsmax(szText)-iLen, "\r%s : \y%s \w%s^n", g_szRecords[iRecord],
            szValue,
            g_szRecordsQuantity[iRecord]);
    }

    new Float:flMaxRoundTimePerRounds = floatmax(g_fRoundTime * float(g_iRecords[player][Warden_PlayedRounds]), 1.0);
    iLen += formatex(szText[iLen], charsmax(szText)-iLen, "\rWarden Survival time per round: \y%d%%^n^n", floatround(
        ((floatmin(float(g_iRecords[player][Warden_SurvivalTime]), flMaxRoundTimePerRounds) / flMaxRoundTimePerRounds)
        ) * 100.0 ) );

    iLen += formatex(szText[iLen], charsmax(szText)-iLen, "\y[\r 2 \y]\w. \rSelect player!");

    show_menu(id, MENU_KEY_1 | MENU_KEY_2, szText, _, "WARDEN_STATS_MENU");
}

WardenStatsPlayersMenu(id, iPage=0)
{
    new szText[512], szPlayerName[32], players[32], pnum, player;

    new iLen = formatex(szText, charsmax(szText), "\y~ Select a player \r][ \wWarden Record!^n^n");
    iLen += formatex(szText[iLen], charsmax(szText)-iLen, "\y[\r 1 \y]\w. \rExit^n^n");

    get_players(players, pnum, "ch");

    if((iPage * 7) > pnum)
    {
        g_iPlayerKeysMenu[id][9] = iPage = max((pnum / 7) - 1, 0);
    }

    for(new i = 7 * iPage, x = 1, end = min(i + 7, pnum); i < end; i++)
    {
        player = players[ i ];

        g_iPlayerKeysMenu[id][x++] = get_user_userid(player);

        get_user_name(player, szPlayerName, charsmax(szPlayerName));
        iLen += formatex(szText[iLen], charsmax(szText)-iLen, "\y[\r %d \y]\w. \r%s^n", x, szPlayerName);

    }

    new ALL_NUM_KEYS = 1023;

    if(((iPage + 1) * 7) >= pnum)
    {
        ALL_NUM_KEYS &= ~MENU_KEY_9;
    }

    if(iPage < 1)
    {
        ALL_NUM_KEYS &= ~MENU_KEY_0;
    }

    iLen += formatex(szText[iLen], charsmax(szText)-iLen, "^n\y[\r 9 \y]\w. \rNext Page!^n");
    iLen += formatex(szText[iLen], charsmax(szText)-iLen, "\y[\r 0 \y]\w. \rPrevious Page!");


    show_menu(id, ALL_NUM_KEYS, szText, _, "WARDEN_PLAYERS_STATS_MENU");
}

public menu_handler(id, key)
{
    switch( key )
    {
        case 0: return PLUGIN_HANDLED;
        case 1: WardenStatsPlayersMenu(id);
    }

    return PLUGIN_HANDLED;
}

public players_menu_handler(id, key)
{
    switch( key )
    {
        case 0: return PLUGIN_HANDLED;
        case 8: WardenStatsPlayersMenu(id, ++g_iPlayerKeysMenu[id][9]);
        case 9: WardenStatsPlayersMenu(id, --g_iPlayerKeysMenu[id][9]);
        default: DisplayWardenRecordMenu(id, find_player("k", g_iPlayerKeysMenu[id][key]));
    }

    return PLUGIN_HANDLED;
}

public jb_round_start()
{
    g_fRoundTime = get_pcvar_float(g_pCvarMPRoundTime);
    g_bWardenInit = g_pPrevWarden = 0;
}

public fw_logmessage_LR_Activated()
{
    new pWarden = g_pWarden;

    if(!pWarden)
    {
        pWarden = g_pPrevWarden;

        if(!pWarden)
           return;
    }

    new szLength[32], id = pWarden;
    g_iRecords[id][Warden_PrisonersControlCount] += g_iPrisonersCount;
    num_to_str(g_iRecords[id][Warden_PrisonersControlCount], szLength, charsmax(szLength));
    g_iPrisonersCount = 0;

    Save_Record(id, Warden_PrisonersControlCount, szLength);
}

public jb_warden_assigned(id, WARDEN_ASSIGNED_STATES:eState)
{
    new players[32], pnum;
    get_players(players, pnum, "ahe", "TERRORIST");

    g_iPrisonersCount = pnum;

    g_fWardenAssignedTime = get_gametime();

    new szLength[32];

    if(g_pPrevWarden != id)
    {
        num_to_str(++g_iRecords[id][Warden_AssignmentCount], szLength, charsmax(szLength));
        Save_Record(id, Warden_AssignmentCount, szLength);
    }

    if(!check_flag(g_bWardenInit, id))
    {
        set_flag(g_bWardenInit, id);

        num_to_str(++g_iRecords[id][Warden_PlayedRounds], szLength, charsmax(szLength));
        Save_Record(id, Warden_PlayedRounds, szLength);
    }

    g_pWarden = id;
}

public jb_warden_dropped(id, WARDEN_DROP_STATES:eState)
{
    g_pWarden = 0;
    g_pPrevWarden = id;

    if(eState == WARDEN_DROP_STATE_DEMOTED)
    {
        g_iRecords[id][Warden_SurvivalTime] += floatround(g_fRoundTime);
    }
    else
    {
        g_iRecords[id][Warden_SurvivalTime] += floatround((get_gametime() - g_fWardenAssignedTime) / 60.0, floatround_tozero);
    }

    new szLength[32];
    num_to_str(g_iRecords[id][Warden_SurvivalTime], szLength, charsmax(szLength));

    Save_Record(id, Warden_SurvivalTime, szLength);

    if(eState == WARDEN_DROP_STATE_QUIT)
    {
        num_to_str(++g_iRecords[id][Warden_QuittingCount], szLength, charsmax(szLength));
        Save_Record(id, Warden_QuittingCount, szLength);
    }
}

public client_voicerecord_on(id) {
    if(jb_get_commander() == id)
    {
        g_fWardenFirstUsageMicTime = get_gametime();
    }
}

public client_voicerecord_off(id) {
    if(jb_get_commander() != id)
        return;

    if(g_fWardenFirstUsageMicTime == 0.0)
    {
        g_fWardenFirstUsageMicTime = g_fWardenAssignedTime;
    }

    g_iRecords[id][Warden_MicUsage] += (get_gametime() - g_fWardenFirstUsageMicTime) / 60.0;

    static szLength[32];
    float_to_str(Float:g_iRecords[id][Warden_MicUsage], szLength, charsmax(szLength));

    Save_Record(id, Warden_MicUsage, szLength);

    g_fWardenFirstUsageMicTime = 0.0;
}

public client_authorized(id)
{
    if(is_user_hltv(id)) return;

    arrayset(g_iRecords[id], 0, sizeof g_iRecords[]);

    Load_Records(id);
}

public plugin_end()
{
    Close_Record();
}

Open_Record()
{
    if(g_nVRecords != INVALID_HANDLE)
    {
        return 0;
    }

    g_nVRecords = nvault_open("jb_top_warden_records");
    return 1;
}

Load_Records(const id)
{
    if(g_nVRecords == INVALID_HANDLE)
    {
        return;
    }

    new szKey[64], szAuthID[32], szData[64];
    get_user_authid(id, szAuthID, charsmax(szAuthID));

    for( new iRecord, iTimeStamp; iRecord < Records; iRecord++)
    {
        formatex(szKey, charsmax(szKey), "%s_#R%d", szAuthID, iRecord);

        if(nvault_lookup(g_nVRecords, szKey, szData, charsmax(szData), iTimeStamp))
        {
            switch( g_szRecordsFormatType[iRecord][ strlen(g_szRecordsFormatType[iRecord]) - 1 ] )
            {
                case 'i', 'd': g_iRecords[id][iRecord] = str_to_num(szData);
                case 'f': g_iRecords[id][iRecord] = any:floatstr(szData);
            }
        }
    }
}

Save_Record(const id, const Records:iRecord, const szValue[])
{
    if(g_nVRecords == INVALID_HANDLE)
    {
        log_error(AMX_ERR_NATIVE, "Failed to save a jb top warden record #%d value ( %s )", iRecord, szValue);
        return 0;
    }

    new szRecord[64], szAuthID[32];
    get_user_authid(id, szAuthID, 31);
    formatex(szRecord, 63, "%s_#R%d", szAuthID, iRecord);

    nvault_set(g_nVRecords, szRecord, szValue);
    return 1;
}

Close_Record()
{
    if(g_nVRecords == INVALID_HANDLE)
    {
        return 0;
    }

    nvault_close(g_nVRecords);
    g_nVRecords = INVALID_HANDLE;
    return 1;
}
