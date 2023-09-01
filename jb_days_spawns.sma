/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <amxmisc>
#include <jailbreak_core>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <rog>

#define PLUGIN "[JB] DAYS:SPAWNS"
#define AUTHOR "Natsheh"

#define MAX_ROG_SPAWNS 64 // maximum random origin generator locations quantity.
#define ROG_MINIMUM_DISTANCE 600.0

#define TASK_SHOW_SPAWNS 329851
#define TASK_RETRIEVE_SPAWN 365478

#if !defined EOS
#define EOS 0
#endif

#if AMXX_VERSION_NUM > 182
	#define client_disconnect client_disconnected
#endif

new MAP_NAME[64], szDataDir[96], bool:g_show_spawns[MAX_PLAYERS+1],
DAYS_MENU, Trie:g_trie_days_spawns, pcvar_auto_rog, 
g_maxplayers, g_laser_spr, HamHook:PrePlayerSpawn, g_iMaxSpecialDaysRegistered,
Array:array_available_ctspawns, Array:array_available_tspawns;

new FILE_NAME[MAX_PLAYERS+1][68], bool:bUserCopy[MAX_PLAYERS+1];

new g_rog_count;

const FILE_KEYVALUE_ERROR = -4;
const FILE_KEYVALUE_FINAL_VALUE = -3;
const FILE_KEYVALUE_KEY_CREATED = -2;
const FILE_KEYVALUE_NO_OUTPUT = -1;
const FILE_KEYVALUE_EDIT = 0;

enum FILE_KEYVALUE_OPERATIONS(+=1)
{
	FILE_KEYVALUE_COPY = 0,
	FILE_KEYVALUE_ADD,
	FILE_KEYVALUE_CHECK,
	FILE_KEYVALUE_REMOVE
}

enum _:SPAWN_INFO
{
	SPAWN_CLASSNAME[32],
	Float:SPAWN_ORIGIN[3],
	SPAWN_TEAM
}

new const Float:PLAYER_SIZE[] = { -16.0, -16.0, -36.0, 16.0, 16.0, 36.0 };

public plugin_precache()
{
	g_laser_spr = precache_model("sprites/laserbeam.spr");
}

public plugin_end()
{
	ArrayDestroy(array_available_ctspawns);
	ArrayDestroy(array_available_tspawns);

	if(g_trie_days_spawns != Invalid_Trie)
	{
		if(g_iMaxSpecialDaysRegistered > 0)
		{
			for(new i, Trie:i_pTrie, szValue[32]; i < g_iMaxSpecialDaysRegistered; i++)
			{
				num_to_str(i, szValue, charsmax(szValue));
				TrieGetCell(g_trie_days_spawns, szValue, i_pTrie);

				if(i_pTrie != Invalid_Trie)
				{
					TrieDestroy(i_pTrie);
				}
			}
		}

		TrieDestroy(g_trie_days_spawns);
	}

	if(DAYS_MENU != INVALID_HANDLE) menu_destroy( DAYS_MENU );
}

public client_connect(id) bUserCopy[id] = false;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	g_maxplayers = get_maxplayers();
	
	get_mapname(MAP_NAME, charsmax(MAP_NAME));
	get_datadir(szDataDir, charsmax(szDataDir));
	format(szDataDir, charsmax(szDataDir), "%s/jb_days_spawns", szDataDir);
	
	if(!dir_exists(szDataDir))
	{
		mkdir(szDataDir);
	}
	
	g_trie_days_spawns = TrieCreate();
	array_available_ctspawns = ArrayCreate(SPAWN_INFO,1);
	array_available_tspawns = ArrayCreate(SPAWN_INFO,1);
	
	register_clcmd("jb_days_spawn_editor", "clcmd_editor", ADMIN_RESERVATION);
	pcvar_auto_rog = register_cvar("jb_days_spawn_auto_rog", "1");
	
	DisableHamForward(PrePlayerSpawn = RegisterHam(Ham_Spawn, "player", "Player_Spawn_Post", 1));
}

public ROG_Counter(Float:fOrigin[3])
{
	if(!check_spawn_valid(fOrigin, PLAYER_SIZE) || (g_rog_count >= MAX_ROG_SPAWNS))
		return 0;

	g_rog_count++;
	return 1;
}

public Player_Spawn_Post(id)
{
	static array_size;
	
	switch( get_user_team(id) )
	{
		case TEAM_GUARDS: {
			if(!(array_size=ArraySize(array_available_ctspawns))) return;
			
			static xArray[SPAWN_INFO], Float:fOrigin[3], x, szString[96];
			ArrayGetArray(array_available_ctspawns, x = random(array_size), xArray);
			fOrigin[0] = xArray[SPAWN_ORIGIN][0];
			fOrigin[1] = xArray[SPAWN_ORIGIN][1];
			fOrigin[2] = xArray[SPAWN_ORIGIN][2];

			if( check_spawn_valid(fOrigin, PLAYER_SIZE) )
			{
				engfunc(EngFunc_SetOrigin, id, fOrigin);
			}

			ArrayDeleteItem(array_available_ctspawns, x);
			formatex(szString, charsmax(szString), "^"%.14f^" ^"%.14f^" ^"%.14f^"", fOrigin[0], fOrigin[1], fOrigin[2]);
			set_task(1.0, "retrieve_ctspawn", TASK_RETRIEVE_SPAWN+id, szString, strlen(szString));
		}
		case TEAM_PRISONERS: {
			if(!(array_size=ArraySize(array_available_tspawns))) return;
			
			static xArray[SPAWN_INFO], Float:fOrigin[3], x, szString[96];
			ArrayGetArray(array_available_tspawns, x = random(array_size), xArray);
			fOrigin[0] = xArray[SPAWN_ORIGIN][0];
			fOrigin[1] = xArray[SPAWN_ORIGIN][1];
			fOrigin[2] = xArray[SPAWN_ORIGIN][2];

			if( check_spawn_valid(fOrigin, PLAYER_SIZE) )
			{
				engfunc(EngFunc_SetOrigin, id, fOrigin);
			}

			ArrayDeleteItem(array_available_tspawns, x);
			formatex(szString, charsmax(szString), "^"%.14f^" ^"%.14f^" ^"%.14f^"", fOrigin[0], fOrigin[1], fOrigin[2]);
			set_task(1.0, "retrieve_tspawn", TASK_RETRIEVE_SPAWN+id, szString, strlen(szString));
		}
	}
}

