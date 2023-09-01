#include <amxmodx>
#include <amxmisc>
#include <jailbreak_core>
#include <cs_player_models_api>
#include <fun>
#include <fakemeta>

native register_realm(const realm_name[], iAccess=0);
forward realm_player_respawn(id, mask_realm);
forward realm_menu_select_pre(id, mask_realm, const newrealm_name[], const oldrealm_name[]);
forward realm_menu_select_post(id, mask_realm, const newrealm_name[], const oldrealm_name[]); 

new const REALM_NAME[] = "Ghost realm";

#define PLUGIN "[REALMS] Ghost Realm"
#define AUTHOR "Natsheh"

#if !defined MAX_PLAYERS
#define MAX_PLAYERS 32
#endif

new g_szModel_Ghost[MAX_CLASS_PMODEL_LENGTH],
 g_IsGhost,
 g_GhostRealm_Mask,
 g_pcvar_cooldown,
 g_pcvar_duration,
 g_pcvar_model_body,
 g_pcvar_model_skin,
 Float:g_fAbilityCooldown[MAX_PLAYERS+1];

static const g_szActivationSounds[][] = {
	"ambience/alien_creeper.wav",
	"ambience/alien_hollow.wav",
	"ambience/alien_powernode.wav",
	"ambience/des_wind1.wav",
	"ambience/des_wind2.wav",
	"ambience/pounder.wav"
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	g_pcvar_cooldown = register_cvar("realms_ghost_ability_cooldown", "10.0");
	g_pcvar_duration = register_cvar("realms_ghost_ability_visduration", "5.0");
	g_pcvar_model_body = register_cvar("realms_ghost_model_body", "9");
	g_pcvar_model_skin = register_cvar("realms_ghost_model_skin", "0");

	register_clcmd("activate_ghost_ability", "ghost_ability_activation");
	register_clcmd("drop", "clcmd_drop");

	g_GhostRealm_Mask = register_realm(REALM_NAME);
}

public plugin_precache()
{
	for(new i, loop = sizeof g_szActivationSounds; i < loop; i++)
	{
		precache_sound(g_szActivationSounds[i]);
	}

	jb_ini_get_keyvalue("GHOST REALM", "GHOST_MDL", g_szModel_Ghost, charsmax(g_szModel_Ghost));

	if(g_szModel_Ghost[0] != EOS)
	{
		new model_path[MAX_FILE_DIRECTORY_LEN];
		formatex(model_path, charsmax(model_path), "models/player/%s/%s.mdl", g_szModel_Ghost, g_szModel_Ghost);
		precache_model(model_path);
		formatex(model_path, charsmax(model_path), "models/player/%s/%sT.mdl", g_szModel_Ghost, g_szModel_Ghost);
		if (file_exists(model_path)) precache_model(model_path);
	}
}

public plugin_natives()
{
	register_native("is_user_ghost", "native_is_user_ghost");
}

public native_is_user_ghost(plugin, argc)
{
	new id = get_param(1);

	static iMaxPlayers = 0; if(!iMaxPlayers) iMaxPlayers = get_maxplayers();

	if (!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, ((id > iMaxPlayers) ? "Invalid player id #%d" : "User is not connected #%d"), id);
		return -1;
	}

	return check_flag(g_IsGhost, id) ? 1:0;
}

public clcmd_drop(id)
{
	if(!check_flag(g_IsGhost, id)) return PLUGIN_CONTINUE;

	ghost_ability_activation(id);
	return PLUGIN_HANDLED;
}

public realm_player_respawn(id, realm_mask)
{
	if (realm_mask != g_GhostRealm_Mask)
	{
		remove_flag(g_IsGhost, id);
		return;
	}

	set_pev(id, pev_solid, SOLID_NOT);
	set_pev(id, pev_movetype, MOVETYPE_NOCLIP);
	set_pev(id, pev_rendermode, kRenderTransAlpha);
	set_pev(id, pev_renderamt, 50.0);
}

public realm_menu_select_post(id, realm_mask)
{
	if (realm_mask != g_GhostRealm_Mask)
	{
		remove_flag(g_IsGhost, id);
		return;
	}

	set_flag(g_IsGhost, id);
	if(g_szModel_Ghost[0] != EOS)
	{
		cs_set_player_model(id, g_szModel_Ghost);
		set_pev(id, pev_body, get_pcvar_num(g_pcvar_model_body));
		set_pev(id, pev_skin, get_pcvar_num(g_pcvar_model_skin));
	}

	cprint_chat(id, _, "Welcome to !gGhost !trealm!y, press the 'drop' key !g[ G ] !tto activate your scaring ability!g!");
}

#if AMXX_VERSION_NUM > 182
public client_disconnected(id)
#else
public client_disconnect(id)
#endif
{
	remove_task(id);
	remove_flag(g_IsGhost, id);
}

public ghost_ability_activation(id)
{
	if(!check_flag(g_IsGhost, id) || task_exists(id)) return PLUGIN_HANDLED;

	new Float:fGameTime;
	if(g_fAbilityCooldown[id] > (fGameTime=get_gametime()))
	{
		client_print(id, print_center, "You ability is in a cooldown %.2f!", (g_fAbilityCooldown[id] - fGameTime));
		return PLUGIN_HANDLED;
	}

	g_fAbilityCooldown[id] = fGameTime + get_pcvar_float(g_pcvar_cooldown);
	make_user_invisible(id, .bInvisible=false);
	set_task(get_pcvar_float(g_pcvar_duration), "ghost_ability_deactivation", id);
	client_print(id, print_center, "You're now visible!");
	emit_sound(id, CHAN_BODY, g_szActivationSounds[random(sizeof g_szActivationSounds)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	return PLUGIN_HANDLED;
}

make_user_invisible(id, bool:bInvisible=true)
{
	set_pev(id, pev_groupinfo, bInvisible ? g_GhostRealm_Mask : 0);
}

public ghost_ability_deactivation(id)
{
	if(!check_flag(g_IsGhost, id)) return;

	make_user_invisible(id, .bInvisible=true);
	client_print(id, print_center, "You're now no longer visible!");
}

