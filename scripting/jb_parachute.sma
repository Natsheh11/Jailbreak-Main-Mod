
#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <engine>
#include <cstrike>
#include <fun>
#include <jailbreak_core>

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif

new bool:g_has_parachute[33], g_IsUserAlive;
new g_para_ent[33];
new g_pDetach, g_pFallSpeed, g_p_shopitem_para;

#define PARACHUTE_LEVEL ADMIN_LEVEL_A

public plugin_init()
{
	register_plugin("[JB] Parachute", "1.0", "Natsheh");
	g_pFallSpeed = register_cvar("parachute_fallspeed", "100");
	g_pDetach = register_cvar("parachute_detach", "1");

	register_concmd("amx_parachute", "admin_give_parachute", PARACHUTE_LEVEL, "<nick, #userid or @team>" );

	register_event("DeathMsg", "death_event", "a");
	RegisterHam(Ham_Spawn, "player", "newSpawn", true);

	g_p_shopitem_para = register_jailbreak_shopitem("Parachute", "Smoothes the landing", 5000, TEAM_ANY);
}

public jb_shop_item_preselect(id, itemid)
{
	if(g_p_shopitem_para == itemid)
	{
		if(g_has_parachute[ id ]) return JB_MENU_ITEM_UNAVAILABLE;
	}

	return JB_IGNORED;
}

public jb_shop_item_bought(id, itemid)
{
	if(g_p_shopitem_para == itemid)
	{
		g_has_parachute[ id ] = true;
	}
}

public plugin_precache()
{
	precache_model("models/parachute.mdl");
}

public client_connect(id)
{
	parachute_reset(id)
}

public client_disconnect(id)
{
	parachute_reset(id)
}

public death_event()
{
	const VICTIM_ARGUMENT = 2;
	new iVictim = read_data( VICTIM_ARGUMENT );
	remove_flag(g_IsUserAlive,iVictim);
	parachute_reset( iVictim );
}

parachute_reset(id)
{
	new parachute = g_para_ent[id];

	if(parachute > 0)
	{
		entity_set_int(parachute, EV_INT_flags, FL_KILLME);
		call_think(parachute);
	}

	g_has_parachute[id] = false;
	g_para_ent[id] = 0;
}

public newSpawn(id)
{
	if(!is_user_alive(id)) return;

	set_flag(g_IsUserAlive,id);

	new parachute = g_para_ent[id];

	if(parachute > 0)
	{
		entity_set_int(parachute, EV_INT_flags, FL_KILLME);
		call_think(parachute);
		g_para_ent[id] = 0;
	}

	if ( access(id, PARACHUTE_LEVEL) )
	{
		g_has_parachute[id] = true;
	}
}

public admin_give_parachute(id, level, cid) {

	if(!cmd_access(id,level,cid,2)) return PLUGIN_HANDLED

	new arg[32], name[32], authid[35];
	read_argv(1,arg,31);
	get_user_name(id,name,31);
	get_user_authid(id,authid,34);

	if (arg[0]=='@')
	{
		new players[32], inum;
		switch ( arg[1] )
		{
			case 'T': get_players(players, inum, "he", "TERRORIST");
			case 'C': get_players(players, inum, "he", "CT");
			default :	get_players(players, inum, "h");
		}

		if (inum == 0) {
			console_print(id,"No clients in such team");
			return PLUGIN_HANDLED;
		}

		for(new a = 0; a < inum; a++)
		{
			g_has_parachute[ players[a] ] = true;
		}

		switch(get_cvar_num("amx_show_activity")) {
			case 2:	client_print(0,print_chat,"ADMIN %s: gave a parachute to ^"%s^" players",name,arg[1])
			case 1:	client_print(0,print_chat,"ADMIN: gave a parachute to ^"%s^" players",arg[1])
		}

		console_print(id,"[AMXX] You gave a parachute to ^"%s^" players",arg[1])
		log_amx("^"%s<%d><%s><>^" gave a parachute to ^"%s^"", name,get_user_userid(id),authid,arg[1])
	}
	else
	{
		new player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF)
		if (!player) return PLUGIN_HANDLED;

		g_has_parachute[player] = true;

		new authid2[35], name2[32];
		get_user_name(player,name2,31);
		get_user_authid(player,authid2,34);

		switch(get_cvar_num("amx_show_activity")) {
			case 2:	client_print(0,print_chat,"ADMIN %s: gave a parachute to ^"%s^"",name,name2)
			case 1:	client_print(0,print_chat,"ADMIN: gave a parachute to ^"%s^"",name2)
		}

		console_print(id,"[AMXX] You gave a parachute to ^"%s^"", name2)
		log_amx("^"%s<%d><%s><>^" gave a parachute to ^"%s<%d><%s><>^"", name,get_user_userid(id),authid,name2,get_user_userid(player),authid2)
	}
	return PLUGIN_HANDLED
}

