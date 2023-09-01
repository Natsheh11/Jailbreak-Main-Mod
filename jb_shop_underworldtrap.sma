#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <engine>
#include <jailbreak_core>

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif

#define UNDERWORLDTRAP "underworld_trap"

#define IsPlayer(%1) (1 <= %1 <= 32)

new g_iHasUnderworldtrap[33];
new g_cvar_health_trap, g_cvar_dmg_trap, g_iItem_Underworldtrap, g_iItemBought;
new g_szTrapModel[MAX_FILE_DIRECTORY_LEN] = "models/jailbreak/w_trap.mdl", 
g_szTrapGibsModel[MAX_FILE_DIRECTORY_LEN] = "models/hgibs.mdl", 
g_szAmbienceSound[MAX_FILE_DIRECTORY_LEN] = "ambience/the_horror4.wav", 
g_Flesh_gibs;

public plugin_precache()
{
	jb_ini_get_keyvalue("UNDERWORLD TRAP", "MODEL", g_szTrapModel, charsmax(g_szTrapModel));
	jb_ini_get_keyvalue("UNDERWORLD TRAP", "GIBS_MDL", g_szTrapGibsModel, charsmax(g_szTrapGibsModel));
	jb_ini_get_keyvalue("UNDERWORLD TRAP", "AMBIENCE", g_szAmbienceSound, charsmax(g_szAmbienceSound));
	
	PRECACHE_WORLD_ITEM(g_szTrapModel);
	g_Flesh_gibs = PRECACHE_WORLD_ITEM_I(g_szTrapGibsModel);
	PRECACHE_SOUND(g_szAmbienceSound);
}

public plugin_init()
{
	register_plugin("[JB] Shop Item: Underworld trap", "1.0", "Natsheh");

	g_cvar_health_trap = register_cvar("jb_health_trap", "3000");
	g_cvar_dmg_trap = register_cvar("jb_trap_dmg_per_sec", "3");

	register_think(UNDERWORLDTRAP, "Underworldtrap_Think");
	register_touch(UNDERWORLDTRAP, "player", "fw_touch_trap");
	RegisterHam(Ham_Killed, "info_target", "fw_info_target_killed", 1);
	RegisterHam(Ham_TakeDamage, "info_target", "fw_info_target_tookdmg", 1);
	RegisterHam(Ham_Spawn, "player", "fw_player_spawned", 1);
	
	register_impulse(100, "hook_flashlight");
	
	g_iItem_Underworldtrap = register_jailbreak_shopitem("Underworld trap", "a visit to the underworld!", 15000, TEAM_PRISONERS);
}

public hook_flashlight(id)
{
	if(!g_iHasUnderworldtrap[id]) return PLUGIN_CONTINUE;
	
	attempt_set_trap(id);
	return PLUGIN_HANDLED;
}

public fw_player_spawned(id)
{
	if(!is_user_alive(id)) return;
	
	static ent; ent = -1;
	while( (ent=find_ent_by_class(ent, UNDERWORLDTRAP)) > 0 )
	{
		if(id == pev(ent, pev_iuser4))
		{
			set_pev(ent, pev_iuser4, 0);
			
			set_pev( ent, pev_frame, 1.0 );
			set_pev( ent, pev_framerate, 1.0 );
			set_pev( ent, pev_sequence, 0 );
			set_pev( ent, pev_animtime, get_gametime() );
			break;
		}
	}
}

public fw_info_target_tookdmg(victim, inflictor, attacker, Float:damage, dmgtype)
{
	if(!IsPlayer(attacker)) return;

	static szClassname[32];
	pev(victim, pev_classname, szClassname, charsmax(szClassname));
	
	if(!equal(szClassname, UNDERWORLDTRAP)) return;
	
	static Float:fHealth;
	pev(victim, pev_health, fHealth);
	if(fHealth > 0.0)
	{
		client_print(attacker, print_center, "Trap Health: %.2f", fHealth);
	}
}

public fw_info_target_killed(victim, killer, iGib)
{
	static szClassname[32];
	pev(victim, pev_classname, szClassname, charsmax(szClassname));
	
	if(!equal(szClassname, UNDERWORLDTRAP)) return;
	
	static Float:fHealth;
	pev(victim, pev_health, fHealth);
	
	if(fHealth <= 0.0)
	{
		new iOrigin[3], Float:fOrigin[3];
		pev(victim, pev_origin, fOrigin);
		FVecIVec(fOrigin, iOrigin);
		iOrigin[2] += 40;
		fOrigin[2] += 40.0;
		
		new iVictim;
		if((iVictim=pev(victim, pev_iuser4)) > 0)
		{
			engfunc(EngFunc_SetOrigin, iVictim, fOrigin);
		}
		
		gib(iOrigin);
	}
}

