/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <hamsandwich>
#include <fakemeta>
#include <xs>
#include <jailbreak_core>

#define PLUGIN "[JB] Suicide-Bomb"
#define AUTHOR "Natsheh"

#define TASK_SUICIDING	7678

#define PEV_TYPE pev_iuser4
#define PEV_OWNER pev_iuser3

#define SUICIDE_BOMB_FRICTION 0.90
#define SUICIDE_BOMB_BOUNCE_FRICTION 0.5

#if !defined IsPlayer
#define IsPlayer(%1) (1 <= %1 <= g_iMaxplayers)
#endif

enum (+=1)
{
	TYPE_SUICIDE_BOMB = 50,
	TYPE_SATCHEL_RADIO
}

const m_pPlayer = 41;

new const satchel_classname[] = "suicidebomb_satchel";
new const suicidebomb_classname[] = "suicidebomb";
new const cs_weapon_classname[] = "weapon_hegrenade";

new SUICIDE_SOUND[64] = "jailbreak/jihad.wav";
new SUICIDE_SOUND_EXPLOSION[64] = "weapons/c4_explode1.wav";
new W_SUICIDE_BOMB_MDL[64] = "models/w_backpack.mdl";
new V_SUICIDE_BOMB_MDL[64] = "models/v_c4.mdl";
new P_SUICIDE_BOMB_MDL[64] = "models/p_c4.mdl";
new V_SATCHEL_RADIO[64] = "models/v_satchel_radio.mdl";
new P_SATCHEL_RADIO[64] = "models/p_satchel_radio.mdl";

new g_has_suicide_bomb, g_has_satchel_radio, g_user_alive;
new g_pcvr_one, g_pcvr_two, g_pcvr_three, g_cvar_glow_bomb, cvar_throw_force;
new g_item, explosion, g_iMaxplayers;

public plugin_precache()
{
	new BOMB_EXP_SPR[64] = "sprites/fexplo.spr";
	jb_ini_get_keyvalue("SUICIDE_BOMB", "BOMB_EXP_SPR", BOMB_EXP_SPR, charsmax(BOMB_EXP_SPR));
	explosion = PRECACHE_SPRITE_I(BOMB_EXP_SPR);
	
	jb_ini_get_keyvalue("SUICIDE_BOMB", "SUICIDE_SND", SUICIDE_SOUND, charsmax(SUICIDE_SOUND));
	jb_ini_get_keyvalue("SUICIDE_BOMB", "BOMB_EXP_SND", SUICIDE_SOUND_EXPLOSION, charsmax(SUICIDE_SOUND_EXPLOSION));
	PRECACHE_SOUND(SUICIDE_SOUND);
	PRECACHE_SOUND(SUICIDE_SOUND_EXPLOSION);
	
	jb_ini_get_keyvalue("SUICIDE_BOMB", "SUICIDE_BOMB_W_MDL", W_SUICIDE_BOMB_MDL, charsmax(W_SUICIDE_BOMB_MDL));
	PRECACHE_WEAPON_WORLD_MODEL(W_SUICIDE_BOMB_MDL);
	
	jb_ini_get_keyvalue("SUICIDE_BOMB", "SUICIDE_BOMB_V_MDL", V_SUICIDE_BOMB_MDL, charsmax(V_SUICIDE_BOMB_MDL));
	PRECACHE_WEAPON_VIEW_MODEL(V_SUICIDE_BOMB_MDL);
	
	jb_ini_get_keyvalue("SUICIDE_BOMB", "SUICIDE_BOMB_P_MDL", P_SUICIDE_BOMB_MDL, charsmax(P_SUICIDE_BOMB_MDL));
	PRECACHE_WEAPON_PLAYER_MODEL(P_SUICIDE_BOMB_MDL);
	
	jb_ini_get_keyvalue("SUICIDE_BOMB", "SATCHEL_RADIO_V_MDL", V_SATCHEL_RADIO, charsmax(V_SATCHEL_RADIO));
	PRECACHE_WEAPON_VIEW_MODEL(V_SATCHEL_RADIO);
	
	jb_ini_get_keyvalue("SUICIDE_BOMB", "SATCHEL_RADIO_P_MDL", P_SATCHEL_RADIO, charsmax(P_SATCHEL_RADIO));
	PRECACHE_WEAPON_PLAYER_MODEL(P_SATCHEL_RADIO);
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	g_pcvr_one = register_cvar("jb_suicide_bomb_radius", "500")
	g_pcvr_two = register_cvar("jb_suicide_bomb_maxdmg", "250")
	g_pcvr_three = register_cvar("jb_suicide_bomb_ff", "1")
	g_cvar_glow_bomb = register_cvar("jb_suicide_bomb_glow", "1");
	cvar_throw_force = register_cvar("jb_suicide_throw_force", "300");
	
	g_item = register_jailbreak_shopitem("Suicide Bomb", "Deadly Explosion!", 12000, TEAM_PRISONERS)
	
	register_concmd("jb_give_suicidebomb", "concmd_give_suicidebomb", ADMIN_IMMUNITY, "gives a suicide bomb to a player")
	
	RegisterHam(Ham_Weapon_PrimaryAttack,  cs_weapon_classname, "fw_c4_primary_attack_pre")
	RegisterHam(Ham_Weapon_SecondaryAttack, cs_weapon_classname, "fw_c4_secondary_attack_pre")
	register_event("DeathMsg", "fw_deathmsg", "a")
	
	register_clcmd("drop", "clcmd_drop")
	
	RegisterHam(Ham_Touch, cs_weapon_classname, "fw_bomb_touch_pre")
	RegisterHam(Ham_Spawn, "player", "Ham_Respawn_post", 1)
	RegisterHam(Ham_Item_Deploy, cs_weapon_classname, "fw_item_deploy_post_c4", 1)
	
	g_iMaxplayers = get_maxplayers();
}

