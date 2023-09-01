/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fun>
#include <cstrike>
#include <jailbreak_core>
#include <fakemeta>
#include <csx>
#include <inc_get_team_fix>

#define PLUGIN "[JB] DAY: GunGame"
#define AUTHOR "Natsheh"

#define MAX_CATEGORIES 7
#define MAX_PHASES 7

#define MAX_PISTOLS 6
#define MAX_SHOTGUNS 2
#define MAX_SMG 5
#define MAX_RIFLES 10
#define MAX_MACHINEGUNS 1
#define MAX_FRAGNADES 1
#define MAX_MELEE_WPNS 1

#define TASK_VOTEMENU 48345
#define TASK_GRANT_WEAPON_LEVEL 18345

#define OFFSET_TEAM	114
#define fm_get_user_team(%1)	get_pdata_int(%1,OFFSET_TEAM)
#define fm_set_user_team(%1,%2)	set_pdata_int(%1,OFFSET_TEAM,%2)

#if AMXX_VERSION_NUM > 182
#define client_disconnect(id) client_disconnected(id)
#endif

enum (+=1)
{
	PHASE_FIRST = 0,
	PHASE_SECOND,
	PHASE_THIRD,
	PHASE_FOURTH,
	PHASE_FIFTH,
	PHASE_SIXTH,
	PHASE_FINAL
}

enum (+=1)
{
	CATEGORY_PISTOLS = 0,
	CATEGORY_SHOTGUNS,
	CATEGORY_SMG,
	CATEGORY_RIFLES,
	CATEGORY_MACHINEGUNS,
	CATEGORY_FRAGNADE,
	CATEGORY_MELEE
}

new const Weapons_categories[][] = {
	"Pistols",
	"Shotguns",
	"Submachine guns",
	"Rifles",
	"Machine gun",
	"Frag grenade",
	"Melee (Knife)"
}

new CATEGORIES_VOTES[MAX_PHASES][MAX_CATEGORIES], CATEGORIES_PHASE[MAX_PLAYERS+1],
	g_TIMER[MAX_PLAYERS+1], g_GLOBAL_TIMER, g_VOTESTATUS[MAX_PLAYERS+1];

enum _:WEAPONS_PARAMS (+=1)
{
	WEAPON_NAME[32] = 0,
	WEAPON_NAME_ID[32],
	WEAPON_BPAMMO
}

new const WEAPONS_CATEGORIES_COUNT[] = {
	MAX_PISTOLS ,
	MAX_SHOTGUNS ,
	MAX_SMG ,
	MAX_RIFLES ,
	MAX_MACHINEGUNS ,
	MAX_FRAGNADES ,
	MAX_MELEE_WPNS
}

new const WEAPONS_INFO[][][WEAPONS_PARAMS] =
{
	{
		{ "USP", "weapon_usp", 100 },
		{ "Glock18", "weapon_glock18", 120 },
		{ "Deagle", "weapon_deagle", 35 },
		{ "P228", "weapon_p228", 52 },
		{ "Five~Seven", "weapon_fiveseven", 100 },
		{ "Elite", "weapon_elite", 120 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 }
	},

	{
		{ "M3", "weapon_m3", 32 },
		{ "Xm1014", "weapon_xm1014", 32 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 }
	},
	
	{
		{ "MP5-Navy", "weapon_mp5navy", 120 },
		{ "TMP", "weapon_tmp", 120 },
		{ "Mac10", "weapon_mac10", 100 },
		{ "P90", "weapon_p90", 100 },
		{ "UMP45", "weapon_ump45", 100 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 }
	},
	
	{
		{ "FAMAS", "weapon_famas", 90 },
		{ "GALIL", "weapon_galil", 90 },
		{ "Scout", "weapon_scout", 90 },
		{ "M4A1", "weapon_m4a1", 90 },
		{ "AK47", "weapon_ak47", 90 },
		{ "AUG", "weapon_aug", 90 },
		{ "SG552", "weapon_sg552", 90 },
		{ "AWP", "weapon_awp", 30 },
		{ "G3SG1", "weapon_g3sg1", 90 },
		{ "SG550", "weapon_sg550", 90 }
	},
	
	{
		{ "M249", "weapon_m249", 1 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 }
	},
	
	{
		{ "Frag Grenade", "weapon_hegrenade", 1 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 }
	},
	
	{
		{ "Knife", "weapon_knife", 1 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 },
		{ "", "", 0 }
	}
}

