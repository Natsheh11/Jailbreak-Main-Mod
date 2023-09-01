/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <jailbreak_core>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <cs_player_models_api>

#define PLUGIN  "[JB] Day Ghost Hunting"
#define AUTHOR  "Natsheh"

#define IsPlayer(%1) (1 <= %1 <= MAX_PLAYERS)

#define INTERACTION_GLOBAL_SCALE 0xFFFFFFFF

enum any:VISITER_DATA (+=1)
{
    VISITER_ID[ MAX_PLAYERS ],
    Float:VISITER_ENTRANCE_TIME[ MAX_PLAYERS ],
    VISITER_COUNTS,
    VISITER_BITS_ARRIVE
}

new g_spday_pointer,
    g_szModel_Ghost[MAX_CLASS_PMODEL_LENGTH],
    g_pModel_body,
    g_pModel_skin,
    g_IsGhost,
    g_IsAlive,
    g_GhostInteracts[ MAX_PLAYERS+1 ],
    g_HostVisiterID[ MAX_PLAYERS+1 ][ MAX_PLAYERS+1 ],
    g_pcvar_ratio,
    g_pcvar_ghost_health,
    g_pcvar_ghost_speed,
    g_pcvar_cooldown,
    g_pcvar_duration,
    g_hunters_weapons,
    Float:g_fAbilityCooldown[MAX_PLAYERS+1],
    g_fw_fm_addtofullpack_post,
    g_fw_fm_player_prethink_post,
    g_UserVisitationData[MAX_PLAYERS+1][ VISITER_DATA ];

new const g_specialday_name[] = "Ghost Hunting",
          g_spday_access = 0,
          Float:g_spday_length = 300.0,
          Day_EndType:g_spday_endtype = DAY_TIMER;

static const g_szActivationSounds[][] = {
    "jailbreak/ghost_moan01.wav",
    "ambience/alien_creeper.wav",
    "ambience/alien_hollow.wav",
    "ambience/alien_powernode.wav",
    "ambience/des_wind1.wav",
    "ambience/des_wind2.wav",
    "ambience/pounder.wav"
}

public plugin_precache()
{
    for(new i, loop = sizeof g_szActivationSounds; i < loop; i++)
    {
        precache_sound(g_szActivationSounds[i]);
    }

    new szBody[3]="0", szSkin[3]="0";
    jb_ini_get_keyvalue("GHOST HUNTING", "GHOST_MDL", g_szModel_Ghost, charsmax(g_szModel_Ghost));
    jb_ini_get_keyvalue("GHOST HUNTING", "GHOST_MDL_BODY", szBody, charsmax(szBody));
    jb_ini_get_keyvalue("GHOST HUNTING", "GHOST_MDL_SKIN", szSkin, charsmax(szSkin));
    g_pModel_body = str_to_num(szBody);
    g_pModel_skin = str_to_num(szSkin);

    if(g_szModel_Ghost[0] != EOS)
    {
        new model_path[MAX_FILE_DIRECTORY_LEN];
        formatex(model_path, charsmax(model_path), "models/player/%s/%s.mdl", g_szModel_Ghost, g_szModel_Ghost);
        precache_model(model_path);
        formatex(model_path, charsmax(model_path), "models/player/%s/%sT.mdl", g_szModel_Ghost, g_szModel_Ghost);
        if (file_exists(model_path)) precache_model(model_path);
    }

    new szDefaultWeapons[MAX_FMT_LENGTH] = "m3,usp,knife";
    jb_ini_get_keyvalue("GHOST HUNTING", "HUNTER_WEAPONS", szDefaultWeapons, charsmax(szDefaultWeapons));

    if(szDefaultWeapons[0] != EOS)
    {
        new szWeapon[20] = "weapon_", CSWID;

        const sizeOfszWeapon = sizeof(szWeapon)-8;

        do
        {
            strtok(szDefaultWeapons, szWeapon[7], sizeOfszWeapon, szDefaultWeapons, charsmax(szDefaultWeapons), ',');
            trim(szWeapon[7]);

            if((CSWID = get_weaponid(szWeapon)))
            {
                set_flag(g_hunters_weapons,CSWID);
            }
        }
        while( szDefaultWeapons[0] != EOS )
    }
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    g_spday_pointer = register_jailbreak_day(g_specialday_name, g_spday_access, g_spday_length, g_spday_endtype);

    g_pcvar_ratio = register_cvar("jb_day_ghost_ratio", "35");
    g_pcvar_ghost_health = register_cvar("jb_day_ghost_hp", "500");
    g_pcvar_ghost_speed = register_cvar("jb_day_ghost_speed", "400");
    g_pcvar_cooldown = register_cvar("jb_day_ghost_ability_cooldown", "10");
    g_pcvar_duration = register_cvar("jb_day_ghost_ability_duration", "4");

    register_clcmd("activate_ghost_ability", "clcmd_ghost_ability_activation");
    register_clcmd("drop", "clcmd_ghost_ability_activation");

    RegisterHam(Ham_Killed, "player", "fw_player_killed_post", true);
    RegisterHam(Ham_Spawn, "player", "fw_player_spawn_post", true);
}