public fw_item_deploy_post_c4(const ent)
{
    new id = get_pdata_cbase(ent, m_pPlayer, 4);

    switch( pev(ent, PEV_TYPE) ) {
        case TYPE_SATCHEL_RADIO:
        {
            set_pev(id, pev_viewmodel2, V_SATCHEL_RADIO);
            set_pev(id, pev_weaponmodel2, P_SATCHEL_RADIO);
        }
        case TYPE_SUICIDE_BOMB:
        {
            set_pev(id, pev_viewmodel2, V_SUICIDE_BOMB_MDL);
            set_pev(id, pev_weaponmodel2, P_SUICIDE_BOMB_MDL);
        }
    }
}

public Ham_Respawn_post(id)
{
	if(!is_user_alive(id)) return;
	remove_flag(g_has_suicide_bomb,id);
	set_flag(g_user_alive,id);
}

public fw_bomb_touch_pre(const wEnt, const player)
{
	if(!pev_valid(wEnt)) return HAM_IGNORED;
	
	static sClname[32];
	pev(wEnt, pev_targetname, sClname, charsmax(sClname))
	
	if((equal(sClname, suicidebomb_classname) || equal(sClname, satchel_classname)))
	{
		static Float:fVelo[3]
		pev(wEnt, pev_velocity, fVelo);
		if(!(1 <= player <= g_iMaxplayers) || !check_flag(g_user_alive,player))
		{
			xs_vec_mul_scalar(fVelo, SUICIDE_BOMB_FRICTION, fVelo);
			fVelo[2] *= SUICIDE_BOMB_BOUNCE_FRICTION;
			set_pev(wEnt, pev_velocity, fVelo);
			return HAM_IGNORED;
		}
		
		if(check_flag(g_has_suicide_bomb,player)) return HAM_IGNORED;
		
		if(equal(sClname, satchel_classname))
		{
			if(pev(wEnt, PEV_OWNER) != player)
			{
				return HAM_IGNORED;
			}
		}
		
		if(!(pev(wEnt, pev_flags) & FL_ONGROUND) || xs_vec_len(fVelo) > 0.0) return HAM_IGNORED;
		
		set_pev(wEnt, pev_flags, FL_KILLME);
		
		give_suicidebomb(player);
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}

public clcmd_drop(id)
{
	if(get_user_weapon(id) == get_weaponid(cs_weapon_classname))
	{
		new ent = -1;
		while( (ent = engfunc(EngFunc_FindEntityByString, ent, "classname", cs_weapon_classname)) > 0 && pev(ent, pev_owner) != id ) { }
		
		if(!ent) return 0;
		
		switch( pev(ent, PEV_TYPE) )
		{
			case TYPE_SUICIDE_BOMB:
			{
				remove_flag(g_has_suicide_bomb,id);
				ham_strip_weapon(id, cs_weapon_classname);
				drop_suicidebomb(id)
			}
			case TYPE_SATCHEL_RADIO:
			{
				if(check_flag(g_has_suicide_bomb,id))
				{
					drop_satchel(id,ent);
				}
			}
		}
		
		return 1;
	}
	return 0;
}

drop_suicidebomb(const id)
{
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, cs_weapon_classname));
	
	if(!ent) return;
	
	new Float:FVelo[3], Float:fOrigin[3], Float:PlayerVelo[3];
	pev(id, pev_origin, fOrigin);
	pev(id, pev_view_ofs, FVelo);
	fOrigin[0] += FVelo[0];
	fOrigin[1] += FVelo[1];
	fOrigin[2] += FVelo[2];
	velocity_by_aim(id, get_pcvar_num(cvar_throw_force), FVelo)
	pev(id, pev_velocity, PlayerVelo);
	xs_vec_add(FVelo, PlayerVelo, FVelo);
	set_pev(ent, pev_velocity, FVelo);
	engfunc(EngFunc_SetOrigin, ent, fOrigin);
	engfunc(EngFunc_SetModel, ent, W_SUICIDE_BOMB_MDL);
	
	set_pev(ent, pev_targetname, suicidebomb_classname);
	set_pev(ent, pev_origin, fOrigin);
	set_pev(ent, pev_movetype,MOVETYPE_TOSS);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	engfunc(EngFunc_SetSize, ent, {-0.3, -0.3, -5.5}, {0.3, 0.3, 0.5});
	//engfunc(EngFunc_DropToFloor, ent)
	
	if(get_pcvar_num(g_cvar_glow_bomb))
	{
		set_pev(ent, pev_renderfx, kRenderFxGlowShell)
		set_pev(ent, pev_rendermode, kRenderNormal)
		set_pev(ent, pev_rendercolor, { 220.0, 0.0, 0.0 })
		set_pev(ent, pev_renderamt, 50)
	}
}

