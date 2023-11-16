
/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <amxmisc>
#include <xs>
#include <fun>
#include <cstrike>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <vip_core>
#include <jailbreak_core>

#define PLUGIN "[JB] Harpoon"
#define AUTHOR "Natsheh"

#define IsPlayer(%1) (1 <= %1 <= 32)

#define HARPOON_CLASSNAME "harpoon"
#define WEAPON_NAME "weapon_harpoon"
#define CSW_HARPOON CSW_SMOKEGRENADE
#define weapon_harpoon "weapon_smokegrenade"
#define PEV_WEAPON_TYPE pev_iuser4
#define WEAPON_TYPE_HARPOON 9905

#define HARPOON_THROW_FORCE 1200.0
#define HARPOON_GRAVITY_FL 1.0
#define HARPOON_THINK_LEN 0.1

#define TASK_HARPOON_STORM 1000

#if AMXX_VERSION_NUM > 182
#define client_disconnect(id) client_disconnected(id)
#endif

new const DAY_NAME[] = "Harpoon War";
new const ITEM_NAME[] = "Harpoon";

new V_HARPOONMDL[64] = "models/jailbreak/v_harpoon.mdl";
new P_HARPOONMDL[64] = "models/jailbreak/p_harpoon.mdl";
new W_HARPOONMDL[64] = "models/jailbreak/w_harpoon.mdl";
new SND_HARPOON_HIT_PLAYER[64] = "jailbreak/jb_harpoonp.wav";
new SND_HARPOON_HIT_WORLD[64] = "jailbreak/jb_harpoonw.wav";
new SND_HARPOON_LIGHTNING[64] = "warcraft3\lightning1.wav";

new const SPR_TRAIL[] = "sprites/laserbeam.spr";
new const SPR_LIGHTNING[] = "sprites/lgtning.spr";

new g_HARPOON_DAYID, g_HARPOON_ITEMID, g_HARPOON_LRITEMID, g_USER_HAS_HARPOON[33], g_pSpriteLightning, g_pShopItem_HarpoonStorm,
g_CVAR_HARPOON_DAMAGE, g_TRAIL_SPR, g_iMsg_TEXTMSG, g_iMsg_WeaponList, g_pCvar_FF, g_iCvar_FF_oldvalue, g_UserPickedHarpoon,
g_iHarpoonStormCount;

public plugin_precache()
{
	jb_ini_get_keyvalue("HARPOON", "HARPOON_V_MDL", V_HARPOONMDL, charsmax(V_HARPOONMDL));
	jb_ini_get_keyvalue("HARPOON", "HARPOON_P_MDL", P_HARPOONMDL, charsmax(P_HARPOONMDL));
	jb_ini_get_keyvalue("HARPOON", "HARPOON_W_MDL", W_HARPOONMDL, charsmax(W_HARPOONMDL));
	jb_ini_get_keyvalue("HARPOON", "HARPOON_HIT_PLAYER_SND", SND_HARPOON_HIT_PLAYER, charsmax(SND_HARPOON_HIT_PLAYER));
	jb_ini_get_keyvalue("HARPOON", "HARPOON_HIT_WORLD_SND", SND_HARPOON_HIT_WORLD, charsmax(SND_HARPOON_HIT_WORLD));
	jb_ini_get_keyvalue("HARPOON", "HARPOON_LIGHTNING_SND", SND_HARPOON_LIGHTNING, charsmax(SND_HARPOON_LIGHTNING));
	PRECACHE_WEAPON_VIEW_MODEL(V_HARPOONMDL);
	PRECACHE_WEAPON_PLAYER_MODEL(P_HARPOONMDL);
	PRECACHE_WEAPON_WORLD_MODEL(W_HARPOONMDL);
	PRECACHE_SOUND(SND_HARPOON_HIT_PLAYER);
	PRECACHE_SOUND(SND_HARPOON_HIT_WORLD);
	PRECACHE_SOUND(SND_HARPOON_LIGHTNING);
	g_TRAIL_SPR = PRECACHE_SPRITE_I(SPR_TRAIL);
	precache_generic("sprites/hud351.spr");
	precache_generic("sprites/hud352.spr");
	precache_generic("sprites/weapon_harpoon.txt");

	register_message((g_iMsg_WeaponList=get_user_msgid("WeaponList")), "fw_message_WeaponList");

	g_pSpriteLightning = precache_model(SPR_LIGHTNING);
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	g_HARPOON_DAYID = register_jailbreak_day(DAY_NAME, 0, 300.0,DAY_ONE_SURVIVOR);
	g_HARPOON_ITEMID = register_jailbreak_shopitem(ITEM_NAME, "Sharp as a whistle", 8000, TEAM_ANY);
	g_HARPOON_LRITEMID = register_jailbreak_lritem(ITEM_NAME);
	
	g_iMsg_TEXTMSG = get_user_msgid("TextMsg");

	g_CVAR_HARPOON_DAMAGE = register_cvar("jb_harpoon_damage", "125");
	
	RegisterHam(Ham_Item_Deploy, weapon_harpoon, "fw_harpoon_deploy_post", 1);
	register_forward(FM_SetModel, "fw_setmodel_pre");
	RegisterHam(Ham_Spawn, "player", "fw_player_respawn_post", 1);
	register_think(HARPOON_CLASSNAME, "fw_harpoon_think");
	register_touch(HARPOON_CLASSNAME, "*", "fw_harpoon_touched");

	register_message(get_user_msgid("SendAudio"), "fw_message_audio");
	RegisterHam(Ham_Item_AddToPlayer, weapon_harpoon, "OnAddToPlayerHarpoon", .Post = true);

	register_clcmd(WEAPON_NAME, "clcmd_weapon_harpoon");

	register_concmd("jb_give_harpoon", "concmd_harpoon_given", ADMIN_KICK, "give a player or players a spear!!!");
	register_concmd("jb_harpoon_storm", "concmd_harpoon_storm", ADMIN_KICK);

	g_pCvar_FF = register_cvar("jb_harpoon_ff", "1");

	register_think("lightningbolt_start", "lightning_think");

	g_pShopItem_HarpoonStorm = register_jailbreak_shopitem("Harpoon Storm", "Summons a deadly storm!", 50000, TEAM_PRISONERS);
}

