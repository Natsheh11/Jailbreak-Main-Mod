#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta_util>
#include <vip_core>
#include <cstrike>
#include <hamsandwich>
#include <jailbreak_core>
#include <fun>
#include <reapi>

#define MAX_PLAYERS 32
#define LOADUP_TIME		1.0
#define SHUTDOWN_TIME	1.7
#define ANIME_IDLE_TIME	6.2
#define WEAPON_TYPE_MINIGUN 696933
#define PEV_WEAPON_TYPE pev_iuser4

// Plugin information
new const PLUGIN[] = "[JB] WPN Minigun"
new const AUTHOR[] = "Natsheh"

// Weapon information
const CSW_MINIGUN = CSW_M249;
new const MINIGUN_CS_CLASSNAME[] = "weapon_m249";
new const MINIGUN_CLASSNAME[] = "weapon_minigun";
new const g_item_name[] = "MiniGUN";
new const g_VIP_item_name[] = "(VIP) MiniGUN";
const g_item_cost = 30000;
const CS_AMMO_ID_762NATO = 2;
const CS_AMMO_ID_MINIGUN = CS_AMMO_ID_762NATO;

// Gunshot decal list
new const GUNSHOT_DECALS[] = {41, 42, 43, 44, 45};

// other
new g_itemid_minigun, g_itemid_VIP_minigun, g_pcvar_mg_fire_rate, g_pcvar_mg_ammo, g_pcvar_mg_damage, Float:g_fMinigunGunPointOrigin[3],
any:g_bHasMinigun[MAX_PLAYERS+1], Float:g_flNextActionTime[MAX_PLAYERS+1], g_iMinigunAmmo[MAX_PLAYERS+1], bool:g_bCanFire[MAX_PLAYERS+1],
MINIGUN_ACTIVITY:g_iNextAction[MAX_PLAYERS+1], bool:g_bAlive[MAX_PLAYERS+1], g_user_equipped_minigun, g_iMsg_WeaponList, bool:g_bReGameDLL;

// CS Player PData Offsets (win32)
const OFFSET_CSTEAMS = 114

// offsets
const offset_m_pPlayer = 41;
const offset_m_flNextPrimaryAttack = 46;
const offset_m_flNextSecondaryAttack = 47;
const offset_m_flTimeWeaponIdle   = 48;
const offset_m_iClip   = 51;
const offset_m_pActiveItem   = 373;
const CBASE_PLAYER_WEAPON_LINUX_DIFF = 4; // offsets 4 higher in Linux builds
const CBASE_PLAYER_LINUX_DIFF = 5; // offsets 5 higher in Linux builds

// Models
new P_MODEL[] = "models/wpnmod/m134/p_minigun.mdl";
new V_MODEL[] = "models/wpnmod/m134/v_minigun.mdl";
new W_MODEL[] = "models/wpnmod/m134/w_minigun.mdl";

// Sounds

enum (+=1)
{
	SND_MINIGUN_SHOOT = 0,
	SND_MINIGUN_SPIN,
	SND_MINIGUN_SPINUP,
	SND_MINIGUN_SPINDOWN
};

new const g_szMinigun_sounds[][] = {
	"wpnmod/minigun/hw_shoot1.wav",
	"wpnmod/minigun/hw_spin.wav",
	"wpnmod/minigun/hw_spinup.wav",
	"wpnmod/minigun/hw_spindown.wav"
};

new const g_noammo_sounds[][] = {"weapons/dryfire_rifle.wav"};

enum (+=1) {
	MINIGUN_EQUIPPED = 1,
	MINIGUN_DEPLOYED
}

enum {
	anim_idle,
	anim_idle2,
	anim_gentleidle,
	anim_stillidle,
	anim_draw,
	anim_holster,
	anim_spinup,
	anim_spindown,
	anim_spinidle,
	anim_spinfire,
	anim_spinidledown
};

enum any:MINIGUN_ACTIVITY(+=1)
{
	MINIGUN_ACT_IDLE = 0,
	MINIGUN_ACT_LOAD_UP,
	MINIGUN_ACT_SPINNING,
	MINIGUN_ACT_LOAD_DOWN,
	MINIGUN_ACT_FIRE,
	MINIGUN_HOLSTER,
	MINIGUN_DEPLOY

};

new const Float:g_fMGBodyGroupDamage[] = {
	1.0, // HIT_GENERIC
	1.5, // HIT_HEAD
	1.2, // HIT_CHEST
	0.8, // HIT_STOMACH
	0.6, // HIT_LEFTARM
	0.6, // HIT_RIGHTARM
	0.4, // HIT_LEFTLEG
	0.4, // HIT_RIGHTLEG
	0.0, // HIT_SHIELD
};