public client_putinserver(id)
{
	remove_flag(g_has_suicide_bomb,id);
	remove_flag(g_has_satchel_radio,id);
}

#if AMXX_VERSION_NUM < 183
public client_disconnect(id)
#else
public client_disconnected(id)
#endif
{
	remove_flag(g_has_suicide_bomb,id);
	remove_flag(g_has_satchel_radio,id);
	remove_flag(g_user_alive,id);
}

public jb_round_start()
{
	new ent;

	while( (ent = engfunc(EngFunc_FindEntityByString, ent, "targetname", suicidebomb_classname)) > 0 )
	{
		set_pev(ent, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, ent);
	}

	if(g_has_satchel_radio)
	{
		while( (ent = engfunc(EngFunc_FindEntityByString, ent, "targetname", satchel_classname)) > 0 )
		{
			set_pev(ent, pev_flags, FL_KILLME);
			dllfunc(DLLFunc_Think, ent);
		}
	}

	g_has_suicide_bomb = 0;
	g_has_satchel_radio = 0;
}

public fw_deathmsg()
{
	new vic = read_data(2);
	
	remove_flag(g_has_suicide_bomb,vic);
	remove_flag(g_has_satchel_radio,vic);
	remove_flag(g_user_alive,vic);
}

give_suicidebomb(id)
{
	set_flag(g_has_suicide_bomb,id);
	
	new ent;
	if((ent=give_item(id, cs_weapon_classname)) > 0)
	{
		client_cmd(id, cs_weapon_classname);
		set_pev(ent, PEV_TYPE, TYPE_SUICIDE_BOMB);
		ExecuteHamB(Ham_Item_Deploy, ent);
	}
	else
	{
		ent = -1;
		while( (ent = engfunc(EngFunc_FindEntityByString, ent, "classname", cs_weapon_classname)) > 0 && pev(ent, pev_owner) != id ) { }
		if(ent > 0)
		{
			client_cmd(id, cs_weapon_classname);
			set_pev(ent, PEV_TYPE, TYPE_SUICIDE_BOMB);
			ExecuteHamB(Ham_Item_Deploy, ent)
		}
	}
	
	cprint_chat(id, _, "press '+attack' button to activate the ^4suicide-bomb^3!")
	cprint_chat(id, _, "press '+attack2' button to drop a ^4satchel-bomb^3!")
}

