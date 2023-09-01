/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <jailbreak_core>
#include <hamsandwich>
#include <cstrike>
#include <fakemeta>
#include <engine>
#include <cs_player_models_api>

#define PLUGIN "[JB] Day:Hulk"
#define AUTHOR "Natsheh"

#define OFFSET_TEAM	114
#define fm_get_user_team(%1)	(clamp(get_pdata_int(%1,OFFSET_TEAM),TEAM_ANY,TEAM_SPECTATOR))
#define fm_set_user_team(%1,%2)	set_pdata_int(%1,OFFSET_TEAM,%2)

#define STEP_DELAY 0.5

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif

#if !defined ORPHEU_INVALID_HOOK
#define ORPHEU_INVALID_HOOK OrpheuHook:-1
#endif

#define MAX_ARMOR_PACK 100

new Float:g_fNextStep[33];

enum CVARS_INFO
{
	CVAR_STRING[32],
	VALUE_STRING[32]
}

enum (+=1)
{
	CVAR_GRAVITY = 0,
	CVAR_SPEED,
	CVAR_JBOOST,
	CVAR_HEALTH,
	CVAR_PUSH_FORCE,
	CVAR_SMASH_RADIUS,
	CVAR_SMASH_DAMAGE,
	CVAR_SMASH_JBOOST,
	CVAR_SMASH_COOLDOWN,
	CVAR_WALLBUMP_DAMAGE
}

new const g_szCvars[][CVARS_INFO] = {
	{ "jb_hulk_gravity", "650" },
	{ "jb_hulk_speed", "380" },
	{ "jb_hulk_jump_boost", "400" },
	{ "jb_hulk_health", "15000" },
	{ "jb_hulk_push_force", "8000" },
	{ "jb_hulk_smash_radius", "250" },
	{ "jb_hulk_smash_damage", "100" },
	{ "jb_hulk_smash_jboost", "600" },
	{ "jb_hulk_smash_cooldown", "5.0" },
	{ "jb_hulk_wallbump_damage", "1000" }
}

new g_dayid, g_user_hulk, g_iCvars[sizeof g_szCvars], HamHook:HamHook1,
HamHook:HamHook2, g_pushed_byhulk, g_hulk_smashed, HamHook:HamHook4, HamHook:HamHook5,
HamHook:HamHook6, HamHook:HamHook9, bool:g_footstep_snd, g_msgidScreenShake, g_iMaxplayers,
g_iOldTeams[MAX_PLAYERS+1], g_msgTeamInfo, bool:g_hulk_jump_snd, bool:g_hulk_smash_jsnd, bool:g_hulk_smash_snd,
Float:g_HULK_SMASHED_COOLING[MAX_PLAYERS+1];

new HULK_PLAYER_MODEL[32] = "hulk",
HULK_SMASH_JUMP_SOUND[64] = "jailbreak/hulk_jump_smash.wav",
HULK_JUMP_SOUND[64] = "jailbreak/hulk_jump.wav",
HULK_SMASH_SND[64] = "jailbreak/hulk_smash.wav",
HULK_VKNIFE_MODEL[64] = "models/jailbreak/v_hulk_hands.mdl",
HULK_FOOTSTEP_SND[64] = "jailbreak/hulk_footstep.wav";

const m_pPlayer = 41;

new g_FW_FM_PLAYER_POSTTHINK_POST;