public concmd_harpoon_storm(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
	{
		return PLUGIN_HANDLED;
	}

	new szTarget[32], iTarget = id;

	enum (+=1)
	{
		HARPOON_STORM_PULSES = 1,
		HARPOON_STORM_THICKNESS,
		HARPOON_STORM_PULSE_DURATION,
		HARPOON_STORM_RADIUS,
		HARPOON_STORM_TARGET
	}

	if(read_argc() >= HARPOON_STORM_TARGET)
	{
		read_argv(HARPOON_STORM_TARGET, szTarget, charsmax(szTarget));
		iTarget = cmd_target(id, szTarget, .flags = CMDTARGET_ONLY_ALIVE);

		if(!iTarget) return PLUGIN_HANDLED;
	}

	new Float:fOrigin[3], any:aParams[10], Array:ArrLocations = Invalid_Array, Float:fRadius = any:floatmax(read_argv_float(HARPOON_STORM_RADIUS), 100.0);
	pev(iTarget, pev_origin, fOrigin);

	if(!find_sky(fOrigin, iTarget))
	{
		console_print(id, "Failed to initiate a harpoon geostorm, sky is not found!");
		return PLUGIN_HANDLED;
	}

	fOrigin[2] -= 100.0;

	aParams[1] = find_location_around_origin(fOrigin, Float:{ 9.0, 9.0, 1.0 }, Float:{ -9.0, -9.0, -1.0 }, fRadius, .pArrayLocations = ArrLocations);
	aParams[0] = any:ArrLocations;
	aParams[2] = max(read_argv_int(HARPOON_STORM_PULSES), 5);
	aParams[3] = max(read_argv_int(HARPOON_STORM_THICKNESS), 5);
	aParams[4] = any:floatmax(read_argv_float(HARPOON_STORM_PULSE_DURATION), 0.01);
	aParams[5] = fRadius;
	aParams[6] = fOrigin[0];
	aParams[7] = fOrigin[1];
	aParams[8] = fOrigin[2];
	aParams[9] = iTarget;

	task_harpoon_storm(aParams, TASK_HARPOON_STORM + (g_iHarpoonStormCount++));
	return PLUGIN_HANDLED;
}

public task_harpoon_storm(any:aParams[10], taskid)
{
    new Float:fOrigin[3], Float:fRadius = aParams[5], Array:ArrLocations = any:aParams[ 0 ];

    if(!ArraySize(ArrLocations))
    {
		fOrigin[0] = aParams[6];
		fOrigin[1] = aParams[7];
		fOrigin[2] = aParams[8];

		ArrayDestroy(ArrLocations);
		ArrLocations = Invalid_Array;
		aParams[1] = find_location_around_origin(fOrigin, Float:{ 9.0, 9.0, 1.0 }, Float:{ -9.0, -9.0, -1.0 }, fRadius, .pArrayLocations = ArrLocations);
		aParams[0] = any:ArrLocations;
    }

    new x = aParams[ 1 ];

    if(x > 0)
    {
    	static Float:fTargetOrigin[3], iTarget;
    	iTarget = aParams[9];

    	if(is_user_alive(iTarget))
    	{
    		pev(iTarget, pev_origin, fTargetOrigin);
    	}
    	else
    	{
    		fTargetOrigin[0] = aParams[6];
    		fTargetOrigin[1] = aParams[7];
    	}

        for(new i, iItemID, maxloop = min(aParams[3], ArraySize(ArrLocations)); i < maxloop; i++)
        {
            iItemID = random(ArraySize(ArrLocations));
            ArrayGetArray(ArrLocations, iItemID, fOrigin);
            ArrayDeleteItem(ArrLocations, iItemID);

            fOrigin[0] = fOrigin[0] + floatsub(fTargetOrigin[0], aParams[6]);
            fOrigin[1] = fOrigin[1] + floatsub(fTargetOrigin[1], aParams[7]);

            if(!IsOriginInsideWorld(fOrigin)) continue;

            launch_harpoon(fOrigin, Float:{ 90.0, 0.0, 0.0 } );
        }
    }

    if(--aParams[2] > 0)
    {
        set_task(Float:aParams[4], "task_harpoon_storm", taskid, aParams, sizeof aParams);
    }
    else if( ArrLocations != Invalid_Array )
    {
        ArrayDestroy(ArrLocations);
    }
}

bool:IsOriginInsideWorld(const Float:fOrigin[3])
{
   if (fOrigin[0] >= 4096.0) return false;
   if (fOrigin[1] >= 4096.0) return false;
   if (fOrigin[2] >= 4096.0) return false;
   if (fOrigin[0] <= -4096.0) return false;
   if (fOrigin[1] <= -4096.0) return false;
   if (fOrigin[2] <= -4096.0) return false;

   return true;
}

new g_iCSW_ID = 0, g_szWeaponName[32], g_iArgumentsValues[8] = { 0, 0, ... };

public fw_message_WeaponList(msgid, dest, id)
{
	if( g_iCSW_ID != CSW_HARPOON && g_iMsg_WeaponList == msgid && get_msg_args() >= 9 ) 
	{
		get_msg_arg_string( 1, g_szWeaponName, charsmax(g_szWeaponName) );
		for(new i = 2; i <= 9; i++) g_iArgumentsValues[ i - 2 ] = get_msg_arg_int( i );

		g_iCSW_ID = g_iArgumentsValues[ 6 ];
	}
}

set_default_smokegrenade_huds(id)
{
	if( g_iCSW_ID == CSW_HARPOON )
	{
		message_begin( MSG_ONE, g_iMsg_WeaponList, .player = id );
		write_string( g_szWeaponName );    	// WeaponName
		for(new i = 0, size = sizeof g_iArgumentsValues; i < size; i++) write_byte( g_iArgumentsValues[ i ] );
		message_end();
	}
}

public clcmd_weapon_harpoon(id)
{
	if(!g_USER_HAS_HARPOON[id]) return PLUGIN_HANDLED;

	static entity_index; entity_index = -1;
	while( (entity_index = engfunc(EngFunc_FindEntityByString, entity_index, "classname", weapon_harpoon)) > 0 && pev(entity_index, pev_owner) != id ) { }
	if(!entity_index)
	{
		return PLUGIN_HANDLED;
	}

	if(pev(entity_index, PEV_WEAPON_TYPE) != WEAPON_TYPE_HARPOON) return PLUGIN_HANDLED;

	engclient_cmd(id, weapon_harpoon);

	return PLUGIN_HANDLED;
}

