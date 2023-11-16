/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <jailbreak_core>
#include <jailbreak_gangs>
#include <nvault>
#include <cstrike>

#define PLUGIN  "[JB] Gang Wars"
#define AUTHOR  "Natsheh"

#define TASK_GANGS_DETAILS  3535

new g_iMaxGangLevels = 7;

new g_pGangWars_SpecialdayID,
HamHook:g_fwHamHookPlayerKilled,
Trie:g_pTrieCurrExistedGangsData = Invalid_Trie,
Array:g_ArrayGangWarsGuns = Invalid_Array,
g_pNVault;

enum CVARS_DATA
{
    CVAR_NAME[32],
    CVAR_VALUE[16]
}

enum
{
    CVAR_GANG_WARS_XP_PER_KILL = 0,
    CVAR_GANG_WARS_XP_PER_HS,
    CVAR_GANG_WARS_XP_PER_KNIFE_KILL
}

new const g_aCvarsData[][CVARS_DATA] =
{
    { "jb_gangwars_xp_per_kill", "5" },
    { "jb_gangwars_xp_per_hs_kill", "3" },
    { "jb_gangwars_xp_per_knife_kill", "2" }
}

new g_pCvars[sizeof g_aCvarsData];

enum any:GANG_WARS_LEVEL_WEAPONS
{
    GANG_WAR_WEAPON_NAME[32],
    GANG_WAR_WEAPON_CLIP,
    GANG_WAR_WEAPON_BPAMMO,
    GANG_WAR_WEAPON_LEVEL
}

enum any:GANG_DATA
{
    GANG_NAME[32],
    GANG_LEVEL,
    GANG_XP
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    for(new i; i < sizeof g_aCvarsData; i++)
    {
        g_pCvars[i] = register_cvar(g_aCvarsData[i][CVAR_NAME], g_aCvarsData[i][CVAR_VALUE]);
    }

    g_pGangWars_SpecialdayID = register_jailbreak_day("Gang Wars", ADMIN_ALL, .fDay_Length=120.0, .DayEndTypo=DAY_TIMER);

    g_pTrieCurrExistedGangsData = TrieCreate();
    g_ArrayGangWarsGuns = ArrayCreate(GANG_WARS_LEVEL_WEAPONS, .reserved = g_iMaxGangLevels);

    DisableHamForward( (g_fwHamHookPlayerKilled = RegisterHam(Ham_Killed, "player", "fw_HamPlayerKilledPost", .Post = true)) );

    SetupGangWeaponsData();

    g_pNVault = nvault_open("gang_wars");
}

