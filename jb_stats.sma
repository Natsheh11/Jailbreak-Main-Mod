
#include <amxmodx>
#include <amxmisc>
#include <jailbreak_core>
#include <nvault>

const TOP_LIST_COUNT = 15;

#if !defined MAX_MENU_LENGTH
    const MAX_MENU_LENGTH = 512;
#endif

#define PLUGIN  "[TOP-LIST] Jailbreak Stats"
#define AUTHOR  "Natsheh"

enum any:JAILBREAK_STATS(+=1)
{
    STATS_PLAYER_NAME[32] = 0,
    STATS_PLAYER_AUTHID[32],
    STATS_COUNT_GLOBAL_KILLS,
    STATS_COUNT_KNIFE_KILLS,
    STATS_COUNT_KNIFE_HEADSHOT_KILLS,
    STATS_COUNT_KILL_PRISONERS,
    STATS_COUNT_KILL_GUARDS,
    STATS_COUNT_LR_WINS,
    STATS_COUNT_LR_LOSES
}

new const g_szStatsName[][] = {
    "Player name",
    "Player authid",
    "Global kills",
    "Knife kills",
    "Knife Headshot kills",
    "Prisoners killed",
    "Guards killed",
    "Last request wins",
    "Last request loses"
}

new const g_szStatsSort[][] = {
    "",
    "",
    "Kills",
    "Kills",
    "Kills",
    "Kills",
    "Kills",
    "Wins",
    "Loses"
}

JB_STATS_SIZE(index)
{
    switch( index )
    {
        case STATS_PLAYER_NAME: return 32;
        case STATS_PLAYER_AUTHID: return 32;
        case STATS_COUNT_GLOBAL_KILLS: return 1;
        case STATS_COUNT_KNIFE_KILLS: return 1;
        case STATS_COUNT_KNIFE_HEADSHOT_KILLS: return 1;
        case STATS_COUNT_KILL_PRISONERS: return 1;
        case STATS_COUNT_KILL_GUARDS: return 1;
        case STATS_COUNT_LR_WINS: return 1;
        case STATS_COUNT_LR_LOSES: return 1;
    }

    return 0;
}

enum any:JAILBREAK_TOP_PLAYERS_STATS (+=1)
{
    TOP_KILLERS_STATS = 0,
    TOP_KNIFE_KILLERS_STATS,
    TOP_KILL_PRISONERS_STATS,
    TOP_KILL_GUARDS_STATS,
    TOP_LR_WINNERS_STATS,
    TOP_LR_LOSERS_STATS
}

new const g_szTOPStatsTitles[][] = {
    "Global Killers",
    "Knife Killers",
    "Prisoners Killers",
    "Guards Killers",
    "LR Winners",
    "LR Losers"
}

new const g_szTOPStatsSort[][] = {
    "Kills",
    "Kills",
    "Kills",
    "Kills",
    "Wins",
    "Loses"
}

new const g_szTOPStatsClCmds[][32] = {
    "say /top15",
    "say /top15kk",
    "say /top15pk",
    "say /top15gk",
    "say /top15lrw",
    "say /top15lrl"
}

get_stats_bylist(const JAILBREAK_TOP_PLAYERS_STATS:list)
{
    switch( list )
    {
        case TOP_KILLERS_STATS: return STATS_COUNT_GLOBAL_KILLS;
        case TOP_KNIFE_KILLERS_STATS: return STATS_COUNT_KNIFE_KILLS;
        case TOP_KILL_PRISONERS_STATS: return STATS_COUNT_KILL_PRISONERS;
        case TOP_KILL_GUARDS_STATS: return STATS_COUNT_KILL_GUARDS;
        case TOP_LR_WINNERS_STATS: return STATS_COUNT_LR_WINS;
        case TOP_LR_LOSERS_STATS: return STATS_COUNT_LR_LOSES;
    }
    return 0;
}

const MENU_PLAYER_STATS = -2;
const MENU_STATS = -1;

