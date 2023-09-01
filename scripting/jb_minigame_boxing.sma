/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <jailbreak_core>
#include <fun>
#include <hamsandwich>
#include <fakemeta>
#include <jb_minigames_core>

#define PLUGIN "[JB] MINIGAMES: BOXING"
#define AUTHOR "Natsheh"

enum (+=1)
{
	V_MODEL = 0,
	P_MODEL

}

new GLOVES_SND_DIRECTORY[64] = "jailbreak/box"

new  red_gloves[][64] = {
	"models/jailbreak/v_boxing_gloves_red.mdl",
	"models/jailbreak/p_boxing_gloves_red.mdl"
}

new  blue_gloves[][64] = {
	"models/jailbreak/v_boxing_gloves_blue.mdl",
	"models/jailbreak/p_boxing_gloves_blue.mdl"
}

// knife sounds
new const knife_sounds[][] = {
	"_deploy1.wav",
	"_hit1.wav",
	"_hit2.wav",
	"_hit3.wav",
	"_hit4.wav",
	"_hitwall1.wav",
	"_slash1.wav",
	"_slash2.wav",
	"_stab.wav"
}

new MINIGAME_INDEX, LR_DUEL_INDEX, MINIGAME_PLAYERS_TEAM[33];

#define WEAPON_LINUXDIFF 4
const m_pPlayer = 41;
const m_pActiveItem = 373;

new HamHook:HamDeploy, HamHook:HamDeploy_Pre, HamHook:HamTakeDamage, HamHook:HamTraceAttack, FW_FM_EMITSOUND = -1;
new g_iLRDuel, g_iLRPrisoner, g_iLRGuard;
new modelindex_vboxgloves[2], g_cvar_one;