public retrieve_ctspawn(const string[], taskid)
{
	new szVector[3][32];
	parse(string, szVector[0], charsmax(szVector[]),szVector[1], charsmax(szVector[]), szVector[2], charsmax(szVector[]));
	new any:xArray[SPAWN_INFO];
	
	for(new i; i < 3; i++)
	{
		trim(szVector[i]);
		remove_quotes(szVector[i]);
		xArray[SPAWN_ORIGIN][i] = floatstr(szVector[i]);
	}

	if( check_spawn_valid(xArray[SPAWN_ORIGIN], PLAYER_SIZE) )
		ArrayPushArray(array_available_ctspawns, xArray);
	else
		set_task(1.0, "retrieve_ctspawn", taskid, string, strlen(string));
}


public retrieve_tspawn(const string[], taskid)
{
	new szVector[3][32];
	parse(string, szVector[0], charsmax(szVector[]), szVector[1], charsmax(szVector[]), szVector[2], charsmax(szVector[]))
	new any:xArray[SPAWN_INFO];
	
	for(new i; i < sizeof szVector; i++)
	{
		trim(szVector[i]);
		remove_quotes(szVector[i]);
		xArray[SPAWN_ORIGIN][i] = floatstr(szVector[i]);
	}
	
	if( check_spawn_valid(xArray[SPAWN_ORIGIN], PLAYER_SIZE) )
		ArrayPushArray(array_available_tspawns, xArray);
	else
		set_task(1.0, "retrieve_tspawn", taskid, string, strlen(string));
}

public clcmd_editor(id, level, cid)
{
	if(!cmd_access(id, level, cid,1))
	{
		return 1;
	}
	
	place_spawns_menu(id);
	return 1;
}