new _:g_TOP_PLAYERS_LIST[ JAILBREAK_TOP_PLAYERS_STATS ][ TOP_LIST_COUNT ][ JAILBREAK_STATS ],
    _:g_TOP_LIST_COUNT[ JAILBREAK_TOP_PLAYERS_STATS ],
    _:g_player_stats[ MAX_PLAYERS+1 ][ JAILBREAK_STATS ],
    g_player_stats_menu_data[ MAX_PLAYERS+1 ],
    g_player_page[ MAX_PLAYERS+1 ], any:g_player_viewinglist[ MAX_PLAYERS+1 ],
    g_nVault,
    g_pJBMMITEM;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_event("DeathMsg", "event_DeathMsg", "a");

    register_cvar("toplist_knife_killers", "v1", FCVAR_SERVER);

    new szMMItemName[64], szLangKey[64];

    for(new i, mloop = sizeof g_szTOPStatsClCmds; i < mloop; i++)
    {
        register_clcmd(g_szTOPStatsClCmds[i], "clcmd_display_list");

        formatex(szLangKey, charsmax(szLangKey), "TOP_%d_%s", TOP_LIST_COUNT, g_szTOPStatsTitles[i]);
        replace_all(szLangKey, charsmax(szLangKey), " ", "_");
        strtoupper(szLangKey);
        formatex(szMMItemName, charsmax(szMMItemName), "\yTOP \r%d \w%s", TOP_LIST_COUNT, g_szTOPStatsTitles[i]);
        AddTranslation("en", CreateLangKey(szLangKey), szMMItemName);
    }

    AddTranslation("en", CreateLangKey("JB_STATS"), "\rJailBreak \yStats");
    g_pJBMMITEM = register_jailbreak_mmitem("JB_STATS", _, TEAM_ANY);

    register_concmd("jb_reset_stats", "clcmd_reset_stats", ADMIN_IMMUNITY);

    g_nVault = nvault_open("JAILBREAK_STATS");

    if(g_nVault == INVALID_HANDLE)
    {
        set_fail_state("Couldn't open nvault!");
        return;
    }

    const MENU_ALL_KEYS = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0;
    register_menu("JB_STATS", MENU_ALL_KEYS, "Menu_Handler");

    LoadList(TOP_KILLERS_STATS);
    LoadList(TOP_KNIFE_KILLERS_STATS);
    LoadList(TOP_KILL_PRISONERS_STATS);
    LoadList(TOP_KILL_GUARDS_STATS);
    LoadList(TOP_LR_WINNERS_STATS);
    LoadList(TOP_LR_LOSERS_STATS);
}

public jb_mm_itemselected(id, itemid)
{
    if(itemid == g_pJBMMITEM)
    {
        stats_menu(id, (g_player_page[id] = 0));
    }
}

public clcmd_reset_stats(id, level, cid)
{
    if(!cmd_access(id, level, cid, 0))
    {
        return PLUGIN_HANDLED;
    }

    console_print(id, "The Jailbreak stats has been reset!");
    nvault_prune(g_nVault, 0, get_systime());
    arrayset(g_TOP_LIST_COUNT, 0, sizeof g_TOP_LIST_COUNT);

    new players[32], pnum;
    get_players(players, pnum, "h");

    for(new i, j, id; i < pnum; i++)
    {
        id = players[ i ];

        for(j = STATS_PLAYER_NAME; j < JAILBREAK_STATS; j++)
        {
            g_player_stats[id][j] = 0;
        }
    }
    return PLUGIN_HANDLED;
}

public plugin_end()
{
    if(g_nVault != INVALID_HANDLE)
    {
        nvault_close(g_nVault);
    }
}

public client_authorized(id)
{
    if(g_nVault != INVALID_HANDLE)
    {
        static szString[512], szAuthID[34], szPlayerName[34], szValue[34], iTimestamp, iLen;
        get_user_authid(id, szAuthID, charsmax(szAuthID));

        if(equal(szAuthID, "BOT"))
        {
            get_user_name(id, szAuthID, 31);
        }

        if(nvault_lookup(g_nVault, szAuthID, szString, charsmax(szString), iTimestamp))
        {
            static maxloop = JAILBREAK_STATS;
            parse(szString, szPlayerName, charsmax(szPlayerName));
            iLen = min(strlen(szPlayerName) + 2, charsmax(szString));
            remove_quotes(szPlayerName);
            trim(szString[iLen]);

            copy(g_player_stats[id][ STATS_PLAYER_NAME ], charsmax(g_player_stats[][ STATS_PLAYER_NAME ]), szPlayerName);
            copy(g_player_stats[id][ STATS_PLAYER_AUTHID ], charsmax(g_player_stats[][ STATS_PLAYER_AUTHID ]), szAuthID);

            for(new j = STATS_COUNT_GLOBAL_KILLS, iType=JB_STATS_SIZE(j); j < maxloop; iType=JB_STATS_SIZE( (j += JB_STATS_SIZE(j)) ) )
            {
                if(iLen >= sizeof szString || !iType)
                {
                    break;
                }

                parse(szString[iLen], szValue, charsmax(szValue));
                iLen = min(iLen + strlen(szValue) + 2, charsmax(szString));
                remove_quotes(szValue);
                trim(szString[iLen]);

                switch( iType )
                {
                    case 1: g_player_stats[id][j] = str_to_num(szValue);
                    default: copy(g_player_stats[id][j], iType-1, szValue);
                }
            }
        }
        else
        {
            for(new j = STATS_PLAYER_NAME; j < JAILBREAK_STATS; j++)
            {
                g_player_stats[id][j] = 0;
            }
        }
    }
}

