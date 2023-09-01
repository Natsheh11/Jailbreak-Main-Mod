#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <fun>
#include <hamsandwich>
#include <jailbreak_core>
#include <xs>

#define PLUGIN "[JB] Bazooka"
#define AUTHOR "Natsheh"

#define TASK_SEEK_CATCH 9000
#define TASK_RELOAD 6700
#define TASK_AMMO 6750

#define PEV_ROCKET_TYPE pev_iuser4
#define PEV_ROCKET_OWNER pev_iuser3
#define PEV_ROCKET_CAM pev_iuser2
#define PEV_RPG_AMMO pev_iuser3

#define IsPlayer(%1) (1<=%1<=32)

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif

new  mrocket[64] = "models/rpgrocket.mdl";
new  mrpg_w[64] = "models/w_rpg.mdl";
new  mrpg_v[64] = "models/v_rpg.mdl";
new  mrpg_p[64] = "models/p_rpg.mdl";

new  sfire[64] = "weapons/rocketfire1.wav";
new  sfly[64] = "weapons/nuke_fly.wav";
new  shit[64] = "weapons/mortarhit.wav";
new  spickup[64] = "items/gunpickup2.wav";
new  sreload[64] = "items/9mmclip2.wav";
new  smodselect[64] = "common/wpn_select.wav";

#define WEAPON_LINUXDIFF	4

// OFFSETS
const m_iWeaponOwner = 41;

// Time between can witch to next mode (Thanks to Nihilanth)
#define SWITCH_TIME	0.5
 
// Register the item
new g_itemid, g_itemid2, g_itemid3;

// Cvars
new pcvar_delay, pcvar_radius, pcvar_speed, pcvar_maxdmg,
	pcvar_speed_homing, pcvar_speed_camera, pcvar_bazookashopammo, pcvar_homingradius, pcvar_rocket_life,
	pcvar_rocket_lights, pcvar_ff, pcvar_launch_push, pcvar_explosion_knockback;
	
// Sprites
new g_rocketsmokeSpr, g_whiteSpr, g_explosionSpr, g_bazsmokeSpr;

// Variables
new g_BazookaAmmo[33], user_controll[33], g_mode[33], g_cvar_ff_oldvalue;

// Bools
new g_hasbazooka, Float:g_flLastShoot[33];

// Floats
new Float:lastSwitchTime[33];

// Messages
new g_msg_death, g_msgBarTime;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
        
	// Cvars
	pcvar_delay = register_cvar("jb_bazooka_delay", "5");
	pcvar_maxdmg = register_cvar("jb_bazooka_maxdamage", "300");
	pcvar_radius = register_cvar("jb_bazooka_radius", "150");
	pcvar_speed = register_cvar("jb_bazooka_rocket_speed", "800");
	pcvar_speed_homing = register_cvar("jb_bazooka_rocket_homing_speed", "250");
	pcvar_speed_camera = register_cvar("jb_bazooka_rocket_camera_speed", "450");
	pcvar_bazookashopammo = register_cvar("jb_bazooka_shop_ammo", "1");
	pcvar_homingradius = register_cvar("jb_bazooka_homing_radius", "500");
	pcvar_rocket_life = register_cvar("jb_bazooka_rocket_life", "5.0");
	pcvar_rocket_lights = register_cvar("jb_bazooka_rocket_lights", "0");
	pcvar_ff = register_cvar("jb_bazooka_friendlyfire", "1");
	pcvar_launch_push = register_cvar("jb_bazooka_launch_push", "135");
	pcvar_explosion_knockback = register_cvar("jb_bazooka_explosion_knockback", "1800");
	
	// Register the Extra Item
	g_itemid = register_jailbreak_lritem("Bazooka Duel!");
	g_itemid2 = register_jailbreak_shopitem("Bazooka", "Flawless Bazooka", 35000, TEAM_ANY);
	g_itemid3 = register_jailbreak_day("Bazooka Day!", 0, 300.0, DAY_ONE_SURVIVOR);
	
	// Events
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_knife_deploy_post", 1);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "fw_bazooka_attack_post", 1);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "fw_bazooka_mode_post", 1);
	RegisterHam(Ham_Killed, "info_target", "fw_rocket_Killed_pre", .Post=false);
	
	RegisterHam(Ham_Killed, "player", "fw_player_killed_post", 1);
	
	// Clcmd's
	register_clcmd("drop", "clcmd_drop")
	register_concmd("jb_give_bazooka", "clcmd_give_bazooka", ADMIN_IMMUNITY, "<name/@a/@C/@T> gives a bazooka to the specified target")
	register_concmd("jb_take_bazooka", "clcmd_take_bazooka", ADMIN_IMMUNITY, "<name/@a/@C/@T> takes a bazooka from the specified target")
	
	register_touch("rpg_temp", "player", "fw_touch_rpg_temp");
	register_touch("rpgrocket", "*", "fw_touch_rpgrocket");
	register_think("rpgrocket", "fw_rpgrocket_think");
	
	// Msgid >.<
	g_msgBarTime = get_user_msgid("BarTime");
	g_msg_death = get_user_msgid("DeathMsg");
}