public plugin_precache()
{
	PRECACHE_WEAPON_PLAYER_MODEL(P_MODEL);
	PRECACHE_WEAPON_VIEW_MODEL(V_MODEL);
	PRECACHE_WEAPON_WORLD_MODEL(W_MODEL);

	for(new i; i < sizeof g_szMinigun_sounds; i++)
	{
		PRECACHE_SOUND(g_szMinigun_sounds[i]);
	}

	PRECACHE_FILE("sprites/weapon_minigun.txt");
	PRECACHE_FILE("sprites/640hud34_m134.spr");
	PRECACHE_FILE("sprites/640hud7.spr");

	register_message((g_iMsg_WeaponList=get_user_msgid("WeaponList")), "fw_message_WeaponList");
}

public vip_flag_creation()
{
	register_vip_flag('c', "Access to minigun");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	g_pcvar_mg_ammo = register_cvar("jb_minigun_ammo_m249","10000");
	g_pcvar_mg_fire_rate = 		register_cvar("jb_minigun_speed","0.08");
	g_pcvar_mg_damage =		register_cvar("jb_minigun_damage","100.0");
	g_itemid_minigun = register_jailbreak_shopitem(g_item_name, "High fire rate!", g_item_cost, TEAM_GUARDS, ADMIN_IMMUNITY);
	g_itemid_VIP_minigun = register_jailbreak_shopitem(g_VIP_item_name, "High fire rate!", g_item_cost, TEAM_GUARDS);

	register_touch(MINIGUN_CLASSNAME, "player", "fw_minigun_touched");

	register_forward(FM_CmdStart, "fwd_CmdStart");
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled", .Post = true);
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", .Post = true);
	RegisterHam(Ham_Use, "player_weaponstrip", "fw_Use_player_weaponstrip", .Post = false);
	//RegisterHam(Ham_Item_CanHolster, MINIGUN_CS_CLASSNAME, "fw_m249_can_holster_pre", .Post = false);
	RegisterHam(Ham_Item_Deploy, MINIGUN_CS_CLASSNAME, "fw_minigun_deployed_post", .Post = true);
	RegisterHam(Ham_Item_Holster, MINIGUN_CS_CLASSNAME, "fw_minigun_holster_post", .Post = true);
	RegisterHam(Ham_Item_AddToPlayer, MINIGUN_CS_CLASSNAME, "OnAddToPlayerMinigun", .Post = true);
	RegisterHam(Ham_Item_AttachToPlayer, MINIGUN_CS_CLASSNAME, "OnAttachToPlayerMinigun", .Post = true);

	register_concmd("jb_give_minigun", "concmd_give_minigun", ADMIN_IMMUNITY, "gives a minigun to a player");

	register_clcmd("drop", "clcmd_drop");
	register_clcmd(MINIGUN_CLASSNAME, "clcmd_weapon_minigun");

	GetMinigunGunPoint(g_fMinigunGunPointOrigin);

	if(is_regamedll())
	{
		g_bReGameDLL = true;
	}
}

GetMinigunGunPoint(Float:vReturnOrigin[3], Float:vAngles[3] = { 0.0, 0.0, 0.0 })
{
	new ent = create_minigun(Float:{0.0, 0.0, 0.0}, 0);
	engfunc(EngFunc_SetModel, ent, P_MODEL);

	new player = find_ent_by_class(-1, "info_player_deathmatch");
	set_pev(player, pev_sequence, 50); // 50 is m249 player aim idle
	set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
	set_pev(ent, pev_aiment, player);
	dllfunc(DLLFunc_Think, ent);

	engfunc(EngFunc_GetAttachment, ent, 0, vReturnOrigin, vAngles);

	new Float:fOrigin[3];
	pev(ent, pev_origin, fOrigin);
	xs_vec_sub(vReturnOrigin, fOrigin, vReturnOrigin);

	set_pev(ent, pev_flags, FL_KILLME);
	dllfunc(DLLFunc_Think, ent);
}