LoadList(const JAILBREAK_TOP_PLAYERS_STATS:LIST)
{
    static szString[512], szValue[32], iTimestamp;

    formatex(szString, charsmax(szString), "%s_COUNT", g_szTOPStatsTitles[_:LIST]);
    if(nvault_lookup(g_nVault, szString, szValue, charsmax(szValue), iTimestamp))
    {
        g_TOP_LIST_COUNT[LIST] = str_to_num(szValue);
    }

    static maxloop = JAILBREAK_STATS;
    server_print("^n|*** TOP %d %s ***|", g_TOP_LIST_COUNT[LIST], g_szTOPStatsTitles[_:LIST]);
    for( new i, j, iType, iLen, loop = g_TOP_LIST_COUNT[LIST], szKey[48], szAuthID[32], szPlayerName[32]; i < loop; i++ )
    {
        formatex(szKey, charsmax(szKey), "%s_%d", g_szTOPStatsTitles[_:LIST], i+1);
        nvault_get(g_nVault, szKey, szAuthID, charsmax(szAuthID));

        if(nvault_lookup(g_nVault, szAuthID, szString, charsmax(szString), iTimestamp))
        {
            //replace_all(szString, charsmax(szString), " ", "");
            parse(szString, szPlayerName, charsmax(szPlayerName));
            iLen = min(strlen(szPlayerName) + 2, charsmax(szString));
            trim(szString[iLen]);
            remove_quotes(szPlayerName);
            copy(g_TOP_PLAYERS_LIST[_:LIST][i][STATS_PLAYER_NAME], charsmax(g_TOP_PLAYERS_LIST[][][STATS_PLAYER_NAME]), szPlayerName);
            copy(g_TOP_PLAYERS_LIST[_:LIST][i][STATS_PLAYER_AUTHID], charsmax(g_TOP_PLAYERS_LIST[][][STATS_PLAYER_AUTHID]), szAuthID);

            for(j = STATS_COUNT_GLOBAL_KILLS, iType=JB_STATS_SIZE(j); j < maxloop; iType=JB_STATS_SIZE( (j += JB_STATS_SIZE(j)) ) )
            {
                if(iLen >= sizeof szString || !iType) break;

                parse(szString[iLen], szValue, charsmax(szValue));
                trim(szString[iLen]);
                iLen = min(iLen + strlen(szValue) + 2, charsmax(szString));
                remove_quotes(szValue);

                switch( iType )
                {
                    case 1: g_TOP_PLAYERS_LIST[_:LIST][i][j] = str_to_num(szValue);
                    default: copy(g_TOP_PLAYERS_LIST[_:LIST][i][j], JB_STATS_SIZE(j)-1, szValue);
                }
            }
            server_print("%d. %s [ %d ]", i+1, szPlayerName, g_TOP_PLAYERS_LIST[_:LIST][i][get_stats_bylist(LIST)] );
        }
    }

    server_print("***** END *****^n");
}

public jb_lr_duel_ended(prisoner, guard, duelid)
{
    if( duelid == JB_LR_IN_COUNTDOWN || duelid == JB_LR_ACTIVATED || duelid == JB_LR_DEACTIVATED ) return;

    if(is_user_alive(prisoner))
    {
        if(is_user_connected(guard) && !is_user_alive(guard))
        {
            g_player_stats[prisoner][STATS_COUNT_LR_WINS] ++;
            g_player_stats[guard][STATS_COUNT_LR_LOSES] ++;
            UpdatePlayerInTheList(prisoner, TOP_LR_WINNERS_STATS);
            UpdatePlayerInTheList(guard, TOP_LR_LOSERS_STATS);
            SavePlayerStats(prisoner);
            SavePlayerStats(guard);
        }
    }
    else if(is_user_alive(guard))
    {
        if(is_user_connected(prisoner) && !is_user_alive(prisoner))
        {
            g_player_stats[guard][STATS_COUNT_LR_WINS] ++;
            g_player_stats[prisoner][STATS_COUNT_LR_LOSES] ++;
            UpdatePlayerInTheList(guard, TOP_LR_WINNERS_STATS);
            UpdatePlayerInTheList(prisoner, TOP_LR_LOSERS_STATS);
            SavePlayerStats(guard);
            SavePlayerStats(prisoner);
        }
    }
}