#if AMXX_VERSION_NUM > 182
public client_disconnected(id)
#else
public client_disconnect(id)
#endif
{
    if(g_IsGhost) // Ugly way to check if ghost hunting day is still active but its efficient!
    {
        remove_flag(g_IsGhost,id);
        GhostDayCheckWinner();
    }

    g_GhostInteracts[id] = 0;
    g_UserVisitationData[id][ VISITER_BITS_ARRIVE ] = 0;
    arrayset(g_HostVisiterID[id], 0, sizeof g_HostVisiterID[]);
}

public clcmd_ghost_ability_activation(id)
{
    if(ghost_ability_activation(id))
    {
        return PLUGIN_HANDLED;
    }
    return PLUGIN_CONTINUE;
}

public jb_day_ended(p_iDAYID)
{
    if(p_iDAYID == g_spday_pointer)
    {
        new iGhosts[ MAX_PLAYERS ], iGhostsCount;

        for( new player = 1, maxplayers = get_maxplayers(); player <= maxplayers; player++)
        {
            jb_block_user_weapons(player,false);

            if(check_flag(g_IsGhost,player))
            {
                remove_flag(g_IsGhost,player);

                if(is_user_alive(player))
                {
                    iGhosts[ iGhostsCount++ ] = player;
                }
            }
        }

        g_IsGhost = 0;

        for( new i = 0; i < iGhostsCount; i++ )
        {
            spawn( iGhosts[i] );
        }
    }
}

public fw_player_spawn_post(id)
{
    if(!is_user_alive(id))
        return;

    set_flag(g_IsAlive,id);

    if( g_IsGhost )
    {
        if(check_flag(g_IsGhost,id))
        {
            set_user_ghost(id);
            jb_set_user_allies(id, JB_ALLIES_EVERYONE);
            jb_set_user_enemies(id, ~g_IsGhost);
        }
        else
        {
            jb_set_user_enemies(id, g_IsGhost);
            jb_set_user_allies(id, ~g_IsGhost);

            jb_block_user_weapons(id, true, ~g_hunters_weapons);

            new maxweapons, iWeapons[32];

            for(new i = CSW_P228; i <= CSW_P90; i++)
            {
                if(check_flag(g_hunters_weapons,i))
                {
                    iWeapons[maxweapons++] = i;
                }
            }

            if(maxweapons)
            {
                for(new x = 0, cswid, szWeapon[24]; x < maxweapons; x++)
                {
                    cswid = iWeapons[x];
                    get_weaponname(cswid, szWeapon, charsmax(szWeapon));
                    give_item(id, szWeapon);
                    if(cswid != CSW_KNIFE) cs_set_user_bpammo(id, cswid, 300);
                }
            }
        }
    }
}