new g_dayid, HamHook:g_fwd_playerspawn_post, HamHook:g_fwd_playerkilled_post, HamHook:g_fwd_weaponboxspawn_post,
 g_cvar_one, g_cvar_two, g_cvar_three, g_cvar_four, g_cvar_five, g_iMAXPLAYERS, 
 Array:g_array_weapons_order = Invalid_Array, g_cvar_nade_give_length, g_msgTeamInfo, g_TeamInfo_Hook = INVALID_HANDLE;

new g_userkills[33], g_userfrags[33], g_userlevel[33], g_Leader, bool:bGunGameCategoryVote = false;

public plugin_end()
{
	if(g_array_weapons_order != Invalid_Array)
	{
		ArrayDestroy(g_array_weapons_order);
		g_array_weapons_order = Invalid_Array;
	}
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	g_dayid = register_jailbreak_day("Gun Game", 0, 9000.0, DAY_TIMER);
	DisableHamForward(g_fwd_playerspawn_post=RegisterHam(Ham_Spawn, "player", "fw_player_spawn_post", true));
	DisableHamForward(g_fwd_playerkilled_post=RegisterHam(Ham_Killed, "player", "fw_player_killed_post", true));
	DisableHamForward(g_fwd_weaponboxspawn_post=RegisterHam(Ham_Spawn, "weaponbox", "fw_weaponbox_spawn_post", true));
	
	g_cvar_three = register_cvar("jb_day_gg_knife_kill_decrlevel", "1");
	g_cvar_two = register_cvar("jb_day_gg_kills_tolevel", "2");
	g_cvar_one = register_cvar("jb_day_gg_cate_votetime", "2");
	g_cvar_four = register_cvar("jb_day_gg_free4all", "1");
	g_cvar_five = register_cvar("jb_day_gg_knifekill_xp", "2");
	g_cvar_nade_give_length = register_cvar("jb_day_gg_nade_give_length", "1.0");
	
	g_iMAXPLAYERS = get_maxplayers();

	g_msgTeamInfo = get_user_msgid("TeamInfo");
}

announce_thewinner(id)
{
	new players[32], pnum;
	get_players(players, pnum, "ah");
	
	for(new i, player; i < pnum; i++)
	{
		player = players[i];
		strip_user_weapons(player);
		give_item(player, "weapon_knife");
	}
	
	new szText[128], szHeader[64], szName[32];
	get_user_name(id, szName, charsmax(szName));
	formatex(szHeader, charsmax(szHeader), "%s has won the gungame!", szName);
	formatex(szText, charsmax(szText), " %s has won the match !!!", szName)
	show_motd(0, szText, szHeader);
	
	jb_end_theday();
}

leveling(id, increasement=0)
{
	if(g_array_weapons_order == Invalid_Array)
	{
		return -1;
	}
	
	if(increasement != 0)
	{
		g_userlevel[id] = clamp((g_userlevel[id] + increasement), 0, ArraySize(g_array_weapons_order));
		
		// we have a winner...
		if(g_userlevel[id] >= ArraySize(g_array_weapons_order))
		{
			g_Leader = 0;
			announce_thewinner(id);
			return -1;
		}

		check_leader();
		
		fw_player_spawn_post(id);
	}
	
	return clamp(g_userlevel[id], 0, ArraySize(g_array_weapons_order)-1);
}

public grenade_throw(index, greindex, wId)
{
	if(wId == CSW_HEGRENADE && jb_get_current_day() == g_dayid && g_array_weapons_order != Invalid_Array)
	{
		new iLevel = leveling(index);
		if(iLevel < 0 || iLevel >= ArraySize(g_array_weapons_order)) return;

		new xArray[WEAPONS_PARAMS];
		ArrayGetArray(g_array_weapons_order, iLevel, xArray);
		
		if(get_weaponid(xArray[WEAPON_NAME_ID]) != CSW_HEGRENADE) return;
		
		set_task(floatmax(get_pcvar_float(g_cvar_nade_give_length), 0.01) , "give_hegrenade", index);
	}
}

public give_hegrenade(id) if(is_user_alive(id)) give_item(id, "weapon_hegrenade");

public fw_weaponbox_spawn_post(iEntity)
{
	set_pev(iEntity, pev_flags, FL_KILLME);
	dllfunc(DLLFunc_Think, iEntity);
}