public event_DeathMsg()
{
    new iKiller,
        iVictim = read_data( 2 ),
        szWeapon[24],
        bool:bHeadShot = bool:read_data( 3 );

    iKiller = get_user_attacker(iVictim);
    read_data( 4 , szWeapon, charsmax(szWeapon));

    if(!iKiller || !is_user_connected(iKiller) || iKiller == iVictim)
    {
        return;
    }

    g_player_stats[ iKiller ][ STATS_COUNT_GLOBAL_KILLS ] ++;

    if(equal(szWeapon, "knife"))
    {
        g_player_stats[ iKiller ][ STATS_COUNT_KNIFE_KILLS ] ++;
        if(bHeadShot) g_player_stats[ iKiller ][ STATS_COUNT_KNIFE_HEADSHOT_KILLS ] ++;
        UpdatePlayerInTheList(iKiller, TOP_KNIFE_KILLERS_STATS);
    }

    switch( get_user_team(iVictim) )
    {
        case TEAM_PRISONERS:
        {
            g_player_stats[ iKiller ][ STATS_COUNT_KILL_PRISONERS ] ++;
            UpdatePlayerInTheList(iKiller, TOP_KILL_PRISONERS_STATS);
        }
        case TEAM_GUARDS:
        {
            g_player_stats[ iKiller ][ STATS_COUNT_KILL_GUARDS ] ++;
            UpdatePlayerInTheList(iKiller, TOP_KILL_GUARDS_STATS);
        }
    }

    UpdatePlayerInTheList(iKiller, TOP_KILLERS_STATS);
    SavePlayerStats(iKiller);
}

SavePlayerStats(id)
{
    new szName[32], szAuthID[32];
    get_user_name(id, szName, 31);
    get_user_authid(id, szAuthID, 31);

    if(equal(szAuthID, "BOT"))
    {
        get_user_name(id, szAuthID, 31);
    }

    static szString[512];
    new iLen = formatex(szString, charsmax(szString), "^"%s^"", szName);

    static maxloop = JAILBREAK_STATS;

    for(new i = STATS_COUNT_GLOBAL_KILLS, iType=JB_STATS_SIZE(i); i < maxloop; iType=JB_STATS_SIZE( (i += JB_STATS_SIZE(i)) ) )
    {
        if(iLen >= sizeof szString || !iType)
        {
            break;
        }

        switch( iType )
        {
            case 1: iLen += formatex(szString[iLen], charsmax(szString)-iLen, " ^"%d^"", g_player_stats[ id ][ i ]); // Integer?
            default: iLen += formatex(szString[iLen], charsmax(szString)-iLen, " ^"%s^"", g_player_stats[ id ][ i ]); // String?
        }
    }

    nvault_set(g_nVault, szAuthID, szString);
}

