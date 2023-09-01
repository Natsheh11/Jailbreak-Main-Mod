#include <amxmodx>
#include <jailbreak_core>
#include <fun>
#include <hamsandwich>
#include <fakemeta>
#include <jb_minigames_core>

#define PLUGIN "[JB] MINIGAMES: TICKING BOMB"
#define AUTHOR "Natsheh"

#define TASK_TICKINGBOMB 48765711

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif

new HamHook:TakeDamagePre, HamHook:TraceAttackPre, user_has_tickingbomb[33], MINIGAME_INDEX, ThinkPost, g_pcvar_one,
g_pcvar_two, MINIGAME_PLAYERS_BITS;

new const tickingbomb_classname[] = "tickingbomb";
new tickingbomb_model[64] = "models/jailbreak/w_bomb.mdl";
new sprites_eexplo;

new const sounds_keys[][] = {
	"BOMB_LVL_1_SND",
	"BOMB_LVL_2_SND",
	"BOMB_LVL_3_SND",
	"BOMB_LVL_4_SND",
	"BOMB_LVL_5_SND"
}

new bomb_tick_sounds[][64] = {
	"weapons/c4_beep1.wav",
	"weapons/c4_beep2.wav",
	"weapons/c4_beep3.wav",
	"weapons/c4_beep4.wav",
	"weapons/c4_beep5.wav"
}

public plugin_precache()
{
	jb_ini_get_keyvalue("MINIGAMES_TICKINGBOMB", "TICKINGBOMB_MDL", tickingbomb_model, charsmax(tickingbomb_model))
	PRECACHE_WORLD_ITEM(tickingbomb_model);
	
	new szValue[64];
	copy(szValue, charsmax(szValue), "sprites/eexplo.spr");
	jb_ini_get_keyvalue("MINIGAMES_TICKINGBOMB", "BOMB_EXPLODE_SPR", szValue, charsmax(szValue))
	sprites_eexplo = PRECACHE_SPRITE_I(szValue);
	
	for(new i; i < sizeof bomb_tick_sounds; i++)
	{
		jb_ini_get_keyvalue("MINIGAMES_TICKINGBOMB", sounds_keys[i], bomb_tick_sounds[i], charsmax(bomb_tick_sounds[]));
		PRECACHE_SOUND(bomb_tick_sounds[i]);
	}
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	MINIGAME_INDEX = register_jb_minigame("Ticking Bomb", "minigame_handling");
	
	g_pcvar_one = register_cvar("jb_minigame_tickingbomb_glow", "0");
	g_pcvar_two = register_cvar("jb_minigame_tickingbomb_life", "15");
	
	DisableHamForward( (TraceAttackPre = RegisterHam(Ham_TraceAttack, "player", "fw_traceattack_player_pre")));
	DisableHamForward( (TakeDamagePre = RegisterHam(Ham_TakeDamage, "player", "fw_takedamage_player_pre")));

}

public minigame_handling( minigame_index, minigame_mode, minigame_players[33], teams[MAX_MINIGAMES_TEAMS], maxteams, players_num, bits_players )
{
	if( !ThinkPost )
		ThinkPost = register_forward(FM_Think, "fw_think_info_target_post", 1);
	
	EnableHamForward(TraceAttackPre);
	EnableHamForward(TakeDamagePre);
	
	MINIGAME_PLAYERS_BITS = bits_players;
	
	set_task(3.0, "give_tickingbomb", TASK_TICKINGBOMB);
	cprint_chat(0, _, "^4~MINIGAMES~ ^3Ticking Bomb ^1Match will start in 3 Seconds, ^4Good luck!")
}

public jb_minigame_ended(const Minigame_Index, const MINIGAMES_MODES:Minigame_Mode, const Winner, players_bits)
{
	if(Minigame_Index == MINIGAME_INDEX)
	{
		unregister_forward(FM_Think, ThinkPost, 1);
		ThinkPost = 0;
		DisableHamForward(TraceAttackPre);
		DisableHamForward(TakeDamagePre);
		
		remove_task(TASK_TICKINGBOMB);
		
		new ent;
		while( (ent = engfunc(EngFunc_FindEntityByString, ent, "classname", tickingbomb_classname)) > 0)
		{
			engfunc(EngFunc_RemoveEntity, ent);
		}
		
		new players[32], pnum;
		get_players(players,pnum, "h")
		
		for(new i; i < pnum; i++)
		{
			user_has_tickingbomb[players[i]] = 0;
		}
	}
}