public fw_rocket_Killed_pre(victim)
{
	static sClassname[16];
	pev(victim, pev_target, sClassname, charsmax(sClassname));
	if(equal(sClassname, "rpgrocket"))
	{
		rocket_explode(victim);
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}
 
public client_putinserver(id)
{
	remove_bazooka(id);
}

public client_disconnect(id)
{
	remove_bazooka(id);
}

public fw_rpgrocket_think(const iEnt)
{
	if(!pev_valid(iEnt)) return FMRES_IGNORED;
	
	static id; id = pev(iEnt, PEV_ROCKET_OWNER);
	if(!id) return FMRES_IGNORED;
	
	switch( pev(iEnt, PEV_ROCKET_TYPE) )
	{
		case 2:
		{
			follow_nearby_target(iEnt);
			set_pev(iEnt, pev_nextthink, get_gametime() + 0.1);
		}
		case 3:
		{
			static rocket; rocket = user_controll[id];
			
			if(rocket != iEnt)
				return  FMRES_IGNORED;
			
			if(!is_user_connected(id))
			{
				rocket_explode(iEnt)
				return FMRES_IGNORED;
			}
			
			static Float:Velocity[3], iCam_ent;
			iCam_ent = pev(rocket, PEV_ROCKET_CAM);
			
			static Float:NewAngle[3]
			entity_get_vector(id, EV_VEC_v_angle, NewAngle)
			NewAngle[0] *= -1;
			entity_set_vector(rocket, EV_VEC_angles, NewAngle)
			NewAngle[0] *= -1;
			
			if(pev_valid(iCam_ent))
			{
				static Float:fTemp[3];
				pev(rocket, pev_origin, Velocity)
				angle_vector(NewAngle, ANGLEVECTOR_FORWARD, fTemp);
				Velocity[0] += fTemp[0] * -20.0;
				Velocity[1] += fTemp[1] * -20.0;
				Velocity[2] += 10.0;
				engfunc(EngFunc_SetOrigin, iCam_ent, Velocity);
				entity_set_vector(iCam_ent, EV_VEC_angles, NewAngle)
			}
			
			VelocityByAim(id, get_pcvar_num(pcvar_speed_camera), Velocity)
			entity_set_vector(rocket, EV_VEC_velocity, Velocity)
			
			set_pev(iEnt, pev_nextthink, get_gametime() + 0.01)
		}
		case 4:
		{
			if(is_user_connected(id) && check_flag(g_hasbazooka,id))
			{
				if(get_user_weapon(id) == CSW_KNIFE)
				{
					static Float:fOrigin[3], iOrigin[3];
					
					get_user_origin(id, iOrigin, 3)
					fOrigin[0] = float(iOrigin[0]);
					fOrigin[1] = float(iOrigin[1]);
					fOrigin[2] = float(iOrigin[2]);
					
					message_begin(MSG_BROADCAST, SVC_TEMPENTITY, _, id);
					write_byte(TE_BEAMPOINTS);
					write_coord (iOrigin[0] + 1);
					write_coord (iOrigin[1] + 1);
					write_coord (iOrigin[2] + 1);
					write_coord (iOrigin[0] - 1);
					write_coord (iOrigin[1] - 1);
					write_coord (iOrigin[2] - 1);
					write_short(g_whiteSpr) ;
					write_byte(1);
					write_byte(10) ;
					write_byte(1) ;
					write_byte(50) ;
					write_byte(0) ;
					write_byte(200);
					write_byte(0);
					write_byte(0);
					write_byte(255);
					write_byte(10);
					message_end();
					
					entity_set_follow(iEnt, 0, get_pcvar_float(pcvar_speed), fOrigin);
				}
			}
			
			set_pev(iEnt, pev_nextthink, get_gametime() + 0.1)
		}
	}
	
	return FMRES_IGNORED;
}

public clcmd_drop(id)
{
	if(!check_flag(g_hasbazooka,id) || get_user_weapon(id) != CSW_KNIFE || jb_get_current_day() == g_itemid3 || jb_get_current_duel() == g_itemid)
		return PLUGIN_CONTINUE;
	
	drop_rpg_temp(id);
	return PLUGIN_HANDLED;
}

public fw_knife_deploy_post(const iKnife)
{
	if(!pev_valid(iKnife)) return HAM_IGNORED;
	
	new id = get_pdata_cbase(iKnife, m_iWeaponOwner, WEAPON_LINUXDIFF);
	
	if(!check_flag(g_hasbazooka,id))
		return HAM_IGNORED;
	
	set_pev(id, pev_viewmodel2, mrpg_v);
	set_pev(id, pev_weaponmodel2, mrpg_p);
	
	return HAM_IGNORED;
}

public jb_round_end()
{
	new iEnt;
	while( (iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "target", "rpg_temp")) > 0) 
	{
		set_pev(iEnt, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, iEnt);
	}

	while( (iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "target", "rpgrocket")) > 0)
	{
		remove_task(iEnt);
		set_pev(iEnt, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, iEnt);
	}
	
	static iMaxplayers = 0; if(!iMaxplayers) iMaxplayers = get_maxplayers();
	for(new i = 1; i <= iMaxplayers; i++)
	{
		remove_bazooka( i );
	}
}

public jb_day_started(dayid)
{
	g_hasbazooka = 0;
	
	if(dayid == g_itemid3)
	{
		g_cvar_ff_oldvalue = get_pcvar_num(pcvar_ff);
		set_pcvar_num(pcvar_ff, 1);

		new players[32], pnum;
		get_players(players, pnum, "ah");
		for(new i = 0, player; i < pnum; i++)
		{
			player = players[i];
			jb_block_user_weapons(player, true, ~player_flag(CSW_KNIFE));
			give_bazooka(player, 9999);
		}
		
		set_hudmessage(100, 240, 100, -1.0, 0.65, 1, 6.0, 6.0, 0.05, 0.01, -1)
		show_hudmessage(0, "[Bazooka Day]^nElimnate each other !!!")
		
		// opening cell's..
		jb_cells();
	}
}