public fw_player_spawn_post(id) {
	
	if(!is_user_alive(id) || g_array_weapons_order == Invalid_Array) return;
	
	remove_task(id + TASK_GRANT_WEAPON_LEVEL);
	set_task(0.5, "task_grant_weapon_level", id + TASK_GRANT_WEAPON_LEVEL);
}

public task_grant_weapon_level( id )
{
	id -= TASK_GRANT_WEAPON_LEVEL;
	if(!is_user_alive(id) || g_array_weapons_order == Invalid_Array) return;

	new xArray[WEAPONS_PARAMS];
	ArrayGetArray(g_array_weapons_order, leveling(id), xArray);

	strip_user_weapons(id);

	give_item(id, xArray[WEAPON_NAME_ID]);
	new wpnid = get_weaponid(xArray[WEAPON_NAME_ID]);
	if(wpnid > 0 && wpnid != CSW_KNIFE)
	{
		cs_set_user_bpammo(id, wpnid, xArray[WEAPON_BPAMMO]);
		give_item(id, "weapon_knife");
	}
}

public fw_player_killed_post(victim, killer, shouldgib)
{
	if((g_iMAXPLAYERS >= victim > 0))
	{
		if(killer != victim && (g_iMAXPLAYERS >= killer > 0) && g_array_weapons_order != Invalid_Array)
		{
			static xArray[WEAPONS_PARAMS], szVicName[32], szAttName[32], CSW_WPNID;
			ArrayGetArray(g_array_weapons_order, leveling(killer), xArray);
			
			get_user_name(victim, szVicName, charsmax(szVicName));
			get_user_name(killer, szAttName, charsmax(szAttName));
			get_user_attacker(victim, CSW_WPNID);

			if(!CSW_WPNID) return;
			
			static WPN[32], szText[64];
			get_weaponname(CSW_WPNID, WPN, charsmax(WPN));
			
			new z;
			if(CSW_WPNID == get_weaponid(xArray[WEAPON_NAME_ID]))
			{
				g_userfrags[killer] ++;
				g_userkills[killer] ++;
				
				formatex(szText, charsmax(szText), "has gained '1' XP thanks to (needed '%d' to levelup)", get_pcvar_num(g_cvar_two) - g_userfrags[killer]);
				jb_logmessage_action(szText, killer, victim)
			}
			else if(((z=get_pcvar_num(g_cvar_five)) > 0) && CSW_WPNID == CSW_KNIFE)
			{
				g_userfrags[killer] += z;
				g_userkills[killer] ++;
				formatex(szText, charsmax(szText), "has gained extra '%d' XP thanks to", z);
				jb_logmessage_action(szText, killer, victim)
			}

			if( CSW_WPNID == CSW_KNIFE && ((z=get_pcvar_num(g_cvar_three)) > 0))
			{
				new viclevel = leveling(victim);
				if(!!viclevel)
				{
					z = clamp(z, 1, max(viclevel,1));
					
					formatex(szText, charsmax(szText), "has stole '%d' levels from", z);
					jb_logmessage_action(szText, killer, victim);
					leveling(victim, -z);
					cprint_chat(0, _, "%L", LANG_PLAYER, "GG_CHAT_STOLE_LEVEL", szVicName, szAttName, z);
					
					ArrayGetArray(g_array_weapons_order, (z=leveling(victim)), xArray);
					formatex(szText, charsmax(szText), "gungame player level '%d' '%s'", z + 1, xArray[WEAPON_NAME]);
					jb_logmessage_action(szText, victim);
				}
			}

			if((z=get_pcvar_num(g_cvar_two)) <= g_userfrags[killer])
			{
				if((z=leveling(killer, floatround((g_userfrags[killer]/floatmax(float(z),1.0)),floatround_floor))) != -1)
				{
					ArrayGetArray(g_array_weapons_order, z, xArray);
					formatex(szText, charsmax(szText), "has level up to '%s' thanks to", xArray[WEAPON_NAME]);
					jb_logmessage_action(szText, killer, victim)
					
					formatex(szText, charsmax(szText), "gungame player level '%d' '%s'", z + 1, xArray[WEAPON_NAME]);
					jb_logmessage_action(szText, killer);
					
					if( (ArraySize(g_array_weapons_order)-1) == z )
					{
						formatex(szText, charsmax(szText), "gungame '%s' is on the final level!", szAttName);
						jb_logmessage(szText);
					}
				}
				
				g_userfrags[killer] = 0;
			}
		}
		
		set_task(2.0, "task_respawn", victim);
	}
}