public concmd_give_minigun(id, level, cid)
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

        for(new i = 0, player, iAmmo = get_pcvar_num(g_pcvar_mg_ammo); i < pnum; i++)
        {
            player = players[i];
            give_minigun(player, iAmmo);
        }

        console_print(id, "You have given %c%c Miniguns!", sTarget[0], sTarget[1]);
        return PLUGIN_HANDLED;
    }

    new target = cmd_target(id, sTarget, CMDTARGET_ALLOW_SELF|CMDTARGET_ONLY_ALIVE);
    if(!target) return PLUGIN_HANDLED;

    get_user_name(target, sTarget, 31);
    give_minigun(target, get_pcvar_num(g_pcvar_mg_ammo));
    cprint_chat(id, _, "you gave ^3%s ^1a ^4Minigun!", sTarget);
    console_print(id, "You gave %s a Minigun!", sTarget);

    return PLUGIN_HANDLED;
}

new g_iCSW_ID = 0, g_szWeaponName[32], g_iArgumentsValues[ 8 ] = { 0, 0, ... };

public fw_message_WeaponList(msgid, dest, id)
{
	if( g_iCSW_ID != CSW_M249 && get_msg_arg_int( 8 ) == CSW_M249 )
	{
		get_msg_arg_string( 1, g_szWeaponName, charsmax(g_szWeaponName) );
		for(new i = 2; i <= 9; i++) g_iArgumentsValues[ i - 2 ] = get_msg_arg_int( i );

		g_iCSW_ID = g_iArgumentsValues[ 6 ];
	}

	return PLUGIN_CONTINUE;
}

set_default_m249_huds(id)
{
	if( g_iCSW_ID == CSW_M249 )
	{
		message_begin( MSG_ONE, g_iMsg_WeaponList, .player = id );
		write_string( g_szWeaponName );    	// WeaponName
		for(new i = 0, size = sizeof g_iArgumentsValues; i < size; i++) write_byte( g_iArgumentsValues[ i ] );
		message_end();
	}
}

public fw_Use_player_weaponstrip(ent, id)
{
	if( 1 <= id <= 32 )
	{
		g_bHasMinigun[id] = false;

		if(HasUserMinigun(id) > 0)
		{
			g_bHasMinigun[id] = MINIGUN_EQUIPPED;
			if(IsUserHoldingMinigun(id) > 0)
				g_bHasMinigun[id] = MINIGUN_DEPLOYED;
		}
	}
}

public OnAttachToPlayerMinigun( const Weapon, const id )
{
  if(!check_flag(g_user_equipped_minigun, id))
  {
    return;
  }

  set_pev(Weapon, PEV_WEAPON_TYPE, WEAPON_TYPE_MINIGUN);
  set_pev(Weapon, pev_classname, MINIGUN_CLASSNAME);
  set_ent_data(Weapon, "CBasePlayerWeapon", "m_iPrimaryAmmoType", CS_AMMO_ID_MINIGUN);
}

public OnAddToPlayerMinigun( const entity, const id )
{
	if( pev_valid(entity) && is_user_alive( id ) ) // just for safety.
	{
		if(!check_flag(g_user_equipped_minigun,id))
		{
			set_default_m249_huds(id);
			return HAM_IGNORED;
		}

		g_bHasMinigun[id] = MINIGUN_EQUIPPED;
		set_pev(entity, PEV_WEAPON_TYPE, WEAPON_TYPE_MINIGUN);

		static MsgIndexWeaponList = 0; MsgIndexWeaponList = !MsgIndexWeaponList ? get_user_msgid("WeaponList") : MsgIndexWeaponList;
		message_begin( MSG_ONE, MsgIndexWeaponList, .player = id );
		write_string( MINIGUN_CLASSNAME );    	// WeaponName
		write_byte( CS_AMMO_ID_MINIGUN );                   // PrimaryAmmoID
		write_byte( 255 );                   // PrimaryAmmoMaxAmount
		write_byte( 0 );                   // SecondaryAmmoID
		write_byte( 0 );                   // SecondaryAmmoMaxAmount
		write_byte( 0 );                    // SlotID (0...N)
		write_byte( 1 );                    // NumberInSlot (1...N)
		write_byte( CSW_MINIGUN );          // WeaponID
		write_byte( ITEM_FLAG_NOAUTORELOAD | ITEM_FLAG_EXHAUSTIBLE );                    // Flags
		message_end();
    }
	return HAM_IGNORED;
}

public fw_minigun_deployed_post( const ent )
{
	if(pev(ent, PEV_WEAPON_TYPE) == WEAPON_TYPE_MINIGUN)
	{
		new id = get_pdata_cbase(ent, offset_m_pPlayer, CBASE_PLAYER_WEAPON_LINUX_DIFF);

		set_pev(id, pev_viewmodel2, V_MODEL);
		set_pev(id, pev_weaponmodel2, P_MODEL);
		g_bHasMinigun[id] = MINIGUN_DEPLOYED;
	}
}