public OnAddToPlayerHarpoon( const entity, const id )
{
	if( pev_valid(entity) && is_user_alive( id ) ) // just for safety.
	{
		if(!g_USER_HAS_HARPOON[id] || !check_flag(g_UserPickedHarpoon,id))
		{
			set_default_smokegrenade_huds(id);
			return HAM_IGNORED;
		}
		
		remove_flag(g_UserPickedHarpoon,id);
		set_pev(entity, PEV_WEAPON_TYPE, WEAPON_TYPE_HARPOON);

		static MsgIndexWeaponList = 0; MsgIndexWeaponList = !MsgIndexWeaponList ? get_user_msgid("WeaponList") : MsgIndexWeaponList;
		message_begin( MSG_ONE, MsgIndexWeaponList, .player = id );
		write_string( WEAPON_NAME );    	// WeaponName
		write_byte( 0 );                   // PrimaryAmmoID
		write_byte( 255 );                   // PrimaryAmmoMaxAmount
		write_byte( -1 );                   // SecondaryAmmoID
		write_byte( -1 );                   // SecondaryAmmoMaxAmount
		write_byte( 3 );                    // SlotID (0...N) 
		write_byte( 3 );                    // NumberInSlot (1...N)
		write_byte( CSW_HARPOON );          // WeaponID
		write_byte( 0 );                    // Flags
		message_end();
    }
	return HAM_IGNORED;
}

public client_disconnect(id)
{
	g_USER_HAS_HARPOON[id] = 0;
}

public concmd_harpoon_given(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new szTarget[32], szAmount[8];
	read_argv(1, szTarget, charsmax(szTarget));
	remove_quotes(szTarget);

	#if AMXX_VERSION_NUM > 182
	new iAmount = read_argv_int(2);
	#else
	new iAmount;
	read_argv(2, szAmount, charsmax(szAmount));
	remove_quotes(szAmount);
	#endif

	iAmount = max(iAmount,0);

	if(szTarget[0] == '@')
	{
		new players[32], pnum, szGroup[32];
		switch( szTarget[1] )
		{
			case 'C', 'G', 'c', 'g': { get_players(players, pnum, "ahe", "CT"); copy(szGroup, charsmax(szGroup), "Guards"); }
			case 'T', 'P', 't', 'p': { get_players(players, pnum, "ahe", "TERRORIST"); copy(szGroup, charsmax(szGroup), "Pris }oners"); }
			case 'S', 's': { get_players(players, pnum, "ahe", "SPECTATOR"); copy(szGroup, charsmax(szGroup), "Spectators"); }
			case 'A', 'a': { get_players(players, pnum, "ah"); copy(szGroup, charsmax(szGroup), "Players"); }
			default: { console_print(id, "^nTarget Invalid!!!^n"); szGroup[0] = 0; }
		}

		for(new i, target; i < pnum; i++)
		{
			target = players[i];
			g_USER_HAS_HARPOON[target] = iAmount;
			give_harpoon(target);
		}

		szAmount[0] = '^1'; szAmount[1] = 0;
		if(iAmount > 1)
		{
			num_to_str(iAmount, szAmount, charsmax(szAmount));
		}

		switch (get_cvar_num("amx_show_activity"))
		{
			case 0: console_print(id, "All %s have been equiped with %s%s!", szGroup, szAmount, iAmount > 1 ? " harpoons":"a harpoon");
			default:
			{
				console_print(id, "All %s have been equiped with %s%s!", szGroup, szAmount, iAmount > 1 ? " harpoons":"a harpoon");
				cprint_chat(0, _, "All %s have been given %s%s!", szGroup, szAmount, iAmount > 1 ? " harpoons":"a harpoon");
			}
		}
	}
	else
	{
		new iTarget = cmd_target(id, szTarget, ~CMDTARGET_OBEY_IMMUNITY);

		if(!iTarget) return PLUGIN_HANDLED;

		g_USER_HAS_HARPOON[iTarget] = iAmount;
		give_harpoon(iTarget);

		new szName[32];
		get_user_name(iTarget, szName, charsmax(szName));

		szAmount[0] = '^1'; szAmount[1] = 0;
		if(iAmount > 1)
		{
			num_to_str(iAmount, szAmount, charsmax(szAmount));
		}

		switch (get_cvar_num("amx_show_activity"))
		{
			case 0: console_print(id, "Player %s has been equiped with %s%s!", szName, szAmount, iAmount > 1 ? " harpoons":"a harpoon");
			default:
			{
				console_print(id, "Player %s has been equiped with %s%s!", szName, szAmount, iAmount > 1 ? " harpoons":"a harpoon");
				cprint_chat(0, _, "Player %s has been given %s%s!", szName, szAmount, iAmount > 1 ? " harpoons":"a harpoon");
			}
		}
	}

	return PLUGIN_HANDLED;
}

public jb_lr_duel_started(prisoner, guard, duelid)
{
	if(duelid != g_HARPOON_LRITEMID) return;

	g_USER_HAS_HARPOON[prisoner] = 99;
	g_USER_HAS_HARPOON[guard] = 99;
	give_harpoon(prisoner);
	give_harpoon(guard);

	jb_block_user_weapons(prisoner, true, ~((1<<CSW_HARPOON)|(1<<CSW_KNIFE)));
	jb_block_user_weapons(guard, true, ~((1<<CSW_HARPOON)|(1<<CSW_KNIFE)));
}

public jb_lr_duel_ended(prisoner, guard, duelid)
{
	g_USER_HAS_HARPOON[prisoner] = 0;
	g_USER_HAS_HARPOON[guard] = 0;
	if(is_user_alive(prisoner))
	{
		strip_user_weapons(prisoner);
		give_item(prisoner, "weapon_knife");
	}
	if(is_user_alive(guard))
	{
		strip_user_weapons(guard);
		give_item(guard, "weapon_knife");
	}

	remove_all_harpoons();
}

public jb_day_started(iDayID)
{
	if(iDayID != g_HARPOON_DAYID) return;
	
	g_iCvar_FF_oldvalue = get_pcvar_num(g_pCvar_FF);
	set_pcvar_num(g_pCvar_FF, 1);

	new players[32], pnum;
	get_players(players, pnum, "ah");
	
	for(new i, id; i < pnum; i++)
	{
		id = players[i];
		
		strip_user_weapons(id);
		give_item(id, "weapon_knife");
		give_harpoon(id);
	}
}

public jb_day_ended(iDayID)
{
	if(iDayID != g_HARPOON_DAYID) return;

	set_pcvar_num(g_pCvar_FF, g_iCvar_FF_oldvalue);
}

public fw_player_respawn_post(id)
	if(is_user_alive(id)) g_USER_HAS_HARPOON[id] = 0;

DetachHarpoon(const harpoon)
{
	set_pev(harpoon, pev_iuser3, FM_NULLENT);
	set_pev(harpoon, pev_movetype, MOVETYPE_TOSS);
}

KillEntityBeams(const ent)
{
	message_begin(MSG_PVS, SVC_TEMPENTITY);
	write_byte(TE_KILLBEAM);
	write_short(ent);
	message_end();
}