SetupGangWeaponsData()
{
    new szValue[128], szKey[64], szProperties[8], szClip[8], szBPAmmo[8], any:xArray[GANG_WARS_LEVEL_WEAPONS];
    num_to_str(g_iMaxGangLevels, szValue, charsmax(szValue));
    jb_ini_get_keyvalue("GANG_WARS", "GANG_MAX_LEVELS", szValue, charsmax(szValue));
    g_iMaxGangLevels = str_to_num(szValue);

    for(new i, a, iStart, iCSWID, szWeaponName[32] = "weapon_"; i < g_iMaxGangLevels; i++)
    {
        switch( i )
        {
            // Level one default weapon.
            case 0: formatex(szValue, charsmax(szValue), "mac10[30,90] glock18[20,120]");
            // Level two default weapon.
            case 1: formatex(szValue, charsmax(szValue), "tmp[30,90] usp[12,100]");
            // Level three default weapon.
            case 2: formatex(szValue, charsmax(szValue), "mp5navy[30,90] p228[13,100]");
            // Level four default weapon.
            case 3: formatex(szValue, charsmax(szValue), "galil[30,90] glock18[20,120]");
            // Level five default weapon.
            case 4: formatex(szValue, charsmax(szValue), "p90[50,100] usp[12,100]");
            // Level six default weapon.
            case 5: formatex(szValue, charsmax(szValue), "m249[100,200] deagle[12,100]");
            // Level seven default weapon.
            case 6: formatex(szValue, charsmax(szValue), "ak47[30,90] deagle[7,35] armor[100]");

        }

        formatex(szKey, charsmax(szKey), "GANG_GUNS_LEVEL_%d", i + 1);
        jb_ini_get_keyvalue("GANG_WARS", szKey, szValue, charsmax(szValue));

        xArray[GANG_WAR_WEAPON_LEVEL] = i;

        a = -1; iStart = 0;
        while( a < charsmax(szValue) && szValue[ ++a ] != EOS )
        {
            if(!isalnum(szValue[a]))
            {
                iStart += copy(szWeaponName[7], min((a - iStart), charsmax(szWeaponName) - 7), szValue[iStart]);

                if((iCSWID=get_weaponid(szWeaponName)) != 0 || equali(szWeaponName[7], "armor"))
                {
                    switch( iCSWID )
                    {
                        case 0: copy(xArray[GANG_WAR_WEAPON_NAME], charsmax(xArray[GANG_WAR_WEAPON_NAME]), szWeaponName[7]);
                        default: copy(xArray[GANG_WAR_WEAPON_NAME], charsmax(xArray[GANG_WAR_WEAPON_NAME]), szWeaponName);
                    }

                    if(szValue[a] == '[')
                    {
                        iStart += (copyc(szProperties, charsmax(szProperties), szValue[min(a + 1, charsmax(szValue))], ']') + 2);

                        if(contain(szProperties, ",") != -1)
                        {
                            strtok2(szProperties, szClip, charsmax(szClip), szBPAmmo, charsmax(szBPAmmo), .token = ',');

                            xArray[GANG_WAR_WEAPON_CLIP] = str_to_num(szClip);
                            xArray[GANG_WAR_WEAPON_BPAMMO] = str_to_num(szBPAmmo);
                        }
                        else
                        {
                            xArray[GANG_WAR_WEAPON_CLIP] = str_to_num(szProperties);
                        }
                    }

                    ArrayPushArray(g_ArrayGangWarsGuns, xArray);
                    a = iStart++;

                    if(szValue[a] == EOS)
                    {
                        break;
                    }
                }
            }
        }
    }
}

public plugin_end()
{
    ArrayDestroy(g_ArrayGangWarsGuns);
    TrieDestroy(g_pTrieCurrExistedGangsData);
    nvault_close(g_pNVault);
}

public client_remove(id)
{
    CheckGangWarsSpecialdayObjective();
}

public fw_HamPlayerKilledPost(victim, killer, gibs)
{
    if(!is_user_connected(killer) || jb_get_user_gang_status(killer) == GANG_NONE)
    {
        return;
    }

    new xp = get_pcvar_num(g_pCvars[CVAR_GANG_WARS_XP_PER_KILL]), bool:bHeadShot = get_ent_data(victim, "CBasePlayer", "m_bHeadshotKilled");

    if(bHeadShot)
    {
        xp += get_pcvar_num(g_pCvars[CVAR_GANG_WARS_XP_PER_HS]);
    }

    if(get_user_weapon(killer) == CSW_KNIFE && pev(victim, pev_dmg_inflictor) == killer)
    {
        xp += get_pcvar_num(g_pCvars[CVAR_GANG_WARS_XP_PER_KNIFE_KILL]);
    }

    static szKey[64], szValue[32], szGangName[32], xArray[GANG_DATA];
    jb_get_user_gang_name(killer, szGangName, charsmax(szGangName));
    TrieGetArray(g_pTrieCurrExistedGangsData, szGangName, xArray, sizeof xArray);

    formatex(szKey, charsmax(szKey), "%s_XP", szGangName);
    new totalxp = (xp + nvault_get(g_pNVault, szKey));
    num_to_str(totalxp, szValue, charsmax(szValue));

    nvault_set(g_pNVault, szKey, szValue);
    xArray[GANG_XP] = totalxp;

    set_hudmessage(120, 230, 25, 0.5, 0.40, 0, 3.0, 1.0, 0.3, 0.5, -1);
    show_hudmessage(killer, "+%d GANG XP", xp);

    formatex(szKey, charsmax(szKey), "%s_LEVEL", szGangName);
    new level = nvault_get(g_pNVault, szKey);

    if(g_iMaxGangLevels > (level + 1))
    {
        while( (((level + 1) * 300) + (250 * level)) <= totalxp)
        {
            num_to_str(++level, szValue, charsmax(szValue));
            nvault_set(g_pNVault, szKey, szValue);
            xArray[GANG_LEVEL] = level;
        }
    }

    TrieSetArray(g_pTrieCurrExistedGangsData, szKey, xArray, sizeof xArray);

    CheckGangWarsSpecialdayObjective();
}

