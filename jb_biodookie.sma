/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <jailbreak_core>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <screenfade_util>

#define TASK_DOOKIE_LIFETIME 25000
#define TASK_HEALTH_REG		 21000

#define PLUGIN "[JB] Bio-Dookie"
#define AUTHOR "Natsheh"

new const DOOKIE_CLASSNAME [] = "dookie";
new const DOOKIE_WEAPONNAME[] = "biodookie";
new const DOOKIE_SOUND1[] = "dookie/dookie1.wav";
new const DOOKIE_SOUND2[] = "dookie/dookie2.wav";
new const DOOKIE_MODEL [] = "models/dookie2.mdl";
new const STEAM_SPRITE [] = "sprites/xsmoke3.spr";
new const SMOKE_SPRITE [] = "sprites/steam1.spr";
new const SHOCKWAVE_SPRITE [] = "sprites/laserbeam.spr";

new g_duel, g_iSteam, g_iSmoke, g_iShockwave, HamHook:g_fw_HamKilled, g_iMSG_DeathMSG, g_iMSG_DeathMSG_origvalue,
	Float:g_userHealthRestoring[MAX_PLAYERS+1], Float:g_fDelaytime[MAX_PLAYERS+1], Float:g_fUseFirstTimePressed[MAX_PLAYERS+1], g_iUseCount[MAX_PLAYERS+1];

public plugin_precache()
{
	PRECACHE_WORLD_ITEM(DOOKIE_MODEL);
	PRECACHE_SOUND(DOOKIE_SOUND1);
	PRECACHE_SOUND(DOOKIE_SOUND2);
	
	g_iSteam = PRECACHE_SPRITE_I(STEAM_SPRITE);
	g_iSmoke = PRECACHE_SPRITE_I(SMOKE_SPRITE);
	g_iShockwave = PRECACHE_SPRITE_I(SHOCKWAVE_SPRITE);
}

new g_pcvr_dookie_delay, g_pcvr_dookie_lr_delay, g_pcvr_lr_lifetime, g_pcvr_maxdmg, g_pcvr_radius, g_pcvr_lifetime, g_pcvr_hp_regenrate_amount, g_pcvr_hp_regenrate_len;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	g_duel = register_jailbreak_lritem("Biohazard Dookie");
	
	register_think(DOOKIE_CLASSNAME, "dookie_think");
	DisableHamForward((g_fw_HamKilled = RegisterHam(Ham_Killed, "player", "fw_player_killed_post", 1)));
	
	g_pcvr_dookie_lr_delay = register_cvar("jb_bio_lr_dropdelay", "3");
	g_pcvr_dookie_delay = register_cvar("jb_bio_dropdelay", "5");
	g_pcvr_maxdmg = register_cvar("jb_bio_dmg", "50");
	g_pcvr_radius = register_cvar("jb_bio_radius", "150");
	g_pcvr_lr_lifetime = register_cvar("jb_bio_lr_lifetime", "15");
	g_pcvr_lifetime = register_cvar("jb_bio_lifetime", "10");
	g_pcvr_hp_regenrate_amount = register_cvar("jb_biodookie_regen_hp", "10");
	g_pcvr_hp_regenrate_len = register_cvar("jb_biodookie_regen_duration", "1");

	g_iMSG_DeathMSG = get_user_msgid("DeathMsg");
}

public dookie_think( const iEnt )
{
	entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 1.0);
	
	new Float:vOrigin[3];
	entity_get_vector(iEnt, EV_VEC_origin, vOrigin);
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_SPRITE);
	engfunc(EngFunc_WriteCoord, vOrigin[ 0 ]);
	engfunc(EngFunc_WriteCoord, vOrigin[ 1 ]);
	engfunc(EngFunc_WriteCoord, vOrigin[ 2 ] + 10.0);
	write_short(g_iSteam);
	write_byte(8);
	write_byte(10);
	message_end();
	
	new player = -1, Float:xOrigin[3], dmg;
	new Float:gcvr_maxdmg = get_pcvar_float(g_pcvr_maxdmg);
	new Float:gcvr_radius = get_pcvar_float(g_pcvr_radius);
	
	new owner = pev(iEnt, pev_owner);
	
	while( (player = find_ent_in_sphere(player, vOrigin, gcvr_radius)) > 0)
	{
		if(!is_user_alive(player) || player == owner)
			continue;
		
		pev(player, pev_origin, xOrigin);
		dmg = calculate_radius_dmg(gcvr_radius, vOrigin, xOrigin, gcvr_maxdmg);
		
		if(dmg > 0)
		{
			biohazard_damage(player, dmg, iEnt, owner);
		}
	}
}

public jb_lr_duel_started(pris, guar, Duid)
{
	if(Duid == g_duel)
	{
		arrayset(g_userHealthRestoring, 0.0, sizeof g_userHealthRestoring);

		jb_block_user_weapons(pris, true);
		jb_block_user_weapons(guar, true, ~(1<<CSW_KNIFE));
		
		// strip prisoner weapons
		strip_user_weapons(pris);
		cprint_chat(pris, _, "Press ^4'E' ^1to drop a ^4biohazard ^1dookie ^3!!!");
		cprint_chat(guar, _, "^4( ^3Alert Biohazard Detected ^3) ^1Stay away from the dookie ^3!!!");
	}
}