public task_respawn(id)
{
	if(!is_user_alive(id) && is_user_connected(id))
	{
		const PDATA_SAFE = 2;
		if(pev_valid(id) && (TEAM_PRISONERS <= fm_get_user_team(id) <= TEAM_GUARDS))
			ExecuteHamB(Ham_CS_RoundRespawn, id);
	}
}

public jb_day_start(iDayid)
{
	if(g_dayid == iDayid)
	{
		if(bGunGameCategoryVote)
		{
			bGunGameCategoryVote = false;
			return JB_IGNORED;
		}
		
		bGunGameCategoryVote = true;
		
		EnableHamForward(g_fwd_playerspawn_post);
		EnableHamForward(g_fwd_playerkilled_post);
		EnableHamForward(g_fwd_weaponboxspawn_post);
		
		new iTime = max(get_pcvar_num(g_cvar_one), 1);
		arrayset(CATEGORIES_PHASE, PHASE_FIRST, sizeof CATEGORIES_PHASE);
		arrayset(g_TIMER, iTime, sizeof g_TIMER);
		arrayset(g_VOTESTATUS, 0, sizeof g_VOTESTATUS);
		arrayset(g_userkills, 0, sizeof g_userkills);
		arrayset(g_userfrags, 0, sizeof g_userfrags);
		arrayset(g_userlevel, 0, sizeof g_userlevel);
		arrayset(CATEGORIES_VOTES[PHASE_FIRST], 0, sizeof CATEGORIES_VOTES[]);
		arrayset(CATEGORIES_VOTES[PHASE_SECOND], 0, sizeof CATEGORIES_VOTES[]);
		arrayset(CATEGORIES_VOTES[PHASE_THIRD], 0, sizeof CATEGORIES_VOTES[]);
		arrayset(CATEGORIES_VOTES[PHASE_FOURTH], 0, sizeof CATEGORIES_VOTES[]);
		arrayset(CATEGORIES_VOTES[PHASE_FIFTH], 0, sizeof CATEGORIES_VOTES[]);
		arrayset(CATEGORIES_VOTES[PHASE_SIXTH], 0, sizeof CATEGORIES_VOTES[]);
		arrayset(CATEGORIES_VOTES[PHASE_FINAL], 0, sizeof CATEGORIES_VOTES[]);
		g_GLOBAL_TIMER = ((iTime + 1) * MAX_CATEGORIES);
		set_task(1.0, "voting_ended", TASK_VOTEMENU, _, _, "b");
		
		new players[32], pnum, player;
		get_players(players, pnum, "h");

		const PDATA_SAFE = 2;
		
		while( pnum-- > 0 )
		{
			player = players[pnum];
			
			if(!is_user_bot(player))
			{
				vote_menu(player);
				set_task(1.0, "task_progress", player + TASK_VOTEMENU, _, _, "b");
			}
			
			if(pev_valid(player) == PDATA_SAFE && !is_user_alive(player) && (TEAM_PRISONERS <= fm_get_user_team(player) <= TEAM_GUARDS))
			{
				ExecuteHamB(Ham_CS_RoundRespawn, player);
			}
		}
		
		return JB_HANDLED;
	}
	
	if(bGunGameCategoryVote)
	{
		return JB_HANDLED;
	}
	return JB_IGNORED;
}

public jb_day_started(iDayID)
{
	if(g_dayid == iDayID)
	{
		if(get_pcvar_num(g_cvar_four) > 0)
		{
			for(new i = 1; i <= g_iMAXPLAYERS; i++)
			{
				jb_set_user_enemies(i, JB_ENEMIES_EVERYONE);
				jb_display_on_player_radar(i, JB_DISPLAY_RADAR_ALL);
			}
		}
		else
		{
			for(new i = 1; i <= g_iMAXPLAYERS; i++) jb_set_user_enemies(i, JB_ENEMIES_DEFAULT);
		}
		if(g_msgTeamInfo > 0 && g_TeamInfo_Hook == INVALID_HANDLE)
		{
			g_TeamInfo_Hook = register_message(g_msgTeamInfo, "fw_TeamInfo_hook");
		}
	}
}