public fw_harpoon_think(entity)
{
	if(pev(entity, pev_movetype) == MOVETYPE_NONE)
	{
		// No owner? no life no sticking...
		if(!pev(entity, pev_owner))
		{
			KillEntityBeams(entity);
			set_pev(entity, pev_flags, FL_KILLME);
			set_pev(entity, pev_nextthink, get_gametime() + 1.0);
			return;
		}

		static iTarget;
		if( pev_valid( (iTarget  = pev(entity, pev_iuser3)) ) )
		{
			if(pev(iTarget, pev_solid) == SOLID_NOT)
			{
				DetachHarpoon(entity);
				set_pev(entity, pev_nextthink, get_gametime() + HARPOON_THINK_LEN);
				return;
			}

			static  Float:fOrigin[3], Float:fShiftAngles[3], Float:fAngleVector[3], Float:fAngleDiff,
					Float:fVector[3], Float:fAngles[3], Float:fDistance, Float:fvCrossProduct[3];
			if(pev(iTarget, pev_solid) == SOLID_BSP) get_brush_entity_origin(iTarget, fOrigin);
			else pev(iTarget, pev_origin, fOrigin);
			pev(iTarget, pev_angles, fAngleVector);
			pev(entity, pev_vuser3, fVector);
			pev(entity, pev_vuser4, fShiftAngles);
			pev(entity, pev_fuser4, fDistance);
			angle_vector(fAngleVector, ANGLEVECTOR_FORWARD, fAngleVector);

			xs_vec_cross(fVector, fAngleVector, fvCrossProduct);

			fAngleDiff = xs_rad2deg( xs_acos( (fVector[0] * fAngleVector[0] + fVector[1] * fAngleVector[1] + fVector[2] * fAngleVector[2]), radian ) );
			xs_vec_cross(fVector, fAngleVector, fvCrossProduct);
			xs_vec_normalize(fvCrossProduct, fvCrossProduct);

			if(fAngleDiff != 0.0)
			{
				if( fvCrossProduct[2] < 0.0 )
				{
					fAngleDiff *= -1.0;
				}

				pev(entity, pev_angles, fAngles);
				fAngles[1] += fAngleDiff;
				fShiftAngles[1] += fAngleDiff;

				pev(iTarget, pev_angles, fVector);
				angle_vector(fVector, ANGLEVECTOR_FORWARD, fVector);
				set_pev(entity, pev_vuser3, fVector);
				set_pev(entity, pev_vuser4, fShiftAngles);

				set_pev(entity, pev_angles, fAngles);
			}

			angle_vector(fShiftAngles, ANGLEVECTOR_FORWARD, fVector);
			fVector[2] *= -1.0;
			xs_vec_mul_scalar(fVector, fDistance, fVector);
			xs_vec_add(fOrigin, fVector, fOrigin);
			engfunc(EngFunc_SetOrigin, entity, fOrigin);

			set_pev(entity, pev_nextthink, get_gametime() + HARPOON_THINK_LEN);
			return;
		}

		set_pev(entity, pev_nextthink, get_gametime() + 999999.0);
		return;
	}

	static Float:fDiff[3];
	pev(entity, pev_velocity, fDiff);

	if(!xs_vec_equal(fDiff, Float:{0.0,0.0,0.0}))
	{
		vector_to_angle(fDiff, fDiff);
		set_pev(entity, pev_angles, fDiff);
		//set_pev(entity, pev_fixangle, 2);
	}

	set_pev(entity, pev_nextthink, get_gametime() + HARPOON_THINK_LEN);
}

public jb_round_start_pre()
{
	remove_all_harpoons();
}

remove_all_harpoons()
{
	new ent;
	while( (ent = find_ent_by_class(ent, HARPOON_CLASSNAME)) > 0 )
	{
		KillEntityBeams(ent);
		set_pev(ent, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, ent);
	}
}