public plugin_precache()
{
	jb_ini_get_keyvalue("MINIGAMES_BOXING", "GUARD_V_GLOVES_MDL", blue_gloves[V_MODEL], charsmax(blue_gloves[]))
	modelindex_vboxgloves[0] = PRECACHE_WEAPON_VIEW_MODEL(blue_gloves[V_MODEL]);
	
	jb_ini_get_keyvalue("MINIGAMES_BOXING", "GUARD_P_GLOVES_MDL", blue_gloves[P_MODEL], charsmax(blue_gloves[]))
	PRECACHE_WEAPON_PLAYER_MODEL(blue_gloves[P_MODEL]);
	
	jb_ini_get_keyvalue("MINIGAMES_BOXING", "PRISONER_V_GLOVES_MDL", red_gloves[V_MODEL], charsmax(red_gloves[]))
	modelindex_vboxgloves[1] = PRECACHE_WEAPON_VIEW_MODEL(red_gloves[V_MODEL]);
	
	jb_ini_get_keyvalue("MINIGAMES_BOXING", "PRISONER_P_GLOVES_MDL", red_gloves[P_MODEL], charsmax(red_gloves[]))
	PRECACHE_WEAPON_PLAYER_MODEL(red_gloves[P_MODEL]);
	
	new szSound[64];
	jb_ini_get_keyvalue("MINIGAMES_BOXING", "GLOVES_SND_DIRECTORY", GLOVES_SND_DIRECTORY, charsmax(GLOVES_SND_DIRECTORY));
	
	for(new i, maxloop = sizeof knife_sounds; i < maxloop; i++)
	{
		formatex(szSound, charsmax(szSound), "%s%s", GLOVES_SND_DIRECTORY, knife_sounds[i]);
		PRECACHE_SOUND(szSound);
	}
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	MINIGAME_INDEX = register_jb_minigame("Boxing", "fw_boxing_handle")
	DisableHamForward( (HamDeploy_Pre = RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_item_deploy", 0)));
	DisableHamForward( (HamDeploy = RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_item_deploy", 1)));
	DisableHamForward( (HamTraceAttack = RegisterHam(Ham_TraceAttack, "player", "fw_traceattack_player_pre")));
	DisableHamForward( (HamTakeDamage = RegisterHam(Ham_TakeDamage, "player", "fw_takedamage_pre")));
	
	LR_DUEL_INDEX = register_jailbreak_lritem("Boxing");

	g_cvar_one = register_cvar("jb_boxing_damage", "0.5");
}

public jb_lr_duel_started(prisoner, guard, duelid)
{
	if(duelid == LR_DUEL_INDEX)
	{
		g_iLRPrisoner = prisoner;
		g_iLRGuard = guard;
		g_iLRDuel = duelid;

		EnableHamForward(HamDeploy_Pre);
		EnableHamForward(HamDeploy);
		EnableHamForward(HamTakeDamage);
		if(FW_FM_EMITSOUND == -1) FW_FM_EMITSOUND = register_forward(FM_EmitSound, "fw_emitsound");

		new z;
		if((z = give_item(prisoner, "weapon_knife")) > 0)
		{
			engclient_cmd(prisoner, "weapon_knife");
			ExecuteHamB(Ham_Item_Deploy, z);
		}
		else {
			engclient_cmd(prisoner, "weapon_knife");
			
			while( (z = engfunc(EngFunc_FindEntityByString, z, "classname", "weapon_knife")) && pev(z, pev_owner) != prisoner ) { }
			if( z > 0) ExecuteHamB(Ham_Item_Deploy, z);
		}

		if((z = give_item(guard, "weapon_knife")) > 0)
		{
			engclient_cmd(guard, "weapon_knife");
			ExecuteHamB(Ham_Item_Deploy, z);
		}
		else {
			engclient_cmd(guard, "weapon_knife");
			
			while( (z = engfunc(EngFunc_FindEntityByString, z, "classname", "weapon_knife")) && pev(z, pev_owner) != guard ) { }
			if( z > 0) ExecuteHamB(Ham_Item_Deploy, z);
		}
	}
}

public jb_lr_duel_ended(prisoner, guard, duelid)
{
	if(duelid == LR_DUEL_INDEX)
	{
		g_iLRPrisoner = 0;
		g_iLRGuard = 0;
		g_iLRDuel = 0;

		DisableHamForward(HamDeploy_Pre);
		DisableHamForward(HamDeploy);
		DisableHamForward(HamTakeDamage);
		if(FW_FM_EMITSOUND != -1)
		{
			unregister_forward(FM_EmitSound, FW_FM_EMITSOUND);
			FW_FM_EMITSOUND = -1;
		}
	}
}

public fw_traceattack_player_pre(victim, attacker, Float:damage, Float:direction[3], traceresults, dmgbits)
{
	if(!(32 >= attacker >= 1) || victim == attacker) return HAM_IGNORED;
	
	if(jb_is_user_inminigame(victim) != MINIGAME_INDEX ||
		jb_is_user_inminigame(attacker) != MINIGAME_INDEX)
			return HAM_IGNORED;
	
	if(!has_boxing_gloves(attacker))
	{
		SetHamParamFloat(3, 0.0);
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}

public fw_emitsound(const entity, const channel, const sound[], Float:vol, Float:attn, flag, pitch)
{
	if(!is_user_connected(entity)) return FMRES_IGNORED;
	
	if(!has_boxing_gloves(entity))
		return FMRES_IGNORED;
	
	for(new i, sSound[64]; i < sizeof knife_sounds; i++)
	{
		if(equal(sound[13], knife_sounds[i]))
		{
			formatex(sSound, charsmax(sSound), "%s%s", GLOVES_SND_DIRECTORY, knife_sounds[i])
			emit_sound(entity, channel, sSound, vol, attn, flag, pitch);
			return FMRES_SUPERCEDE;
		}
	}
	return FMRES_IGNORED;
}

public fw_takedamage_pre(victim, inflictor, attacker, Float:damage, dmgbits)
{
	if(!is_user_connected(attacker) || victim == attacker) return HAM_IGNORED;
	
	if(jb_is_user_inminigame(victim) == MINIGAME_INDEX && jb_is_user_inminigame(attacker) == MINIGAME_INDEX)
	{
		if(!has_boxing_gloves(attacker) || inflictor != attacker)
		{
			set_pev(victim, pev_punchangle, Float:{0.0,0.0,0.0});
			SetHamParamFloat(4, 0.0);
			return HAM_SUPERCEDE;
		}
	}
	else if ( !has_boxing_gloves(attacker) || inflictor != attacker )
	{
		return HAM_IGNORED;
	}
	
	new Float:fAngles[3];
	fAngles[0] = floatclamp(damage * random_num(1,-1), -90.0, 90.0); // upwards knock
	fAngles[1] = floatclamp(damage * random_num(1,-1), -90.0, 90.0); // sideway knock
	set_pev(victim, pev_punchangle, fAngles);
	
	SetHamParamFloat(4, damage * get_pcvar_float(g_cvar_one));
	return HAM_HANDLED;
}

has_boxing_gloves(id)
{
	new szViewModel[64], iTemp;
	pev(id, pev_viewmodel2, szViewModel, charsmax(szViewModel));
	iTemp = engfunc(EngFunc_ModelIndex, szViewModel);
	
	if(modelindex_vboxgloves[0] != iTemp && modelindex_vboxgloves[1] != iTemp)
	{
		return false;
	}
	
	return true
}

public fw_item_deploy(const ent)
{
	new id = get_pdata_cbase(ent, m_pPlayer, WEAPON_LINUXDIFF);
	
	if(jb_is_user_inminigame(id) == MINIGAME_INDEX)
	{
		if((MINIGAME_PLAYERS_TEAM[id]%2) == 1)
		{
			set_pev(id, pev_viewmodel2, blue_gloves[V_MODEL])
			set_pev(id, pev_weaponmodel2, blue_gloves[P_MODEL])
		}
		else {
			set_pev(id, pev_viewmodel2, red_gloves[V_MODEL])
			set_pev(id, pev_weaponmodel2, red_gloves[P_MODEL])
		}

		// incase of something overrides the gloves.
		set_pev(ent, pev_classname, "weapon_boxing_gloves");
		return;
	}

	if(g_iLRDuel == LR_DUEL_INDEX)
	{
		if(g_iLRGuard == id)
		{
			set_pev(id, pev_viewmodel2, blue_gloves[V_MODEL])
			set_pev(id, pev_weaponmodel2, blue_gloves[P_MODEL])
		}
		else if(g_iLRPrisoner == id) {
			set_pev(id, pev_viewmodel2, red_gloves[V_MODEL])
			set_pev(id, pev_weaponmodel2, red_gloves[P_MODEL])
		}

		// incase of something overrides the gloves.
		set_pev(ent, pev_classname, "weapon_boxing_gloves");
	}

}

public jb_minigame_ended(const Minigame_Index, const MINIGAMES_MODES:Minigame_Mode, const Winner, bits_players)
{
	if(Minigame_Index == MINIGAME_INDEX)
	{
		DisableHamForward(HamDeploy_Pre);
		DisableHamForward(HamDeploy);
		DisableHamForward(HamTraceAttack);
		DisableHamForward(HamTakeDamage);
		if(FW_FM_EMITSOUND != -1)
		{
			unregister_forward(FM_EmitSound, FW_FM_EMITSOUND);
			FW_FM_EMITSOUND = -1;
		}
		
		new player, t, players[32], pnum;
		get_players(players, pnum, "ahe", "TERRORIST");
		
		for(new i; i < pnum; i++)
		{
			player = players[i];
			
			if(!check_flag(bits_players,player)) continue;
			
			t = get_pdata_cbase(player, m_pActiveItem);
			if(pev_valid(t)) ExecuteHamB(Ham_Item_Deploy, t);
		}
	}
}

public fw_boxing_handle( minigame_index, minigame_mode, minigame_players[33], teams[MAX_MINIGAMES_TEAMS], maxteams, players_num, bits_players )
{
	EnableHamForward(HamDeploy_Pre);
	EnableHamForward(HamDeploy);
	EnableHamForward(HamTraceAttack);
	EnableHamForward(HamTakeDamage);
	if(FW_FM_EMITSOUND == -1) FW_FM_EMITSOUND = register_forward(FM_EmitSound, "fw_emitsound");
	
	for(new i, maxloop = sizeof MINIGAME_PLAYERS_TEAM; i < maxloop; i++) MINIGAME_PLAYERS_TEAM[i] = minigame_players[i];
	
	new players[32], pnum;
	get_players(players, pnum, "ahe", "TERRORIST");
	
	for(new i, id, z; i < pnum; i++)
	{
		id = players[i];
		
		if(!check_flag(bits_players,id)) continue;
		
		if((z = give_item(id, "weapon_knife")) > 0)
		{
			engclient_cmd(id, "weapon_knife");
			ExecuteHamB(Ham_Item_Deploy, z);
		}
		else {
			engclient_cmd(id, "weapon_knife");
			
			while( (z = engfunc(EngFunc_FindEntityByString, z, "classname", "weapon_knife")) && pev(z, pev_owner) != id ) { }
			if( z > 0) ExecuteHamB(Ham_Item_Deploy, z);
		}
	}
}