public fw_TeamInfo_hook(msgid, dest, id)
{
	if(get_msg_argtype(2) != ARG_STRING) return;
	
	new szTeam[2],
	player = get_msg_arg_int(1);
	get_msg_arg_string(2, szTeam, charsmax(szTeam));

	switch( szTeam[0] )
	{
		case 'C', 'c', 'T', 't':
		{
			set_task(3.0, "task_respawn", player);
		}
	}
}

public client_disconnect(id)
{
	if(task_exists(id + TASK_VOTEMENU)) remove_task(id + TASK_VOTEMENU);
	if(task_exists(id)) remove_task(id);

	if(id == g_Leader)
	{
		g_Leader = 0;
		check_leader();
	}
}

public jb_day_ended(iDayid)
{
	if(g_dayid == iDayid)
	{
		if(g_msgTeamInfo > 0 && g_TeamInfo_Hook != INVALID_HANDLE)
		{
			unregister_message(g_msgTeamInfo, g_TeamInfo_Hook);
			g_TeamInfo_Hook = INVALID_HANDLE;
		}

		bGunGameCategoryVote = false;
		g_Leader = 0;

		for(new i = 1; i <= g_iMAXPLAYERS; i++)
		{
			jb_set_user_enemies(i, JB_ENEMIES_DEFAULT);
			jb_display_on_player_radar(i, JB_DISPLAY_RADAR_DEFAULT);
		}

		DisableHamForward(g_fwd_playerspawn_post);
		DisableHamForward(g_fwd_playerkilled_post);
		DisableHamForward(g_fwd_weaponboxspawn_post);
		
		remove_task(TASK_VOTEMENU);
		
		new players[32], pnum, player;
		get_players(players, pnum, "ch");
		
		while( pnum-- > 0 )
		{
			player = players[pnum];
			if(task_exists(player + TASK_VOTEMENU)) remove_task(player + TASK_VOTEMENU);
		}

		if(g_array_weapons_order != Invalid_Array)
		{
			ArrayDestroy(g_array_weapons_order);
			g_array_weapons_order = Invalid_Array;
		}
	}
}

public jb_round_end_pre()
{
	if(bGunGameCategoryVote)
	{
		return JB_HANDLED;
	}
	return JB_IGNORED;
}

public voting_ended(taskid)
{
	if(!g_GLOBAL_TIMER)
	{
		show_menu(0, 0, " ^n ");
		
		if(g_array_weapons_order == Invalid_Array) g_array_weapons_order = ArrayCreate(WEAPONS_PARAMS, 1);
		
		new iWpnOrder[MAX_CATEGORIES],
		iAvailableList[MAX_CATEGORIES] = {
			CATEGORY_PISTOLS,
			CATEGORY_SHOTGUNS,
			CATEGORY_SMG,
			CATEGORY_RIFLES,
			CATEGORY_MACHINEGUNS,
			CATEGORY_FRAGNADE,
			CATEGORY_MELEE }, AvailableListSize=MAX_CATEGORIES;

		for(new PHASE, list_id, chosen, i, x; PHASE < MAX_PHASES; PHASE++)
		{
			chosen = iAvailableList[ (list_id = 0) ];

			if(AvailableListSize >= 1)
			{
				for(i = 1; i < AvailableListSize; i++)
				{
					x = iAvailableList[ i ];
					if(CATEGORIES_VOTES[ PHASE ][ x ] > CATEGORIES_VOTES[ PHASE ][chosen])
					{
						chosen = x;
						list_id = i;
					}
				}

				iAvailableList[ list_id ] = iAvailableList[ --AvailableListSize ];
			}

			iWpnOrder[ PHASE ] = chosen;
		}
		
		for(new i, j, xArray[WEAPONS_PARAMS], maxloop, x; i < MAX_CATEGORIES; i++)
		{
			x = iWpnOrder[i];
			maxloop = WEAPONS_CATEGORIES_COUNT[x];
			for(j = 0; j < maxloop; j++)
			{
				copy(xArray[WEAPON_NAME], charsmax(xArray[WEAPON_NAME]), WEAPONS_INFO[x][j][WEAPON_NAME]);
				copy(xArray[WEAPON_NAME_ID], charsmax(xArray[WEAPON_NAME_ID]), WEAPONS_INFO[x][j][WEAPON_NAME_ID]);
				xArray[WEAPON_BPAMMO] = WEAPONS_INFO[x][j][WEAPON_BPAMMO];
				ArrayPushArray(g_array_weapons_order, xArray);
			}
		}
		
		// start the DAY!
		jb_start_theday(g_dayid);
		
		new szText[MAX_LOG_MESSAGE_LENGTH],
		FirstGunCategory = iWpnOrder[0];
		formatex(szText, charsmax(szText), "GunGame match has begin! (first gun '%s')", WEAPONS_INFO[FirstGunCategory][0][WEAPON_NAME]);
		jb_logmessage(szText);
		
		new players[32], pnum, player;
		get_players(players, pnum, "he", "CT");
		while( pnum-- > 0 )
		{
			player = players[pnum];
			formatex(szText, charsmax(szText), "gungame player level '1' '%s'", WEAPONS_INFO[FirstGunCategory][0][WEAPON_NAME]);
			jb_logmessage_action(szText, player);
			ExecuteHamB(Ham_CS_RoundRespawn, player);
		}
		
		get_players(players, pnum, "he", "TERRORIST");
		while( pnum-- > 0 )
		{
			player = players[pnum];
			formatex(szText, charsmax(szText), "gungame player level '%d' '%s'", 1, WEAPONS_INFO[FirstGunCategory][0][WEAPON_NAME]);
			jb_logmessage_action(szText, player);
			ExecuteHamB(Ham_CS_RoundRespawn, player);
		}
		
		remove_task(taskid);
		
		return;
	}
	
	// update weapons category order menu.
	update_wpns_category_order_menu();
	g_GLOBAL_TIMER --;
}