public fw_minigun_holster_post( const ent )
{
	if(pev(ent, PEV_WEAPON_TYPE) == WEAPON_TYPE_MINIGUN)
	{
		new id = get_pdata_cbase(ent, offset_m_pPlayer, CBASE_PLAYER_WEAPON_LINUX_DIFF);

		g_bHasMinigun[id] = MINIGUN_EQUIPPED;
	}
}

// Client leaving
#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif

public client_disconnect(id)
{
	g_bAlive[id] = g_bHasMinigun[id] = g_bCanFire[id] = false;
}

public fw_PlayerSpawn_Post(id)
{
	// Not alive or didn't join a team yet
	if (!is_user_alive(id))
		return;
	// Player spawned
	g_bAlive[id] = true;
	g_bHasMinigun[id] = false;

	if(HasUserMinigun(id) > 0)
	{
		g_bHasMinigun[id] = MINIGUN_EQUIPPED;
		if(IsUserHoldingMinigun(id) > 0)
			g_bHasMinigun[id] = MINIGUN_DEPLOYED;
	}
}

public fw_PlayerKilled(victim, attacker, shouldgib)
{
	//player die
	g_bAlive[victim] = false;

	new i = HasUserMinigun(victim);

	if( i > 0 )
	{
		drop_minigun(victim, i);
	}
}

public clcmd_weapon_minigun(id)
{
	if(!HasUserMinigun(id)) return PLUGIN_HANDLED;

	new entity_index = -1;
	while( (entity_index = engfunc(EngFunc_FindEntityByString, entity_index, "classname", MINIGUN_CLASSNAME)) > 0 && pev(entity_index, pev_owner) != id ) { }
	if(!entity_index)
	{
		return PLUGIN_HANDLED;
	}

	if(pev(entity_index, PEV_WEAPON_TYPE) != WEAPON_TYPE_MINIGUN) return PLUGIN_HANDLED;

	engclient_cmd(id, MINIGUN_CLASSNAME);

	return PLUGIN_HANDLED;
}

drop_minigun(const id, const iMinigun)
{
	new Float:fAim[3], Float:fOrigin[3];
	entity_get_vector(id, EV_VEC_origin, fOrigin);
	entity_get_vector(id, EV_VEC_view_ofs, fAim);
	xs_vec_add(fOrigin, fAim, fOrigin);
	VelocityByAim(id, 64, fAim);

	fOrigin[0] += fAim[0];
	fOrigin[1] += fAim[1];

	new iOldAmmo = get_ent_data(id, "CBasePlayer", "m_rgAmmo", CS_AMMO_ID_MINIGUN);
	create_minigun(fOrigin, get_pdata_int(iMinigun, offset_m_iClip, CBASE_PLAYER_WEAPON_LINUX_DIFF) + (g_iMinigunAmmo[id] * 100));
	set_ent_data(id, "CBasePlayer", "m_rgAmmo", iOldAmmo - g_iMinigunAmmo[id], CS_AMMO_ID_MINIGUN);
	g_iMinigunAmmo[id] = 0;

	remove_minigun(id);
}


public jb_round_start_pre()
{
	remove_miniguns();
}

// remove gun and save all guns
remove_minigun(id)
{
	ham_strip_minigun(id);
	g_bHasMinigun[id] = false;
}

public jb_shop_item_preselect(id, itemid)
{
    if(itemid == g_itemid_minigun)
    {
        if(get_user_vip(id) & read_flags("c"))
        {
            return JB_MENU_ITEM_DONT_SHOW;
        }

        return JB_IGNORED;
    }

    if(itemid == g_itemid_VIP_minigun)
    {
        if(get_user_vip(id) & read_flags("c"))
        {
            return JB_IGNORED;
        }

        return JB_MENU_ITEM_UNAVAILABLE;
    }

    return JB_IGNORED;
}

// someone bought our extra item
public jb_shop_item_bought(id, itemid)
{
	if (itemid == g_itemid_minigun || itemid == g_itemid_VIP_minigun)
	{
		give_minigun(id, get_pcvar_num(g_pcvar_mg_ammo));
	}
}

// item pre select
public jb_shop_item_postselect(id, itemid)
{
	if (itemid == g_itemid_minigun)
	{
		if(g_bHasMinigun[id])
		{
			return JB_MENU_ITEM_UNAVAILABLE;
		}
	}
	return JB_IGNORED;
}