UpdatePlayerInTheList(id, const JAILBREAK_TOP_PLAYERS_STATS:iList)
{
    static maxloop = JAILBREAK_STATS;

    get_user_name(id, g_player_stats[id][STATS_PLAYER_NAME], charsmax(g_player_stats[][STATS_PLAYER_NAME]));
    get_user_authid(id, g_player_stats[id][STATS_PLAYER_AUTHID], charsmax(g_player_stats[][STATS_PLAYER_AUTHID]));

    if(equal(g_player_stats[id][STATS_PLAYER_AUTHID], "BOT"))
    {
        get_user_name(id, g_player_stats[id][STATS_PLAYER_AUTHID], charsmax(g_player_stats[][STATS_PLAYER_AUTHID]));
    }

    if(g_TOP_LIST_COUNT[iList] < TOP_LIST_COUNT && !AlreadyInTheTOPList(g_player_stats[id][STATS_PLAYER_AUTHID], iList))
    {
        new i = g_TOP_LIST_COUNT[iList];

        for(new j = STATS_PLAYER_NAME, iType=JB_STATS_SIZE(j); j < maxloop; iType=JB_STATS_SIZE( (j += JB_STATS_SIZE(j)) ) )
        {
            switch( iType )
            {
                case 0: break;
                case 1: g_TOP_PLAYERS_LIST[iList][i][j] = g_player_stats[ id ][ j ]; // Integer?
                default: copy(g_TOP_PLAYERS_LIST[iList][i][j], iType-1, g_player_stats[ id ][ j ]); // String?
            }
        }

        g_TOP_LIST_COUNT[iList]++;

        new szKey[48], szValue[16];
        formatex(szKey, charsmax(szKey), "%s_%d", g_szTOPStatsTitles[_:iList], ++i);
        nvault_set(g_nVault, szKey, g_player_stats[id][STATS_PLAYER_AUTHID]);

        formatex(szKey, charsmax(szKey), "%s_COUNT", g_szTOPStatsTitles[_:iList]);
        num_to_str(i, szValue, charsmax(szValue));
        nvault_set(g_nVault, szKey, szValue);
        return;
    }

    static pStats[ JAILBREAK_STATS ];

    for(new j = STATS_PLAYER_NAME, iType=JB_STATS_SIZE(j); j < maxloop; iType=JB_STATS_SIZE( (j += JB_STATS_SIZE(j)) ) )
    {
        switch( iType )
        {
            case 0: break;
            case 1: pStats[j] = g_player_stats[ id ][ j ]; // Integer?
            default: copy(pStats[j], iType-1, g_player_stats[ id ][ j ]); // String?
        }
    }

    // comparing..
    for(new i, j, pStatsBackUP[ JAILBREAK_STATS ], szKey[48], iTemp, iType; i < g_TOP_LIST_COUNT[iList]; i++)
    {
        iTemp = get_stats_bylist(iList);
        if( pStats[ iTemp ] >= g_TOP_PLAYERS_LIST[iList][i][ iTemp ] )
        {
            if((iTemp=AlreadyInTheTOPList(pStats[STATS_PLAYER_AUTHID], iList)) && iTemp <= (i+1))
            {
                iTemp--;
                for(j = STATS_PLAYER_NAME, iType=JB_STATS_SIZE(j); j < maxloop; iType=JB_STATS_SIZE( (j += JB_STATS_SIZE(j)) ) )
                {
                    switch( iType )
                    {
                        case 0: break;
                        case 1: g_TOP_PLAYERS_LIST[iList][iTemp][j] = pStats[ j ]; // Integer?
                        default: copy(g_TOP_PLAYERS_LIST[iList][iTemp][j], iType-1, pStats[ j ]); // String?
                    }
                }

                formatex(szKey, charsmax(szKey), "%s_%d", g_szTOPStatsTitles[_:iList], ++iTemp);
                nvault_set(g_nVault, szKey, pStats[STATS_PLAYER_AUTHID]);
                return;
            }

            if( iTemp-- )
            {
                for(j = STATS_PLAYER_NAME, iType=JB_STATS_SIZE(j); j < maxloop; iType=JB_STATS_SIZE( (j += JB_STATS_SIZE(j)) ) )
                {
                    switch( iType )
                    {
                        case 0: break;
                        case 1: g_TOP_PLAYERS_LIST[iList][iTemp][ j ] = g_TOP_PLAYERS_LIST[iList][i][ j ]; // Integer?
                        default: copy(g_TOP_PLAYERS_LIST[iList][iTemp][ j ], iType-1, g_TOP_PLAYERS_LIST[iList][i][ j ]); // String?
                    }
                }

                formatex(szKey, charsmax(szKey), "%s_%d", g_szTOPStatsTitles[_:iList], iTemp+1);
                nvault_set(g_nVault, szKey, g_TOP_PLAYERS_LIST[iList][iTemp][ STATS_PLAYER_AUTHID ]);
            }

            for(j = STATS_PLAYER_NAME, iType=JB_STATS_SIZE(j); j < maxloop; iType=JB_STATS_SIZE( (j += JB_STATS_SIZE(j)) ) )
            {
                switch( iType )
                {
                    case 0: break;
                    case 1: pStatsBackUP[j] = g_TOP_PLAYERS_LIST[iList][i][j]; // Integer?
                    default: copy(pStatsBackUP[j], iType-1, g_TOP_PLAYERS_LIST[iList][i][j]); // String?
                }
            }

            for(j = STATS_PLAYER_NAME, iType=JB_STATS_SIZE(j); j < maxloop; iType=JB_STATS_SIZE( (j += JB_STATS_SIZE(j)) ) )
            {
                switch( iType )
                {
                    case 0: break;
                    case 1: g_TOP_PLAYERS_LIST[iList][i][j] = pStats[ j ]; // Integer?
                    default: copy(g_TOP_PLAYERS_LIST[iList][i][j], iType-1, pStats[ j ]); // String?
                }
            }

            formatex(szKey, charsmax(szKey), "%s_%d", g_szTOPStatsTitles[_:iList], i+1);
            nvault_set(g_nVault, szKey, pStats[STATS_PLAYER_AUTHID]);

            for(j = STATS_PLAYER_NAME, iType=JB_STATS_SIZE(j); j < maxloop; iType=JB_STATS_SIZE( (j += JB_STATS_SIZE(j)) ) )
            {
                switch( iType )
                {
                    case 0: break;
                    case 1: pStats[j] = pStatsBackUP[ j ]; // Integer?
                    default: copy(pStats[j], iType-1, pStatsBackUP[ j ]); // String?
                }
            }
        }
    }
}