public client_disconnect(id)
{
	new ent = -1;
	while( (ent=find_ent_by_class(ent, UNDERWORLDTRAP)) > 0 )
	{
		if(pev(ent, pev_iuser1) == id)
		{
			ExecuteHamB(Ham_Killed, ent, ent, GIB_NORMAL);
		}
	}
}

public jb_round_start()
{
	if(!g_iItemBought)
		return;
	
	new ent = -1;
	while( (ent=find_ent_by_class(ent, UNDERWORLDTRAP)) > 0 )
	{
		set_pev(ent, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, ent);
	}
	
	arrayset(g_iHasUnderworldtrap, 0, sizeof g_iHasUnderworldtrap);
	g_iItemBought = false;
}

public jb_shop_item_bought(id, item)
{
	if(g_iItem_Underworldtrap == item)
	{
		g_iHasUnderworldtrap[id] ++;
		cprint_chat(id, _, "Press !g'F' !yto spawn an underworld trap!");
		g_iItemBought = true;
	}
}

attempt_set_trap(id)
{
	if(g_iHasUnderworldtrap[id] > 0)
	{
		new origin1[3], origin2[3];
		get_user_origin(id, origin1, 3);
		origin1[2] += 5;
		get_user_origin(id, origin2, 0);
		new dist = get_distance(origin1, origin2);
	
		if(50 <= dist <= 100)
		{
			new Float:fOrigin1[3], Float:fOrigin2[3], Float:flFraction, iTr2 = create_tr2();
			IVecFVec(origin1, fOrigin1);
			fOrigin1[2] += 16.0;
			static const Float:direction_size[4][2] = { { 0.0, 18.0 }, { 0.0, -18.0 }, { 18.0, 0.0 }, { -18.0, 0.0 } }
			
			for(new i, maxloop = sizeof direction_size; i < maxloop; i++)
			{
				fOrigin2[0] = fOrigin1[0] + direction_size[i][0];
				fOrigin2[1] = fOrigin1[1] + direction_size[i][1];
				fOrigin2[2] = fOrigin1[2];
				
				engfunc(EngFunc_TraceHull, fOrigin1, fOrigin2, IGNORE_MISSILE|DONT_IGNORE_MONSTERS, HULL_POINT, 0, iTr2);
				get_tr2(iTr2, TR_flFraction, flFraction);
				
				if(flFraction != 1.0)
				{
					free_tr2(iTr2);
					cprint_chat(id, _, "You can not place the trap right there, no enough space!");
					return PLUGIN_CONTINUE;
				}
			}
			
			fOrigin2[0] = fOrigin1[0];
			fOrigin2[1] = fOrigin1[1];
			fOrigin2[2] = fOrigin1[2] - 18.0;
			engfunc(EngFunc_TraceLine, fOrigin1, fOrigin2, DONT_IGNORE_MONSTERS, 0, iTr2);
			if(get_tr2(iTr2, TR_pHit) > 0)
			{
				free_tr2(iTr2);
				cprint_chat(id, _, "You can only place the trap on the ground!");
				return PLUGIN_CONTINUE;
			}
			
			fOrigin2[0] = fOrigin1[0];
			fOrigin2[1] = fOrigin1[1];
			fOrigin2[2] = fOrigin1[2] + 64.0;
			engfunc(EngFunc_TraceMonsterHull, id, fOrigin1, fOrigin2, DONT_IGNORE_MONSTERS, 0, iTr2);
			get_tr2(iTr2, TR_flFraction, flFraction);
			if(flFraction != 1.0 || get_tr2(iTr2, TR_AllSolid))
			{
				free_tr2(iTr2);
				cprint_chat(id, _, "You can not place the trap right there, no enough space!");
				return PLUGIN_CONTINUE;
			}
			
			free_tr2(iTr2);
			
			g_iHasUnderworldtrap[id] --;
			trap_create(id, origin1);
		}
		else
		{
			cprint_chat(id, _, "Try to place the trap nearby, not far nor close to you!");
		}
	}
	return PLUGIN_CONTINUE;
}