public concmd_give_suicidebomb(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	
	new sTarget[32];
	read_argv(1, sTarget, 31);
	
	if(sTarget[0] == '@')
	{
		new players[32], pnum;
		switch( sTarget[1] )
		{
			case 'C', 'c': get_players(players, pnum, "ae", "CT");
			case 'T', 't': get_players(players, pnum, "ae", "TERRORIST");
			default: get_players(players, pnum, "a");
		}
		
		for(new i = 0, player; i < pnum; i++)
		{
			player = players[i];
			if(check_flag(g_has_suicide_bomb,player)) continue;
			give_suicidebomb(player);
		}
		
		console_print(id, "You have given %c%c Suicide Bombs", sTarget[0], sTarget[1])
		return PLUGIN_HANDLED;
	}
	
	new target = cmd_target(id, sTarget, CMDTARGET_ALLOW_SELF|CMDTARGET_ONLY_ALIVE)
	if(!target) return PLUGIN_HANDLED;
	
	get_user_name(target, sTarget, 31)
	
	if(check_flag(g_has_suicide_bomb,target))
	{
		console_print(id, "user %s has already a suicide bomb!", sTarget)
		return PLUGIN_HANDLED;
	}
	
	give_suicidebomb(target);
	cprint_chat(id, _, "you gave ^3%s ^1a ^4suicide bomb!", sTarget)
	console_print(id, "You gave %s a Suicide Bomb!", sTarget)
	
	return PLUGIN_HANDLED;
}

public fw_c4_primary_attack_pre(wEnt)
{
	if(!pev_valid(wEnt)) return HAM_IGNORED;
	
	new id = get_pdata_cbase(wEnt, m_pPlayer, 4);
	
	if(!check_flag(g_has_suicide_bomb,id) && !check_flag(g_has_satchel_radio,id)) return HAM_IGNORED;
	
	switch( pev(wEnt, PEV_TYPE) )
	{
		case TYPE_SUICIDE_BOMB:
		{
			if(task_exists(id+TASK_SUICIDING)) return HAM_SUPERCEDE;
			
			activate_bomb(id);
			return HAM_SUPERCEDE;
		}
		case TYPE_SATCHEL_RADIO:
		{
			if(task_exists(id+TASK_SUICIDING)) return HAM_SUPERCEDE;
			
			radio_transmit_trigger(id);
			return HAM_SUPERCEDE;
		}
	}
	return HAM_IGNORED;
}

public fw_c4_secondary_attack_pre(wEnt)
{
	if(!pev_valid(wEnt)) return HAM_IGNORED;
	
	new id = get_pdata_cbase(wEnt, m_pPlayer, 4);
	
	if(!check_flag(g_has_suicide_bomb,id)) return HAM_IGNORED;
	
	if(task_exists(id+TASK_SUICIDING)) return HAM_SUPERCEDE;
	
	drop_satchel(id,wEnt);
	return HAM_SUPERCEDE;
}