AlreadyInTheTOPList(const szAuthID[], const JAILBREAK_TOP_PLAYERS_STATS:iList)
{
    // comparing..
    for(new i, maxloop = g_TOP_LIST_COUNT[iList]; i < maxloop; i++)
    {
        if(equal(g_TOP_PLAYERS_LIST[iList][i][STATS_PLAYER_AUTHID], szAuthID))
        {
            return i+1;
        }
    }

    return 0;
}

public clcmd_display_list(id)
{
    new szArgs[32], i, mloop, szCmd[32], iLen;

    iLen = clamp(read_argv(0, szCmd, charsmax(szCmd))+1, 0, charsmax(g_szTOPStatsClCmds[]));
    read_args(szArgs, charsmax(szArgs));
    remove_quotes(szArgs);

    for(i=0, mloop = sizeof g_szTOPStatsClCmds; i < mloop; i++)
    {
        if(equali(szArgs, g_szTOPStatsClCmds[i][iLen]))
        {
            break;
        }
    }

    display_toplist( id, any:i );
    return 1;
}

display_toplist(const id, const JAILBREAK_TOP_PLAYERS_STATS:LIST)
{
    if(LIST >= JAILBREAK_TOP_PLAYERS_STATS) return 0;

    top_stats_list(id, LIST, (g_player_page[id] = 0));
    return 1;
}

player_stats_menu(const id, const page=0, const data=STATS_PLAYER_NAME)
{
    g_player_viewinglist[id] = MENU_PLAYER_STATS;

    static szText[MAX_MENU_LENGTH], maxItems = sizeof g_szStatsName;
    new iLen = formatex(szText, charsmax(szText), "\rPlayer \yStats: ^n^n"),
    keys = MENU_KEY_0, iItemsPerPage = maxItems > 9 ? 7 : 9;

    new
    start = page * iItemsPerPage,
    end = min(start + iItemsPerPage, maxItems), i = data;

    for(new x = start, iType=JB_STATS_SIZE(i); x < end; iType=JB_STATS_SIZE( (i += JB_STATS_SIZE(i)) ) )
    {
        switch( iType )
        {
            case 0: break;
            case 1: iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "\r* \y%s: \w%d \d%s^n", g_szStatsName[x], g_player_stats[id][i], g_szStatsSort[x]);
            default: iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "\r* \y%s: \w%s \d%s^n", g_szStatsName[x], g_player_stats[id][i], g_szStatsSort[x]);
        }

        x++;
    }

    g_player_stats_menu_data[id] = i;

    if( iItemsPerPage == 7 )
    {
        if(page > 0) keys |= MENU_KEY_8;
        iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "^n%s8. Previous ^n", (page > 0) ? "\r":"\d");

        if(end < JAILBREAK_STATS) keys |= MENU_KEY_9;
        iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "%s9. Next ^n", (end < JAILBREAK_STATS) ? "\r":"\d");
    }

    iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "^n\r0. Back");

    show_menu(id, keys, szText, _, "JB_STATS");
    return PLUGIN_HANDLED;
}