public client_PreThink(id)
{
	//parachute.mdl animation information
	//0 - deploy - 84 frames
	//1 - idle - 39 frames
	//2 - detach - 29 frames

	if (!check_flag(g_IsUserAlive,id) || !g_has_parachute[id]) return;

	static button, oldbutton, flags, Float:fFrame = 0.0;
	button = get_user_button(id);
	oldbutton = get_user_oldbutton(id);
	flags = get_entity_flags(id);

	static para_ent = 0;
	para_ent = g_para_ent[id];

	if (para_ent > 0 && (flags & FL_ONGROUND)) {

		static bDetach = 0; bDetach = !bDetach ? get_pcvar_num(g_pDetach):bDetach;
		if (bDetach)
		{

			if (entity_get_int(para_ent,EV_INT_sequence) != 2) {
				entity_set_int(para_ent, EV_INT_sequence, 2);
				entity_set_int(para_ent, EV_INT_gaitsequence, 1);
				entity_set_float(para_ent, EV_FL_frame, 0.0);
				entity_set_float(para_ent, EV_FL_fuser1, 0.0);
				entity_set_float(para_ent, EV_FL_animtime, 0.0);
				entity_set_float(para_ent, EV_FL_framerate, 0.0);
				return
			}

			fFrame = entity_get_float(para_ent,EV_FL_fuser1) + 2.0;
			entity_set_float(para_ent,EV_FL_fuser1,fFrame);
			entity_set_float(para_ent,EV_FL_frame,fFrame);

			if (fFrame > 254.0)
			{
				entity_set_int(para_ent, EV_INT_flags, FL_KILLME);
				call_think(para_ent);
				g_para_ent[id] = 0;
			}
		}
		else
		{
			entity_set_int(para_ent, EV_INT_flags, FL_KILLME);
			call_think(para_ent);
			g_para_ent[id] = 0;
		}

		return
	}

	if (button & IN_USE)
	{
		static Float:fFallspeed = 0.0, Float:velocity[3]; fFallspeed = (fFallspeed == 0.0) ? ( -get_pcvar_float(g_pFallSpeed) ) : fFallspeed;
		entity_get_vector(id, EV_VEC_velocity, velocity)

		if (velocity[2] < 0.0) {

			if(para_ent <= 0) {
				para_ent = create_entity("info_target")
				if(para_ent > 0)
				{
					g_para_ent[id] = para_ent;
					entity_set_string(para_ent,EV_SZ_classname,"parachute");
					entity_set_edict(para_ent, EV_ENT_aiment, id);
					entity_set_edict(para_ent, EV_ENT_owner, id);
					entity_set_int(para_ent, EV_INT_movetype, MOVETYPE_FOLLOW);
					entity_set_model(para_ent, "models/parachute.mdl");
					entity_set_int(para_ent, EV_INT_sequence, 0);
					entity_set_int(para_ent, EV_INT_gaitsequence, 1);
					entity_set_float(para_ent, EV_FL_frame, 0.0);
					entity_set_float(para_ent, EV_FL_fuser1, 0.0);
				}
			}

			if (para_ent > 0) {

				entity_set_int(id, EV_INT_sequence, 3)
				entity_set_int(id, EV_INT_gaitsequence, 1)
				entity_set_float(id, EV_FL_frame, 1.0)
				entity_set_float(id, EV_FL_framerate, 1.0)

				velocity[2] = (velocity[2] + 40.0 < fFallspeed) ? velocity[2] + 40.0 : fFallspeed
				entity_set_vector(id, EV_VEC_velocity, velocity)

				if (entity_get_int(para_ent,EV_INT_sequence) == 0) {

					fFrame = entity_get_float(para_ent,EV_FL_fuser1) + 1.0
					entity_set_float(para_ent,EV_FL_fuser1,fFrame)
					entity_set_float(para_ent,EV_FL_frame,fFrame)

					if (fFrame > 100.0) {
						entity_set_float(para_ent, EV_FL_animtime, 0.0)
						entity_set_float(para_ent, EV_FL_framerate, 0.4)
						entity_set_int(para_ent, EV_INT_sequence, 1)
						entity_set_int(para_ent, EV_INT_gaitsequence, 1)
						entity_set_float(para_ent, EV_FL_frame, 0.0)
						entity_set_float(para_ent, EV_FL_fuser1, 0.0)
					}
				}
			}
		}
		else if (para_ent > 0) {
			entity_set_int(para_ent, EV_INT_flags, FL_KILLME);
			call_think(para_ent);
			g_para_ent[id] = 0;
		}
	}
	else if ((oldbutton & IN_USE) && para_ent > 0 ) {
		entity_set_int(para_ent, EV_INT_flags, FL_KILLME);
		call_think(para_ent);
		g_para_ent[id] = 0
	}
}