public clcmd_drop(id)
{
	if(g_bAlive[id])
	{
		new iMinigun = IsUserHoldingMinigun(id);

		if(iMinigun <= 0)
		{
			return PLUGIN_CONTINUE;
		}

		drop_minigun(id, iMinigun);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

create_minigun(const Float:fOrigin[3], const iAmmo)
{
	new minigun = create_entity("info_target");

	if(!minigun) return 0;

	entity_set_string(minigun, EV_SZ_classname, MINIGUN_CLASSNAME);
	entity_set_model(minigun, W_MODEL);

	entity_set_size(minigun, Float:{-2.0,-2.0,-2.0}, Float:{5.0,5.0,5.0});
	entity_set_int(minigun, EV_INT_solid, SOLID_TRIGGER);

	entity_set_int(minigun,EV_INT_movetype, MOVETYPE_TOSS);
	entity_set_vector(minigun, EV_VEC_origin, fOrigin);

	set_pev(minigun, pev_iuser3, iAmmo);

	return minigun;
}

IsUserHoldingMinigun(id)
{
	static ent = 0;
	ent = get_pdata_cbase(id, offset_m_pActiveItem, CBASE_PLAYER_LINUX_DIFF);

	if(ent > 0)
	{
		if(pev(ent, PEV_WEAPON_TYPE) == WEAPON_TYPE_MINIGUN)
		{
			return ent;
		}
	}

	return 0;
}

HasUserMinigun(id)
{
	static ent = 0;
	while( (ent = find_ent_by_owner(ent, MINIGUN_CLASSNAME, id)) > 0 )
	{
		if(pev(ent, pev_solid) != SOLID_TRIGGER)
		{
			break;
		}
	}

	return ent;
}

remove_miniguns()
{
	new nextitem  = find_ent_by_class(-1, MINIGUN_CLASSNAME);

	while( nextitem )
	{
		if(pev(nextitem, pev_solid) == SOLID_TRIGGER)
		{
			set_pev(nextitem, pev_flags, FL_KILLME);
			dllfunc(DLLFunc_Think, nextitem);
		}

		nextitem = find_ent_by_class(nextitem, MINIGUN_CLASSNAME);
	}
}

public fw_minigun_touched(const MG, const iPlayer)
{
	if(pev_valid(MG) && !g_bHasMinigun[iPlayer])
	{
		give_minigun(iPlayer, pev(MG, pev_iuser3));

		cprint_chat(iPlayer, _, "Minigun ammo: !g%d", pev(MG, pev_iuser3));

		set_pev(MG, pev_solid, SOLID_NOT);
		set_pev(MG, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, MG);
	}
}

give_minigun(const id, const iAmmo)
{
	set_flag(g_user_equipped_minigun, id);

	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, MINIGUN_CS_CLASSNAME));
	if(!pev_valid(ent)) return;

	set_pev(ent, pev_classname, MINIGUN_CLASSNAME);
	set_pev(ent, pev_spawnflags, SF_NORESPAWN);
	set_pev(ent, PEV_WEAPON_TYPE, WEAPON_TYPE_MINIGUN);
	dllfunc(DLLFunc_Spawn, ent);

	if(!ExecuteHamB(Ham_AddPlayerItem, id, ent))
	{
		set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);
		return;
	}

	ExecuteHamB(Ham_Item_AttachToPlayer, ent, id);

	if(ent > 0 || (ent = find_ent_by_owner(-1, MINIGUN_CS_CLASSNAME, id)) > 0)
	{
		set_ent_data(ent, "CBasePlayerWeapon", "m_iPrimaryAmmoType", CS_AMMO_ID_MINIGUN);

		g_bHasMinigun[id] = MINIGUN_EQUIPPED;

		set_pev(ent, PEV_WEAPON_TYPE, WEAPON_TYPE_MINIGUN);

		new iClip = min(iAmmo - (floatround(float(iAmmo) / 100.0, floatround_tozero) * 100), 100);

		if(!iClip)
		{
			iClip = min(iAmmo, 100);
		}

		g_iMinigunAmmo[id] = floatround(float(iAmmo - iClip) / 100.0, floatround_tozero);

		set_pdata_int(ent, offset_m_iClip, iClip, CBASE_PLAYER_WEAPON_LINUX_DIFF);
		set_ent_data(id, "CBasePlayer", "m_rgAmmo", get_ent_data(id, "CBasePlayer", "m_rgAmmo", CS_AMMO_ID_MINIGUN) + g_iMinigunAmmo[id], CS_AMMO_ID_MINIGUN);

		if(get_pdata_cbase(id, offset_m_pActiveItem, CBASE_PLAYER_LINUX_DIFF) == ent)
		{
			ExecuteHamB(Ham_Item_Deploy, ent);
		}
	}

	remove_flag(g_user_equipped_minigun, id);
}