public give_tickingbomb(TASK_ID)
{
	new players[32], pnum, j;
	get_players(players, pnum, "ahe", "TERRORIST");
	
	for(new i, player; i < pnum; i++)
	{
		player = players[i];
		if(check_flag(MINIGAME_PLAYERS_BITS,player))
		{
			players[j] = players[i];
			j++;
		}
	}
	
	if(!j) return;
	
	new randperson = players[random(j)];
	
	if(!is_user_connected(randperson))
	{
		if(!jb_is_minigame_active(MINIGAME_INDEX)) return;
		
		set_task(3.0, "give_tickingbomb", TASK_TICKINGBOMB);
		cprint_chat(0, _, "^4~MINIGAMES~ ^3Ticking time bomb, ^1Giving a new ticking time bomb to a random person in 3 seconds, ^4Good luck!")
		
		return;
	}
	
	new szName[32];
	get_user_name(randperson, szName, charsmax(szName))
	set_user_tickingbomb(randperson)
	cprint_chat(0, _, "^4~MINIGAMES~ ^3Ticking time bomb ^4- ^3%s ^1has the bomb!", szName)
	
	set_hudmessage(255, 0, 0, -1.0, 0.35, 1, 6.0, 6.0, 0.01, 0.05, -1)
	show_hudmessage(randperson, "!! You have the ticking time bomb !! ^n Pass it quick!")
}

public fw_traceattack_player_pre(victim, attacker, Float:damage, Float:direction[3], traceresults, dmgbits)
{
	if(!(32 >= attacker >= 1) || victim == attacker) return HAM_IGNORED;
	
	if(jb_is_user_inminigame(victim) != MINIGAME_INDEX ||
		jb_is_user_inminigame(attacker) != MINIGAME_INDEX)
			return HAM_IGNORED;
	
	if(get_user_weapon(attacker) != CSW_KNIFE)
	{
		SetHamParamFloat(3, 0.0);
		SetHamParamInteger(6, 0);
		return HAM_SUPERCEDE;
	}
	
	SetHamParamFloat(3, 0.0);
	return HAM_HANDLED;
}

public fw_takedamage_player_pre(victim, inflictor, attacker, Float:damage, dmgbits)
{
	if(!(32 >= attacker >= 1) || victim == attacker) return HAM_IGNORED;
	
	if((jb_is_user_inminigame(victim) != MINIGAME_INDEX ||
		jb_is_user_inminigame(attacker) != MINIGAME_INDEX))
			return HAM_IGNORED;
	
	if(inflictor != attacker || get_user_weapon(attacker) != CSW_KNIFE)
	{
		set_pev(victim, pev_punchangle, Float:{0.0,0.0,0.0});
		SetHamParamFloat(4, 0.0);
		return HAM_SUPERCEDE;
	}
	
	new ent;
	if((ent = user_has_tickingbomb[attacker]) > 0 && !user_has_tickingbomb[victim])
	{
		set_pev(ent, pev_aiment, victim);
		set_pev(ent, pev_owner, attacker);
		user_has_tickingbomb[victim] = ent;
		user_has_tickingbomb[attacker] = 0;
		
		set_hudmessage(255, 0, 0, -1.0, 0.35, 1, 6.0, 6.0, 0.01, 0.05, -1)
		show_hudmessage(victim, "!! You've the ticking time bomb !! ^n Pass it quick!")
	}
	
	SetHamParamFloat(4, 0.0);
	return HAM_SUPERCEDE;
}

