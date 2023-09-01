#include <amxmodx>
#include <hamsandwich>
//#include <fun>
#include <cstrike>
#include <vip_core>

#define PLUGIN "[ VIP ] ARMOR"
#define VERSION "1.0"
#define AUTHOR "Natsheh"

#define STR_FLAG "a"
#define INT_FLAG 'a'

#define MAX_ARMOR_PACK 999

new g_pcvar_apamount, g_pcvar_aptype;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	g_pcvar_aptype = register_cvar("vip_armor_type", "vest & helmet");
	g_pcvar_apamount = register_cvar("vip_armor_amount", "100");

	RegisterHam(Ham_Spawn, "player", "fw_player_spawn_post", .Post = true);
}

public vip_flag_creation() {
	register_vip_flag(INT_FLAG, "Gains free armor on each spawn");
}

public fw_player_spawn_post(id)
{
	if(is_user_alive(id) && (get_user_vip(id) & read_flags(STR_FLAG)))
	{
		new szType[20], CsArmorType:iArmorType = CS_ARMOR_NONE;
		get_pcvar_string(g_pcvar_aptype, szType, charsmax(szType));

		if(containi(szType, "kevlar") != -1)
		{
			iArmorType = CS_ARMOR_KEVLAR;
		}
		
		if(containi(szType, "helmet") != -1)
		{
			iArmorType = CS_ARMOR_VESTHELM;
		}

		// use Cstrike Module ?
		cs_set_user_armor(id, clamp(get_pcvar_num(g_pcvar_apamount), 0, MAX_ARMOR_PACK), iArmorType);

		// use Fun module ?
		// set_user_armor(id, get_pcvar_num(g_pcvar_apamount));
	}
}