//play anim
native_playanim(player,anim)
{
	set_pev(player, pev_weaponanim, anim);
	message_begin(MSG_ONE, SVC_WEAPONANIM, {0, 0, 0}, player);
	write_byte(anim);
	write_byte(pev(player, pev_body));
	message_end();
}


 //marks on hit
 public native_gi_get_gunshot_decal()
{
	return GUNSHOT_DECALS[random(sizeof GUNSHOT_DECALS)]
}

bool:fire_minigun_bullet(const id, const iEnt)
{
	static iClip;

	iClip = get_pdata_int(iEnt, offset_m_iClip, CBASE_PLAYER_WEAPON_LINUX_DIFF);

	// no ammo?
	if(iClip <= 0)
	{
		// try for backup ammo....
		if( g_iMinigunAmmo[id] <= 0 )
			return false;

		set_ent_data(id, "CBasePlayer", "m_rgAmmo", --g_iMinigunAmmo[id], CS_AMMO_ID_MINIGUN);
		iClip = 100;
	}

	static Float:fOrigin[3], Float:fStart[3], Float:fDirection[3];
	pev(id, pev_origin, fOrigin);
	pev(id, pev_v_angle, fDirection);
	angle_vector(fDirection, ANGLEVECTOR_FORWARD, fDirection);
	xs_vec_mul_scalar(fDirection, xs_vec_len(g_fMinigunGunPointOrigin), fStart);
	xs_vec_add(fOrigin, fStart, fStart);

	static Float:fMinigunDamage, iBody = HIT_GENERIC, iTarget, fw_traceline;
	fMinigunDamage = get_pcvar_float(g_pcvar_mg_damage);
	get_user_aiming(id, iTarget, iBody);

	fw_traceline = register_forward(FM_TraceLine, "fw_traceline", ._post = true);
	FireBullets(iEnt, fStart, fDirection, 0.0, 8192.0, BULLET_PLAYER_762MM, floatround(fMinigunDamage * g_fMGBodyGroupDamage[iBody]), id);
	unregister_forward(FM_TraceLine, fw_traceline, .post = true);

	// Decrease 1 bullet ...
	set_pdata_int(iEnt, offset_m_iClip, iClip - 1, CBASE_PLAYER_WEAPON_LINUX_DIFF);

	return  true;
}

public fw_traceline(const Float:vecS[3], Float:vecE[3], const flags, const id, const ptr)
{
	static pHit, decal;
	get_tr2(ptr, TR_vecEndPos, vecE);
	pHit = get_tr2(ptr, TR_Hit);
	decal = native_gi_get_gunshot_decal();

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecS, 0);
	write_byte(TE_TRACER);
	engfunc(EngFunc_WriteCoord, vecS[0]);
	engfunc(EngFunc_WriteCoord, vecS[1]);
	engfunc(EngFunc_WriteCoord, vecS[2]);

	engfunc(EngFunc_WriteCoord, vecE[0]);
	engfunc(EngFunc_WriteCoord, vecE[1]);
	engfunc(EngFunc_WriteCoord, vecE[2]);
	message_end();

	if(pHit <= 0)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
		write_byte(TE_WORLDDECAL);
		engfunc(EngFunc_WriteCoord, vecE[0]);
		engfunc(EngFunc_WriteCoord, vecE[1]);
		engfunc(EngFunc_WriteCoord, vecE[2]);
		write_byte(decal);
		message_end();
	}
	else if(pev(pHit, pev_solid) == SOLID_BSP)
	{
		// Put decal on an entity
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
		write_byte(TE_DECAL);
		engfunc(EngFunc_WriteCoord, vecE[0]);
		engfunc(EngFunc_WriteCoord, vecE[1]);
		engfunc(EngFunc_WriteCoord, vecE[2]);
		write_byte(decal);
		write_short(pHit);
		message_end();
	}

	// Show sparcles
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_GUNSHOTDECAL);
	engfunc(EngFunc_WriteCoord, vecE[0]);
	engfunc(EngFunc_WriteCoord, vecE[1]);
	engfunc(EngFunc_WriteCoord, vecE[2]);
	write_short(id);
	write_byte(decal);
	message_end();
}