public fw_think_info_target_post(const ent)
{
	if(!pev_valid(ent)) return FMRES_IGNORED;
	
	static classname[32]
	pev(ent, pev_classname, classname, charsmax(classname))
	
	if(!equal(classname, tickingbomb_classname)) return FMRES_IGNORED;
	
	static Float:fExpTime, Float:fGTime, iTarget, iOwner;
	iOwner = pev(ent, pev_owner);
	iTarget = pev(ent, pev_aiment);
	
	if(!is_user_connected(iOwner))
	{
		iOwner = iTarget;
		set_pev(ent, pev_owner, iTarget);
	}
	
	if(!is_user_alive(iTarget))
	{
		remove_user_tickingbomb(iTarget);
		
		if(jb_is_minigame_active(MINIGAME_INDEX))
		{
			set_task(3.0, "give_tickingbomb", TASK_TICKINGBOMB);
			cprint_chat(0, _, "^4~MINIGAMES~ ^3Ticking Bomb, ^1Giving a new ticking bomb to a random person in 3 Seconds, ^4Good luck!")
		}
		return FMRES_IGNORED;
	}
	
	fGTime = get_gametime();
	pev(ent, pev_fuser4, fExpTime)
	
	switch( floatround((fExpTime - fGTime)) )
	{
		case 25..999:
		{
			emit_sound(iTarget, CHAN_AUTO, bomb_tick_sounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			set_pev(ent, pev_nextthink, fGTime + 1.4);
		}
		case 15..24:
		{
			emit_sound(iTarget, CHAN_AUTO, bomb_tick_sounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			set_pev(ent, pev_nextthink, fGTime + 1.2);
		}
		case 10..14:
		{
			emit_sound(iTarget, CHAN_AUTO, bomb_tick_sounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			set_pev(ent, pev_nextthink, fGTime + 1.0);
		}
		case 4..9:
		{
			emit_sound(iTarget, CHAN_AUTO, bomb_tick_sounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			set_pev(ent, pev_nextthink, fGTime + 0.8);
		}
		case 0..3:
		{
			emit_sound(iTarget, CHAN_AUTO, bomb_tick_sounds[4], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			set_pev(ent, pev_nextthink, fGTime + 0.4);
		}
		default:
		{
			static Float:fOrigin[3];
			pev(ent, pev_origin, fOrigin);
			
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_EXPLOSION)
			engfunc(EngFunc_WriteCoord, fOrigin[0])
			engfunc(EngFunc_WriteCoord, fOrigin[1])
			engfunc(EngFunc_WriteCoord, fOrigin[2])
			write_short(sprites_eexplo)
			write_byte(10)
			write_byte(10)
			write_byte(0)
			message_end()
			
			remove_user_tickingbomb(iTarget)
			
			new frags = get_user_frags(iOwner);
			ExecuteHamB(Ham_Killed, iTarget, iOwner, 1);
			set_user_frags(iOwner, frags + 1);
			
			if(!jb_is_minigame_active(MINIGAME_INDEX)) return FMRES_IGNORED;
			
			set_task(3.0, "give_tickingbomb", TASK_TICKINGBOMB)
			cprint_chat(0, _, "^4~MINIGAMES~ ^3Ticking time bomb, ^1Giving a new ticking time bomb to a random person in 3 seconds, ^4Good luck!")
		}
	}
	return FMRES_IGNORED;
}

remove_user_tickingbomb(const index)
{
	new ent;
	if(!pev_valid((ent = user_has_tickingbomb[index]))) return 0;
	
	engfunc(EngFunc_RemoveEntity, ent);
	user_has_tickingbomb[index] = 0;
	return 1;
}

public client_disconnect(id)
{
	if(remove_user_tickingbomb(id))
	{
		if(!jb_is_minigame_active(MINIGAME_INDEX)) return;
		
		set_task(3.0, "give_tickingbomb", TASK_TICKINGBOMB);
		cprint_chat(0, _, "^4~MINIGAMES~ ^3Ticking time bomb, ^1Giving a new ticking time bomb to a random person in 3 seconds, ^4Good luck!")
	}
}

set_user_tickingbomb(const index)
{
	if(user_has_tickingbomb[index] > 0) return 0;
	
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	if(!ent) return 0;
	
	user_has_tickingbomb[index] = ent;
	
	new Float:fgametime = get_gametime();
	
	set_pev(ent, pev_classname, tickingbomb_classname);
	engfunc(EngFunc_SetModel, ent, tickingbomb_model);
	set_pev(ent, pev_solid, SOLID_NOT);
	set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
	set_pev(ent, pev_aiment, index);
	set_pev(ent, pev_owner, index);
	set_pev(ent, pev_fuser4, (fgametime + floatclamp(get_pcvar_float(g_pcvar_two), 5.0, 30.0)));
	set_pev(ent, pev_nextthink, fgametime + 0.5);

	
	if(get_pcvar_num(g_pcvar_one) > 0)
	{
		set_pev(ent, pev_renderfx, kRenderFxGlowShell);
		set_pev(ent, pev_rendercolor, Float:{255.0,0.0,0.0});
		set_pev(ent, pev_renderamt, 255.0);
	}
	
	return ent;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