trap_create(id, origin[3])
{
	
	new ent = create_entity("info_target");
	entity_set_string(ent, EV_SZ_classname, UNDERWORLDTRAP);

	entity_set_model(ent, g_szTrapModel);
	entity_set_size(ent, Float:{ -16.0, -16.0, -8.0 }, Float:{ 16.0, 16.0, 8.0 });

	entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_NONE);
	entity_set_float(ent, EV_FL_health, get_pcvar_float(g_cvar_health_trap));
	entity_set_float(ent, EV_FL_takedamage, DAMAGE_YES);
	
	new Float:fOrigin[3];
	IVecFVec(origin, fOrigin);
	entity_set_origin(ent, fOrigin);
	
	entity_set_int(ent, EV_INT_iuser1, id);
	entity_set_int(ent, EV_INT_flags, FL_MONSTER);

	entity_set_float(ent, EV_FL_nextthink, get_gametime() + 1.0);
}

public Underworldtrap_Think(ent)
{
	if(!pev_valid(ent)) return;
	
	static Float:fGametime, id, iVictim;
	id = entity_get_int(ent, EV_INT_iuser1);
	fGametime = get_gametime();
	
	iVictim = pev(ent, pev_iuser4);
	
	if(IsPlayer(iVictim) && (!is_user_alive(iVictim) || get_user_noclip(iVictim)))
	{
		set_pev(ent, pev_iuser4, 0);
		
		set_pev( ent, pev_frame, 1.0 );
		set_pev( ent, pev_framerate, 1.0 );
		set_pev( ent, pev_sequence, 0 );
		set_pev( ent, pev_animtime, fGametime );
	}
	else if(IsPlayer(iVictim))
	{
		static Float:fOrigin[3];
		pev(ent, pev_origin, fOrigin);
		
		fOrigin[2] += 5.0;
		engfunc(EngFunc_SetOrigin, iVictim, fOrigin);

		new iDamage = get_pcvar_num(g_cvar_dmg_trap);
		
		if(iDamage >= get_user_health(iVictim))
		{
			if(!is_user_connected(id))
			{
				id = iVictim;
			}

			ExecuteHamB(Ham_Killed, iVictim, id, GIB_ALWAYS);
			set_pev(ent, pev_iuser4, 0);
			
			set_pev( ent, pev_frame, 1.0 );
			set_pev( ent, pev_framerate, 1.0 );
			set_pev( ent, pev_sequence, 0 );
			set_pev( ent, pev_animtime, fGametime );
		}
		else
		{
			ExecuteHamB(Ham_TakeDamage, iVictim, ent, ent, float(iDamage), DMG_CRUSH);
		}
	}
	
	if(g_szAmbienceSound[0] != EOS) emit_sound(ent, CHAN_STREAM, g_szAmbienceSound, VOL_NORM, ATTN_IDLE, SND_SPAWNING, PITCH_NORM);
	
	entity_set_float(ent, EV_FL_nextthink, fGametime + 1.0);
}

public fw_touch_trap(ent, id)
{
	if(!is_user_alive(id) || !pev_valid(ent) || pev(ent, pev_iuser4) > 0) return;
	
	new Trap_owner = entity_get_int(ent, EV_INT_iuser1);
	
	if(id == Trap_owner) return;
	
	static Float:fOrigin[3];
	pev(ent, pev_origin, fOrigin);
	
	fOrigin[2] += 5.0;
	engfunc(EngFunc_SetOrigin, id, fOrigin);
	set_pev(ent, pev_iuser4, id);
	
	set_pev( ent, pev_animtime, get_gametime() + 0.1 );
	set_pev( ent, pev_frame, 1.0 );
	set_pev( ent, pev_framerate, 0.1 );
	set_pev( ent, pev_sequence, 1 );
}

gib(const i_v_Origin[3])
{
	message_begin(MSG_PVS,SVC_TEMPENTITY, i_v_Origin);
	write_byte(TE_BREAKMODEL);
	
	write_coord(i_v_Origin[0]);
	write_coord(i_v_Origin[1]);
	write_coord(i_v_Origin[2] + 5);
	
	write_coord(32);
	write_coord(32);
	write_coord(32);
	
	write_coord(0);
	write_coord(0);
	write_coord(25);
	
	write_byte(10);
	
	write_short(g_Flesh_gibs);
	
	write_byte(8);
	write_byte(30);
	const BREAK_FLESH   =    0x04;
	write_byte(BREAK_FLESH);
	message_end();
}