public client_PreThink(id)
{
	if(!is_user_alive(id))
		return;

	static buttons, iOldButtons;
	buttons = pev(id, pev_button);
	iOldButtons = pev(id, pev_oldbuttons);

	if(buttons & IN_USE && !(iOldButtons & IN_USE))
	{
		static Float:fGameTime;
		fGameTime = get_gametime();

		if(g_fDelaytime[id] > fGameTime)
		{
			return;
		}

		if((fGameTime - g_fUseFirstTimePressed[id]) > 1.0)
		{
			g_iUseCount[id] = 0;
		}

		if(++g_iUseCount[id] >= 4)
		{
			g_fDelaytime[id] = (fGameTime + get_pcvar_float(g_pcvr_dookie_delay));
			create_dookie(id, get_pcvar_float(g_pcvr_lifetime));
		}
		else if(g_iUseCount[id] == 1)
		{
			static prisoner;
			if(jb_get_current_duel(.prisoner=prisoner) == g_duel && prisoner == id)
			{
				g_fDelaytime[id] = (fGameTime + get_pcvar_float(g_pcvr_dookie_lr_delay));
				create_dookie(id, get_pcvar_float(g_pcvr_lr_lifetime));
				g_iUseCount[id] = 0;
			}

			g_fUseFirstTimePressed[id] = fGameTime;
		}
	}
}

public jb_round_end()
{
	new iEntity;
	
	while((iEntity = find_ent_by_class(iEntity, DOOKIE_CLASSNAME)) > 0)
	{
		remove_task(iEntity+TASK_DOOKIE_LIFETIME);
		fm_remove_entity(iEntity);
	}
}

public jb_lr_duel_ended(pris, gur, Duid)
{
	if(Duid == g_duel)
	{
		new iEntity = -1;
		
		while((iEntity = find_ent_by_class(iEntity, DOOKIE_CLASSNAME)) > 0)
		{
			remove_task(iEntity+TASK_DOOKIE_LIFETIME);
			fm_remove_entity(iEntity);
		}
		
		if(is_user_alive(pris)) give_item(pris, "weapon_knife");
	}
}

public dookie_lifetime(taskid)
{
	new ent = taskid - TASK_DOOKIE_LIFETIME;
	
	if(!pev_valid(ent))
	{
		return;
	}
	
	new Float:fOrigin[3], origin[3];
	entity_get_vector(ent, EV_VEC_origin, fOrigin);
	
	origin[0] = floatround(fOrigin[0]);
	origin[1] = floatround(fOrigin[1]);
	origin[2] = floatround(fOrigin[2]);
	
	// ring
	message_begin(MSG_PVS,SVC_TEMPENTITY, origin,0);
	write_byte(TE_BEAMCYLINDER);
	write_coord(origin[0]); // x
	write_coord(origin[1]); // y
	write_coord(origin[2]); // z
	write_coord(origin[0]); // x axis
	write_coord(origin[1]); // y axis
	write_coord(origin[2] + 200); // z axis
	write_short(g_iShockwave); // sprite
	write_byte(0); // start frame
	write_byte(0); // framerate
	write_byte(4); // life
	write_byte(15); // width
	write_byte(0); // noise
	write_byte(0); // red
	write_byte(200); // green
	write_byte(0); // blue
	write_byte(200); // brightness
	write_byte(0); // speed
	message_end();
	
	fm_remove_entity(ent);
}

public create_dookie(id, Float:fLife)
{
	if(!is_user_alive(id))
		return;
	
	new ent = create_entity("info_target");
	
	if(!ent)
	{
		return;
	}
	
	set_task(fLife, "dookie_lifetime", ent+TASK_DOOKIE_LIFETIME);
	
	entity_set_string(ent, EV_SZ_classname, DOOKIE_CLASSNAME);
	
	new Float:fOrigin[3];
	entity_get_vector(id, EV_VEC_origin, fOrigin);
	
	entity_set_origin(ent, fOrigin);
	entity_set_float(ent, EV_FL_nextthink, get_gametime() + 1.0);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_TOSS);
	entity_set_int(ent, EV_INT_solid, SOLID_NOT);
	entity_set_edict(ent, EV_ENT_owner, id);
	
	static const Float:fMin[3] = {-5.0, -5.0, 0.0};
	static const Float:fMax[3] = {5.0, 5.0, 10.0};
	
	entity_set_model(ent, DOOKIE_MODEL);
	entity_set_size(ent, fMin, fMax);
	
	engfunc( EngFunc_EmitSound, id, CHAN_VOICE, random_num(0, 1) ? DOOKIE_SOUND2 : DOOKIE_SOUND1, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
	write_byte( TE_SMOKE );
	engfunc( EngFunc_WriteCoord, fOrigin[ 0 ] );
	engfunc( EngFunc_WriteCoord, fOrigin[ 1 ] );
	engfunc( EngFunc_WriteCoord, fOrigin[ 2 ] );
	write_short( g_iSmoke );
	write_byte(60);
	write_byte(5);
	message_end()
	
	dookie_think( ent );
}