public plugin_cfg()
{
	file_keyvalue("jb_days_random_spawns_gen.cfg", szDataDir, "INFO", FILE_KEYVALUE_ADD, "Remove unwanted specialday name from the file to disable auto spawn generating for that specialday!");

	new sDayname[64], pcvarvalue_auto_rog = get_pcvar_num(pcvar_auto_rog);
	
	DAYS_MENU = menu_create("Choose a day to edit its spawns!", "day_menu_handler");

	g_iMaxSpecialDaysRegistered = jb_get_days_registered();
	if(g_iMaxSpecialDaysRegistered > 0)
	{
		jb_get_day_name(0, sDayname, charsmax(sDayname))
		
		for(new i = 0; i < g_maxplayers; i++)
		{
			formatex(FILE_NAME[i], charsmax(FILE_NAME[]), "%s.txt", sDayname);
		}

		new bool:bSpecialdaysAutoSpawnGenerating = false, bool:ROG_bCache = false;
		if(file_keyvalue("jb_days_random_spawns_gen.cfg", szDataDir, "ENABLED", FILE_KEYVALUE_CHECK, "") == FILE_KEYVALUE_KEY_CREATED )
		{
			bSpecialdaysAutoSpawnGenerating = true;
		}

		new bool:DAY_MAP_CATE_EXIST=false, Array:tmp_array, __half_spawns;
		for(new j = 0, i = 0, Float:fOrigin[3], szVector[3][20], szValue[128], xArray[SPAWN_INFO],
			szFile[68], szClassname[32],iStartL; i < g_iMaxSpecialDaysRegistered; i++)
		{
			jb_get_day_name(i, sDayname, charsmax(sDayname));
			menu_additem(DAYS_MENU, sDayname);
			TrieSetCell(g_trie_days_spawns, sDayname, (tmp_array=ArrayCreate(SPAWN_INFO,1)));
			num_to_str(i, szValue, charsmax(szValue));
			TrieSetCell(g_trie_days_spawns, szValue, tmp_array);

			iStartL = 0;
			formatex(szFile, charsmax(szFile), "%s.txt", sDayname);
			
			DAY_MAP_CATE_EXIST = file_keyvalue(szFile, szDataDir, MAP_NAME, FILE_KEYVALUE_CHECK, "") == FILE_KEYVALUE_KEY_CREATED ? false:true;
			
			if(DAY_MAP_CATE_EXIST)
			{
				while( ((iStartL=file_keyvalue(szFile, szDataDir, MAP_NAME, FILE_KEYVALUE_COPY, szValue, charsmax(szValue), iStartL)) != FILE_KEYVALUE_NO_OUTPUT))
				{
					if(szValue[0] != EOS && parse(szValue, szVector[0], charsmax(szVector[]),
						szVector[1], charsmax(szVector[]), szVector[2], charsmax(szVector[]),
							szClassname, charsmax(szClassname)) == 4)
					{
						trim(szVector[0]);
						trim(szVector[1]);
						trim(szVector[2]);
						remove_quotes(szVector[0]);
						remove_quotes(szVector[1]);
						remove_quotes(szVector[2]);
						remove_quotes(szClassname);
						fOrigin[0] = floatstr(szVector[0]);
						fOrigin[1] = floatstr(szVector[1]);
						fOrigin[2] = floatstr(szVector[2]);
						
						copy(xArray[SPAWN_CLASSNAME], charsmax(xArray[SPAWN_CLASSNAME]), szClassname);
						xArray[SPAWN_ORIGIN][0] = _:fOrigin[0];
						xArray[SPAWN_ORIGIN][1] = _:fOrigin[1];
						xArray[SPAWN_ORIGIN][2] = _:fOrigin[2];

						if(equal(xArray[SPAWN_CLASSNAME], "info_player_deathmatch"))
							xArray[SPAWN_TEAM] = TEAM_PRISONERS;
						else if(equal(xArray[SPAWN_CLASSNAME], "info_player_start"))
							xArray[SPAWN_TEAM] = TEAM_GUARDS;

						ArrayPushArray(tmp_array, xArray);
					}

					szValue[0] = EOS;
				}
			}
			else if(!DAY_MAP_CATE_EXIST && pcvarvalue_auto_rog) // automatic random spawn generating?
			{
				if( bSpecialdaysAutoSpawnGenerating )
				{
					file_keyvalue("jb_days_random_spawns_gen.cfg", szDataDir, "ENABLED", FILE_KEYVALUE_ADD, sDayname);
				}
				else if(file_keyvalue("jb_days_random_spawns_gen.cfg", szDataDir, "ENABLED", FILE_KEYVALUE_CHECK, sDayname) <= -1 )
				{
					continue;
				}

				if( !ROG_bCache )
				{
					ROG_bCache = true;
					g_rog_count = 0;
					ROGInitialize(ROG_MINIMUM_DISTANCE, "ROG_Counter");

					server_print("[ SPECIAL DAYS AUTO SPAWN GENERATOR ]");
					server_print(" >> MAP : %s", MAP_NAME);
					server_print(" >> RANDOM SPAWNS GENERATED: %d", g_rog_count);
				}

				ROGShuffleOrigins();
				__half_spawns = floatround(g_rog_count * 0.5);

				// TEAM_GUARDS
				for(j = 0; j < __half_spawns; j++)
				{
					ROGGetOrigin(fOrigin);
					formatex(szValue, charsmax(szValue), "^"%.14f^" ^"%.14f^" ^"%.14f^" ^"%s^"",
										fOrigin[0], fOrigin[1], fOrigin[2], "info_player_start");
					file_keyvalue(szFile, szDataDir, MAP_NAME, FILE_KEYVALUE_ADD, szValue);

					copy(xArray[SPAWN_CLASSNAME], charsmax(xArray[SPAWN_CLASSNAME]), "info_player_start");
					xArray[SPAWN_ORIGIN][0] = _:fOrigin[0];
					xArray[SPAWN_ORIGIN][1] = _:fOrigin[1];
					xArray[SPAWN_ORIGIN][2] = _:fOrigin[2];
					xArray[SPAWN_TEAM] = TEAM_GUARDS;
					TrieGetCell(g_trie_days_spawns, sDayname, tmp_array);
					ArrayPushArray(tmp_array, xArray);
				}

				// TEAM_PRISONERS
				for(j = __half_spawns; j < g_rog_count; j++)
				{
					ROGGetOrigin(fOrigin);
					formatex(szValue, charsmax(szValue), "^"%.14f^" ^"%.14f^" ^"%.14f^" ^"%s^"",
										fOrigin[0], fOrigin[1], fOrigin[2], "info_player_deathmatch");
					file_keyvalue(szFile, szDataDir, MAP_NAME, FILE_KEYVALUE_ADD, szValue);
					
					copy(xArray[SPAWN_CLASSNAME], charsmax(xArray[SPAWN_CLASSNAME]), "info_player_deathmatch");
					xArray[SPAWN_ORIGIN][0] = _:fOrigin[0];
					xArray[SPAWN_ORIGIN][1] = _:fOrigin[1];
					xArray[SPAWN_ORIGIN][2] = _:fOrigin[2];
					xArray[SPAWN_TEAM] = TEAM_PRISONERS;
					TrieGetCell(g_trie_days_spawns, sDayname, tmp_array);
					ArrayPushArray(tmp_array, xArray);
				}
			}
		}
	}
}