radio_transmit_trigger(id)
{
	if(!check_flag(g_has_satchel_radio,id)) return;
	ham_strip_weapon(id, cs_weapon_classname);
	
	new ent = -1, ent2, Float:fOrigin[3], Float:cvar_one_value = get_pcvar_float(g_pcvr_one), Float:cvar_two_value = get_pcvar_float(g_pcvr_two);
	while( (ent = engfunc(EngFunc_FindEntityByString, ent, "targetname", satchel_classname)) > 0 )
	{
		if(pev(ent, PEV_OWNER) == id)
		{
			pev(ent, pev_origin, fOrigin);
			bomb_explosion(id, fOrigin, cvar_one_value, cvar_two_value);
			
			ent2 = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
			if(ent2 > 0)
			{
				engfunc(EngFunc_SetOrigin, ent2, fOrigin);
				emit_sound(ent2, CHAN_AUTO, SUICIDE_SOUND_EXPLOSION, VOL_NORM, ATTN_NORM, 0, PITCH_HIGH)
				set_pev(ent2, pev_nextthink, get_gametime() + 10.0);
				set_pev(ent2, pev_flags, FL_KILLME);
			}
			
			set_pev(ent, pev_flags, FL_KILLME);
		}
	}
	
	remove_flag(g_has_satchel_radio,id);
}

drop_satchel(id,ent)
{
	remove_flag(g_has_suicide_bomb,id);
	set_flag(g_has_satchel_radio,id);
	
	set_pev(ent, PEV_TYPE, TYPE_SATCHEL_RADIO);
	ExecuteHamB(Ham_Item_Deploy, ent);
	
	new package = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, cs_weapon_classname));
	
	if(package > 0)
	{
		new Float:FVelo[3], Float:fOrigin[3], Float:PlayerVelo[3];
		pev(id, pev_origin, fOrigin);
		pev(id, pev_view_ofs, FVelo);
		fOrigin[0] += FVelo[0];
		fOrigin[1] += FVelo[1];
		fOrigin[2] += FVelo[2];
		velocity_by_aim(id, get_pcvar_num(cvar_throw_force), FVelo)
		pev(id, pev_velocity, PlayerVelo);
		xs_vec_add(FVelo, PlayerVelo, FVelo);
		set_pev(package, pev_velocity, FVelo);
		engfunc(EngFunc_SetOrigin, package, fOrigin);
		engfunc(EngFunc_SetModel, package, W_SUICIDE_BOMB_MDL);
		
		set_pev(package, pev_targetname, satchel_classname);
		set_pev(package, pev_movetype,MOVETYPE_BOUNCE);
		set_pev(package, pev_solid, SOLID_TRIGGER);
		engfunc(EngFunc_SetSize, package, {-0.3, -0.3, -5.5}, {0.3, 0.3, 0.5});

		set_pev(package, PEV_OWNER, id);
		//engfunc(EngFunc_DropToFloor, package);
	}
}

activate_bomb(id)
{
	emit_sound(id, CHAN_AUTO, SUICIDE_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_HIGH);
	set_task(2.0, "task_explosion", id+TASK_SUICIDING);
}

public task_explosion(taskid)
{
	new id = taskid - TASK_SUICIDING;
	if(!check_flag(g_user_alive,id) || get_user_weapon(id) != get_weaponid(cs_weapon_classname))
	{
		remove_task(taskid);
		return;
	}
	
	new Float:fOrigin[3];
	pev(id, pev_origin, fOrigin);
	emit_sound(id, CHAN_AUTO, SUICIDE_SOUND_EXPLOSION, VOL_NORM, ATTN_NORM, 0, PITCH_HIGH);
	remove_flag(g_has_suicide_bomb,id);
	ham_strip_weapon(id, cs_weapon_classname);
	bomb_explosion(id, fOrigin, get_pcvar_float(g_pcvr_one), get_pcvar_float(g_pcvr_two));
	
	remove_task(taskid);
}