bool:CheckGangWarsSpecialdayObjective()
{
    if(jb_get_current_day() != g_pGangWars_SpecialdayID)
    {
        return;
    }

    new iRemainingGangs = GetCurrentExistedGangsData();

    if(iRemainingGangs <= 1)
    {
        if(iRemainingGangs == 1)
        {
            new any:xArray[GANG_DATA];
            TrieGetArray(g_pTrieCurrExistedGangsData, "#1", xArray, sizeof xArray);
            client_print(0, print_center, "%s has won the war!", xArray[GANG_NAME]);
        }

        jb_end_theday();
    }
}

GetCurrentExistedGangsData()
{
    TrieClear(g_pTrieCurrExistedGangsData);

    new players[32], szKey[32], pnum, iGangsCount, xArray[GANG_DATA];
    get_players(players, pnum, "ach");

    for(new player, i, szGangName[32]; i < pnum; i++)
    {
        player = players[ i ];

        if(jb_get_user_gang_status(player) == GANG_NONE)
        {
            continue;
        }

        jb_get_user_gang_name(player, szGangName, charsmax(szGangName));

        if( TrieKeyExists(g_pTrieCurrExistedGangsData, szGangName) ) continue;

        copy(xArray[GANG_NAME], charsmax(xArray[GANG_NAME]), szGangName);

        formatex(szKey, charsmax(szKey), "%s_LEVEL", szGangName);
        xArray[GANG_LEVEL] = nvault_get(g_pNVault, szKey);

        formatex(szKey, charsmax(szKey), "%s_XP", szGangName);
        xArray[GANG_XP] = nvault_get(g_pNVault, szKey);

        TrieSetArray(g_pTrieCurrExistedGangsData, szGangName, xArray, sizeof xArray);

        formatex(szKey, charsmax(szKey), "#%d", ++iGangsCount);
        TrieSetArray(g_pTrieCurrExistedGangsData, szKey, xArray, sizeof xArray);
    }

    return iGangsCount;
}

public jb_day_preselected(id, iDayid, iAccess)
{
    if(iDayid == g_pGangWars_SpecialdayID)
    {
        if(GetCurrentExistedGangsData() <= 1)
            return JB_MENU_ITEM_UNAVAILABLE;
    }
    return JB_IGNORED;
}

public jb_day_start(iDayid)
{
    if(iDayid == g_pGangWars_SpecialdayID)
    {
        if(GetCurrentExistedGangsData() <= 1)
            return JB_HANDLED;
    }

    return JB_IGNORED;
}

public jb_day_started(iDayid)
{
    if(iDayid == g_pGangWars_SpecialdayID)
    {
        EnableHamForward(g_fwHamHookPlayerKilled);
        DisarmPlayers();
        ArmGangsters();
        SetUpPlayersRelations();

        task_show_gangs_details();
    }
}

public task_show_gangs_details()
{
    new szText[512], szKey[3] = "#";

    for(new i, iLen, xArray[GANG_DATA]; i < g_iMaxGangLevels; i++)
    {
        szKey[1] = '1' + i;

        if(!TrieKeyExists(g_pTrieCurrExistedGangsData, szKey)) break;

        TrieGetArray(g_pTrieCurrExistedGangsData, szKey, xArray, sizeof xArray);
        iLen += formatex(szText[iLen], charsmax(szText)-iLen, "%s *Level %d *XP : %d^n", xArray[GANG_NAME], xArray[GANG_LEVEL], xArray[GANG_XP]);
    }

    set_hudmessage(225, 225, 225, 0.05, 0.15, 0, 3.0, 0.99, 0.3, 0.5, -1);
    show_hudmessage(0, szText);

    set_task(1.0, "task_show_gangs_details", TASK_GANGS_DETAILS);
}