public fw_message_audio(msg_id, msg_dest, msg_entity)
{
	if(get_msg_args() < 2) return PLUGIN_CONTINUE;
	
	new id = get_msg_arg_int(1);

	if(!user_has_harpoon(id)) return PLUGIN_CONTINUE;

	new szString[20];
	get_msg_arg_string(2, szString, charsmax(szString));
	
	if(equal(szString, "%!MRAD_FIREINHOLE"))
	{
		if(get_msg_block(g_iMsg_TEXTMSG) == BLOCK_NOT) set_msg_block(g_iMsg_TEXTMSG, BLOCK_ONCE);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public fw_harpoon_touched(const entity, const toucher)
{
	// Harpoon is not valid.
	if(pev(entity, pev_flags) & FL_KILLME) return;

	if(IsPlayer(toucher))
	{
		// Item is waiting to get picked up by a player.
		if(pev(entity, pev_movetype) == MOVETYPE_NONE)
		{
			set_pev(entity, pev_flags, FL_KILLME);
			dllfunc(DLLFunc_Think, entity);
			give_harpoon(toucher);
			return;
		}

		// Added a delay so the thrower won't kill himself immediately
		static Float:flDamageTime, Float:fGameTime;
		fGameTime = get_gametime();
		pev(entity, pev_fuser1, flDamageTime);
		if( flDamageTime > fGameTime && pev(entity, pev_owner) == toucher )
		{
			return;
		}
		
		// is player not immortal ?
		static Float:flTakeDamage;
		pev(toucher, pev_takedamage, flTakeDamage);

		if(flTakeDamage != DAMAGE_NO)
		{
			new killer = pev(entity, pev_owner);

			if(!is_user_connected(killer)) killer = toucher;

			new iDamage = get_pcvar_num(g_CVAR_HARPOON_DAMAGE);
			// lets damage or kill this peasent!
			if(iDamage < get_user_health(toucher))
			{
				if(IsPlayer(killer) && killer != toucher && get_user_team(killer) == get_user_team(toucher) && !get_pcvar_num(g_pCvar_FF))
				{
					return;
				}

				static mp_friendlyfire = 0, iOldFF;
				if(!mp_friendlyfire) mp_friendlyfire = get_cvar_pointer("mp_friendlyfire");
				iOldFF = get_pcvar_num(mp_friendlyfire);
				set_pcvar_num(mp_friendlyfire, 1);
				ExecuteHamB(Ham_TakeDamage, toucher, entity, killer, float(iDamage), DMG_SLASH|DMG_BULLET);
				set_pcvar_num(mp_friendlyfire, iOldFF);
			}
			else // if(pev(toucher, pev_deadflag) == DEAD_NO)
			{
				if(IsPlayer(killer) && killer != toucher && get_user_team(killer) == get_user_team(toucher) && !get_pcvar_num(g_pCvar_FF))
				{
					return;
				}

				const PLAYER_GIBS = 2;
				static iMSG_DEATHMSG = 0, mp_friendlyfire = 0, iOldValue, iOldFF;
				if(!iMSG_DEATHMSG) iMSG_DEATHMSG = get_user_msgid("DeathMsg");
				
				iOldValue = get_msg_block(iMSG_DEATHMSG);
				set_msg_block(iMSG_DEATHMSG, BLOCK_SET);
				if(!mp_friendlyfire) mp_friendlyfire = get_cvar_pointer("mp_friendlyfire");
				iOldFF = get_pcvar_num(mp_friendlyfire);
				set_pcvar_num(mp_friendlyfire, 1);
				ExecuteHamB(Ham_Killed, toucher, killer, PLAYER_GIBS);
				set_pcvar_num(mp_friendlyfire, iOldFF);
				set_msg_block(iMSG_DEATHMSG, iOldValue);

				emessage_begin(MSG_ALL, iMSG_DEATHMSG, {0,0,0}, 0);
				ewrite_byte(killer);
				ewrite_byte(toucher);
				ewrite_byte(false);
				ewrite_string(HARPOON_CLASSNAME);
				emessage_end();
			}

			emit_sound(toucher, CHAN_BODY, SND_HARPOON_HIT_PLAYER, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
		}
	}
	else if(pev(entity, PEV_WEAPON_TYPE) == WEAPON_TYPE_HARPOON)
	{
		if(pev_valid(toucher))
		{
			if(pev(entity, pev_movetype) != MOVETYPE_NONE)
			{
				static iSolid, Float:fDamageType;
				pev(toucher, pev_takedamage, fDamageType);
				if(fDamageType != DAMAGE_NO)
				{
					ExecuteHamB(Ham_TakeDamage, toucher, entity, pev(entity, pev_owner),
						get_pcvar_float(g_CVAR_HARPOON_DAMAGE), DMG_SLASH|DMG_BULLET);
				}

				if((iSolid=pev(toucher, pev_solid)) == SOLID_BBOX || iSolid == SOLID_BSP || iSolid == SOLID_SLIDEBOX)
				{
					if(fDamageType != DAMAGE_NO)
					{
						static Float:fHealth;
						pev(toucher, pev_health, fHealth);
						if(fHealth <= 0.0)
						{
							emit_sound(entity, CHAN_ITEM, SND_HARPOON_HIT_WORLD, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
							return;
						}
					}

					static Float:fOrigin[3], Float:fOriginToucher[3], Float:fAngleVector[3];
					set_pev(entity, pev_movetype, MOVETYPE_NONE);
					engfunc(EngFunc_SetSize, entity, Float:{-0.5,-0.5,-0.5}, Float:{0.5, 0.5, 1.0});

					if(pev(toucher, pev_solid) == SOLID_BSP) get_brush_entity_origin(toucher, fOriginToucher);
					else pev(toucher, pev_origin, fOriginToucher);

					pev(entity, pev_origin, fOrigin);
					pev(toucher, pev_angles, fAngleVector);
					set_pev(entity, pev_iuser3, toucher);
					set_pev(entity, pev_fuser4, get_distance_f(fOriginToucher, fOrigin));
					angle_vector(fAngleVector, ANGLEVECTOR_FORWARD, fAngleVector);
					set_pev(entity, pev_vuser3, fAngleVector);

					xs_vec_sub(fOriginToucher, fOrigin, fAngleVector);
					xs_vec_normalize(fAngleVector, fAngleVector);
					xs_vec_neg(fAngleVector, fAngleVector);
					vector_to_angle(fAngleVector, fAngleVector);
					set_pev(entity, pev_vuser4, fAngleVector);
				}
			}

			emit_sound(entity, CHAN_ITEM, SND_HARPOON_HIT_WORLD, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
			return;
		}

		if(pev(entity, pev_movetype) != MOVETYPE_NONE)
		{
			static owner; owner = pev(entity, pev_owner);

			if(IsPlayer(owner) && get_user_vip(owner) & read_flags("e"))
			{
				lightning_strike(entity);
			}

			emit_sound(entity, CHAN_ITEM, SND_HARPOON_HIT_WORLD, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

			set_pev(entity, pev_movetype, MOVETYPE_NONE);
			engfunc(EngFunc_SetSize, entity, Float:{-0.5,-0.5,-0.5}, Float:{0.5,0.5,1.0});
		}
	}
}

lightning_strike(const entity, const iLightnings = 8, const Float:fRadius = 100.0)
{
	new Float:fStart[3], Float:fEnd[3], Float:fOrigin[3];
	pev(entity, pev_origin, fOrigin);
	xs_vec_copy(fOrigin, fStart);

	if(!find_sky(fStart, entity))
	{
		return;
	}

	new iTr2 = create_tr2();
	engfunc(EngFunc_TraceLine, fStart, fOrigin, IGNORE_MISSILE|IGNORE_MONSTERS, 0, iTr2);
	get_tr2(iTr2, TR_vecEndPos, fEnd);
	free_tr2(iTr2);

	for(new i, bolt, Float:fAngle = -180.0, Float:fADDAngle = ((1.0 / float(iLightnings)) * 360.0); i < iLightnings; i++)
	{
		fStart[0] = fOrigin[0] + (fRadius * floatcos(fAngle, degrees));
		fStart[1] = fOrigin[1] + (fRadius * floatsin(fAngle, degrees));
		fEnd[0]   = fStart [0] + random_float(5.0, 10.0) * floatcos(random_float(0.0, 360.0), degrees);
		fEnd[1]   = fStart [1] + random_float(5.0, 10.0) * floatsin(random_float(0.0, 360.0), degrees);

		bolt = create_lightning_bolt(fStart, fEnd, 3.0, 100, entity);

		if(bolt > 0)
		{
			set_pev(bolt, pev_fuser4, fRadius);
		}

		fAngle += fADDAngle;
	}
}

public vip_flag_creation()
{
	register_vip_flag('e', "Harpoon Lightning bolts!");
}

public task_destroy_lightning(const pStartLightning)
{
	new CEnvBeam = 		pev(pStartLightning, pev_iuser4);
	new pEndLightning = pev(pStartLightning, pev_iuser3);

	set_pev(CEnvBeam, pev_flags, FL_KILLME);
	dllfunc(DLLFunc_Think, CEnvBeam);

	set_pev(pEndLightning, pev_flags, FL_KILLME);
	dllfunc(DLLFunc_Think, pEndLightning);

	set_pev(pStartLightning, pev_flags, FL_KILLME);
	dllfunc(DLLFunc_Think, pStartLightning);
}

public lightning_think(const id)
{
	if(!pev_valid(id)) return;

	static CEnvBeam, pEndLightning;
	CEnvBeam = 		pev(id, pev_iuser4);
	pEndLightning = pev(id, pev_iuser3);

	static Float:fStart[3], Float:fEnd[3], Float:fOrigin[3], Float:fAngles[3], Float:fRadius, Float:fLife;
	pev(id, pev_origin, fStart);
	pev(id, pev_fuser4, fRadius);
	pev(id, pev_fuser3, fLife);
	pev(pEndLightning, pev_origin, fEnd);
	pev(id, pev_vuser4, fOrigin);

	fRadius = floatmax(fRadius - (fRadius / (fLife - get_gametime())), 1.0);

	xs_vec_sub(fStart, fOrigin, fAngles);
	xs_vec_normalize(fAngles, fAngles);
	vector_to_angle(fAngles, fAngles);
	fAngles[1] += 5.0;

	fStart[0] = fOrigin[0] + (fRadius * floatcos(fAngles[1], degrees));
	fStart[1] = fOrigin[1] + (fRadius * floatsin(fAngles[1], degrees));
	fEnd[0]   = fStart [0] + random_float(5.0, 10.0) * floatcos(random_float(0.0, 360.0), degrees);
	fEnd[1]   = fStart [1] + random_float(5.0, 10.0) * floatsin(random_float(0.0, 360.0), degrees);

	engfunc(EngFunc_SetOrigin, id, fStart);
	engfunc(EngFunc_SetOrigin, pEndLightning, fEnd);
	engfunc(EngFunc_SetOrigin, CEnvBeam, fEnd);

	set_pev(id, pev_nextthink, get_gametime() + 0.01);
}

create_lightning_bolt(const Float:fStart[3], const Float:fEnd[3], const Float:fLife, const iWidth, const pOwner = 0, const iAmplitude = 10, const Float:fPulse = 0.1)
{
	new CEnvBeam = create_entity("env_beam"),
	pStartLightning = create_entity("info_target"),
	pEndLightning = create_entity("info_target");

	if( ! CEnvBeam || ! pStartLightning || ! pEndLightning )
	{
		if( CEnvBeam )
		{
			remove_entity(CEnvBeam);
		}
		if( pStartLightning )
		{
			remove_entity(pStartLightning);
		}
		if( pEndLightning )
		{
			remove_entity(pEndLightning);
		}

		return 0;
	}

	new szStartEnt[32], szEndEnt[32];
	formatex(szStartEnt, charsmax(szStartEnt), "LIGHTNING_BEAM_S_%d", CEnvBeam);
	formatex(szEndEnt, charsmax(szEndEnt), "LIGHTNING_BEAM_E_%d", CEnvBeam);
	set_pev(pStartLightning, pev_targetname, szStartEnt);
	set_pev(pEndLightning, pev_targetname, szEndEnt);
	engfunc(EngFunc_SetOrigin, pStartLightning, fStart);
	engfunc(EngFunc_SetOrigin, pEndLightning, fEnd);

	set_pev(pStartLightning, pev_fuser3, get_gametime() + fLife);
	set_pev(pStartLightning, pev_iuser4, CEnvBeam);
	set_pev(pStartLightning, pev_iuser3, pEndLightning);
	set_pev(pStartLightning, pev_classname, "lightningbolt_start");

	if(pOwner > 0)
	{
		new Float:fOrigin[3];
		pev(pOwner, pev_origin, fOrigin);
		fOrigin[2] = fStart[2];
		set_pev(pStartLightning, pev_vuser4, fOrigin);
		set_pev(pStartLightning, pev_nextthink, get_gametime() + 0.01);
	}

	set_task(fLife, "task_destroy_lightning", pStartLightning);

	engfunc(EngFunc_SetOrigin, CEnvBeam, fEnd);

	new szDamage[16];
	DispatchKeyValue(CEnvBeam, "dmg", "9999");
	formatex(szDamage, charsmax(szDamage), "%i", DMG_ENERGYBEAM|DMG_BURN);
	DispatchKeyValue(CEnvBeam, "damagetype", szDamage);

	set_pev(CEnvBeam, pev_dmg, 9999.0);
	set_pev(CEnvBeam, pev_spawnflags, SF_BEAM_SPARKEND);
	set_pev(CEnvBeam, pev_renderamt, 200.0);
	set_pev(CEnvBeam, pev_rendercolor, Float:{ 200.0, 200.0, 200.0 });

	set_ent_data(CEnvBeam, "CLightning", "m_spriteTexture", g_pSpriteLightning);
	set_ent_data(CEnvBeam, "CLightning", "m_iszSpriteName", engfunc(EngFunc_AllocString, SPR_LIGHTNING));
	set_ent_data(CEnvBeam, "CLightning", "m_iszStartEntity", engfunc(EngFunc_AllocString, szStartEnt));
	set_ent_data(CEnvBeam, "CLightning", "m_iszEndEntity", engfunc(EngFunc_AllocString, szEndEnt));
	set_ent_data(CEnvBeam, "CLightning", "m_boltWidth", iWidth);
	set_ent_data(CEnvBeam, "CLightning", "m_noiseAmplitude", iAmplitude);
	set_ent_data_float(CEnvBeam, "CLightning", "m_life", fPulse);

	DispatchSpawn(CEnvBeam);

	emit_sound(pEndLightning, CHAN_AUTO, SND_HARPOON_LIGHTNING, VOL_NORM, ATTN_NORM, 0, PITCH_HIGH);

	return pStartLightning;
}

public jb_shop_item_postselect(id, itemid)
{
	if(itemid == g_pShopItem_HarpoonStorm)
	{
		new Float:fOrigin[3];
		pev(id, pev_origin, fOrigin);
		if(!find_sky(fOrigin, id))
		{
			return JB_MENU_ITEM_UNAVAILABLE;
		}
	}
	return JB_IGNORED;
}

public jb_shop_item_bought(id, itemid)
{
	if(itemid == g_HARPOON_ITEMID)
	{
		give_harpoon(id);
	}
	else if(itemid == g_pShopItem_HarpoonStorm)
	{
		new Float:fOrigin[3], any:aParams[10], Array:ArrLocations = Invalid_Array;
		pev(id, pev_origin, fOrigin);
		find_sky(fOrigin, id);
		fOrigin[2] -= 100.0;

		const Float:fRadius = 800.0;

		aParams[1] = find_location_around_origin(fOrigin, Float:{ 9.0, 9.0, 1.0 }, Float:{ -9.0, -9.0, -1.0 }, fRadius, .pArrayLocations = ArrLocations);
		aParams[0] = any:ArrLocations;
		aParams[2] = 500;
		aParams[3] = 5;
		aParams[4] = 0.2;
		aParams[5] = fRadius;
		aParams[6] = fOrigin[0];
		aParams[7] = fOrigin[1];
		aParams[8] = fOrigin[2];
		aParams[9] = id;

		task_harpoon_storm(aParams, TASK_HARPOON_STORM + (g_iHarpoonStormCount++));
	}
}

public fw_harpoon_deploy_post(const wEnt)
{
	if(!pev_valid(wEnt)) return HAM_IGNORED;
	
	new id = pev(wEnt, pev_owner);
	if(!id || !g_USER_HAS_HARPOON[id]) return HAM_IGNORED;
	
	if(pev(wEnt, PEV_WEAPON_TYPE) != WEAPON_TYPE_HARPOON) return HAM_IGNORED;

	set_pev(id, pev_viewmodel2, V_HARPOONMDL);
	set_pev(id, pev_weaponmodel2, P_HARPOONMDL);
	return HAM_HANDLED;
}

public fw_setmodel_pre(const ent, const model[])
{
	if(!pev_valid(ent)) return FMRES_IGNORED;
	
	// Check classname;
	static sClname[10];
	pev(ent, pev_classname, sClname, charsmax(sClname))
	if(!equal(sClname, "grenade")) return FMRES_IGNORED;
	
	new id = pev(ent, pev_owner);

	if(!IsPlayer(id) || !user_has_harpoon(id)) return FMRES_IGNORED;

	new Float:fAngle[3], Float:fOrigin[3];
	pev(ent, pev_origin, fOrigin);
	pev(id, pev_v_angle, fAngle);
	launch_harpoon(fOrigin, fAngle, id);

	set_pev(ent, pev_flags, FL_KILLME);
	dllfunc(DLLFunc_Think, ent);

	return FMRES_SUPERCEDE;
}

launch_harpoon(const Float:fOrigin[3], const Float:fDestAngle[3], const owner=0)
{
	new ent = create_entity("info_target");

	if(!ent) return 0;

	// set entity data..
	set_pev(ent, pev_classname, HARPOON_CLASSNAME);


	set_pev(ent, pev_takedamage, DAMAGE_YES);
	set_pev(ent, pev_health, 1000.0);
	set_pev(ent, pev_gravity, HARPOON_GRAVITY_FL);
	set_pev(ent, PEV_WEAPON_TYPE, WEAPON_TYPE_HARPOON);
	set_pev(ent, pev_owner, owner);

	new Float:fVelocity[3], Float:fvTemp[3];
	angle_vector(fDestAngle, ANGLEVECTOR_FORWARD, fVelocity);
	xs_vec_mul_scalar(fVelocity, HARPOON_THROW_FORCE, fVelocity);

	if(IsPlayer(owner))
	{
		g_USER_HAS_HARPOON[owner] --;
		set_pev(ent, pev_groupinfo, pev(owner, pev_groupinfo));

		pev(owner, pev_velocity, fvTemp);
		xs_vec_add(fVelocity, fvTemp, fVelocity);
	}

	set_pev(ent, pev_velocity, fVelocity);

	vector_to_angle(fVelocity, fvTemp);
	set_pev(ent, pev_angles, fvTemp);
	set_pev(ent, pev_fixangle, 1);

	// setting world model and entity size.
	engfunc(EngFunc_SetOrigin, ent, fOrigin);
	engfunc(EngFunc_SetModel, ent, W_HARPOONMDL);

	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	engfunc(EngFunc_SetSize, ent, Float:{-1.0,-1.0,-1.0}, Float:{1.0,1.0,1.0});

	new Float:fGameTime = get_gametime();
	set_pev(ent, pev_nextthink, fGameTime + 0.1);
	set_pev(ent, pev_fuser1, fGameTime + 1.0);

	new iColor[ 3 ] = { 200, 145, 000 };

	message_begin(MSG_PVS, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW) // TE id
	write_short(ent) // entity
	write_short(g_TRAIL_SPR) // sprite
	write_byte(20) // life
	write_byte(2) // width
	write_byte(iColor[0]) // r
	write_byte(iColor[1]) // g
	write_byte(iColor[2]) // b
	write_byte(200) // brightness
	message_end();

	return ent;
}

give_harpoon(id)
{
	set_flag(g_UserPickedHarpoon,id);
	g_USER_HAS_HARPOON[id] ++;
	new entity_index = give_item(id, weapon_harpoon);
	if(g_USER_HAS_HARPOON[id] > 1) cs_set_user_bpammo(id, CSW_HARPOON, g_USER_HAS_HARPOON[id]);
	if(entity_index > 0)
	{
		set_pev(entity_index, PEV_WEAPON_TYPE, WEAPON_TYPE_HARPOON);
		ExecuteHamB(Ham_Item_Deploy, entity_index);
	}
	else
	{
		entity_index = -1;
		while( (entity_index = engfunc(EngFunc_FindEntityByString, entity_index, "classname", weapon_harpoon)) > 0 && pev(entity_index, pev_owner) != id ) { }
		if(entity_index > 0)
		{
			client_cmd(id, weapon_harpoon);
			set_pev(entity_index, PEV_WEAPON_TYPE, WEAPON_TYPE_HARPOON);
			ExecuteHamB(Ham_Item_Deploy, entity_index)
		}
	}

	engclient_cmd(id, weapon_harpoon);
	
	if(get_user_weapon(id) == CSW_HARPOON)
	{
		set_pev(id, pev_viewmodel2, V_HARPOONMDL)
		set_pev(id, pev_weaponmodel2, P_HARPOONMDL)
	}

	emit_sound(id, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

bool:user_has_harpoon(id)
{
	if(!g_USER_HAS_HARPOON[id]) return false;
	if(get_user_weapon(id) != CSW_HARPOON) return false;
	
	static szWpnMDL[32];
	pev(id, pev_viewmodel2, szWpnMDL, charsmax(szWpnMDL));
	if(!equal(szWpnMDL, V_HARPOONMDL,strlen(szWpnMDL))) return false;
	
	return true;
}

bool:find_sky(Float:fOrigin[3], const ignore_ent=-1)
{
	if(engfunc(EngFunc_PointContents, fOrigin) == CONTENTS_SKY)
	{
		return true;
	}

 	static szTexture[16], iTr2, Float:fEnd[3]; iTr2 = create_tr2();

 	fEnd[0] = fOrigin[0];
 	fEnd[1] = fOrigin[1];
 	fEnd[2] = 4096.0;

 	new const NULL_TEXTURE[] = "NoTexture";

	while( true )
 	{
 		engfunc(EngFunc_TraceLine, fOrigin, fEnd, (IGNORE_MONSTERS|IGNORE_MISSILE), ignore_ent, iTr2);
 		engfunc(EngFunc_TraceTexture, 0, fOrigin, fEnd, szTexture, charsmax(szTexture));
		get_tr2(iTr2, TR_vecEndPos, fEnd);

		if(equal(szTexture, NULL_TEXTURE))
	    {
			free_tr2(iTr2);

			return false;
	    }

		if(equal(szTexture, "sky") || engfunc(EngFunc_PointContents, fEnd) == CONTENTS_SKY)
		{
			xs_vec_copy(fEnd, fOrigin);
			free_tr2(iTr2);
			return true;
		}

		// Are we inside a solid matter? DIG UP!!!
		if(!get_tr2(iTr2, TR_InOpen) && get_tr2(iTr2, TR_StartSolid) && get_tr2(iTr2, TR_AllSolid))
		{
			fOrigin[2] += 1.0;
			fEnd[2] = 4096.0;
			continue;
		}

		fEnd[2] += 1.0;
		xs_vec_copy(fEnd, fOrigin);
		fEnd[2] = 4096.0;
	}

	free_tr2(iTr2);
	return false;
}

stock find_location_around_origin(Float:fOrigin[3], const Float:fMaxs[3], const Float:fMins[3], const Float:fDistance, const bool:bRandom=false, &Array:pArrayLocations = any:-1)
{
    fOrigin[2] += floatabs(fMins[2]);

    static iTr2, Float:fTestOrigin[3], Float:fStart[3], Float:fEnd[3], Float:fYShift, Float:fXShift, i, d, iSafe;

    static iOrder[][][3] =
    {
        { {  0,  0,  1 }, {  0,  0, -1 } }, // Inner line
        { {  1,  1,  1 }, {  1,  1, -1 } }, // 4 square lines SIDES
        { { -1, -1,  1 }, { -1, -1, -1 } },
        { { -1,  1,  1 }, { -1,  1, -1 } },
        { {  1, -1,  1 }, {  1, -1, -1 } },
        { {  1,  1,  1 }, { -1,  1,  1 } }, // 4 square lines TOP
        { {  1,  1,  1 }, {  1, -1,  1 } },
        { { -1, -1,  1 }, { -1,  1,  1 } },
        { { -1, -1,  1 }, {  1, -1,  1 } },
        { {  1,  1, -1 }, { -1,  1, -1 } }, // 4 square lines BOTTOM
        { {  1,  1, -1 }, {  1, -1, -1 } },
        { { -1, -1, -1 }, { -1,  1, -1 } },
        { { -1, -1, -1 }, {  1, -1, -1 } },
        { {  1,  1,  1 }, { -1,  1, -1 } }, // front cross
        { {  1,  1, -1 }, { -1,  1,  1 } },
        { {  1, -1,  1 }, { -1, -1, -1 } }, // back cross
        { {  1, -1, -1 }, { -1, -1,  1 } },
        { {  1,  1,  1 }, {  1, -1, -1 } }, // right cross
        { {  1,  1, -1 }, {  1, -1,  1 } },
        { { -1,  1,  1 }, { -1, -1, -1 } }, // left cross
        { { -1,  1, -1 }, { -1, -1,  1 } },
        { {  1,  1,  1 }, { -1, -1,  1 } }, // up cross
        { {  1, -1,  1 }, { -1,  1,  1 } },
        { {  1,  1, -1 }, { -1, -1, -1 } }, // down cross
        { {  1, -1, -1 }, { -1,  1, -1 } }
    };

    fXShift = (fMaxs[0] - fMins[0]) ;
    fYShift = (fMaxs[1] - fMins[1]) ;

    const sizeofOrder = sizeof iOrder;

    iTr2 = create_tr2();

    fTestOrigin[1] = fOrigin[1] + fDistance;
    fTestOrigin[2] = fOrigin[2];

    static Float:flFraction, Float:fAngle, Float:fvBegin[3], Array:pTempArray=Invalid_Array;

    if(bRandom || pArrayLocations != Array:-1)
    {
        pTempArray = ArrayCreate(3, 1);
    }

    while( floatabs(fTestOrigin[1] - fOrigin[1]) <= fDistance  )
    {
        fAngle = floatasin( (fTestOrigin[1] - fOrigin[1]) / fDistance, degrees );
        fvBegin[0] = floatcos(fAngle,degrees) * fDistance;
        fvBegin[1] = floatsin(fAngle,degrees) * fDistance;
        fTestOrigin[0] = fOrigin[0] + fvBegin[0];

        while( get_distance_f(fTestOrigin, fOrigin) <= fDistance )
        {
            for( i = iSafe = 0; i < sizeofOrder; i++ )
            {
                for( d = 0; d < 3; d++ )
                {
                    switch( iOrder[i][0][d] )
                    {
                        case -1: fStart[d] = fTestOrigin[d] + fMins[d];
                        case 0: fStart[d] = fTestOrigin[d];
                        case 1: fStart[d] = fTestOrigin[d] + fMaxs[d];
                    }

                    switch( iOrder[i][1][d] )
                    {
                        case -1: fEnd[d] = fTestOrigin[d] + fMins[d];
                        case 0: fEnd[d] = fTestOrigin[d];
                        case 1: fEnd[d] = fTestOrigin[d] + fMaxs[d];
                    }
                }

                // Traces...
                engfunc(EngFunc_TraceLine, fStart, fEnd, DONT_IGNORE_MONSTERS, -1, iTr2);
                get_tr2(iTr2, TR_flFraction, flFraction);
                if(flFraction == 1.0 && get_tr2(iTr2, TR_InOpen) && !get_tr2(iTr2, TR_StartSolid) && !get_tr2(iTr2, TR_AllSolid))
                {
                    iSafe++;
                    continue;
                }

                break;
            }

            if(iSafe >= sizeofOrder)
            {
                if(pTempArray == Invalid_Array)
                {
                    xs_vec_copy(fTestOrigin, fOrigin);
                    free_tr2(iTr2);
                    return 1;
                }

                ArrayPushArray(pTempArray, fTestOrigin);
            }

            fTestOrigin[0] -= fXShift;
        }

        fTestOrigin[1] -= fYShift;
    }

    if(pTempArray != Invalid_Array)
    {
        if((i=ArraySize(pTempArray)) && bRandom)
        {
            ArrayGetArray(pTempArray, random(i), fOrigin);
        }

        if(pArrayLocations == any:-1)
        {
            ArrayDestroy(pTempArray);
        }
        else
        {
            pArrayLocations = pTempArray;
        }

        pTempArray = Invalid_Array;
        free_tr2(iTr2);
        return i;
    }

    free_tr2(iTr2);
    return 0;
}