FireBullets(const this, Float:fStart[3], Float:fDirection[3], Float:fVecSpread, Float:fDist, any:iBulletType, iDamage, iAttacker)
{
	if(g_bReGameDLL)
	{
		rg_fire_bullets3(this, iAttacker, fStart, fDirection, fVecSpread, fDist, 3, iBulletType, iDamage, .flRangeModifier = 0.90, .bPistol = false, .shared_rand = false);
		return;
	}
}

 public fwd_CmdStart(id, uc_handle, seed)
{
	if(!g_bAlive[id])
	{
		return;
	}
	
	if(g_bHasMinigun[id] == MINIGUN_DEPLOYED)
	{
		static buttons;
		buttons = get_uc(uc_handle, UC_Buttons);

		if(buttons & IN_ATTACK)
		{
			switch(g_iNextAction[id])
			{
				case MINIGUN_ACT_IDLE:
				trigger_mode(id, MINIGUN_ACT_LOAD_UP);

				case MINIGUN_ACT_SPINNING:
				trigger_mode(id, MINIGUN_ACT_FIRE);

				default:
				trigger_mode(id, g_iNextAction[id]);
			}
		}
		else if(buttons & IN_ATTACK2)
		{
			switch( g_iNextAction[id] )
			{
				case MINIGUN_ACT_IDLE: trigger_mode(id, MINIGUN_ACT_LOAD_UP);
				case MINIGUN_ACT_LOAD_UP, MINIGUN_ACT_SPINNING, MINIGUN_ACT_FIRE: trigger_mode(id, MINIGUN_ACT_SPINNING);
			}
		}
		else if(g_iNextAction[id] == MINIGUN_ACT_FIRE || g_iNextAction[id] == MINIGUN_ACT_SPINNING)
		{
			trigger_mode(id, MINIGUN_ACT_LOAD_DOWN);
		}
		else if(g_iNextAction[id] != MINIGUN_ACT_IDLE)
		{
			trigger_mode(id, MINIGUN_ACT_IDLE);
		}

		buttons &= ~IN_ATTACK;
		buttons &= ~IN_ATTACK2;
		set_uc(uc_handle, UC_Buttons, buttons);
	}
}