check_leader()
{
	new players[32], pnum, player, i;
	get_players(players, pnum, "he", "CT");
	
	new iNewLeader = players[0];
	
	for(i = 0; i < pnum; i++)
	{
		player = players[i];
		if(g_userlevel[player] > g_userlevel[iNewLeader])
			if(g_userkills[player] > g_userkills[iNewLeader])
			{
				iNewLeader = player;
			}
	}
	
	get_players(players, pnum, "he", "TERRORIST");
	for(i = 0; i < pnum; i++)
	{
		player = players[i];
		if(g_userlevel[player] > g_userlevel[iNewLeader])
			if(g_userkills[player] > g_userkills[iNewLeader])
			{
				iNewLeader = player;
			}
	}
	
	if(g_iMAXPLAYERS >= iNewLeader > 0)
	{
		if(!g_Leader)
		{
			jb_logmessage_action("1st leader leading the gungame", iNewLeader);
			g_Leader = iNewLeader;
		}
		else if(iNewLeader != g_Leader)
		{
			jb_logmessage_action("is leading the gungame", iNewLeader);
			jb_logmessage_action("has stolen the gungame lead from", iNewLeader, g_Leader);
			g_Leader = iNewLeader;
		}
	}
}

public task_progress(id)
{
	id -= TASK_VOTEMENU;
	
	static iTime;
	iTime = g_TIMER[id] --;
	
	if(!iTime)
	{
		CATEGORIES_PHASE[id] ++;
		
		if(CATEGORIES_PHASE[id] > PHASE_FINAL)
		{
			if(!g_GLOBAL_TIMER)
			{
				remove_task(id + TASK_VOTEMENU);
				return;
			}
			
			g_TIMER[id] = g_GLOBAL_TIMER;
		}
		else
		{
			g_TIMER[id] = max(get_pcvar_num(g_cvar_one), 1);
		}
	}
	
	vote_menu(id, g_VOTESTATUS[id]);
}