public jb_shop_item_preselect(id, itemid)
{
	if(itemid == g_item)
	{
		if(check_flag(g_has_suicide_bomb,id))
		{
			return JB_MENU_ITEM_DONT_SHOW;
		}
	}
	return PLUGIN_CONTINUE;
}

public jb_shop_item_postselect(id, itemid)
{
	if(itemid == g_item)
	{
		if(check_flag(g_has_suicide_bomb,id)) return JB_MENU_ITEM_UNAVAILABLE;
	}
	return PLUGIN_CONTINUE;
}

public jb_shop_item_bought(id, itemid)
{
	if(itemid == g_item)
	{
		give_suicidebomb(id);
		cprint_chat(id, _, "press '+attack' button to activate the ^4suicide-bomb^3!")
	}
}

stock ham_strip_weapon(id, const weapon[])
{
	if(!equal(weapon,"weapon_",7)) return 0;
	new wId = get_weaponid(weapon);
	if(!wId) return 0;
	new wEnt = -1
	while((wEnt = engfunc(EngFunc_FindEntityByString, wEnt, "classname", weapon)) > 0 && pev(wEnt, pev_owner) != id) {}
	if(!wEnt) return 0;
	if(get_user_weapon(id) == wId) ExecuteHamB(Ham_Weapon_RetireWeapon,wEnt);
	if(!ExecuteHamB(Ham_RemovePlayerItem,id,wEnt)) return 0;
	ExecuteHamB(Ham_Item_Kill, wEnt);
	set_pev(id, pev_weapons, pev(id,pev_weapons) & ~(1<<wId));
	return 1;
}

bomb_explosion(id, const Float:fOrigin[3], Float:Radius,  const Float:Maxdmg) 
{
	if(Radius <= 0.0) Radius = 1.0;
	new Float:fOrigin2[3];
	
	new bool:ff_dmg = get_pcvar_num(g_pcvr_three) > 0 ? true:false, uteam = get_user_team(id), Float:flTakeDamage;
	
	new iEnt=-1, Float:distance, dmg;
	while((iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, Radius)) > 0)
	{
		if(IsPlayer(iEnt))
		{
			if(!check_flag(g_user_alive,iEnt)) continue;

			if(id != iEnt && !ff_dmg && uteam == get_user_team(iEnt)) continue;
		}

		pev(iEnt, pev_takedamage, flTakeDamage);

		if(flTakeDamage == DAMAGE_NO)
		{
			continue;
		}
		
		if(pev(iEnt, pev_solid) == SOLID_BSP)
			get_brush_entity_origin(iEnt, fOrigin2);
		else
			pev(iEnt, pev_origin, fOrigin2);


		distance = get_distance_f(fOrigin, fOrigin2);
		dmg = floatround(floatsub(Maxdmg,(floatdiv(distance,Radius) * Maxdmg)));
		if(dmg <= 0) continue;
		
		ExecuteHamB(Ham_TakeDamage, iEnt, id, id, float(dmg), DMG_BLAST|DMG_ALWAYSGIB);
	}
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_SPRITE);
	engfunc(EngFunc_WriteCoord, fOrigin[0]);
	engfunc(EngFunc_WriteCoord, fOrigin[1]);
	engfunc(EngFunc_WriteCoord, fOrigin[2] + 80);
	write_short(explosion);
	write_byte(60);
	write_byte(255);
	message_end();
}

get_brush_entity_origin(ent, Float:orig[3])
{
	new Float:Min[3], Float:Max[3];

	pev(ent, pev_origin, orig);
	pev(ent, pev_mins, Min);
	pev(ent, pev_maxs, Max);

	orig[0] += (Min[0] + Max[0]) * 0.5;
	orig[1] += (Min[1] + Max[1]) * 0.5;
	orig[2] += (Min[2] + Max[2]) * 0.5;

	return 1;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang11265\\ f0\\ fs16 \n\\ par }
*/