// attempt to end the round!?
public fw_player_killed_post(vic)
{
    remove_flag(g_IsAlive,vic);

    if(jb_get_current_day() == g_spday_pointer)
    {
        remove_task(vic);
        GhostDayCheckWinner();
    }

    return HAM_IGNORED;
}

GhostDayCheckWinner()
{
    static players[MAX_PLAYERS], pnum, i, iGhosts;
    get_players(players, pnum, "ah");

    for( i = iGhosts = 0; i < pnum; i++ )
    {
        if(check_flag(g_IsGhost,players[i]))
        {
            iGhosts++;
        }
    }

    if(!iGhosts)
    {
        client_print(0, print_center, "Hunters win!");
        jb_logmessage("%s specialday the hunters have won the match!", g_specialday_name);
        jb_end_theday();
    }
    else if(iGhosts >= pnum)
    {
        client_print(0, print_center, "Ghosts win!");
        jb_logmessage("%s specialday the ghosts have won the match!", g_specialday_name);
        jb_end_theday();
    }
}

public jb_day_started(p_iDAYID)
{
    if(p_iDAYID == g_spday_pointer)
    {
        new players[MAX_PLAYERS], pnum;
        get_players(players, pnum, "ah");

        if(!pnum) return;

        new player, iTemp, iRatio = floatround(pnum * (get_pcvar_float(g_pcvar_ratio) / 100.0));

        if(iRatio >= pnum) iRatio = pnum - 1;
        if(iRatio <= 0) iRatio = 1;

        new ghosts[MAX_PLAYERS], iGhostsCount;

        while(iRatio-- > 0)
        {
            if( pnum )
            {
                player = players[ (iTemp=random(pnum--)) ];
                players[ iTemp ] = players[ pnum ];

                set_user_ghost(player);
                ghosts[iGhostsCount++] = player;
            }
        }

        for(new i; i < iGhostsCount; i++)
        {
            player = ghosts[i];
            jb_set_user_allies(player, JB_ALLIES_EVERYONE);
            jb_set_user_enemies(player, ~g_IsGhost);
        }

        new maxweapons, iWeapons[32];

        for(new i = CSW_P228; i <= CSW_P90; i++)
        {
            if(check_flag(g_hunters_weapons,i))
            {
                iWeapons[maxweapons++] = i;
            }
        }

        new x, szWeapon[24];

        // give regular players regular weapons :)
        if(maxweapons)
        {
            new cswid;
            while(pnum-- > 0)
            {
                player = players[ pnum ];

                jb_set_user_enemies(player, g_IsGhost);
                jb_set_user_allies(player, ~g_IsGhost);

                jb_block_user_weapons(player, true, ~g_hunters_weapons);

                for(x = 0; x < maxweapons; x++)
                {
                    cswid = iWeapons[x];
                    get_weaponname(cswid, szWeapon, charsmax(szWeapon));
                    give_item(player, szWeapon);
                    if(cswid != CSW_KNIFE) cs_set_user_bpammo(player, cswid, 300);
                }
            }
        }

        if(!g_fw_fm_addtofullpack_post) g_fw_fm_addtofullpack_post = register_forward(FM_AddToFullPack, "fw_addtofullpack_post", true);
        if(!g_fw_fm_player_prethink_post) g_fw_fm_player_prethink_post = register_forward(FM_PlayerPreThink, "fw_player_prethink_post", true);
    }
}