vote_menu(id, votestatus=0)
{
	new sText[256];
	if(CATEGORIES_PHASE[id] > PHASE_FINAL)
	{
		new szString[MAX_PHASES][32];

		new iAvailableList[MAX_CATEGORIES] = {
			CATEGORY_PISTOLS,
			CATEGORY_SHOTGUNS,
			CATEGORY_SMG,
			CATEGORY_RIFLES,
			CATEGORY_MACHINEGUNS,
			CATEGORY_FRAGNADE,
			CATEGORY_MELEE }, AvailableListSize=MAX_CATEGORIES;

		for(new PHASE, list_id, chosen, i, x; PHASE < MAX_PHASES; PHASE++)
		{
			chosen = iAvailableList[ (list_id = 0) ];

			if(AvailableListSize >= 1)
			{
				for(i = 1; i < AvailableListSize; i++)
				{
					x = iAvailableList[ i ];
					if(CATEGORIES_VOTES[ PHASE ][ x ] > CATEGORIES_VOTES[ PHASE ][chosen])
					{
						chosen = x;
						list_id = i;
					}
				}

				iAvailableList[ list_id ] = iAvailableList[ --AvailableListSize ];
			}

			copy(szString[PHASE], charsmax(szString[]), Weapons_categories[chosen]);
		}
		
		formatex(sText, charsmax(sText), "%L ^n^n^n\
		\r1st. \w%s^n\
		\r2th. \w%s^n\
		\r3th. \w%s^n\
		\r4th. \w%s^n\
		\r5th. \w%s^n\
		\r6th. \w%s^n\
		\r7th. \w%s^n^n^n", id, "GG_CATEGORY_VOTEMENU_TITLE",
		g_GLOBAL_TIMER, szString[PHASE_FIRST], szString[PHASE_SECOND],
			szString[PHASE_THIRD], szString[PHASE_FOURTH], szString[PHASE_FIFTH], szString[PHASE_SIXTH], szString[PHASE_FINAL]);
		new menu = menu_create(sText, "vote_menu_handler", true);
		
		formatex(sText, charsmax(sText), "%L", id, "MENU_EXIT");
		menu_additem(menu, sText, "SERIAL_000");
		menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
		menu_display(id, menu);
	}
	else
	{
		formatex(sText, charsmax(sText), "%L", id, "GG_CATEGORY_VOTEMENU_TITLE2",
		CATEGORIES_PHASE[id] + 1, (CATEGORIES_PHASE[id] == PHASE_FIRST) ? "st":"th", g_TIMER[id]);
		new menu = menu_create(sText, "vote_menu_handler",true);
		
		const NO_ACCESS = (1<<26);
		
		for(new i, maxloop = sizeof Weapons_categories; i < maxloop; i++)
		{
			formatex(sText, charsmax(sText), "%s%s   \y%d votes", votestatus & (1<<(i&31)) ? "\d":"\r", Weapons_categories[i],
										CATEGORIES_VOTES[min(CATEGORIES_PHASE[id],PHASE_FINAL)][i]);

			menu_additem(menu, sText, "", votestatus & (1<<(i&31)) ? NO_ACCESS:0);
		}
		
		menu_setprop(menu, MPROP_PERPAGE, 0);
		formatex(sText, charsmax(sText), "%L", id, "MENU_EXIT");
		menu_additem(menu, sText, "Exit");
		menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
		menu_display(id, menu);
	}
}

public vote_menu_handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	if(CATEGORIES_PHASE[id] > PHASE_FINAL)
	{
		remove_task(id+TASK_VOTEMENU);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new szInfo[2], iCall, pAccess;
	menu_item_getinfo(menu, item, pAccess, szInfo, charsmax(szInfo), "", 0, iCall);
	menu_destroy(menu);
	
	if(szInfo[0] == 'E') // Player self exit the menu.
	{
		remove_task(id+TASK_VOTEMENU);
		return PLUGIN_HANDLED;
	}
	
	CATEGORIES_VOTES[min(CATEGORIES_PHASE[id],PHASE_FINAL)][item] ++;
	
	new szText[64];
	formatex(szText, charsmax(szText), "GunGame voted for %s to be in the %d%s phase", Weapons_categories[item], CATEGORIES_PHASE[id] + 1, CATEGORIES_PHASE[id] > PHASE_FIRST ? "th":"st");
	jb_logmessage_action(szText, id);
	
	g_TIMER[id] = max(get_pcvar_num(g_cvar_one), 1);
	CATEGORIES_PHASE[id] ++;
	g_VOTESTATUS[id] |= (1<<(item&31));
	
	vote_menu(id, g_VOTESTATUS[id]);

	// update weapons category order menu.
	update_wpns_category_order_menu();
	
	return PLUGIN_HANDLED;
}

update_wpns_category_order_menu()
{
	new players[32], pnum, OldMenu, NewMenu, pAccess, sInfo[12], iCall;
	get_players(players, pnum, "ch");
	for(new i, player; i < pnum; i++)
	{
		player = players[i];
		
		if(player_menu_info(player, OldMenu, NewMenu) == 1)
		{
			if(NewMenu > -1)
			{
				menu_item_getinfo(NewMenu, 0, pAccess, sInfo, charsmax(sInfo), "", 0, iCall);
				if(equal(sInfo, "SERIAL_000"))
				{
					vote_menu(player, g_VOTESTATUS[player]);
				}
			}
		}
	}
}