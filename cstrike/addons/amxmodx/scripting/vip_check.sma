/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <hamsandwich>
#include <vip_core>

#define PLUGIN "[ VIP ] Check"
#define VERSION "1.0"
#define AUTHOR "Natsheh"

#define szFLAG "b"
#define iFLAG 'b'

new const g_szFlag_Info[] = "accessibility in the vip list";
new g_iMsg_ScoreAttrib;
const SCOREATTRIB_FLAG_VIP = (1<<2);

public vip_flag_creation()
{
	register_vip_flag(iFLAG, g_szFlag_Info);
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd("say /vips", "check_vips");
	register_clcmd("say !vips", "check_vips");
	register_clcmd("say_team /vips", "check_vips");
	register_clcmd("say_team !vips", "check_vips");
	
	g_iMsg_ScoreAttrib = get_user_msgid("ScoreAttrib");
	
	register_message(g_iMsg_ScoreAttrib, "msg_ScoreAttrib");
	RegisterHam(Ham_Spawn, "player", "fw_player_spawn_post", 1)
}

public fw_player_spawn_post(id)
{
	if(!is_user_alive(id) || !(get_user_vip(id) & read_flags(szFLAG))) return;
	
	message_begin(MSG_ALL, g_iMsg_ScoreAttrib);
	write_byte(id);
	write_byte(SCOREATTRIB_FLAG_VIP); // FLAG VIP
	message_end();
}

public msg_ScoreAttrib(MsgID, MsgDest, MsgReciver) {
	// Checking for valid user
	if(get_user_vip(get_msg_arg_int(1)) & read_flags(szFLAG))
		set_msg_arg_int(2, ARG_BYTE, (get_msg_arg_int(2)|SCOREATTRIB_FLAG_VIP));
}

public check_vips(id)
{
	new sBuffer[128], sVipname[32], sSlots[34], userid, vs, i;
	
	formatex(sBuffer, charsmax(sBuffer), "!t[-!gV!tI!gP's!t-] !gOnline: ");
	
	new z;
	if((z = get_vips_online()))
	{
		new players[32], pnum, iBitsFLAG = read_flags(szFLAG);
		get_players(players, pnum, "ch");
		
		for(i = 0; i < pnum; i++)
		{
			userid = players[i];
			
			if(!(get_user_vip(userid) & iBitsFLAG))
				continue;
			
			vs ++;
			get_user_name(userid, sVipname, charsmax(sVipname));
			formatex(sSlots, charsmax(sSlots), "!t%s!g%s", sVipname, z == vs ? ".":", ");
			add(sBuffer, charsmax(sBuffer), sSlots);
		}
	}
	else if(!get_vips_online())
	{
		add(sBuffer, charsmax(sBuffer), "!tThere are no vips !gOnline!");
	}
	
	chat_message(id, sBuffer);
}

get_vips_online()
{
	new players[32], pnum, vs, i, userid;
	get_players(players, pnum, "ch");
	
	for(i = 0; i < pnum; i++)
	{
		userid = players[i];
		
		if(!(get_user_vip(userid) & read_flags(szFLAG)))
			continue;
		
		vs ++;
	}
	
	return vs;
}

chat_message(index, const message[], any:...)
{
	new sBuffer[192], dest;
	vformat(sBuffer[1], charsmax(sBuffer)-1, message, 3);
	
	sBuffer[0] = '^1';
	
	replace_all(sBuffer, charsmax(sBuffer), "!y", "^1");
	replace_all(sBuffer, charsmax(sBuffer), "!n", "^1");
	replace_all(sBuffer, charsmax(sBuffer), "!t", "^3");
	replace_all(sBuffer, charsmax(sBuffer), "!g", "^4");
	
	sBuffer[191] = 0;
	
	if(index > 0)
	{
		dest = MSG_ONE;
	}
	else
	{
		dest = MSG_ALL;
	}
	
	static iMsg_SayText = 0; iMsg_SayText = !iMsg_SayText ? get_user_msgid("SayText") : iMsg_SayText ;

	message_begin(dest, iMsg_SayText, {0, 0, 0}, index);
	write_byte(index);
	write_string(sBuffer);
	message_end();
}