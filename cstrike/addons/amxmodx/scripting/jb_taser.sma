/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <jailbreak_core>
#include <screenfade_util>
#include <fun>

#define TASK_PARALYZED 98765343

new ITEM_ID, CLASS_ID;
new const ITEM_NAME[] = "Taser";
new const ITEM_INFO[] = "Electrocution Shock!";
new const ITEM_COST = 6000;
new const ITEM_TEAM = TEAM_GUARDS;

new g_user_has_taser, g_disallow_taser_drop, g_user_paralyzed, g_user_alive, g_fUser_angles[33][3];

new V_TASER_MDL[64] = "models/jailbreak/v_taser.mdl";
new P_TASER_MDL[64] = "models/jailbreak/p_taser.mdl";
new W_TASER_MDL[64] = "models/jailbreak/w_taser.mdl";

// knife sounds
new const knife_sounds[][] = {
	"weapons/knife_deploy1.wav",
	"weapons/knife_hit1.wav",
	"weapons/knife_hit2.wav",
	"weapons/knife_hit3.wav",
	"weapons/knife_hit4.wav",
	"weapons/knife_hitwall1.wav",
	"weapons/knife_slash1.wav",
	"weapons/knife_slash2.wav",
	"weapons/knife_stab.wav"
}

new const taser_sounds_keys[][] = {
	"TASER_DEPLOY_SND",
	"TASER_HIT1_SND",
	"TASER_HIT2_SND",
	"TASER_HIT3_SND",
	"TASER_HIT4_SND",
	"TASER_HITWALL1_SND",
	"TASER_SLASH1_SND",
	"TASER_SLASH2_SND",
	"TASER_STAB_SND"
}

new taser_sounds[][64] = {
	"jailbreak/taser_deploy1.wav",
	"jailbreak/taser_hit1.wav",
	"jailbreak/taser_hit2.wav",
	"jailbreak/taser_hit3.wav",
	"jailbreak/taser_hit4.wav",
	"jailbreak/taser_hitwall1.wav",
	"jailbreak/taser_slash1.wav",
	"jailbreak/taser_slash2.wav",
	"jailbreak/taser_stab.wav"
}

new const classname[] = "Security Guard";
new const classmodel[] = "security_guard";
new const classprimarywpns[] = "usp,glock18,deagle,p228,fiveseven";
new const classsecwpns[] = "flashbang,smokegrenade";
new const classvknifemdl[] = "models/jailbreak/v_taser.mdl";
new const classpknifemdl[] = "models/jailbreak/p_taser.mdl";
new const classknifesounds[] = "jailbreak/taser";
new const classteam = TEAM_GUARDS;
new const classflag = ADMIN_ALL;


stock const XO_CBASEPLAYERWEAPON = 4;
stock const m_pPlayer = 41;
stock const m_flNextPrimaryAttack = 46;
stock const m_flNextSecondaryAttack = 47;

public plugin_precache()
{
	for(new i; i < sizeof taser_sounds_keys; i++)
	{
		jb_ini_get_keyvalue("TASER", taser_sounds_keys[i], taser_sounds[i], charsmax(taser_sounds[]));
		PRECACHE_SOUND(taser_sounds[i]);
	}
	
	jb_ini_get_keyvalue("TASER", "TASER_V_MDL", V_TASER_MDL, charsmax(V_TASER_MDL));
	PRECACHE_WEAPON_VIEW_MODEL(V_TASER_MDL);
	
	jb_ini_get_keyvalue("TASER", "TASER_P_MDL", P_TASER_MDL, charsmax(P_TASER_MDL));
	PRECACHE_WEAPON_PLAYER_MODEL(P_TASER_MDL);
	
	jb_ini_get_keyvalue("TASER", "TASER_W_MDL", W_TASER_MDL, charsmax(W_TASER_MDL));
	PRECACHE_WEAPON_WORLD_MODEL(W_TASER_MDL);
}

public jb_class_creation()
{
	CLASS_ID = register_jailbreak_class(classname, classmodel,classprimarywpns,classsecwpns,classflag,
	classteam, classvknifemdl,classpknifemdl,classknifesounds);
}

new HamHook:HamPlayerPreThink, HamHook:HamKnifeItemDeploy, HamHook:HamPlayerTakeDamage, HamHook:HamTouchInfoTarget;