stats_menu(const id, const page=0)
{
    g_player_viewinglist[id] = MENU_STATS;

    static szText[MAX_MENU_LENGTH], maxItems = sizeof g_szTOPStatsTitles;
    new iLen = formatex(szText, charsmax(szText), "\rJailbreak \yStats: ^n^n"),
    keys = MENU_KEY_0, iNum, iItemsPerPage = maxItems > 8 ? 6 : 8, szLangKey[64];

    keys |= (1<<iNum);
    iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "\y%d. \yMy Stats ^n^n", ++iNum);

    new
    start = page * iItemsPerPage,
    end = min(start + iItemsPerPage, maxItems);

    for(new i = start; i < end; i++)
    {
        keys |= (1<<iNum);

        formatex(szLangKey, charsmax(szLangKey), "TOP_%d_%s", TOP_LIST_COUNT, g_szTOPStatsTitles[i]);
        replace_all(szLangKey, charsmax(szLangKey), " ", "_");
        strtoupper(szLangKey);
        iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "\r%d. %L ^n", ++iNum, LANG_PLAYER, szLangKey );
    }

    if( iItemsPerPage == 6 )
    {
        if(page > 0) keys |= (1<<iNum);
        iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "^n%s%d. Previous ^n", (page > 0) ? "\r":"\d", ++iNum);

        if(end < maxItems) keys |= (1<<iNum);
        iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "%s%d. Next ^n", (end < maxItems) ? "\r":"\d", ++iNum);
    }

    iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "^n\r0. Exit");

    show_menu(id, keys, szText, _, "JB_STATS");
    return PLUGIN_HANDLED;
}

top_stats_list(const id, const JAILBREAK_TOP_PLAYERS_STATS:list, page=0)
{
    g_player_viewinglist[id] = list;

    static szText[MAX_MENU_LENGTH];
    new iLen = formatex(szText, charsmax(szText), "TOP %d: %s^n", TOP_LIST_COUNT, g_szTOPStatsTitles[_:list]),
    keys = MENU_KEY_0;

    iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "%s1. Previous ^n", (page > 0) ? "\r":"\d");
    if(page > 0) keys |= MENU_KEY_1;

    new i=(page * 10), end = min(i + 10, g_TOP_LIST_COUNT[list]);
    iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "%s2. Next ^n^n", (end < g_TOP_LIST_COUNT[list]) ? "\r":"\d");

    for(/*Empty*/ ; i < end; i++ )
    {
        iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "\r[%02d] \w%s \d%s: %i^n", i+1, g_TOP_PLAYERS_LIST[_:list][ i ][ STATS_PLAYER_NAME ], g_szTOPStatsSort[_:list], g_TOP_PLAYERS_LIST[_:list][ i ][ get_stats_bylist(list) ] );
    }

    if(end < g_TOP_LIST_COUNT[list]) keys |= MENU_KEY_2;

    iLen += formatex( szText[ iLen ], charsmax( szText ) - iLen, "^n\r0. Back");

    show_menu(id, keys, szText, _, "JB_STATS");
    return PLUGIN_HANDLED;
}

public Menu_Handler(id, key)
{
    if(g_player_viewinglist[id] == MENU_PLAYER_STATS)
    {
        switch( key )
        {
            case 7: player_stats_menu(id, --g_player_page[id], g_player_stats_menu_data[id]);
            case 8: player_stats_menu(id, ++g_player_page[id], g_player_stats_menu_data[id]);
            case 9: stats_menu(id, (g_player_page[id]=0));
        }

        return PLUGIN_HANDLED;
    }

    if(g_player_viewinglist[id] == MENU_STATS)
    {
        switch( key )
        {
            case 0: player_stats_menu(id, (g_player_page[id]=0), (g_player_stats_menu_data[id]=STATS_PLAYER_NAME));
            case 7: stats_menu(id, --g_player_page[id]);
            case 8: stats_menu(id, ++g_player_page[id]);
            case 9: return PLUGIN_HANDLED;
            default: display_toplist( id, JAILBREAK_TOP_PLAYERS_STATS:( key - 1 ) )
        }

        return PLUGIN_HANDLED;
    }

    /* player is viewing a top list menu */

    switch( key )
    {
        case 0: top_stats_list(id, g_player_viewinglist[id], --g_player_page[id]);
        case 1: top_stats_list(id, g_player_viewinglist[id], ++g_player_page[id]);
        case 9: stats_menu(id, (g_player_page[id]=0));
    }

    return PLUGIN_HANDLED;
} 