public jb_day_ended(dayid)
{
	if(dayid == g_itemid3)
	{
		set_pcvar_num(pcvar_ff, g_cvar_ff_oldvalue);

		new players[32], pnum;
		get_players(players, pnum, "ah")
		for(new i = 0, player; i < pnum; i++)
		{
			player = players[i];
			jb_block_user_weapons(player, false);
			remove_bazooka(player);
		}
	}
}

public jb_lr_duel_started(prisoner, guard, duelid)
{
	g_hasbazooka = 0;
	
	if(duelid == g_itemid)
	{
		new gName[32], pName[32];
		get_user_name(guard, gName, 31);
		get_user_name(prisoner, pName, 31);
		give_bazooka(prisoner, 9999);
		give_bazooka(guard, 9999);
	}
}

public jb_lr_duel_ended(pris, guar, duelid)
{
	if(duelid == g_itemid)
	{
		remove_bazooka(pris);
		remove_bazooka(guar);
	}
}

public jb_shop_item_preselect(player, itemid)
{
	if (itemid == g_itemid2)
	{
		if(check_flag(g_hasbazooka,player))
		{
			return JB_MENU_ITEM_UNAVAILABLE
		}
	}
	return PLUGIN_CONTINUE
}

public jb_shop_item_postselect(player, itemid)
{
	if (itemid == g_itemid2)
	{
		if(check_flag(g_hasbazooka,player))
		{
			return JB_MENU_ITEM_UNAVAILABLE
		}
	}
	return PLUGIN_CONTINUE
}

public jb_shop_item_bought(player, itemid)
{
	if(itemid == g_itemid2)
	{
		give_bazooka(player, get_pcvar_num(pcvar_bazookashopammo))
	}
}