public day_menu_handler(id, menu, item)
{
	switch(item)
	{
		case MENU_EXIT: return PLUGIN_HANDLED;
		default:
		{
			new szData[64], paccess;
			menu_item_getinfo(menu, item, paccess, "", 0, szData, charsmax(szData), paccess);
			
			if(bUserCopy[id])
			{
				new Array:tmpArray;
				TrieGetCell(g_trie_days_spawns, szData, tmpArray);
				
				if(!ArraySize(tmpArray))
				{
					cprint_chat(id, _, "!g***** !tThis special day has no private spawns to copy from !g*****")
				}
				else
				{
					new Array:tmpArray2, szString[128], Float:fOrigin[3], szDayname[64];
					copyc(szDayname, charsmax(szDayname), FILE_NAME[id], '.');
					TrieGetCell(g_trie_days_spawns, szDayname, tmpArray2);
					
					for(new i, xArray[SPAWN_INFO], maxloop = ArraySize(tmpArray); i < maxloop; i++)
					{
						ArrayGetArray(tmpArray, i, xArray);
						ArrayPushArray(tmpArray2, xArray);
						
						fOrigin[0] = xArray[SPAWN_ORIGIN][0];
						fOrigin[1] = xArray[SPAWN_ORIGIN][1];
						fOrigin[2] = xArray[SPAWN_ORIGIN][2];
						formatex(szString, charsmax(szString), "^"%.14f^" ^"%.14f^" ^"%.14f^" ^"%s^"",
								fOrigin[0], fOrigin[1], fOrigin[2], xArray[SPAWN_CLASSNAME]);
						file_keyvalue(FILE_NAME[id], szDataDir, MAP_NAME, FILE_KEYVALUE_ADD, szString);
					}
					
					cprint_chat(id, _, "!t***** !gThe %s Spawns has successfully copied to the %s !t*****", szData, szDayname)
				}
				
				bUserCopy[id] = false;
				place_spawns_menu(id)
				return PLUGIN_HANDLED;
			}
			
			formatex(FILE_NAME[id], charsmax(FILE_NAME[]), "%s.txt", szData);
			place_spawns_menu(id);
		}
	}
	
	return PLUGIN_HANDLED;
}

public client_disconnect(id)
{
	g_show_spawns[id] = false;
	bUserCopy[id] = false;
}

public jb_day_started(iDayid)
{
	if(iDayid > DAY_NONE) {
		new sDayname[64], Array:tmpArray;
		jb_get_day_name(iDayid, sDayname, charsmax(sDayname))
		TrieGetCell(g_trie_days_spawns, sDayname, tmpArray);
		
		if(ArraySize(tmpArray) > 0)
		{
			set_day_spawns(tmpArray);
		}
	}
}

public jb_round_end()
{
	DisableHamForward(PrePlayerSpawn);
}

public jb_day_end(iDayid)
{
	DisableHamForward(PrePlayerSpawn);
}

set_day_spawns(Array:array_spawns)
{
	ArrayClear(array_available_tspawns);
	ArrayClear(array_available_ctspawns);
	
	new xArray[SPAWN_INFO];
	for(new i, maxloop = ArraySize(array_spawns); i < maxloop; i++)
	{
		ArrayGetArray(array_spawns, i, xArray);
		
		if(equal(xArray[SPAWN_CLASSNAME], "info_player_deathmatch"))
			ArrayPushArray(array_available_tspawns, xArray);
		else if(equal(xArray[SPAWN_CLASSNAME], "info_player_start"))
			ArrayPushArray(array_available_ctspawns, xArray);
	}
	
	EnableHamForward(PrePlayerSpawn);
	
	new players[32], pnum;
	get_players(players, pnum, "ah");
	
	for(new i; i < pnum; i++)
	{
		set_task(0.1, "Player_Spawn_Post", players[i]);
	}
}

place_spawns_menu(id)
{
	new sText[128];
	formatex(sText, charsmax(sText), "\wDays \r~[\ySpawns Editor\r]~");
	new menu =menu_create(sText, "menu_handler");
	
	new Array:tmpArray, szDayname[64], ctspawns, tspawns;
	copyc(szDayname, charsmax(szDayname), FILE_NAME[id], '.');
	TrieGetCell(g_trie_days_spawns, szDayname, tmpArray);
	for(new i, xArray[SPAWN_INFO], maxloop = ArraySize(tmpArray); i < maxloop; i++)
	{
		ArrayGetArray(tmpArray, i, xArray);
		
		if(equal(xArray[SPAWN_CLASSNAME], "info_player_deathmatch"))
			tspawns++;
		else if(equal(xArray[SPAWN_CLASSNAME], "info_player_start"))
			ctspawns++;
	}
	
	// item number 1
	formatex(sText, charsmax(sText), "\rAdd \ya CT-Spawn!^n>> %d Spawns.", ctspawns);
	menu_additem(menu, sText, "");
	
	// item number 2
	formatex(sText, charsmax(sText), "\rAdd \ya T-Spawn!^n>> %d Spawns.", tspawns);
	menu_additem(menu, sText, "");
	
	// item number 3
	formatex(sText, charsmax(sText), "\rRemove \ya Spawn!^n");
	menu_additem(menu, sText, "");
	
	// item number 4
	formatex(sText, charsmax(sText), "\rRemove All the Spawns!^n");
	menu_additem(menu, sText, "");

	// item number 5
	formatex(sText, charsmax(sText), "\yRemove a Spawn from all specialdays!^n");
	menu_additem(menu, sText, "");
	
	// item number 6
	formatex(sText, charsmax(sText), "\yShow \wSpawns: %s.", g_show_spawns[id] ? "Yes":"No");
	menu_additem(menu, sText, "");
	
	// item number 7
	formatex(sText, charsmax(sText), "\yDay Spawn Edit: \r%s.", FILE_NAME[id]);
	menu_additem(menu, sText, "");
	
	// item number 8
	formatex(sText, charsmax(sText), "\yCopy Day \rSpawns\y!");
	menu_additem(menu, sText, "");
	
	// item number 9
	formatex(sText, charsmax(sText), "\yGenerate Random \rSpawns\y!");
	menu_additem(menu, sText, "");

	// item number 10
	formatex(sText, charsmax(sText), "\rExit!");
	menu_additem(menu, sText, "");

	menu_setprop(menu, MPROP_PERPAGE, 0);
	menu_display(id, menu);
}