public plugin_precache()
{
	new szModel[64];
	
	jb_ini_get_keyvalue("HULK", "HULK_MODEL", HULK_PLAYER_MODEL, charsmax(HULK_PLAYER_MODEL));

	formatex(szModel, charsmax(szModel), "models/player/%s/%s.mdl", HULK_PLAYER_MODEL, HULK_PLAYER_MODEL);
	PRECACHE_PLAYER_MODEL(szModel);
	
	formatex(szModel, charsmax(szModel), "models/player/%s/%sT.mdl", HULK_PLAYER_MODEL, HULK_PLAYER_MODEL);
	if(file_exists(szModel)) PRECACHE_PLAYER_MODEL(szModel);
	
	jb_ini_get_keyvalue("HULK", "HULK_V_HANDS", HULK_VKNIFE_MODEL, charsmax(HULK_VKNIFE_MODEL));
	PRECACHE_WEAPON_VIEW_MODEL(HULK_VKNIFE_MODEL);
	
	jb_ini_get_keyvalue("HULK", "JUMP_SND", HULK_JUMP_SOUND, charsmax(HULK_JUMP_SOUND));
	if(PRECACHE_SOUND(HULK_JUMP_SOUND) > 0)
	{
		g_hulk_jump_snd = true;
	}
	
	jb_ini_get_keyvalue("HULK", "SMASH_JUMP_SND", HULK_SMASH_JUMP_SOUND, charsmax(HULK_SMASH_JUMP_SOUND));
	if(PRECACHE_SOUND(HULK_SMASH_JUMP_SOUND) > 0)
	{
		g_hulk_smash_jsnd = true;
	}
	
	jb_ini_get_keyvalue("HULK", "SMASH_SND", HULK_SMASH_SND, charsmax(HULK_SMASH_SND));
	if(PRECACHE_SOUND(HULK_SMASH_SND) > 0)
	{
		g_hulk_smash_snd = true;
	}
	
	jb_ini_get_keyvalue("HULK", "FOOTSTEP_SND", HULK_FOOTSTEP_SND, charsmax(HULK_FOOTSTEP_SND));
	if(PRECACHE_SOUND(HULK_FOOTSTEP_SND) > 0)
	{
		g_footstep_snd = true;
	}

	PRECACHE_FILE("decals.wad");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	g_dayid = register_jailbreak_day("Hulk Day", 0, 60 * 3.0, DAY_TIMER);
	
	register_concmd("jb_hulk", "concmd_hulk", ADMIN_IMMUNITY);
	
	for(new i; i < sizeof g_szCvars; i++)
	{
		g_iCvars[i] = register_cvar(g_szCvars[i][CVAR_STRING], g_szCvars[i][VALUE_STRING]);
	}
	
	DisableHamForward(HamHook1=RegisterHam(Ham_Player_Jump, "player", "fw_player_jump_post", 1));
	DisableHamForward(HamHook2=RegisterHam(Ham_TraceAttack, "player", "fw_player_traceattack_pre"));
	DisableHamForward(HamHook4=RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_knife_deploy_post", 1));
	DisableHamForward(HamHook5=RegisterHam(Ham_Player_PreThink, "player", "fwd_PlayerPreThink"));
	DisableHamForward(HamHook6=RegisterHam(Ham_Spawn, "player", "fw_player_spawn_post", 1));
	DisableHamForward(HamHook9=RegisterHam(Ham_Killed, "player", "fw_player_killed_post", 1));
	
	g_msgTeamInfo = get_user_msgid("TeamInfo");
	g_msgidScreenShake = get_user_msgid("ScreenShake");
	g_iMaxplayers = get_maxplayers();
}

public fw_player_postthink_post( id )
{
	if(!g_user_hulk)
	{
		unregister_forward(FM_PlayerPostThink, g_FW_FM_PLAYER_POSTTHINK_POST, true);
		g_FW_FM_PLAYER_POSTTHINK_POST = 0;
	}

	static iUserLanded;

	// player on ground.
	if(pev(id,pev_flags) & FL_ONGROUND)
	{
		if(!check_flag(iUserLanded,id))
		{
			set_flag(iUserLanded,id);
			player_on_ground(id);
		}

		// not a critical hit by hulk
		if(check_flag(g_pushed_byhulk,id)) remove_flag(g_pushed_byhulk,id);
		return;
	}
	else if(check_flag(iUserLanded,id))
	{
		remove_flag(iUserLanded,id);
	}

	player_in_the_air(id);
}

player_in_the_air(id)
{
	// HULK IN THE AIR AND HES SMASHING!!!
	if(check_flag(g_user_hulk,id) && check_flag(g_hulk_smashed,id))
	{
		static Float:fVelocity[3];
		pev(id, pev_velocity, fVelocity);

		if(-get_pcvar_float(g_iCvars[CVAR_SMASH_JBOOST]) < fVelocity[2] <= 0.0)
		{
			fVelocity[0] = fVelocity[1] = 0.0;
			fVelocity[2] = -get_pcvar_float(g_iCvars[CVAR_SMASH_JBOOST]);
			set_pev(id, pev_velocity, fVelocity);
		}
	}
}

public fw_player_killed_post(vic, att, gibs)
{
	remove_flag(g_pushed_byhulk,vic);

	if(check_flag(g_user_hulk,vic))
	{
		set_user_human(vic);
		
		if(jb_get_current_day() == g_dayid && !g_user_hulk)
		{
			jb_end_theday();
		}
	}
	else if(jb_get_current_day() == g_dayid)
	{
		// lets count the survivors.
		new players[32], pnum, i, iSurvivors;
		get_players(players, pnum, "ah");
		for(i = iSurvivors = 0; i < pnum; i++)
		{
			// if user is not hulk then he's a survivor.
			if(!check_flag(g_user_hulk,players[i]))
			{
				iSurvivors ++;
			}
		}
		
		// No survivors end the day!
		if(!iSurvivors)
		{
			// all soliders are down, end the round there's no point.
			jb_end_theday();
		}
	}
}

public fw_player_spawn_post(id)
{
	if(!is_user_alive(id))
		return;
	
	new xDay = jb_get_current_day();
	
	if(check_flag(g_user_hulk,id))
	{
		set_user_hulk(id);
		
		if(!g_iOldTeams[id] && xDay == g_dayid)
		{
			g_iOldTeams[id] = get_user_team(id);
			set_user_teaminfo(id, TEAM_GUARDS);
		}
	}
	else if(xDay == g_dayid)
	{
		give_item(id, "weapon_m4a1");
		give_item(id, "weapon_ak47");
		give_item(id, "weapon_awp");
		give_item(id, "weapon_deagle");
		cs_set_user_bpammo(id, CSW_M4A1, 1000);
		cs_set_user_bpammo(id, CSW_AK47, 1000);
		cs_set_user_bpammo(id, CSW_AWP, 1000);
		cs_set_user_bpammo(id, CSW_DEAGLE, 1000);
		cs_set_user_armor(id, MAX_ARMOR_PACK, CS_ARMOR_VESTHELM);
	}
}

public jb_lr_duel_started(prisoner, guard, duelid)
{
	if(check_flag(g_user_hulk,guard))
	{
		set_user_human(guard);
	}
	if(check_flag(g_user_hulk,prisoner))
	{
		set_user_human(prisoner);
	}
}

public concmd_hulk(id,level,cid)
{
	if(!cmd_access(id,level,cid, 1))
	{
		return 1;
	}
	
	new szTarget[32], player;
	read_argv(1, szTarget, charsmax(szTarget))
	
	if(szTarget[0] == '@' && strlen(szTarget) <= 4)
	{
		new players[32], pnum;
		switch(szTarget[1])
		{
			case 'T','t': get_players(players, pnum, "he", "TERRORIST");
			case 'C','c': get_players(players, pnum, "he", "CT");
			case 'A','a': get_players(players, pnum, "h");
			default:
			{
				console_print(id, "Target is not found!");
				return 1;
			}
		}
		
		new szValue[4];
		read_argv(2, szValue, charsmax(szValue))
		
		if(!szValue[0])
		{
			console_print(id, "Please add the secound argument <1=hulk/0=human>");
			return 1;
		}
		
		new bool:bSwitch = str_to_num(szValue) ? true:false;
		
		if(!g_user_hulk && bSwitch && pnum > 0)
		{
			Hulk_Status();
		}
		
		for(new i; i < pnum; i++)
		{
			player = players[i];
			if((check_flag(g_user_hulk,player) ? true:false) == bSwitch) continue;
			switch( bSwitch )
			{
				case true: set_user_hulk(player);
				case false: set_user_human(player);
			}
		}
		
		if(!g_user_hulk && pnum > 0)
		{
			Hulk_Status(false);
		}
		
		new AName[32], sTeam[16];
		get_user_name(id, AName, charsmax(AName));
		
		switch(szTarget[1])
		{
			case 'T','t': copy(sTeam, charsmax(sTeam), "Terrorist");
			case 'C','c': copy(sTeam, charsmax(sTeam), "Counter terrorist");
			case 'A','a': copy(sTeam, charsmax(sTeam), "Players");
		}
		
		cprint_chat(0, _, "^4Admin ^3%s ^1has transferred All the ^4%s^1 into ^3%s!", AName, sTeam, bSwitch ? "Hulk":"Humans");
		
		return 1;
	}
	
	player = find_player("a", szTarget);
	if(!player) player = find_player("b", szTarget);
	if(!player) player = find_player("c", szTarget);
	if(!player && szTarget[0] == '#') player = find_player("k", str_to_num(szTarget[1]));
	
	if(!player)
	{
		console_print(id, "Target is not found!")
		return 1;
	}
	
	if(check_flag(g_user_hulk,player))
	{
		set_user_human(player)
		if(!g_user_hulk)
		{
			Hulk_Status(false);
		}
	}
	else
	{
		if(!g_user_hulk)
		{
			Hulk_Status();
		}
		set_user_hulk(player)
	}
	
	new AName[32], PName[32];
	get_user_name(id, AName, charsmax(AName));
	get_user_name(player, PName, charsmax(PName));
	cprint_chat(0, _, "^4Admin ^3%s ^1has transferred player ^4%s^1 into a ^3%s!", AName, PName, check_flag(g_user_hulk,player) ? "Hulk":"Human")
	
	return 1;
}

public fwd_PlayerPreThink(id)
{
	if(!check_flag(g_user_hulk,id) || !g_footstep_snd)
		return HAM_IGNORED;
	if(!is_user_alive(id))
		return HAM_IGNORED;
		
	set_pev(id, pev_flTimeStepSound, 999.0);
	
	if(g_fNextStep[id] < get_gametime())
	{
		if(fm_get_ent_speed(id) && (pev(id, pev_flags) & FL_ONGROUND))
			emit_sound(id, CHAN_BODY, HULK_FOOTSTEP_SND, VOL_NORM, ATTN_STATIC, 0, PITCH_NORM);
	
		g_fNextStep[id] = get_gametime() + STEP_DELAY;
	}
	return HAM_IGNORED;
}

stock Float:fm_get_ent_speed(id)
{
	if(!pev_valid(id))
		return 0.0;
	
	static Float:vVelocity[3];
	pev(id, pev_velocity, vVelocity);
	
	vVelocity[2] = 0.0;
	
	return vector_length(vVelocity);
}

public fw_knife_deploy_post(const ent)
{
	new id = get_pdata_cbase(ent,m_pPlayer,4);
	
	if(check_flag(g_user_hulk,id))
	{
		set_pev(id, pev_viewmodel2, HULK_VKNIFE_MODEL);
		set_pev(id, pev_weaponmodel2, "");
	}
}

player_on_ground(id)
{
	if(is_user_alive(id))
	{
		if(check_flag(g_pushed_byhulk,id))
		{
			remove_flag(g_pushed_byhulk,id);
			new hulk = pev(id, pev_iuser3);
			ExecuteHamB(Ham_TakeDamage, id, hulk, hulk, get_pcvar_float(g_iCvars[CVAR_WALLBUMP_DAMAGE]), DMG_CRUSH|DMG_ALWAYSGIB);
			set_pev(id, pev_iuser3, 0);
		}
		
		if(check_flag(g_user_hulk,id))
		{
			if(check_flag(g_hulk_smashed,id))
			{
				new Float:fVelo[3];
				pev(id, pev_velocity, fVelo);

				if(fVelo[2] <= 0.0)
				{
					remove_flag(g_hulk_smashed,id);
					hulk_smashed(id, get_pcvar_float(g_iCvars[CVAR_SMASH_RADIUS]), get_pcvar_float(g_iCvars[CVAR_SMASH_DAMAGE]));
				}
			}
		}
	}
}

public fw_player_traceattack_pre(vic, attacker, Float:damage, Float:direction[3], traceresult, damagebits)
{
	if(1 <= attacker <= g_iMaxplayers && vic != attacker)
	{
		if(check_flag(g_user_hulk,attacker))
		{
			new Float:fVelo[3], Float:fForce = get_pcvar_float(g_iCvars[CVAR_PUSH_FORCE]);
			fVelo[0] = direction[0] * fForce;
			fVelo[1] = direction[1] * fForce;
			fVelo[2] = direction[2] * fForce;
			set_flag(g_pushed_byhulk, vic);
			set_pev(vic, pev_iuser3, attacker);
			set_pev(vic, pev_velocity, fVelo);
			
			const TRACEATTACK_DMG_BITS_PARAM = 6;
			SetHamParamInteger(TRACEATTACK_DMG_BITS_PARAM, damagebits|DMG_CRUSH|DMG_ALWAYSGIB);
			return HAM_HANDLED;
		}
	}
	
	return HAM_IGNORED;
}

public jb_day_ended(iDayid)
{
	if(iDayid == g_dayid)
	{
		Hulk_Status(false);
		
		for(new i = 1; i <= g_iMaxplayers; i++)
		{
			jb_set_user_enemies(i, JB_ENEMIES_DEFAULT);
			jb_set_user_allies(i, JB_ALLIES_DEFAULT);
		}
		
		new players[32],pnum;
		get_players(players,pnum, "ah");
		
		for(new i,player; i < pnum; i++)
		{
			player = players[i];
			
			if(!!g_iOldTeams[player])
			{
				set_user_teaminfo(player, g_iOldTeams[player]);
				strip_user_weapons(player);
				give_item(player, "weapon_knife");
			}
			
			if(check_flag(g_user_hulk,player))
			{
				set_user_human(player);
			}
		}
		
		g_user_hulk = 0;
	}
}

Hulk_Status(bool:bActive=true)
{
	switch( bActive )
	{
		case true:
		{
			EnableHamForward(HamHook1);
			EnableHamForward(HamHook2);
			EnableHamForward(HamHook4);
			EnableHamForward(HamHook5);
			EnableHamForward(HamHook6);
			EnableHamForward(HamHook9);
			
			if(!g_FW_FM_PLAYER_POSTTHINK_POST)
			{
				g_FW_FM_PLAYER_POSTTHINK_POST = register_forward(FM_PlayerPostThink, "fw_player_postthink_post", true);
			}
		}
		default:
		{
			DisableHamForward(HamHook1);
			DisableHamForward(HamHook2);
			DisableHamForward(HamHook4);
			DisableHamForward(HamHook5);
			DisableHamForward(HamHook6);
			DisableHamForward(HamHook9);
		}
	}
}

public client_disconnect(id)
{
	g_iOldTeams[id] = 0;
	
	if(check_flag(g_user_hulk,id))
	{
		set_user_human(id);
		
		if(!g_user_hulk)
		{
			Hulk_Status(false);
			
			if(jb_get_current_day() == g_dayid)
			{
				jb_end_theday();
			}
		}
	}
}

public jb_day_started(iDayid)
{
	if(iDayid == g_dayid)
	{
		Hulk_Status(true);
		
		new players[32], pnum;
		get_players(players,pnum, "ah");
		
		for(new i, player; i < pnum; i++)
		{
			player = players[i];
			
			switch( get_user_team(player) )
			{
				case TEAM_GUARDS, TEAM_PRISONERS:
				{
					continue;
				}
				default: players[i--] = players[ --pnum ];
			}
		}
		
		new g_hulk = players[random(pnum)];
		
		set_user_hulk(g_hulk);
		
		for(new i = 1; i <= g_iMaxplayers; i++)
		{
			if(check_flag(g_user_hulk,i))
			{
				continue;
			}

			jb_set_user_allies(i, ~g_user_hulk);
		}
		
		jb_cells(JB_CELLS_OPEN);
		
		for(new i,player; i < pnum; i++)
		{
			player = players[i];
			
			g_iOldTeams[player] = fm_get_user_team(player);
			if(check_flag(g_user_hulk,player))
			{
				set_user_teaminfo(player, TEAM_GUARDS);
			}
			else
			{
				set_user_teaminfo(player, TEAM_PRISONERS);
				give_item(player, "weapon_m4a1");
				give_item(player, "weapon_ak47");
				give_item(player, "weapon_awp");
				give_item(player, "weapon_deagle");
				cs_set_user_bpammo(player, CSW_M4A1, 1000);
				cs_set_user_bpammo(player, CSW_AK47, 1000);
				cs_set_user_bpammo(player, CSW_AWP, 1000);
				cs_set_user_bpammo(player, CSW_DEAGLE, 1000);
				cs_set_user_armor(player, MAX_ARMOR_PACK, CS_ARMOR_VESTHELM);
			}
		}
	}
	else if(g_user_hulk > 0)
	{
		Hulk_Status(false);
		
		new players[32], pnum;
		get_players(players, pnum, "h")
		
		for(new i; i < pnum; i++)
		{
			if(check_flag(g_user_hulk,players[i]))
			{
				jb_set_user_class_model(players[i]);
			}
		}
	}
}

set_user_hulk(id)
{
	set_flag(g_user_hulk,id);
	
	for(new i = 1; i <= g_iMaxplayers; i++)
	{
		if(!check_flag(g_user_hulk, i))
		{
			jb_set_user_enemies(i, jb_get_user_enemies(i) | player_flag(id));
		}
	}
	
	jb_set_user_enemies(id, JB_ENEMIES_EVERYONE);
	
	cs_set_player_model(id, HULK_PLAYER_MODEL);
	
	new Float:g_fGravity = get_pcvar_float(g_iCvars[CVAR_GRAVITY]), Float:g_fNormalize = get_cvar_float("sv_gravity");
	set_user_gravity(id, (g_fGravity / g_fNormalize));
	
	set_user_health(id, get_pcvar_num(g_iCvars[CVAR_HEALTH]));
	
	strip_user_weapons(id);
	jb_block_user_weapons(id,true,~player_flag(CSW_KNIFE));
	new ent = give_item(id, "weapon_knife");
	if(ent > 0) ExecuteHamB(Ham_Item_Deploy, ent);
	
	set_user_maxspeed(id, get_pcvar_float(g_iCvars[CVAR_SPEED]));
}

set_user_human(id)
{
	remove_flag(g_user_hulk,id);
	remove_flag(g_hulk_smashed,id);
	jb_block_user_weapons(id,false);
	
	jb_set_user_enemies(id, g_user_hulk);
	
	for(new i = 1; i <= g_iMaxplayers; i++)
	{
		if(!check_flag(g_user_hulk, i))
		{
			jb_set_user_enemies(i, jb_get_user_enemies(i) & ~player_flag(id));
			continue;
		}

		jb_set_user_enemies(i, jb_get_user_enemies(i) | player_flag(id));
	}
	
	if(is_user_alive(id))
	{
		set_user_gravity(id, get_cvar_num("sv_gravity")/800.0);
		strip_user_weapons(id);
		new ent = give_item(id, "weapon_knife");
		if(ent > 0) ExecuteHamB(Ham_Item_Deploy, ent);
		set_user_maxspeed(id, 250.0);
		set_user_health(id, 100);
	}
	
	// safe check since we're calling this function at disconnect.
	if(is_user_connected(id))
	{
		jb_set_user_class_model(id);
	}
}

public fw_player_jump_post(id)
{
	if(!is_user_alive(id))
		return;
	
	if(check_flag(g_user_hulk,id))
	{
		new buttons = pev(id, pev_button);            // buttons in current frame
		new oldbuttons = pev(id, pev_oldbuttons);    // buttons in previous frame
		
		if(pev(id, pev_flags) & FL_ONGROUND)
		{
			if((buttons & IN_JUMP) && !(oldbuttons & IN_JUMP) &&
				(buttons & IN_DUCK) && (oldbuttons & IN_DUCK) && g_HULK_SMASHED_COOLING[id] <= get_gametime())
			{
				new Float:fVelo[3];
				fVelo[2] = get_pcvar_float(g_iCvars[CVAR_SMASH_JBOOST]);
				entity_set_vector(id, EV_VEC_velocity, fVelo);
				if(g_hulk_smash_jsnd)
					emit_sound(id, CHAN_AUTO, HULK_SMASH_JUMP_SOUND,VOL_NORM, ATTN_NORM, 0, PITCH_HIGH);
				set_flag(g_hulk_smashed,id);
			}
			else if((buttons & IN_JUMP) && !(oldbuttons & IN_JUMP))
			{
				new Float:fVelo[3];
				entity_get_vector(id, EV_VEC_velocity, fVelo);
				fVelo[2] = get_pcvar_float(g_iCvars[CVAR_JBOOST]);
				entity_set_vector(id, EV_VEC_velocity, fVelo);
				if(g_hulk_jump_snd)
					emit_sound(id, CHAN_BODY, HULK_JUMP_SOUND,VOL_NORM, ATTN_NORM, 0, PITCH_HIGH);
			}
		}
	}
}

hulk_smashed(id, Float:Radius, Float:MaxDamage)
{
	g_HULK_SMASHED_COOLING[id] = get_gametime() + get_pcvar_float(g_iCvars[CVAR_SMASH_COOLDOWN]);

	new Float:fOrigin[3], victim, Float:fUserOrigin[3], Float:fDamage;
	pev(id, pev_origin, fOrigin);
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_WORLDDECAL);
	engfunc(EngFunc_WriteCoord, fOrigin[0] );
	engfunc(EngFunc_WriteCoord, fOrigin[1] );
	engfunc(EngFunc_WriteCoord, fOrigin[2] - 36.0 );
	write_byte(engfunc( EngFunc_DecalIndex, "{crack3"));
	message_end();

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte( TE_IMPLOSION );
	engfunc(EngFunc_WriteCoord, ( fOrigin[0] + random_float( -100.0, 100.0 ) ));
	engfunc(EngFunc_WriteCoord, ( fOrigin[1] + random_float( -100.0, 100.0 ) ));
	engfunc(EngFunc_WriteCoord, ( fOrigin[2] + random_float( -50.0, 50.0 ) ));
	write_byte( random_num( 20,40 ) );
	write_byte( 12 );
	write_byte( 0 );
	message_end( );
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, _, 0);
	write_byte(TE_EXPLOSION2);
	engfunc(EngFunc_WriteCoord, ( fOrigin[0] ));
	engfunc(EngFunc_WriteCoord, ( fOrigin[1] ));
	engfunc(EngFunc_WriteCoord, ( fOrigin[2] ));
	write_byte( 120 );
	write_byte( 14 );
	message_end();
	
	while( (victim=engfunc(EngFunc_FindEntityInSphere, victim, fOrigin, Radius)) > 0 )
	{
		if(victim == id) continue;
		
		if(is_user_alive(victim))
		{
			if(get_user_godmode(victim)) continue;
			
			pev(victim, pev_origin, fUserOrigin);
			
			fDamage = MaxDamage - floatmul(MaxDamage, floatdiv(get_distance_f(fOrigin, fUserOrigin), Radius));  
			
			if(get_user_health(victim) <= floatround(fDamage))
			{
				ExecuteHamB(Ham_Killed, victim, id, 2);
			}
			else
			{
				message_begin(MSG_ONE_UNRELIABLE, g_msgidScreenShake, {0,0,0}, victim);
				write_short(0xFFFF);
				write_short(1<<13);
				write_short(0xFFFF);
				message_end();
				
				ExecuteHamB(Ham_TakeDamage, victim, id, id, fDamage, DMG_CRUSH|DMG_ALWAYSGIB);
			}
		}
	}
	
	if(g_hulk_smash_snd) emit_sound(id, CHAN_BODY, HULK_SMASH_SND, VOL_NORM, ATTN_NORM, 0, PITCH_HIGH);
}

set_user_teaminfo(id, team)
{
	static const TeamInfo[][] = 
	{ 
		"UNASSIGNED",
		"TERRORIST",
		"CT",
		"SPECTATOR" 
	};
	
	message_begin(MSG_ALL, g_msgTeamInfo);
	write_byte(id); 
	write_string(TeamInfo[team]); 
	message_end(); 
}