new Float:TASER_MAX_DMG, Float:TASER_MIN_DMG, pcvar_taser_maxdmg, pcvar_taser_mindmg;

public plugin_init()
{
	register_plugin("[JB] PLUGIN:Taser", "v1.0", "Natsheh");
	
	ITEM_ID = register_jailbreak_shopitem(ITEM_NAME, ITEM_INFO, ITEM_COST, ITEM_TEAM, _, (1<<(DAY_NONE+1)));
	
	DisableHamForward( (HamTouchInfoTarget = RegisterHam(Ham_Touch, "info_target", "fw_touch_knife_pre")) );
	
	register_forward(FM_EmitSound, "fw_EmitSound_pre")
	RegisterHam(Ham_Spawn, "player", "fw_player_respawn_post", 1)
	
	DisableHamForward( (HamKnifeItemDeploy = RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_knife_deploy_post", 1)) );
	DisableHamForward( (HamPlayerTakeDamage = RegisterHam(Ham_TakeDamage, "player", "fw_player_takedmg_pre")) );
	DisableHamForward( (HamPlayerPreThink = RegisterHam(Ham_Player_PreThink, "player", "fw_player_prethink_post", 1)) );
	
	pcvar_taser_maxdmg = register_cvar("jb_taser_maxdamage", "30");
	pcvar_taser_mindmg = register_cvar("jb_taser_mindamage", "10");
	
	register_clcmd("drop", "clcmd_drop")
	register_event("DeathMsg", "eDeathMsg", "a");
}

public eDeathMsg()
{
	new vic = read_data(2);
	
	if(check_flag(g_user_paralyzed,vic))
	{
		new wpns[32];
		new amount = get_user_weapons_ent(vic, wpns);
		for(new i, went; i < amount; i++)
		{
			went = wpns[i];
			set_pdata_float(went, m_flNextPrimaryAttack, -1.0, XO_CBASEPLAYERWEAPON)
			set_pdata_float(went, m_flNextSecondaryAttack, -1.0, XO_CBASEPLAYERWEAPON)
		}
	}
	
	remove_flag(g_user_has_taser,vic);
	remove_flag(g_disallow_taser_drop,vic);
	remove_flag(g_user_paralyzed,vic);
	remove_flag(g_user_alive,vic);
	
	if(!g_user_has_taser)
	{
		DisableHamForward(HamKnifeItemDeploy);
		DisableHamForward(HamPlayerTakeDamage);
	}
	
	if(!g_user_paralyzed)
	{
		DisableHamForward(HamPlayerPreThink);
	}
}

public jb_lr_duel_ended()
{
	new players[32], pnum, id;
	get_players(players, pnum, "ah");
	
	while( pnum-- > 0 )
	{
		id = players[pnum];
		if(jb_get_user_classid(id) == CLASS_ID)
		{
			give_taser(id);
			set_flag(g_disallow_taser_drop,id);
		}
	}
}

public jb_day_ended()
{
	new players[32], pnum, id;
	get_players(players, pnum, "ah");
	
	while( pnum-- > 0 )
	{
		id = players[pnum];
		if(jb_get_user_classid(id) == CLASS_ID)
		{
			give_taser(id);
			set_flag(g_disallow_taser_drop,id);
		}
	}
}

public jb_day_start(iDayid)
{
	if( iDayid == JB_DAY_CAGEDAY || iDayid == JB_DAY_VOTEDAY ) return;
	
	if(g_user_has_taser > 0)
	{
		DisableHamForward(HamKnifeItemDeploy);
		DisableHamForward(HamPlayerTakeDamage);
	}
	
	if(g_user_paralyzed > 0)
	{
		DisableHamForward(HamPlayerPreThink);
	}
	
	g_user_has_taser = 0;
	g_disallow_taser_drop = 0;
	g_user_paralyzed = 0;
	
	DisableHamForward(HamTouchInfoTarget);
	
	new ent;
	while( (ent = find_ent_by_class(ent, "weapon_taser")) > 0)
	{
		set_pev(ent, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, ent);
	}
}

public jb_lr_duel_start()
{
	if(g_user_has_taser > 0)
	{
		DisableHamForward(HamKnifeItemDeploy);
		DisableHamForward(HamPlayerTakeDamage);
	}
	
	if(g_user_paralyzed > 0)
	{
		DisableHamForward(HamPlayerPreThink);
	}
	
	g_user_has_taser = 0;
	g_disallow_taser_drop = 0;
	g_user_paralyzed = 0;
	
	DisableHamForward(HamTouchInfoTarget);
	
	new ent;
	while( (ent = find_ent_by_class(ent, "weapon_taser")) > 0)
	{
		set_pev(ent, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, ent);
	}
}

public jb_round_end()
{
	if(g_user_has_taser > 0)
	{
		DisableHamForward(HamKnifeItemDeploy);
		DisableHamForward(HamPlayerTakeDamage);
	}
	
	if(g_user_paralyzed > 0)
	{
		DisableHamForward(HamPlayerPreThink);
	}
	
	g_user_has_taser = 0;
	g_disallow_taser_drop = 0;
	g_user_paralyzed = 0;
	
	DisableHamForward(HamTouchInfoTarget);
	
	new ent;
	while( (ent = find_ent_by_class(ent, "weapon_taser")) > 0)
	{
		set_pev(ent, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, ent);
	}
}

public jb_round_start()
{
	TASER_MAX_DMG = floatabs(get_pcvar_float(pcvar_taser_maxdmg));
	TASER_MIN_DMG = floatabs(get_pcvar_float(pcvar_taser_mindmg));
	
	TASER_MAX_DMG = floatmax(TASER_MAX_DMG, TASER_MIN_DMG + 1.0);
	TASER_MIN_DMG = floatclamp(TASER_MIN_DMG, 0.0, TASER_MAX_DMG - 1.0);
}

get_user_weapons_ent(index, wpns_index[32])
{
	new wpns_amount;
	get_user_weapons(index, wpns_index, wpns_amount);
	
	new sWpnname[32];
	for(new i, cswid, went; i < wpns_amount;i++)
	{
		cswid = wpns_index[i];
		get_weaponname(cswid, sWpnname, charsmax(sWpnname))

		if( (went = find_ent_by_owner(-1, sWpnname, index)) )
		{
			wpns_index[i] = went;
		}
		else
		{
			i--; wpns_amount--;
		}
	}
	
	return wpns_amount;
}

get_user_weapon_ent(index)
{
	new cswid = get_user_weapon(index);
	if(!cswid) return 0;
	new szWpnname[24];
	get_weaponname(cswid, szWpnname, charsmax(szWpnname))
	return find_ent_by_owner(-1, szWpnname, index);
}

public fw_player_prethink_post(const player)
{
	if(!check_flag(g_user_alive,player) || !check_flag(g_user_paralyzed,player)) return HAM_IGNORED;
	
	static iButton, iOldButtons, userwpn;
	iButton = pev(player, pev_button);
	iOldButtons = pev(player, pev_oldbuttons);
	
	if(iButton & IN_ATTACK && !(iOldButtons & IN_ATTACK))
	{
		userwpn = get_user_weapon_ent(player);
		if(userwpn > 0) set_pdata_float(userwpn, m_flNextPrimaryAttack, 9999.9, XO_CBASEPLAYERWEAPON)
	}
	if(iButton & IN_ATTACK2 && !(iOldButtons & IN_ATTACK2))
	{
		userwpn = get_user_weapon_ent(player);
		if(userwpn > 0) set_pdata_float(userwpn, m_flNextSecondaryAttack, 9999.9, XO_CBASEPLAYERWEAPON)
	}
	if(iButton & IN_FORWARD || iButton & IN_BACK || iButton & IN_RUN || iButton & IN_MOVELEFT || iButton & IN_MOVERIGHT || iButton & IN_JUMP)
	{
		static Float:fVelocity[3];
		pev(player, pev_velocity, fVelocity);
		fVelocity[0] = fVelocity[1] = 0.0;
		if(fVelocity[2] > 0.0) fVelocity[2] = 0.0;
		set_pev(player, pev_velocity, fVelocity);
		client_print(player, print_center, "you are paralyzed!");
	}
	
	set_pev(player, pev_v_angle, g_fUser_angles[player]);
	set_pev(player, pev_fixangle, 2);
	return HAM_IGNORED;
}

public fw_player_respawn_post(const id)
{
	if(!is_user_alive(id)) return;
	
	set_flag(g_user_alive,id);
	remove_flag(g_disallow_taser_drop,id);
	remove_flag(g_user_paralyzed,id)
	
	if(g_user_has_taser)
	{
		remove_flag(g_user_has_taser,id);
		
		if(!g_user_has_taser)
		{
			DisableHamForward(HamKnifeItemDeploy);
			DisableHamForward(HamPlayerTakeDamage);
		}
	}
	
	if(jb_get_current_day() == DAY_NONE)
	{
		if(jb_get_user_classid(id) == CLASS_ID)
		{
			give_taser(id);
			set_flag(g_disallow_taser_drop,id);
		}
	}
}

public fw_EmitSound_pre(id, const channel, const sample[])
{
	if(!(1 <= id <= 32) || !IsUserHoldingTaser(id)) return FMRES_IGNORED;
	
	for(new i = 0; i < sizeof knife_sounds; i++)
	{
		if(equal(sample, knife_sounds[i]))
		{
			emit_sound(id, channel, taser_sounds[i], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED;
}

public clcmd_drop(id)
{
	if(!check_flag(g_user_alive,id)) return 0;
	if(check_flag(g_user_paralyzed,id))
	{
		client_print(id, print_center, "you are paralyzed!");
		return 1;
	}
	if(IsUserHoldingTaser(id) && !check_flag(g_disallow_taser_drop,id))
	{
		remove_flag(g_user_has_taser,id);
		new wEnt = find_ent_by_owner(-1, "weapon_knife", id);
		if(wEnt > 0)
		{
			ExecuteHamB(Ham_Item_Deploy, wEnt);
			drop_taser(id);
			return 1;
		}
	}
	return 0;
}

public fw_touch_knife_pre(const ent, const id)
{
	if(!check_flag(g_user_alive,id) || check_flag(g_user_has_taser,id)) return HAM_IGNORED;
	
	static sWpnname[24];
	pev(ent, pev_classname, sWpnname, charsmax(sWpnname));
	
	if(equal(sWpnname, "weapon_taser"))
	{
		set_pev(ent, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, ent);

		give_taser(id);
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}

public fw_knife_deploy_post(const wEnt)
{
	new id = get_pdata_cbase(wEnt, m_pPlayer, XO_CBASEPLAYERWEAPON);
	if(!check_flag(g_user_has_taser,id)) return HAM_IGNORED;
	
	set_pev(id, pev_viewmodel2, V_TASER_MDL)
	set_pev(id, pev_weaponmodel2, P_TASER_MDL)
	
	return HAM_HANDLED;
}

drop_taser(id)
{
	if(!find_ent_by_class(-1, "weapon_taser")) EnableHamForward(HamTouchInfoTarget)
	
	new ent = create_entity("info_target");
	
	if(!ent) return;
	
	new Float:fAim[3] , Float:fOrigin[3];
	velocity_by_aim(id , 64 , fAim);
	pev(id , pev_origin , fOrigin);
 
	fOrigin[0] += fAim[0];
	fOrigin[1] += fAim[1];
	
	set_pev(ent, pev_classname, "weapon_taser");
	entity_set_model(ent, W_TASER_MDL);
	set_pev(ent, pev_origin, fOrigin);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	entity_set_size(ent, Float:{-1.0,-1.0,35.0}, Float:{1.0,1.0,45.0});
}

give_taser(id)
{
	if(!g_user_has_taser)
	{
		EnableHamForward(HamKnifeItemDeploy);
		EnableHamForward(HamPlayerTakeDamage);
	}
	
	set_flag(g_user_has_taser,id);
	
	new wEnt;
	if(!(wEnt = find_ent_by_owner(-1, "weapon_knife", id)))
	{
		wEnt = give_item(id, "weapon_knife");
	}
	
	client_cmd(id, "weapon_knife");
	if(wEnt > 0) ExecuteHamB(Ham_Item_Deploy, wEnt);
	return 1;
}

#if AMXX_VERSION_NUM > 182
public client_disconnected(id)
#else
public client_disconnect(id)
#endif
{
	remove_flag(g_user_has_taser,id);
	remove_flag(g_disallow_taser_drop,id);
	remove_flag(g_user_paralyzed,id);
	remove_flag(g_user_alive,id);
	
	if(!g_user_has_taser)
	{
		DisableHamForward(HamKnifeItemDeploy);
		DisableHamForward(HamPlayerTakeDamage);
	}
	
	if(!g_user_paralyzed) DisableHamForward(HamPlayerPreThink);
}

public jb_shop_item_bought(id, itemid)
{
	if(itemid == ITEM_ID)
	{
		give_taser(id);
		remove_flag(g_disallow_taser_drop,id)
	}
}

public jb_shop_item_postselect(id, itemid)
{
	if(itemid == ITEM_ID)
	{
		if(check_flag(g_user_has_taser,id))
		{
			return JB_MENU_ITEM_UNAVAILABLE;
		}
	}
	return PLUGIN_CONTINUE;
}

public jb_shop_item_preselect(id, itemid)
{
	if(itemid == ITEM_ID)
	{
		if(check_flag(g_user_has_taser,id))
		{
			return JB_MENU_ITEM_UNAVAILABLE;
		}
	}
	return PLUGIN_CONTINUE;
}

public fw_player_takedmg_pre(victim, inflictor, attacker, Float:damage, damagebits)
{
	if(!( 1 <= attacker <= 32 ) || inflictor != attacker || victim == attacker) return HAM_IGNORED;
	
	if(!IsUserHoldingTaser(attacker)) return HAM_IGNORED;
	
	if(get_user_team(victim) == get_user_team(attacker)) return HAM_IGNORED;
	
	damage = random_float(TASER_MIN_DMG, TASER_MAX_DMG);
	SetHamParamFloat(4, damage);
	SetHamParamInteger(5, (DMG_SHOCK|DMG_SLOWBURN|DMG_ENERGYBEAM));
	electrecuted(victim, attacker)
	return HAM_HANDLED;
}

public task_fadenormal(id)
{
	id -= TASK_PARALYZED;
	
	UTIL_ScreenFade(id, _, _, _, _, FFADE_OUT);
	
	if(check_flag(g_user_alive,id))
	{
		set_pev(id, pev_maxspeed, 250.0);
		
		new wpns[32];
		new amount = get_user_weapons_ent(id, wpns);
		for(new i, went; i < amount; i++)
		{
			went = wpns[i];
			set_pdata_float(went, m_flNextPrimaryAttack, -1.0, XO_CBASEPLAYERWEAPON);
			set_pdata_float(went, m_flNextSecondaryAttack, -1.0, XO_CBASEPLAYERWEAPON);
		}
	}
	
	remove_flag(g_user_paralyzed,id);
	
	if(!g_user_paralyzed)
	{
		DisableHamForward(HamPlayerPreThink);
	}
	
	remove_task(TASK_PARALYZED+id);
}

bool:IsUserHoldingTaser(id)
{
	if(!check_flag(g_user_alive,id) || !check_flag(g_user_has_taser,id)) return false;
	if(get_user_weapon(id) != CSW_KNIFE) return false;
	
	static szWpnMDL[32];
	pev(id, pev_viewmodel2, szWpnMDL, charsmax(szWpnMDL));
	if(!equal(szWpnMDL, V_TASER_MDL)) return false;
	
	return true;
}

electrecuted(victim, attacker)
{
	// fade out 1 sec..
	UTIL_FadeToBlack(victim, 0.1, true, false)
	if(!task_exists(victim+TASK_PARALYZED))
	{
		if(!g_user_paralyzed) EnableHamForward(HamPlayerPreThink);
		
		set_flag(g_user_paralyzed,victim);
		set_task(2.5, "task_fadenormal", victim+TASK_PARALYZED);
	}
	
	static Float:origin[3];
	pev(attacker, pev_origin, origin)
	pev(victim, pev_v_angle, g_fUser_angles[victim]);
	
	// Lighting
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, origin, 0)
	write_byte(TE_DLIGHT)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2])
	write_byte(10) // radius
	write_byte(125)
	write_byte(125)
	write_byte(0)
	write_byte(5)
	write_byte(1)
	message_end()
	
	static Float:fview[3];
	pev(attacker, pev_view_ofs, fview)
	
	origin[0] += fview[0];
	origin[1] += fview[1];
	origin[2] += fview[2];
	
	// Sparks
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
	write_byte(TE_SPARKS)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2])
	message_end();
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang11265\\ f0\\ fs16 \n\\ par }
*/