public menu_handler(id, menu, item)
{
	menu_destroy(menu);
	
	switch( item )
	{
		case MENU_EXIT, 9: return PLUGIN_HANDLED;
		case 0, 1:
		{
			new Float:fOrigin[3], szString[128];
			pev(id, pev_origin, fOrigin);
			fOrigin[2] += 10.0;
			
			if(!check_spawn_valid(fOrigin, PLAYER_SIZE, id))
			{
				cprint_chat(id, _, "!tCouldn't add the spawn, !gPlayer could be stuck or killed here!");
				place_spawns_menu(id);
				return PLUGIN_HANDLED;
			}

			formatex(szString, charsmax(szString), "^"%.14f^" ^"%.14f^" ^"%.14f^" ^"%s^"",
								fOrigin[0], fOrigin[1], fOrigin[2],
								!item ? "info_player_start":"info_player_deathmatch");
			file_keyvalue(FILE_NAME[id], szDataDir, MAP_NAME, FILE_KEYVALUE_ADD, szString);
			
			new xArray[SPAWN_INFO], szDayname[64];
			copy(xArray[SPAWN_CLASSNAME], charsmax(xArray[SPAWN_CLASSNAME]),
				!item ? "info_player_start":"info_player_deathmatch");
			xArray[SPAWN_ORIGIN][0] = _:fOrigin[0];
			xArray[SPAWN_ORIGIN][1] = _:fOrigin[1];
			xArray[SPAWN_ORIGIN][2] = _:fOrigin[2];
			xArray[SPAWN_TEAM] = !item ? TEAM_GUARDS:TEAM_PRISONERS;
			
			new Array:tmpArray;
			copyc(szDayname, charsmax(szDayname), FILE_NAME[id], '.');
			TrieGetCell(g_trie_days_spawns, szDayname, tmpArray);
			ArrayPushArray(tmpArray, xArray);
			
			cprint_chat(id, _, "!gSpawn has been successfully added!");
		}
		case 2:
		{
			new Float:fOrigin2[3], Float:fOrigin[3], iEnd = -1, ixStart,
			Float:closet_point = 50.0, xArray[SPAWN_INFO];
			new Float:fDistance, szChosenValue[128];
			pev(id, pev_origin, fOrigin2);
			
			new Array:tmpArray, szDayname[64];
			copyc(szDayname, charsmax(szDayname), FILE_NAME[id], '.');
			TrieGetCell(g_trie_days_spawns, szDayname, tmpArray);
			
			for(new i, maxloop = ArraySize(tmpArray); i < maxloop; i++)
			{
				ArrayGetArray(tmpArray, i, xArray);
				fOrigin[0] = xArray[SPAWN_ORIGIN][0];
				fOrigin[1] = xArray[SPAWN_ORIGIN][1];
				fOrigin[2] = xArray[SPAWN_ORIGIN][2];
				
				if((fDistance=get_distance_f(fOrigin, fOrigin2)) < closet_point)
				{
					closet_point = fDistance;
					iEnd = i;
					
				}
			}
			
			new szVector[3][32],szClassname[32],szString[128];
			closet_point = 50.0;
			while( ((ixStart=file_keyvalue(FILE_NAME[id], szDataDir, MAP_NAME, FILE_KEYVALUE_COPY,
						szString, charsmax(szString), ixStart)) != FILE_KEYVALUE_NO_OUTPUT) )
			{
				if(szString[0] != EOS && parse(szString, szVector[0], charsmax(szVector[]),
					szVector[1], charsmax(szVector[]), szVector[2], charsmax(szVector[]),
						szClassname, charsmax(szClassname)) == 4)
				{
					trim(szVector[0]);
					trim(szVector[1]);
					trim(szVector[2]);
					remove_quotes(szVector[0]);
					remove_quotes(szVector[1]);
					remove_quotes(szVector[2]);
					remove_quotes(szClassname);
					fOrigin[0] = floatstr(szVector[0]);
					fOrigin[1] = floatstr(szVector[1]);
					fOrigin[2] = floatstr(szVector[2]);
					
					if((fDistance=get_distance_f(fOrigin, fOrigin2)) < closet_point)
					{
						closet_point = fDistance;
						formatex(szChosenValue, charsmax(szChosenValue), szString);
					}
				}
				
				szString[0] = EOS;
			}
			
			if(iEnd > -1 && szChosenValue[0] != EOS)
			{
				ArrayDeleteItem(tmpArray, iEnd);
				file_keyvalue(FILE_NAME[id], szDataDir, MAP_NAME, FILE_KEYVALUE_REMOVE, szChosenValue);
				cprint_chat(id, _, "!gSpawn has been successfully removed!");
			}
		}
		case 3:
		{
			file_keyvalue(FILE_NAME[id], szDataDir, MAP_NAME, FILE_KEYVALUE_REMOVE, "");
			
			new Array:tmp_Array, szDayname2[64];
			copyc(szDayname2, charsmax(szDayname2), FILE_NAME[id], '.');
			TrieGetCell(g_trie_days_spawns, szDayname2, tmp_Array);
			
			ArrayClear(tmp_Array);
			
			cprint_chat(id, _, "!gAll Spawns has been successfully deleted!");
		}
		case 4:
		{
			if(g_iMaxSpecialDaysRegistered > 0)
			{
				new Float:fOrigin2[3], Float:fOrigin[3], iEnd, ixStart, iCounter,
				 Float:closet_point = 50.0, xArray[SPAWN_INFO],
				 Array:tmpArray, szDayname[64],
				 Float:fDistance, szChosenValue[128],
				 szVector[3][32], szClassname[32], szString[128];
				pev(id, pev_origin, fOrigin2);
				
				for(new i, j, maxloop2; i < g_iMaxSpecialDaysRegistered; i++)
				{
					ixStart = 0; iEnd = -1; closet_point = 50.0;
					jb_get_day_name(i, szDayname, charsmax(szDayname));
					TrieGetCell(g_trie_days_spawns, szDayname, tmpArray);
					add(szDayname, charsmax(szDayname), ".txt");

					for(j = 0, maxloop2 = ArraySize(tmpArray); j < maxloop2; j++)
					{
						ArrayGetArray(tmpArray, j, xArray);
						fOrigin[0] = xArray[SPAWN_ORIGIN][0];
						fOrigin[1] = xArray[SPAWN_ORIGIN][1];
						fOrigin[2] = xArray[SPAWN_ORIGIN][2];
						
						if((fDistance=get_distance_f(fOrigin, fOrigin2)) < closet_point)
						{
							closet_point = fDistance;
							iEnd = j;
						}
					}
					
					closet_point = 50.0; szString[0] = EOS;
					while( ((ixStart=file_keyvalue(szDayname, szDataDir, MAP_NAME, FILE_KEYVALUE_COPY,
								szString, charsmax(szString), ixStart)) != FILE_KEYVALUE_NO_OUTPUT) )
					{
						if(szString[0] != EOS && parse(szString, szVector[0], charsmax(szVector[]),
							szVector[1], charsmax(szVector[]), szVector[2], charsmax(szVector[]),
								szClassname, charsmax(szClassname)) == 4)
						{
							trim(szVector[0]);
							trim(szVector[1]);
							trim(szVector[2]);
							remove_quotes(szVector[0]);
							remove_quotes(szVector[1]);
							remove_quotes(szVector[2]);
							remove_quotes(szClassname);
							fOrigin[0] = floatstr(szVector[0]);
							fOrigin[1] = floatstr(szVector[1]);
							fOrigin[2] = floatstr(szVector[2]);
							
							if((fDistance=get_distance_f(fOrigin, fOrigin2)) < closet_point)
							{
								closet_point = fDistance;
								formatex(szChosenValue, charsmax(szChosenValue), szString);
							}
						}
						
						szString[0] = EOS;
					}

					if(iEnd > -1 && szChosenValue[0] != EOS)
					{
						ArrayDeleteItem(tmpArray, iEnd);
						file_keyvalue(szDayname, szDataDir, MAP_NAME, FILE_KEYVALUE_REMOVE, szChosenValue);
						szChosenValue[0] = EOS;
						iCounter++;
					}
				}

				cprint_chat(id, _, "!gThe current spawn has been removed from !t%d !yspecialdays!", iCounter);
			}
		}
		case 5:
		{
			g_show_spawns[id] = !g_show_spawns[id];
			
			if(g_show_spawns[id])
			{
				set_task(1.0, "Show_Spawns", id+TASK_SHOW_SPAWNS, _, _, "b");
			}
		}
		case 6:
		{
			bUserCopy[id] = false;
			menu_display(id, DAYS_MENU);
			return PLUGIN_HANDLED;
		}
		case 7:
		{
			bUserCopy[id] = true;
			menu_display(id, DAYS_MENU);
			return PLUGIN_HANDLED;
		}
		case 8:
		{
			// Generating random spawns...
			g_rog_count = 0;
			ROGInitialize(ROG_MINIMUM_DISTANCE, "ROG_Counter");

			ROGShuffleOrigins();

			console_print(id, "[ SPECIAL DAYS AUTO SPAWN GENERATOR ]");
			console_print(id, " >> MAP : %s", MAP_NAME);
			console_print(id, " >> RANDOM SPAWNS GENERATED: %d", g_rog_count);

			new Float:fOriginX[3], Array:tmpArrayX;
			new xArrayX[SPAWN_INFO], szDaynameX[64], szString[128], __half_spawns = floatround(g_rog_count * 0.5);

			// TEAM GUARDS
			for(new i; i < __half_spawns; i++)
			{
				ROGGetOrigin(fOriginX);
				formatex(szString, charsmax(szString), "^"%.14f^" ^"%.14f^" ^"%.14f^" ^"%s^"",
									fOriginX[0], fOriginX[1], fOriginX[2], "info_player_start");
				file_keyvalue(FILE_NAME[id], szDataDir, MAP_NAME, FILE_KEYVALUE_ADD, szString);
				
				copy(xArrayX[SPAWN_CLASSNAME], charsmax(xArrayX[SPAWN_CLASSNAME]), "info_player_start");
				xArrayX[SPAWN_ORIGIN][0] = _:fOriginX[0];
				xArrayX[SPAWN_ORIGIN][1] = _:fOriginX[1];
				xArrayX[SPAWN_ORIGIN][2] = _:fOriginX[2];
				xArrayX[SPAWN_TEAM] = TEAM_GUARDS;
				
				copyc(szDaynameX, charsmax(szDaynameX), FILE_NAME[id], '.');
				TrieGetCell(g_trie_days_spawns, szDaynameX, tmpArrayX);
				ArrayPushArray(tmpArrayX, xArrayX);
			}
			
			// TEAM PRISONERS
			for(new i = __half_spawns; i < g_rog_count; i++)
			{
				ROGGetOrigin(fOriginX);
				formatex(szString, charsmax(szString), "^"%.14f^" ^"%.14f^" ^"%.14f^" ^"%s^"",
									fOriginX[0], fOriginX[1], fOriginX[2], "info_player_deathmatch");
				file_keyvalue(FILE_NAME[id], szDataDir, MAP_NAME, FILE_KEYVALUE_ADD, szString);

				copy(xArrayX[SPAWN_CLASSNAME], charsmax(xArrayX[SPAWN_CLASSNAME]), "info_player_deathmatch");
				xArrayX[SPAWN_ORIGIN][0] = _:fOriginX[0];
				xArrayX[SPAWN_ORIGIN][1] = _:fOriginX[1];
				xArrayX[SPAWN_ORIGIN][2] = _:fOriginX[2];
				xArrayX[SPAWN_TEAM] = TEAM_PRISONERS;

				copyc(szDaynameX, charsmax(szDaynameX), FILE_NAME[id], '.');
				TrieGetCell(g_trie_days_spawns, szDaynameX, tmpArrayX);
				ArrayPushArray(tmpArrayX, xArrayX);
			}

			cprint_chat(id, _, "!gRandom spawns has been successfully generated!");
		}
	}
	
	place_spawns_menu(id);
	return PLUGIN_HANDLED;
}