public jb_day_ended(iDayid)
{
    if(iDayid == g_pGangWars_SpecialdayID)
    {
        DisarmPlayers();
        DisableHamForward(g_fwHamHookPlayerKilled);

        for(new i = 1; i <= MAX_PLAYERS; i++)
        {
            jb_set_user_allies(i, JB_ALLIES_DEFAULT);
            jb_set_user_enemies(i, JB_ENEMIES_DEFAULT);
        }

        remove_task(TASK_GANGS_DETAILS);
    }
}

SetUpPlayersRelations()
{
    for(new i = 1, szGuestGangName[32], szHostGangName[32]; i <= MAX_PLAYERS; i++)
    {
        jb_set_user_enemies(i, JB_ENEMIES_EVERYONE);
        jb_set_user_allies(i, JB_ALLIES_DEFAULT);

        if(is_user_connected(i))
        {
            // Player has no allies...
            if(jb_get_user_gang_status(i) == GANG_NONE)
            {
                continue;
            }

            for(new j = 1; j <= MAX_PLAYERS; j++)
            {
                if( j == i ) continue;

                if(is_user_connected(j))
                {
                    jb_get_user_gang_name(j, szGuestGangName, charsmax(szGuestGangName));
                    jb_get_user_gang_name(i, szHostGangName, charsmax(szHostGangName));

                    if(equal(szGuestGangName, szHostGangName))
                    {
                        jb_set_user_allies(i, jb_get_user_allies(i) | player_flag(j));
                        jb_set_user_enemies(i, jb_get_user_enemies(i) & ~player_flag(j));
                    }
                }
            }
        }
    }
}

DisarmPlayers()
{
    new players[32], pnum;
    get_players(players, pnum, "ah");

    for(new i, player; i < pnum; i++)
    {
        player = players[ i ];
        strip_user_weapons(player);
        give_item(player, "weapon_knife");
    }
}

ArmGangsters()
{
    new players[32], pnum, xArray[GANG_DATA], xArrGangWarsWeapons[GANG_WARS_LEVEL_WEAPONS], GangWarsWeaponsCount = ArraySize(g_ArrayGangWarsGuns);
    get_players(players, pnum, "ch");

    for(new player, iEnt, szGangName[32], i, x; i < pnum; i++)
    {
        player = players [ i ];

        if(jb_get_user_gang_status(player) == GANG_NONE)
        {
            continue;
        }

        jb_get_user_gang_name(player, szGangName, charsmax(szGangName));
        TrieGetArray(g_pTrieCurrExistedGangsData, szGangName, xArray, sizeof xArray);

        x = GangWarsWeaponsCount;
        while( x-- > 0 )
        {
            ArrayGetArray(g_ArrayGangWarsGuns, x, xArrGangWarsWeapons);

            if(xArrGangWarsWeapons[GANG_WAR_WEAPON_LEVEL] == xArray[GANG_LEVEL])
            {
                if(equali(xArrGangWarsWeapons[GANG_WAR_WEAPON_NAME], "armor"))
                {
                    cs_set_user_armor(player, xArrGangWarsWeapons[GANG_WAR_WEAPON_CLIP], CS_ARMOR_VESTHELM);
                    continue;
                }

                iEnt = give_item(player, xArrGangWarsWeapons[GANG_WAR_WEAPON_NAME]);

                if(iEnt > 0)
                {
                    set_ent_data(iEnt, "CBasePlayerWeapon", "m_iClip", xArrGangWarsWeapons[GANG_WAR_WEAPON_CLIP]);
                    set_ent_data(player, "CBasePlayer", "m_rgAmmo", xArrGangWarsWeapons[GANG_WAR_WEAPON_BPAMMO],
                            get_ent_data(iEnt, "CBasePlayerWeapon", "m_iPrimaryAmmoType"));
                }
            }
        }
    }
}
