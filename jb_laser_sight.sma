/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <jailbreak_core>
#include <fakemeta>

#define PLUGIN "[JB] SHOP: Laser sight"
#define AUTHOR "Natsheh"

#if !defined Origin_AimEndEyes
#define Origin_AimEndEyes 3
#endif

new g_laserbeam, g_has_laser, g_shopitem_id, Fw_FM_PlayerPreThinkPost;

const NO_WEAPON = (1<<0);
const MELEE_WEAPONS = (1<<CSW_KNIFE)|(1<<CSW_HEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_C4)|NO_WEAPON;

public plugin_precache()
{
	g_laserbeam = PRECACHE_SPRITE_I("sprites/laserbeam.spr");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	g_shopitem_id = register_jailbreak_shopitem("Laser Sight", "weapons attachment", 5000, TEAM_ANY);
}

public jb_shop_item_preselect(id, itemid)
{
	if(itemid == g_shopitem_id && check_flag(g_has_laser,id))
	{
		return JB_MENU_ITEM_UNAVAILABLE
	}
	return JB_IGNORED;
}

public jb_shop_item_bought(id, itemid)
{
	if(itemid == g_shopitem_id)
	{
		give_user_laser(id)
	}
}

give_user_laser(id)
{
	if(!check_flag(g_has_laser,id))
	{
		if(g_has_laser == 0 && !Fw_FM_PlayerPreThinkPost)
		{
			Fw_FM_PlayerPreThinkPost = register_forward(FM_PlayerPreThink, "FM_PlayerPreThinkPost", true);
		}
		
		set_flag(g_has_laser,id);
	}
}

remove_user_laser(id)
{
	if(check_flag(g_has_laser,id))
	{
		remove_flag(g_has_laser,id);
		
		if(g_has_laser == 0 && Fw_FM_PlayerPreThinkPost > 0)
		{
			unregister_forward(FM_PlayerPostThink, Fw_FM_PlayerPreThinkPost, true);
			Fw_FM_PlayerPreThinkPost = 0;
		}
	}
}

public FM_PlayerPreThinkPost(id)
{
	if(!check_flag(g_has_laser,id)) return;
	
	if(!is_user_alive(id))
	{
		remove_user_laser(id);
		return;
	}
	
	if((1<<get_user_weapon(id)) & MELEE_WEAPONS) return;
	
	static hOrigin[3], iTarget;
	get_user_origin(id, hOrigin, Origin_AimEndEyes);
	
	#if AMXX_VERSION_NUM > 182
	get_user_aiming(id, iTarget);
	#else
	static null;
	get_user_aiming(id, iTarget, null);
	#endif
	
	create_laserbeam(id, hOrigin, (32 >= iTarget > 0) ? 255:0, (32 >= iTarget > 0) ? 0:255);
	
}

create_laserbeam(id, horigin[3], red=0, green=255, blue=0, brightness=200, width=5)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMENTPOINT)
	write_short(id|0x1000)
	write_coord(horigin[0])	// End X
	write_coord(horigin[1])	// End Y
	write_coord(horigin[2])	// End Z
	write_short(g_laserbeam)     // Sprite
	write_byte(1)			// Start frame
	write_byte(10)  		// Frame rate
	write_byte(1)			// Life
	write_byte(width)		// Line width
	write_byte(0)			// Noise
	write_byte(red)	    	// Red
	write_byte(green)			// Green
	write_byte(blue)			// Blue
	write_byte(brightness) 		// Brightness
	write_byte(10)			// Scroll speed
	message_end()
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