check_spawn_valid(Float:fOrigin[3], const Float:SIZE[6], const ignore_ent = 0)
{
	static ent = 0, Float:fMaxs[2][3], Float:fMins[2][3], Float:fDamage;

	fMaxs[0][0] = fOrigin[0] + SIZE[3];
	fMaxs[0][1] = fOrigin[1] + SIZE[4];
	fMaxs[0][2] = fOrigin[2] + SIZE[5];
	fMins[0][0] = fOrigin[0] + SIZE[0];
	fMins[0][1] = fOrigin[1] + SIZE[1];
	fMins[0][2] = fOrigin[2] + SIZE[2];

	while( (ent = find_ent_by_class(ent, "func_water")) )
	{
		pev(ent, pev_dmg, fDamage);
		if(fDamage <= 0.0) continue;

		pev(ent, pev_absmax, fMaxs[1]);
		pev(ent, pev_absmin, fMins[1]);

		if ( check_collision(fMaxs[0], fMins[0], fMaxs[1], fMins[1]) ) {
			return false;
		}

	}

	while( (ent = find_ent_by_class(ent, "trigger_hurt")) )
	{
		pev(ent, pev_dmg, fDamage);
		if(fDamage < 0.0) continue;

		pev(ent, pev_absmax, fMaxs[1]);
		pev(ent, pev_absmin, fMins[1]);

		if ( check_collision(fMaxs[0], fMins[0], fMaxs[1], fMins[1]) ) {
			return false;
		}

	}

	while( (ent = find_ent_by_class(ent, "trigger_push")) )
	{
		pev(ent, pev_absmax, fMaxs[1]);
		pev(ent, pev_absmin, fMins[1]);

		if ( check_collision(fMaxs[0], fMins[0], fMaxs[1], fMins[1]) ) {
			return false;
		}

	}
	
	while( (ent = find_ent_by_class(ent, "trigger_teleport")) )
	{
		pev(ent, pev_absmax, fMaxs[1]);
		pev(ent, pev_absmin, fMins[1]);

		if ( check_collision(fMaxs[0], fMins[0], fMaxs[1], fMins[1]) ) {
			return false;
		}

	}

	new OLD_SOLID, bValid;
	if( ignore_ent )
	{
		OLD_SOLID = pev(ignore_ent, pev_solid);
		set_pev(ignore_ent, pev_solid, SOLID_NOT);
	}

	bValid = ValidSpotFound(fOrigin);
	if( ignore_ent ) set_pev(ignore_ent, pev_solid, OLD_SOLID);

	return bValid;
}