biohazard_damage(player, dmg, wpnid, attacker)
{
	new iColor[3] = { 0, 200, 0 }, Float:fDamage = float(dmg), Float:fHealth;
	
	UTIL_ScreenFade(player, iColor, 1.0, 1.5, 200, FFADE_IN|FFADE_OUT);
	
	static iMsg_ScreenShake = 0;
	if(!iMsg_ScreenShake) iMsg_ScreenShake = get_user_msgid("ScreenShake");

	message_begin(MSG_ONE_UNRELIABLE, iMsg_ScreenShake, _, player);
	write_short(1 << 15);
	write_short(1 << 11);
	write_short(1 << 15);
	message_end();

	pev(player, pev_health, fHealth);
	
	if(fDamage < fHealth)
	{
		if(ExecuteHamB(Ham_TakeDamage, player, wpnid, attacker, fDamage, DMG_ACID|DMG_NERVEGAS))
		{
			new Float:fCurrHealth;
			pev(player, pev_health, fCurrHealth);
			g_userHealthRestoring[player] += floatmax(fHealth - fCurrHealth, 0.0);
			remove_task(player+TASK_HEALTH_REG);
			set_task( get_pcvar_float(g_pcvr_hp_regenrate_len), "task_health_regeneration", player+TASK_HEALTH_REG);
		}
	}
	else
	{
		g_iMSG_DeathMSG_origvalue = get_msg_block(g_iMSG_DeathMSG);
		set_msg_block(g_iMSG_DeathMSG, BLOCK_SET);

		ExecuteHamB(Ham_TakeDamage, player, wpnid, attacker, fDamage, DMG_ACID|DMG_NERVEGAS);

		pev(player, pev_health, fHealth);

		if(fHealth <= 0.0)
		{
			remove_task(player+TASK_HEALTH_REG);
			EnableHamForward(g_fw_HamKilled);
			ExecuteHamB(Ham_Killed, player, attacker, false);
			DisableHamForward(g_fw_HamKilled);
		}

		set_msg_block(g_iMSG_DeathMSG, g_iMSG_DeathMSG_origvalue);
	}
}

public task_health_regeneration(taskid)
{
	static id; id = taskid - TASK_HEALTH_REG;

	if(!is_user_alive(id))
	{
		g_userHealthRestoring[id] = 0.0;
		return;
	}

	new Float:fHealth, Float:fMaxHealth;
	pev(id, pev_health, fHealth);
	pev(id, pev_max_health, fMaxHealth);

	if(fHealth >= fMaxHealth)
	{
		return;
	}

	if( g_userHealthRestoring[id] > 0.0 )
	{
		new Float:fRegenratedHP = floatmin(g_userHealthRestoring[id], get_pcvar_float(g_pcvr_hp_regenrate_amount));
		set_pev(id, pev_health, fHealth + fRegenratedHP);
		g_userHealthRestoring[id] -= fRegenratedHP;

		if( g_userHealthRestoring[id] > 0.0)
		{
			set_task(get_pcvar_float(g_pcvr_hp_regenrate_len), "task_health_regeneration", id+TASK_HEALTH_REG);
		}
	}
}

public fw_player_killed_post(victim, killer, shouldgib)
{
	g_userHealthRestoring[victim] = 0.0;
	remove_task(victim+TASK_HEALTH_REG);

	message_begin(MSG_ALL, g_iMSG_DeathMSG);
	write_byte(killer);
	write_byte(victim);
	write_byte(false);
	write_string(DOOKIE_WEAPONNAME);
	message_end();
	
	new kname[32], vname[32], kauthid[32], vauthid[32], kteam[10], vteam[10];

	get_user_name(killer, kname, 31);
	get_user_team(killer, kteam, 9);
	get_user_authid(killer, kauthid, 31);
 
	get_user_name(victim, vname, 31);
	get_user_team(victim, vteam, 9);
	get_user_authid(victim, vauthid, 31);
		
	log_message("^"%s<%d><%s><%s>^" killed ^"%s<%d><%s><%s>^" with ^"%s^"", 
	kname, get_user_userid(killer), kauthid, kteam, 
 	vname, get_user_userid(victim), vauthid, vteam, DOOKIE_WEAPONNAME);
}

calculate_radius_dmg(Float:Radius, Float:eOrigin[3], Float:pOrigin[3], Float:Damage)
{
	new Float:distance = get_distance_f(eOrigin, pOrigin)
	
	if(Radius <= distance)
	{
		return 0;
	}
	
	if(Radius <= 0.0) Radius = 1.0;
	
	return floatround(Damage - ((distance * Damage)/Radius));
}

fm_remove_entity(const entity)
{
	set_pev(entity, pev_flags, FL_KILLME);
	dllfunc(DLLFunc_Think, entity);
}