give_bazooka(player, ammo)
{
	set_flag(g_hasbazooka,player);
	g_BazookaAmmo[player] = ammo;
	//LastShoot[player] = 0.0
	g_mode[player] = 1;
	emit_sound(player, CHAN_WEAPON, spickup, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	cprint_chat(player, _, "You got a Bazooka! [Attack2: CHANGE MODES] [Reload:^x04 %2.1f^x01 seconds]", get_pcvar_float(pcvar_delay))
	if(!task_exists(TASK_AMMO+player)) set_task(1.0, "show_bazooka_ammo", TASK_AMMO+player, _, _, "b");
	
	if(is_user_connected(player))
	{
		// switch to knife
		engclient_cmd(player, "weapon_knife")
		
		if(get_user_weapon(player) == CSW_KNIFE)
		{
			set_pev(player, pev_viewmodel2, mrpg_v);
			set_pev(player, pev_weaponmodel2, mrpg_p);
		}
	}
}

public show_bazooka_ammo(taskid)
{
	new id = taskid - TASK_AMMO;
	
	if(!is_user_connected(id) || !check_flag(g_hasbazooka,id))
	{
		remove_task(taskid)
		return;
	}
	if(get_user_weapon(id) != CSW_KNIFE) return;
	
	set_hudmessage(120, 230, 25, 0.75, 0.90, 0, 3.0, 1.0, 0.3, 0.5, -1);
	show_hudmessage(id, "Ammo: %d", g_BazookaAmmo[id]);
}

remove_bazooka(player)
{
	if(check_flag(g_hasbazooka,player)) 
	{
		remove_flag(g_hasbazooka,player);
		g_BazookaAmmo[player] = 0;
		g_flLastShoot[player] = 0.0
		g_mode[player] = 1;
		
		if(task_exists(TASK_AMMO+player)) remove_task(TASK_AMMO+player);
		
		if(is_user_connected(player))
		{
			if(get_user_weapon(player) == CSW_KNIFE)
			{
				new knife = find_ent_by_owner(-1, "weapon_knife", player);

				if(!knife) knife = give_item(player, "weapon_knife");

				if(pev_valid(knife)) {
					ExecuteHamB(Ham_Item_Deploy, knife);
				}

				engclient_cmd(player, "weapon_knife");
			}
		}
	}
}

public clcmd_give_bazooka(id,level,cid)
{
	if(!cmd_access(id, level, cid, 2)) 
	{
		return 1;
	}
	
	new arg1[32], arg2[16];
	read_argv(1, arg1, charsmax(arg1));
	read_argv(2, arg2, charsmax(arg2));
	new player = cmd_target(id, arg1, CMDTARGET_ALLOW_SELF);
	new ammo = str_to_num(arg2);
	
	if (!player)
	{
		if ( arg1[0] == '@' ) 
		{
			new players[32], pnum;
			switch( arg1[1] )
			{
				case 'T', 't': get_players(players, pnum, "ae", "TERRORIST")
				case 'C', 'c': get_players(players, pnum, "ae", "CT")
				default: get_players(players, pnum, "a")
			}
			
			for ( new i = 0; i < pnum; i++ ) 
			{
				player = players[i];
				
				give_bazooka(player, ammo);
			}
			
			console_print(id, "[BAZOOKA] Players has been given bazooka!")
		} 
		else 
		{
			client_print(id, print_console, "[BAZOOKA] No such a player or team found '%s'", arg1);
			return 1;
		}
	} 
	else if (is_user_connected(player))
	{
		if(!ammo) ammo = 9999;
		give_bazooka(player, ammo);
	}
	
	return 1;
}

public clcmd_take_bazooka(id,level,cid)
{
	if(!cmd_access(id, level, cid, 1)) 
	{
		return 1;
	}
	
	new arg1[32];
	read_argv(1, arg1, charsmax(arg1));
	new player = cmd_target(id, arg1, CMDTARGET_ALLOW_SELF|CMDTARGET_OBEY_IMMUNITY);
	
	if (!player)
	{
		if ( arg1[0] == '@' ) 
		{
			new players[32], pnum;
			switch( arg1[1] )
			{
				case 'T', 't': get_players(players, pnum, "ae", "TERRORIST")
				case 'C', 'c': get_players(players, pnum, "ae", "CT")
				default: get_players(players, pnum, "a")
			}
			
			for ( new i = 0; i < pnum; i++ ) 
			{
				player = players[i];
				
				remove_bazooka(player);
			}
			
			console_print(id, "[BAZOOKA] Bazooka were stripped from the players")
		} 
		else 
		{
			client_print(id, print_console, "[BAZOOKA] No such a player or team found '%s'", arg1);
			return 1;
		}
	} 
	else if (is_user_connected(player))
	{
		remove_bazooka(player);
	}
	
	return 1;
}

public plugin_precache()
{
	jb_ini_get_keyvalue("BAZOOKA", "ROCKET_MDL", mrocket, charsmax(mrocket))
	PRECACHE_WORLD_ITEM(mrocket);        
	
	jb_ini_get_keyvalue("BAZOOKA", "RPG_P_MDL", mrpg_p, charsmax(mrpg_p))
	jb_ini_get_keyvalue("BAZOOKA", "RPG_W_MDL", mrpg_w, charsmax(mrpg_w))
	jb_ini_get_keyvalue("BAZOOKA", "RPG_V_MDL", mrpg_v, charsmax(mrpg_v))
	PRECACHE_WEAPON_WORLD_MODEL(mrpg_w);
	PRECACHE_WEAPON_VIEW_MODEL(mrpg_v);
	PRECACHE_WEAPON_PLAYER_MODEL(mrpg_p);
	
	jb_ini_get_keyvalue("BAZOOKA", "FIRE_SND", sfire, charsmax(sfire))
	PRECACHE_SOUND(sfire);
	
	jb_ini_get_keyvalue("BAZOOKA", "FLY_SND", sfly, charsmax(sfly))
	PRECACHE_SOUND(sfly);
	
	jb_ini_get_keyvalue("BAZOOKA", "HIT_SND", shit, charsmax(shit))
	PRECACHE_SOUND(shit);
	
	jb_ini_get_keyvalue("BAZOOKA", "PICKUP_SND", spickup, charsmax(spickup))
	PRECACHE_SOUND(spickup);
	
	jb_ini_get_keyvalue("BAZOOKA", "RELOAD_SND", sreload, charsmax(sreload))
	PRECACHE_SOUND(sreload);
	
	jb_ini_get_keyvalue("BAZOOKA", "FIRE_MODE_SELECT_SND", smodselect, charsmax(smodselect))
	PRECACHE_SOUND(smodselect);
	
	new szFile[64];
	copy(szFile, charsmax(szFile), "sprites/smoke.spr");
	jb_ini_get_keyvalue("BAZOOKA", "ROCKET_SMOKE_SPR", szFile, charsmax(szFile));
	g_rocketsmokeSpr = PRECACHE_SPRITE_I(szFile);
	
	copy(szFile, charsmax(szFile), "sprites/white.spr");
	jb_ini_get_keyvalue("BAZOOKA", "ROCKET_BLAST_SPR", szFile, charsmax(szFile));
	g_whiteSpr = PRECACHE_SPRITE_I(szFile);

	copy(szFile, charsmax(szFile), "sprites/fexplo.spr");
	jb_ini_get_keyvalue("BAZOOKA", "ROCKET_EXPLODE_SPR", szFile, charsmax(szFile));
	g_explosionSpr = PRECACHE_SPRITE_I(szFile);

	copy(szFile, charsmax(szFile), "sprites/steam1.spr");
	jb_ini_get_keyvalue("BAZOOKA", "ROCKET_STEAM_SPR", szFile, charsmax(szFile));
	g_bazsmokeSpr  = PRECACHE_SPRITE_I(szFile);
}

fire_rocket(id) 
{
	if (!CanShoot(id) ) return;

	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	
	if (!pev_valid(ent))
		return;
	
	new data[1];
	data[0] = id;
	g_flLastShoot[id] = get_gametime();
	
	if(g_BazookaAmmo[id]-- > 1)
	{
		new g_delay = get_pcvar_num(pcvar_delay);
		Progress_status(id, g_delay)
		set_task(float(g_delay), "rpg_reload", TASK_RELOAD+id);
		set_task(1.0, "bazooka_reload", id);
	}
 
	new Float:StartOrigin[3], Float:fvTemp[3];
	pev(id, pev_origin, StartOrigin);
	pev(id, pev_view_ofs, fvTemp);
	xs_vec_add(StartOrigin, fvTemp, StartOrigin);
	
	set_pev(ent, pev_classname, "rpgrocket");
	set_pev(ent, pev_target, "rpgrocket");
	engfunc(EngFunc_SetOrigin, ent, StartOrigin);
	
	set_pev(ent, pev_movetype, MOVETYPE_FLYMISSILE);
	set_pev(ent, pev_solid, SOLID_BBOX);
	set_pev(ent, pev_owner, id);
	engfunc(EngFunc_SetModel, ent, mrocket);
	engfunc(EngFunc_SetSize, ent, Float:{-2.0,-2.0,-2.0}, Float:{2.0,2.0,2.0});
	
	set_pev(ent, PEV_ROCKET_OWNER, id);
	set_pev(ent, pev_groupinfo, pev(id, pev_groupinfo));
	
	set_pev(ent, pev_takedamage, DAMAGE_YES);
	set_pev(ent, pev_health, 1.0);
	set_pev(ent, pev_dmg_take, 1.0);
 
	new Float:fAim[3],Float:fAngles[3],Float:fOrigin[3]
	velocity_by_aim(id,64,fAim)
	vector_to_angle(fAim,fAngles)
	set_pev(ent, pev_angles, fAngles);
	pev(id,pev_origin,fOrigin)
        
	fOrigin[0] += fAim[0]
	fOrigin[1] += fAim[1]
	fOrigin[2] += fAim[2]
 
	new Float:nVelocity[3];
	switch( g_mode[id] )
	{
		case 3: velocity_by_aim(id, get_pcvar_num(pcvar_speed_camera), nVelocity);
		default: velocity_by_aim(id, get_pcvar_num(pcvar_speed), nVelocity);
	}
	
	set_pev(ent, pev_velocity, nVelocity);
	if(get_pcvar_num(pcvar_rocket_lights)) entity_set_int(ent, EV_INT_effects, entity_get_int(ent, EV_INT_effects)|EF_BRIGHTLIGHT)
	
	emit_sound(ent, CHAN_WEAPON, sfire, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	emit_sound(ent, CHAN_VOICE, sfly, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);
	write_short(ent);
	write_short(g_rocketsmokeSpr);
	write_byte(50);
	write_byte(3);
	write_byte(255);
	write_byte(255);
	write_byte(255);
	write_byte(255);
	message_end();
	
	set_pev(ent, PEV_ROCKET_TYPE, g_mode[id]);
	
	new Float:gtime = get_gametime();
	
	switch( g_mode[id] )
	{
		case 2: set_pev(ent, pev_nextthink, gtime + 0.1)
		case 3:
		{
			if(is_user_connected(id))
			{
				new ent2 = create_entity("info_target");
				
				if(ent2 > 0)
				{
					set_pev(ent2, pev_movetype, MOVETYPE_FLY);
					set_pev(ent2, pev_aiment, ent);
					set_pev(ent2, pev_owner, ent);
					engfunc(EngFunc_SetModel, ent2, mrocket);
					attach_view(id, ent2);
					set_pev(ent, PEV_ROCKET_CAM, ent2);
					set_rendering(ent2, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0);
				}
				
				set_pev(ent, pev_nextthink, gtime + 0.01);
				user_controll[id] = ent;
			}
		}
		case 4: set_pev(ent, pev_nextthink, gtime + 0.1);
	}
	
	launch_push(id, get_pcvar_num(pcvar_launch_push));
	set_task(floatclamp(get_pcvar_float(pcvar_rocket_life), 1.0, 9999999.0), "rocket_explode", ent);
}
 
public rpg_reload(taskid)
{
	new id = taskid - TASK_RELOAD;
	
	if (!is_user_connected(id) || !check_flag(g_hasbazooka,id)) return;
	
	client_print(id, print_center, "Bazooka reloaded!");
	emit_sound(id, CHAN_WEAPON, spickup, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
 
public fw_touch_rpg_temp(ent, player)
{
	if(!pev_valid(ent) || check_flag(g_hasbazooka, player))
	{
		return;
	}

	emit_sound(player, CHAN_VOICE, spickup, 1.0, ATTN_NORM, 0, PITCH_NORM);
	give_bazooka(player, pev(ent, PEV_RPG_AMMO));

	set_pev(ent, pev_flags, FL_KILLME);
	dllfunc(DLLFunc_Think, ent);
}

public fw_touch_rpgrocket(ent, other)
{
	if(!pev_valid(ent) || pev(ent, PEV_ROCKET_OWNER) == other)
	{
		return;
	}

	rocket_explode(ent);
}

public rocket_explode(ent)
{
	if(!pev_valid(ent) || pev(ent, pev_flags) & FL_KILLME) return;
	
	// rocket died!
	set_pev(ent, pev_takedamage, DAMAGE_NO);

	// remove rocket self destruction.
	remove_task(ent);
	
	static Float:EndOrigin[3];
	pev(ent, pev_origin, EndOrigin);
	static id; id = pev(ent, PEV_ROCKET_OWNER);

	if(!is_user_connected(id)) id = 0;
	
	if(user_controll[id] == ent)
	{
		attach_view(id, id);
		user_controll[id] = 0;
	}
		
	emit_sound(ent, CHAN_WEAPON, shit, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	emit_sound(ent, CHAN_VOICE, shit, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	
	// removing the entity..
	new temp_ent = pev(ent, PEV_ROCKET_CAM);
	if(pev_valid(temp_ent))
	{
		set_pev(temp_ent, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, temp_ent);
	}

	new Float:fDamageradius = floatclamp(get_pcvar_float(pcvar_radius), 1.0, 5000.0);
	
	Create_Explosion(EndOrigin, get_pcvar_float(pcvar_maxdmg), fDamageradius, id);

	// Kill the rocket on nextthink!
	set_pev(ent, pev_flags, FL_KILLME);
	dllfunc(DLLFunc_Think, ent);

	new ent_seek, iEntMoveType, Float:flKnockBackPower = get_pcvar_float(pcvar_explosion_knockback);

	new ent2 = -1, Float:fOrigin[3], Float:fVicOrigin[3], Float:fDistOrigin[3];

	while( (ent_seek=find_ent_in_sphere(ent_seek, EndOrigin, fDamageradius)) )
	{
		if( (pev(ent_seek, pev_solid) != SOLID_BSP) &&
			( (iEntMoveType=pev(ent_seek, pev_movetype)) == MOVETYPE_TOSS || iEntMoveType == MOVETYPE_WALK || iEntMoveType == MOVETYPE_STEP ||
				iEntMoveType == MOVETYPE_PUSH || iEntMoveType == MOVETYPE_BOUNCE || iEntMoveType == MOVETYPE_PUSHSTEP || iEntMoveType == MOVETYPE_FLY )
			)
		{
			if(IsPlayer(ent_seek))
			{
				// Means player is on a ladder.
				if(pev(ent_seek, pev_movetype) == MOVETYPE_FLY)
				{
					pev(ent_seek, pev_origin, fVicOrigin);

					while( (ent2 = find_ent_by_class(ent2, "func_ladder")) > 0)
					{
						get_brush_entity_origin(ent2, fOrigin);
						xs_vec_sub(fVicOrigin, fOrigin, fDistOrigin);

						if(xs_vec_len_2d(fDistOrigin) <= 36.0)
						{
							set_pev(ent2, pev_origin, Float:{ 0.0, 0.0, 4096.0});
							set_task(1.0, "task_retrieve_ladder", ent2);
						}
					}
				}
			}

			entity_explosion_knockback(ent_seek, EndOrigin, fDamageradius, flKnockBackPower);
		}
	}
}

Create_Explosion(const Float:vecCenter[3], Float:fMaxDamage, Float:fMagnitude, iInfluencer=0)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_SPRITE);
	engfunc(EngFunc_WriteCoord, vecCenter[0]);
	engfunc(EngFunc_WriteCoord, vecCenter[1]);
	engfunc(EngFunc_WriteCoord, vecCenter[2] + 100);
	write_short(g_explosionSpr);
	write_byte(60);
	write_byte(255);
	message_end();

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_SMOKE);
	engfunc(EngFunc_WriteCoord, vecCenter[0]);
	engfunc(EngFunc_WriteCoord, vecCenter[1]);
	engfunc(EngFunc_WriteCoord, vecCenter[2] + fMagnitude);
	write_short(g_bazsmokeSpr);
	write_byte(125);
	write_byte(5);
	message_end();

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMCYLINDER);
	engfunc(EngFunc_WriteCoord, vecCenter[0]);
	engfunc(EngFunc_WriteCoord, vecCenter[1]);
	engfunc(EngFunc_WriteCoord, vecCenter[2]);
	engfunc(EngFunc_WriteCoord, fMagnitude);
	engfunc(EngFunc_WriteCoord, fMagnitude);
	engfunc(EngFunc_WriteCoord, fMagnitude);
	write_short(g_whiteSpr);
	write_byte(0);
	write_byte(0);
	write_byte(16);
	write_byte(128);
	write_byte(0);
	write_byte(255);
	write_byte(255);
	write_byte(192);
	write_byte(128);
	write_byte(0);
	message_end();

	if(fMagnitude == 0.0) fMagnitude = 1.0;

	new iTeam = 0;
	if(iInfluencer != 0)
	{
		if(IsPlayer(iInfluencer))
		{
			iTeam = get_user_team(iInfluencer);
		}
		else
		{
			iTeam = pev(iInfluencer, pev_team);
		}
	}

	new iVictim, Float:fDamage, Float:fHealth, Float:fDistance, Float:vecVictimOrigin[3], bool:bFriendlyfire = (get_pcvar_num(pcvar_ff) > 0) ? true:false, iOldDeathMsgValue = get_msg_block(g_msg_death);
	while((iVictim = engfunc(EngFunc_FindEntityInSphere, iVictim, vecCenter, fMagnitude)) > 0)
	{
		pev(iVictim, pev_health, fHealth);
		if(entity_take_damage(iVictim) == DAMAGE_NO || fHealth <= 0.0 || (iInfluencer != 0 && iInfluencer != iVictim && !bFriendlyfire && iTeam == ( IsPlayer(iVictim) ? get_user_team(iVictim) : pev(iVictim, pev_team) )))
		{
			continue;
		}

		if(pev(iVictim, pev_solid) == SOLID_BSP)
		{
			get_brush_entity_origin(iVictim, vecVictimOrigin);
		}
		else
		{
			pev(iVictim, pev_origin, vecVictimOrigin);
		}

		fDistance = floatmin(get_distance_f(vecVictimOrigin, vecCenter), fMagnitude);

		fDamage = fMaxDamage - floatmul(fMaxDamage, floatdiv(fDistance, fMagnitude));

		if(fDamage < fHealth)
		{
			ExecuteHamB(Ham_TakeDamage, iVictim, iInfluencer, iInfluencer, fDamage, (DMG_BLAST|DMG_BURN|DMG_SHOCK));
		}
		else
		{
			if(IsPlayer(iVictim))
			{
				set_msg_block(g_msg_death, BLOCK_SET);
				ExecuteHamB(Ham_TakeDamage, iVictim, iInfluencer, iInfluencer, fDamage,
				((fDamage / floatmax(fMaxDamage,1.0)) >= 0.75) ? (DMG_BLAST|DMG_BURN|DMG_SHOCK|DMG_ALWAYSGIB) : (DMG_BLAST|DMG_BURN|DMG_SHOCK));
				set_msg_block(g_msg_death, iOldDeathMsgValue);

				if(get_user_health(iVictim) <= 0)
				{
					deathmsg_player_bazooka_killed(iVictim, iInfluencer);
				}
			}
			else
			{
				ExecuteHamB(Ham_TakeDamage, iVictim, iInfluencer, iInfluencer, fDamage, (DMG_BLAST|DMG_BURN|DMG_SHOCK));
			}
		}
	}
}

drop_rpg_temp(id) 
{
	new Float:fEnd[3] , Float:fOrigin[3];
	pev(id , pev_origin , fOrigin);
	pev(id, pev_view_ofs, fEnd);
	xs_vec_add(fOrigin, fEnd, fOrigin);
	velocity_by_aim(id , 60 , fEnd);
	
	fEnd[0] += fOrigin[0];
	fEnd[1] += fOrigin[1];
	fEnd[2] = fOrigin[2];
	
	new tr2 = create_tr2();
	engfunc(EngFunc_TraceLine, fOrigin, fEnd, IGNORE_MISSILE|IGNORE_MONSTERS, id, tr2);
	get_tr2(tr2, TR_vecEndPos, fEnd);
	free_tr2(tr2);
	
	new rpg = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	
	if(!rpg) return;
	
	set_pev(rpg, pev_classname, "rpg_temp");
	set_pev(rpg, pev_target, "rpg_temp");
	engfunc(EngFunc_SetModel, rpg, mrpg_w);
 	engfunc(EngFunc_SetOrigin, rpg, fEnd);

	set_pev(rpg, pev_movetype, MOVETYPE_TOSS);
	set_pev(rpg, pev_solid , SOLID_TRIGGER);
	engfunc(EngFunc_SetSize, rpg, { -16.0, -16.0, -16.0 }, { 16.0, 16.0, 16.0 } );

	set_pev(rpg , PEV_RPG_AMMO, g_BazookaAmmo[id])
	set_pev(rpg, pev_groupinfo, pev(id, pev_groupinfo));
	
	remove_bazooka(id);
}

deathmsg_player_bazooka_killed(victim, killer)
{
	if(!is_user_connected(killer)) killer = victim;

	static kname[32], vname[32], kauthid[32], vauthid[32], kteam[10], vteam[10];

	get_user_name(killer, kname, 31);
	get_user_team(killer, kteam, 9);
	get_user_authid(killer, kauthid, 31);

	get_user_name(victim, vname, 31);
	get_user_team(victim, vteam, 9);
	get_user_authid(victim, vauthid, 31);

	log_message("^"%s<%d><%s><%s>^" killed ^"%s<%d><%s><%s>^" with ^"%s^"",
		kname, get_user_userid(killer), kauthid, kteam,
		vname, get_user_userid(victim), vauthid, vteam, "Bazooka");

	emessage_begin(MSG_ALL, g_msg_death, {0,0,0}, 0);
	ewrite_byte(killer);
	ewrite_byte(victim);
	ewrite_byte(true);
	ewrite_string("Bazooka");
	emessage_end();
}

public fw_player_killed_post(victim, killer, gib)
{
	if(check_flag(g_hasbazooka,victim))
	{
		if(jb_get_current_day() == DAY_NONE)
		{
			drop_rpg_temp(victim);
		}

		remove_bazooka(victim);
	}
}

follow_nearby_target(ent)
{
		static Float:fTargetOrigin[3], Float:fRocketOrigin[3], Float:shortest_distance, id_owner,
		iLock_OnTarget, iTarget, iTeam, Float:distance, bool:bFriendlyfire, iGroup, targetMoveType;
		id_owner = pev(ent, PEV_ROCKET_OWNER);
		pev(ent, pev_origin, fRocketOrigin);
		shortest_distance = get_pcvar_float(pcvar_homingradius);
		bFriendlyfire = get_pcvar_num(pcvar_ff) ? true:false;
		iLock_OnTarget = iTarget = 0;
		iTeam = get_user_team(id_owner);
		iGroup = pev(id_owner, pev_groupinfo);

		while( (iTarget=find_ent_in_sphere(iTarget, fRocketOrigin, shortest_distance)) > 0 )
		{
			if(iTarget == ent ||
				iTarget == id_owner ||
				pev(iTarget, pev_solid) == SOLID_NOT ||
				((targetMoveType=pev(iTarget, pev_movetype)) != MOVETYPE_WALK &&
				targetMoveType != MOVETYPE_STEP && targetMoveType != MOVETYPE_PUSHSTEP) ||
				(iGroup != 0 && !(pev(iTarget, pev_groupinfo) & iGroup)) || // prevents the rocket from targeting an unseen object/entity
				entity_take_damage(iTarget) == DAMAGE_NO ||
				(!bFriendlyfire && iTeam == ( IsPlayer(iTarget) ? get_user_team(iTarget) : pev(iTarget, pev_team) ) )) continue;
			
			pev(iTarget, pev_origin, fTargetOrigin);

			// target is unreachable due some wall or entity intersecting in the middle
			if(iTarget != trace_line(ent, fRocketOrigin, fTargetOrigin, fTargetOrigin))
			{
				continue;
			}

			distance = get_distance_f(fTargetOrigin, fRocketOrigin);
			
			if(distance < shortest_distance)
			{
				shortest_distance = distance;
				iLock_OnTarget = iTarget;
			}
		}
		
		if(pev_valid(iLock_OnTarget))
		{
			entity_set_follow(ent, iLock_OnTarget, get_pcvar_float(pcvar_speed_homing))
		}
}
 
entity_set_follow(entity, target, Float:speed, const Float:XTarget_origin[3]={0.0,0.0,0.0})
{
	static Float:entity_origin[3], Float:target_origin[3]
	pev(entity, pev_origin, entity_origin)
	if(target > 0)
	{
		pev(target, pev_origin, target_origin);
	}
	else
	{
		xs_vec_copy(XTarget_origin, target_origin);
	}

	static Float:diff[3], Float:length;
	diff[0] = target_origin[0] - entity_origin[0]
	diff[1] = target_origin[1] - entity_origin[1]
	diff[2] = target_origin[2] - entity_origin[2]
 
	length = floatsqroot(floatpower(diff[0], 2.0) + floatpower(diff[1], 2.0) + floatpower(diff[2], 2.0))
	if(length == 0.0) length = 1.0;
       	static Float:velocity[3]
	velocity[0] = diff[0] * (speed / length);
	velocity[1] = diff[1] * (speed / length);
	velocity[2] = diff[2] * (speed / length);
	
	static Float:EntityAngles[3];
	static Float:Direction[3];
	
	xs_vec_sub(target_origin, entity_origin, Direction);
	xs_vec_normalize(Direction, Direction);
	
	vector_to_angle(Direction, EntityAngles);
	set_pev(entity, pev_angles, EntityAngles);
	set_pev(entity, pev_velocity, velocity)
}

public bazooka_reload(id)
{
	if(!is_user_connected(id) || get_user_weapon(id) != CSW_KNIFE || !check_flag(g_hasbazooka,id))
	{
		return;
	}
	
	playWeaponAnimation(id, 2)
}

playWeaponAnimation(id, iAnim)
{
	set_pev(id, pev_weaponanim, iAnim);
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id );
	write_byte(iAnim);
	write_byte(pev(id, pev_body));
	message_end();
}

public fw_bazooka_attack_post(ent)
{
	new id = get_pdata_cbase(ent, m_iWeaponOwner, WEAPON_LINUXDIFF);
	
	if(!check_flag(g_hasbazooka,id) || !CanShoot(id)) return;
        	
	if(g_BazookaAmmo[id] > 0)
	{
		fire_rocket(id); 
	}
	else
	{
		playWeaponAnimation(id, 0);
		client_print(id, print_center, "You have no rockets ammo!")
	}
}

public fw_bazooka_mode_post(ent)
{
	new id = get_pdata_cbase(ent,m_iWeaponOwner, WEAPON_LINUXDIFF);
	
	if(!check_flag(g_hasbazooka,id)) return 
	
	playWeaponAnimation(id, 0)
	
	if((get_gametime() - lastSwitchTime[id]) < SWITCH_TIME) return;
	
	emit_sound(id, CHAN_WEAPON, smodselect, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	switch(g_mode[id])
	{
		case 1:
		{
			g_mode[id] = 2;
			client_print(id, print_center, "Homing fire mode!")
		}
		case 2:
		{
			g_mode[id] = 3;
			client_print(id, print_center, "Camera fire mode!")
		}
		case 3:
		{
			g_mode[id] = 4;
			client_print(id, print_center, "Aiming target mode!")
		}
		default:
		{
			g_mode[id] = 1;
			client_print(id, print_center, "Normal fire mode!")
		}
	}
	
	lastSwitchTime[id] = get_gametime();
}

launch_push(id, velamount)
{
	static Float:flNewVelocity[3], Float:flCurrentVelocity[3]
	
	velocity_by_aim(id, -velamount, flNewVelocity)
	
	get_user_velocity(id, flCurrentVelocity)
	xs_vec_add(flNewVelocity, flCurrentVelocity, flNewVelocity)
	
	set_user_velocity(id, flNewVelocity)
}

public task_retrieve_ladder(ent)
{
	set_pev(ent, pev_origin, Float:{ 0.0, 0.0, 0.0});
}

entity_explosion_knockback(victim, Float:fExpOrigin[3], Float:fExpShockwaveRadius=500.0, Float:fExpShockwavePower=500.0)
{
	new Float:fOrigin[3], Float:fDistVec[3];
	if(pev(victim, pev_solid) == SOLID_BSP)
	{
		get_brush_entity_origin(victim, fOrigin);
	}
	else
	{
		pev(victim, pev_origin, fOrigin);
	}

	xs_vec_sub(fOrigin, fExpOrigin, fDistVec);

	new Float:fTemp;
	// victim is in the range of the shockwave explosion!
	if((fTemp=xs_vec_len(fDistVec)) <= fExpShockwaveRadius)
	{
		new Float:fPower = fExpShockwavePower * ( 1.0 - ( fTemp / floatmax(fExpShockwaveRadius, 1.0) ) ), Float:fVelo[3], Float:fKnockBackVelo[3];
		if(fTemp == 0.0)
		{
			xs_vec_set(fDistVec, random_float(-1.0,1.0), random_float(-1.0,1.0), 1.0);
		}

		pev(victim, pev_velocity, fVelo);
		xs_vec_normalize(fDistVec, fKnockBackVelo);
		xs_vec_mul_scalar(fKnockBackVelo, fPower, fKnockBackVelo);
		xs_vec_add(fVelo, fKnockBackVelo, fVelo);
		set_pev(victim, pev_velocity, fVelo);
	}
}

Progress_status( const id, const duration )
{
	message_begin(MSG_ONE, g_msgBarTime, _, id);
	write_short(duration);
	message_end();
}

CanShoot(id)
{
	return ((get_gametime() - g_flLastShoot[id]) >= get_pcvar_float(pcvar_delay))
}

Float:entity_take_damage(target)
{
	static Float:flTakeDamage;
	pev(target, pev_takedamage, flTakeDamage);
	return flTakeDamage;
}