check_collision( Float:absmax1[3], Float:absmin1[3], Float:absmax2[3], Float:absmin2[3] ) {

	if( (absmin1[0] > absmax2[0]) ||
		(absmin1[1] > absmax2[1]) ||
		(absmin1[2] > absmax2[2]) ||
		(absmin2[0] > absmax1[0]) ||
		(absmin2[1] > absmax1[1]) ||
		(absmin2[2] > absmax1[2]) ) return false;

	return true;
}

public Show_Spawns(taskid)
{
	new id = taskid - TASK_SHOW_SPAWNS;
	
	if(!g_show_spawns[id])
	{
		remove_task(taskid);
		return;
	}
	
	new Array:tmpArray, szDayname[64];
	copyc(szDayname, charsmax(szDayname), FILE_NAME[id], '.');
	TrieGetCell(g_trie_days_spawns, szDayname, tmpArray);
	new maxloop = ArraySize(tmpArray);
	
	if(!maxloop) return;
	
	for(new i, xArray[SPAWN_INFO], Float:fOrigin[3]; i < maxloop; i++)
	{
		ArrayGetArray(tmpArray, i, xArray);
		fOrigin[0] = xArray[SPAWN_ORIGIN][0];
		fOrigin[1] = xArray[SPAWN_ORIGIN][1];
		fOrigin[2] = xArray[SPAWN_ORIGIN][2];

		if(!is_in_viewcone(id, fOrigin))
		{
			continue;
		}
		
		engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, fOrigin, id);
		write_byte(TE_BEAMPOINTS);
		engfunc(EngFunc_WriteCoord, fOrigin[0]);
		engfunc(EngFunc_WriteCoord, fOrigin[1]);
		engfunc(EngFunc_WriteCoord, fOrigin[2] - 36.0);
		engfunc(EngFunc_WriteCoord, fOrigin[0]);
		engfunc(EngFunc_WriteCoord, fOrigin[1]);
		engfunc(EngFunc_WriteCoord, fOrigin[2] + 36.0);
		write_short(g_laser_spr);
		write_byte(0) ;
		write_byte(10) ;
		write_byte(10) ;
		write_byte(20) ;
		write_byte(0) ;

		switch( xArray[SPAWN_TEAM] )
		{
			case TEAM_PRISONERS:
			{
				write_byte(255);
				write_byte(0);
				write_byte(0);
			}
			case TEAM_GUARDS:
			{
				write_byte(0);
				write_byte(0);
				write_byte(255);
			}
		}

		write_byte(250);
		write_byte(1);
		message_end();
	}
}