// minigun triggered
trigger_mode(id, MINIGUN_ACTIVITY:type)
{
	static Float:gtime;
	gtime = get_gametime();

	static iMinigun;
	iMinigun = IsUserHoldingMinigun(id);
	
	if(iMinigun <= 0)
	{
		return;
	}

	switch( type )
	{
		case MINIGUN_ACT_IDLE:
		{
			if(g_flNextActionTime[id] <= gtime)
			{
				native_playanim(id, random_num(anim_idle, anim_idle2));
				g_iNextAction[id] = MINIGUN_ACT_IDLE;
				g_flNextActionTime[id] = gtime;
			}

			set_pdata_float(iMinigun, offset_m_flTimeWeaponIdle, gtime + ANIME_IDLE_TIME, CBASE_PLAYER_WEAPON_LINUX_DIFF);
			set_pdata_float(iMinigun, offset_m_flNextPrimaryAttack, gtime, CBASE_PLAYER_WEAPON_LINUX_DIFF);
			set_pdata_float(iMinigun, offset_m_flNextSecondaryAttack, gtime, CBASE_PLAYER_WEAPON_LINUX_DIFF);
		}
		case MINIGUN_ACT_LOAD_UP:
		{
			if(g_flNextActionTime[id] <= gtime)
			{
				emit_sound(id, CHAN_WEAPON, g_szMinigun_sounds[SND_MINIGUN_SPINUP], 1.0, ATTN_NORM, 0, PITCH_NORM);
				native_playanim(id, anim_spinup);
				g_iNextAction     [id] = MINIGUN_ACT_SPINNING;
				g_flNextActionTime[id] = gtime + LOADUP_TIME;
			}

			set_pdata_float(iMinigun, offset_m_flTimeWeaponIdle, gtime + 9999.0, CBASE_PLAYER_WEAPON_LINUX_DIFF);
			set_pdata_float(iMinigun, offset_m_flNextPrimaryAttack, gtime, CBASE_PLAYER_WEAPON_LINUX_DIFF);
			set_pdata_float(iMinigun, offset_m_flNextSecondaryAttack, gtime, CBASE_PLAYER_WEAPON_LINUX_DIFF);
		}
		case MINIGUN_ACT_FIRE:
		{
			if(g_flNextActionTime[id] <= gtime)
			{
				g_bCanFire[id] = true;
			}

			if(g_bCanFire[id])
			{
				if(fire_minigun_bullet(id, iMinigun))
				{
					native_playanim(id, anim_spinfire);
					emit_sound(id, CHAN_WEAPON, g_szMinigun_sounds[SND_MINIGUN_SHOOT], 1.0, ATTN_NORM, 0, PITCH_NORM);
				}
				else
				{
					native_playanim(id, anim_spinidle);
					emit_sound(id, CHAN_WEAPON, g_noammo_sounds[random(sizeof g_noammo_sounds)], 1.0, ATTN_NORM, 0, PITCH_NORM);
				}

				g_flNextActionTime[id] = gtime + get_pcvar_float(g_pcvar_mg_fire_rate);
				g_iNextAction     [id] = MINIGUN_ACT_FIRE;
				g_bCanFire		  [id] = false;
			}

			set_pdata_float(iMinigun, offset_m_flTimeWeaponIdle, gtime + 9999.0, CBASE_PLAYER_WEAPON_LINUX_DIFF);
			set_pdata_float(iMinigun, offset_m_flNextPrimaryAttack, gtime, CBASE_PLAYER_WEAPON_LINUX_DIFF);
			set_pdata_float(iMinigun, offset_m_flNextSecondaryAttack, gtime, CBASE_PLAYER_WEAPON_LINUX_DIFF);
		}
		case MINIGUN_ACT_SPINNING:
		{
			if(g_flNextActionTime[id] <= gtime)
			{
				g_bCanFire[id] = true;

				emit_sound(id, CHAN_WEAPON, g_szMinigun_sounds[SND_MINIGUN_SPIN], 1.0, ATTN_NORM, 0, PITCH_NORM);
				native_playanim(id, anim_spinidle);
				g_iNextAction[id] = MINIGUN_ACT_SPINNING;

				static Float:spin_time = 0.0; if(spin_time == 0.0) spin_time = (13.0 / 30.0);
				g_flNextActionTime[id] = gtime + spin_time;
			}

			set_pdata_float(iMinigun, offset_m_flTimeWeaponIdle, gtime + 9999.0, CBASE_PLAYER_WEAPON_LINUX_DIFF);
			set_pdata_float(iMinigun, offset_m_flNextPrimaryAttack, gtime, CBASE_PLAYER_WEAPON_LINUX_DIFF);
			set_pdata_float(iMinigun, offset_m_flNextSecondaryAttack, gtime, CBASE_PLAYER_WEAPON_LINUX_DIFF);
		}
		case MINIGUN_ACT_LOAD_DOWN:
		{
			if(g_flNextActionTime[id] <= gtime)
			{
				g_bCanFire[id] = false;

				native_playanim(id, anim_spinidledown);
				emit_sound(id, CHAN_WEAPON, g_szMinigun_sounds[SND_MINIGUN_SPINDOWN], 1.0, ATTN_NORM, 0, PITCH_NORM)
				g_flNextActionTime[id] = gtime + SHUTDOWN_TIME;
				g_iNextAction[id] = MINIGUN_ACT_IDLE;
			}

			set_pdata_float(iMinigun, offset_m_flTimeWeaponIdle, g_flNextActionTime[id], CBASE_PLAYER_WEAPON_LINUX_DIFF);
			set_pdata_float(iMinigun, offset_m_flNextPrimaryAttack, g_flNextActionTime[id], CBASE_PLAYER_WEAPON_LINUX_DIFF);
			set_pdata_float(iMinigun, offset_m_flNextSecondaryAttack, g_flNextActionTime[id], CBASE_PLAYER_WEAPON_LINUX_DIFF);
		}
	}
}

ham_strip_minigun(id)
{
	new wEnt = -1
	while((wEnt = engfunc(EngFunc_FindEntityByString, wEnt, "classname", MINIGUN_CLASSNAME)) > 0 && pev(wEnt, pev_owner) != id) {}

	if(!wEnt) return 0;

	if(get_pdata_cbase(id, offset_m_pActiveItem, CBASE_PLAYER_LINUX_DIFF) == wEnt) ExecuteHamB(Ham_Weapon_RetireWeapon,wEnt);

	if(!ExecuteHamB(Ham_RemovePlayerItem,id,wEnt)) return 0;

	set_pev(id, pev_weapons, pev(id, pev_weapons) & ~(1<<CSW_MINIGUN));
	ExecuteHamB(Ham_Item_Kill, wEnt);

	return 1;
}