set_user_ghost(player)
{
    // Player is officially now a ghost!
    set_flag(g_IsGhost,player);

    const bool:NOCLIP_ON = true;

    set_user_noclip(player, NOCLIP_ON);
    g_GhostInteracts[player] = 0;
    set_pev(player, pev_solid, SOLID_NOT);

    jb_block_user_weapons(player, true, ~(1<<CSW_KNIFE));
    give_item(player, "weapon_knife");
    client_cmd(player, "weapon_knife");
    set_user_health(player, get_pcvar_num(g_pcvar_ghost_health));

    new ent_knife, Float:fGhostMaxSpeed = get_pcvar_float(g_pcvar_ghost_speed);
    set_user_maxspeed(player, fGhostMaxSpeed);
    if( (ent_knife = cs_find_ent_by_owner(-1, "weapon_knife", player)) > 0 )
    {
        ExecuteHamB(Ham_CS_Item_GetMaxSpeed, ent_knife, fGhostMaxSpeed);
    }

    if(g_szModel_Ghost[0] != EOS)
    {
        cs_set_player_model(player, g_szModel_Ghost);
        set_pev(player, pev_body, g_pModel_body);
        set_pev(player, pev_skin, g_pModel_skin);
    }
}

ghost_ability_activation(id)
{
    if(!check_flag(g_IsGhost, id) || task_exists(id)) return PLUGIN_CONTINUE;

    new Float:fGameTime;
    if(g_fAbilityCooldown[id] > (fGameTime=get_gametime()))
    {
        client_print(id, print_center, "You ability is in a cooldown %.2f!", (g_fAbilityCooldown[id] - fGameTime));
        return PLUGIN_HANDLED;
    }

    g_fAbilityCooldown[id] = fGameTime + get_pcvar_float(g_pcvar_cooldown);
    make_user_invisible(id, .bInvisible=false);
    set_task(get_pcvar_float(g_pcvar_duration), "ghost_ability_deactivation", id);
    client_print(id, print_center, "You're now visible!");
    emit_sound(id, CHAN_BODY, g_szActivationSounds[random(sizeof g_szActivationSounds)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    return PLUGIN_HANDLED;
}

public ghost_ability_deactivation(id)
{
    if(!check_flag(g_IsGhost, id)) return;

    make_user_invisible(id, .bInvisible=true);
    client_print(id, print_center, "You're now no longer visible!");
}

make_user_invisible(id, bool:bInvisible=true, target=0)
{
    if( bInvisible )
    {
        remove_flag(g_GhostInteracts[id], target);
        if(!target) g_GhostInteracts[id] = 0;
        set_pev(id, pev_solid, SOLID_NOT);
        jb_set_user_allies(id, JB_ALLIES_EVERYONE);
    }
    else
    {
        set_flag(g_GhostInteracts[id], target);
        if(!target) g_GhostInteracts[id] = INTERACTION_GLOBAL_SCALE;
        set_pev(id, pev_solid, SOLID_SLIDEBOX);
        jb_set_user_allies(id, g_IsGhost);
    }

}

public fw_player_prethink_post(id)
{
    // If there're no ghosts there's no point proceeding...
    if(!g_IsGhost)
    {
        if(g_fw_fm_player_prethink_post)
        {
            unregister_forward(FM_PlayerPreThink, g_fw_fm_player_prethink_post, true);
            g_fw_fm_player_prethink_post = 0;
        }

        return;
    }

    if( !check_flag(g_IsAlive,id) )
    {
        return;
    }

    if( !check_flag(g_IsGhost,id) )
    {
        static players[MAX_PLAYERS], pnum, player, i;
        get_players(players, pnum, "ah");

        for(i = 0; i < pnum; i++)
        {
            player = players[i];

            if(check_flag(g_IsGhost,player))
            {
                if(check_flag(g_GhostInteracts[player],id))
                {
                    set_pev(player, pev_solid, SOLID_SLIDEBOX);
                    continue;
                }

                set_pev(player, pev_solid, SOLID_NOT);
            }
        }
    }
    else if( check_flag(g_IsGhost,id) )
    {
        if(g_GhostInteracts[id] == INTERACTION_GLOBAL_SCALE)
        {
            return;
        }

        static players[MAX_PLAYERS], pnum, i, Float:fOrigin[3], Float:fOriginEnt[3], Float:fGameTime, BitsVisiters, iVisitersCount, iTarget, ent = 0;
        get_players(players, pnum, "ch");
        pev(id, pev_origin, fOrigin);
        fGameTime = get_gametime();
        iTarget = ent = BitsVisiters = 0;

        for(i = 0; i < pnum; i++)
        {
            ent = players[ i ];

            if( id == ent || check_flag(g_IsGhost,ent) ) continue;

            pev(ent, pev_origin, fOriginEnt);

            if( get_distance_f(fOrigin, fOriginEnt) > 300.0 ) continue;

            set_flag(BitsVisiters,ent);

            if( !check_flag(g_UserVisitationData[id][ VISITER_BITS_ARRIVE ],ent) )
            {
                iVisitersCount = g_UserVisitationData[id][ VISITER_COUNTS ];
                g_UserVisitationData[id][ VISITER_ID ][ iVisitersCount ] = ent;
                g_HostVisiterID[ent][id] = iVisitersCount;
                g_UserVisitationData[id][ VISITER_ENTRANCE_TIME ][ iVisitersCount ] = fGameTime;
                g_UserVisitationData[id][ VISITER_COUNTS ]++;
                set_flag(g_UserVisitationData[id][ VISITER_BITS_ARRIVE ],ent);
                continue;
            }

            iTarget = g_HostVisiterID[ent][id];

            // The Ghost is near the Host for some time now...
            if( (fGameTime - g_UserVisitationData[id][ VISITER_ENTRANCE_TIME ][ iTarget ]) >= 3.0 )
            {
                make_user_invisible(id, .bInvisible=false, .target=ent);
            }
        }

        iVisitersCount = g_UserVisitationData[id][ VISITER_COUNTS ];

        if( iVisitersCount )
        {
            static i;
            for(i = 0; i < iVisitersCount; i++)
            {
                ent = g_UserVisitationData[id][ VISITER_ID ][ i ];
                if(!check_flag(BitsVisiters,ent)) // Player is not near the ghost no need to render !
                {
                    g_HostVisiterID[ent][id] = 0;
                    remove_flag(g_UserVisitationData[id][ VISITER_BITS_ARRIVE ],ent);
                    make_user_invisible(id, .bInvisible=true, .target=ent);
                    iVisitersCount = --g_UserVisitationData[id][ VISITER_COUNTS ];
                    ent = g_UserVisitationData[id][ VISITER_ID ][ i ] = g_UserVisitationData[id][ VISITER_ID ][ iVisitersCount ];
                    g_UserVisitationData[id][ VISITER_ENTRANCE_TIME ][ i ] = g_UserVisitationData[id][ VISITER_ENTRANCE_TIME ][ iVisitersCount ];
                    g_HostVisiterID[ent][id] = i--;
                }
            }
        }

    }
}

public fw_addtofullpack_post(es_handle, e, ent, host, hostflags, player, pset)
{
    if(!g_IsGhost)
    {
        if(g_fw_fm_addtofullpack_post)
        {
            unregister_forward(FM_AddToFullPack, g_fw_fm_addtofullpack_post, true);
            g_fw_fm_addtofullpack_post = 0;
        }
        return;
    }

    if( check_flag(g_IsGhost,host) )
    {
        return;
    }

    if(player)
    {
        if( check_flag(g_IsGhost,ent) )
        {
            set_es(es_handle, ES_RenderMode, kRenderTransAlpha);
            set_es(es_handle, ES_RenderAmt, check_flag(g_GhostInteracts[ent],host) ? 150:000);
        }
    }
    else
    {
        if( pev_valid(ent) && pev(ent, pev_movetype) == MOVETYPE_FOLLOW )
        {
            ent = pev(ent, pev_aiment);

            if( (1 <= ent <= MAX_PLAYERS) && check_flag(g_IsGhost,ent) )
            {
                set_es(es_handle, ES_RenderMode, kRenderTransAlpha);
                set_es(es_handle, ES_RenderAmt, check_flag(g_GhostInteracts[ent],host) ? 150:000);
            }
        }
    }
}