file_keyvalue(const filename[], const director[], const key[], FILE_KEYVALUE_OPERATIONS:iOperation, value[], len = 0, start=0)
{
	if(start == FILE_KEYVALUE_FINAL_VALUE)
	{
		return FILE_KEYVALUE_NO_OUTPUT;
	}

	static sFile[128], fp;
	formatex(sFile, charsmax(sFile), "%s/%s", director, filename);
	
	fp = fopen(sFile, "at+");
	
	if(!fp)
	{
		set_fail_state("Error opening the file!");
		return FILE_KEYVALUE_ERROR;
	}

	static sBuffer[256], szKey[64], key_found, line, delete_line, nextline;
	key_found = line = delete_line = nextline = -1;

	while( !feof(fp) )
	{
		line ++;
		fgets(fp, sBuffer, charsmax(sBuffer));
		trim(sBuffer);
		
		if(!sBuffer[0] || (strlen(sBuffer) <= 2) || sBuffer[0] == ';' || (sBuffer[0] == '/' && sBuffer[1] == '/'))
			continue;
		
		if(sBuffer[0] == '[' && contain(sBuffer[1], "]") > -1)
		{
			if(key_found == -1)
			{
				copyc(szKey, charsmax(szKey), sBuffer[1], ']');
				
				if(equali(szKey, key))
				{
					key_found = line;

					switch ( iOperation )
					{
						case FILE_KEYVALUE_CHECK: if(value[0] == EOS) break;
						case FILE_KEYVALUE_REMOVE: start = key_found + 1;
					}

				}
				
				continue;
			}

			break;
		}
		
		if( key_found > -1 && (line >= start >= 0) )
		{
			if(nextline == FILE_KEYVALUE_FINAL_VALUE) // nextline is available !
			{
				nextline = line;
				break;
			}

			switch( iOperation )
			{
				case FILE_KEYVALUE_CHECK, FILE_KEYVALUE_ADD:
				{
					if(equali(sBuffer, value, strlen(value)))
					{
						iOperation = FILE_KEYVALUE_CHECK;
						nextline = line;
						break;
					}
				}
				case FILE_KEYVALUE_COPY:
				{
					if(len > 0)
					{
						nextline = FILE_KEYVALUE_FINAL_VALUE;
						copy(value, len, sBuffer);
					}
				}
				case FILE_KEYVALUE_REMOVE:
				{
					if(value[0] != EOS)
					{
						if(equali(sBuffer, value, strlen(value)))
						{
							delete_line = line;
							break;
						}
					}
					else
					{
						delete_line = line;
					}
				}
			}
		}
	}

	if(key_found == -1)
	{
		fprintf(fp, "^n[%s]^n", key);
		
		if(iOperation == FILE_KEYVALUE_ADD)
		{
			fputs(fp, value);
			fputc(fp, '^n');
		}
		
		nextline = FILE_KEYVALUE_KEY_CREATED;
	}
	
	else if(delete_line > -1 || iOperation == FILE_KEYVALUE_ADD)
	{
		static sFile2[128], fp2;
		formatex(sFile2, charsmax(sFile2), "%s/2_%s", director, filename);
		
		fp2 = fopen(sFile2, "at+");
		
		if(!fp2)
		{
			set_fail_state("Error opening the file!");
			return -4;
		}
		
		line = -1;
		fseek(fp, 0, SEEK_SET);
		while( !feof(fp) )
		{
			line ++;
			
			if(fgets(fp, sBuffer, charsmax(sBuffer)) == 0) continue;

			switch( iOperation )
			{
				case FILE_KEYVALUE_ADD:
				{
					if(line == key_found)
					{
						formatex(szKey, charsmax(szKey), "[%s]", key);
						fprintf(fp2, "%s^n", szKey);
						
						formatex(sBuffer, charsmax(sBuffer), value);
						add(sBuffer, charsmax(sBuffer), "^n");
					}
				}
				case FILE_KEYVALUE_REMOVE:
				{
					if(sBuffer[0] != '^n' && sBuffer[0] != ';' && (sBuffer[0] != '/' && sBuffer[1] != '/'))
					{
						if((value[0] == EOS && start <= line <= delete_line) || delete_line == line)
						{
							continue;
						}
					}
				}
			}

			fprintf(fp2, sBuffer);
		}
		
		fclose(fp2);
		fclose(fp);
		
		delete_file(sFile);
		if(!rename_file(sFile2, sFile,1)) delete_file(sFile2);
		
		return FILE_KEYVALUE_EDIT;
	}
	
	fclose(fp);
	
	return nextline;
}
