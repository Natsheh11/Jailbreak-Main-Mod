
#if defined _inc_get_team_fix
  #endinput
#endif
#define _inc_get_team_fix


#define get_team_fix
#if defined get_team_fix
#include <fakemeta>
#define OFFSET_TEAM	114
#define fm_get_user_team(%1)	get_pdata_int(%1,OFFSET_TEAM)
#define fm_set_user_team(%1,%2)	set_pdata_int(%1,OFFSET_TEAM,%2)

#define get_user_team get_user_team2
#define get_players get_players2

stock get_user_team2(id, team[]="", len=0)
{
	static const szTEAM[][] = {
		"UNASSIGNED",
		"TERRORIST",
		"CT",
		"SPECTATOR"
	}
	
	new x = fm_get_user_team(id);
	
	if( x >= 0 && x < sizeof szTEAM) copy(team, len, szTEAM[x]);
	return x;
}

stock get_players2(players[32], &num, const flags[]="", const team[]="")
{
	static iMaxPlayers = 0;
	if(!iMaxPlayers) iMaxPlayers = get_maxplayers();
	
	static const szTEAM[][] = {
		"UNASSIGNED",
		"TERRORIST",
		"CT",
		"SPECTATOR"
	}
	
	new iTeam = -1;
	for(new i = 0; i < sizeof szTEAM; i++)
	{
		if(equal(szTEAM[i], team))
		{
			iTeam = i;
			break;
		}
	}
	
	new xnum;
	
	for(new szName[32], i = 1; i <= iMaxPlayers; i++)
	{
		if( !( is_user_connected(i) || (contain(flags, "i") != -1 && is_user_connecting(i)) ) ) continue;
		
		if(contain(flags, "a") != -1 && !is_user_alive(i)) continue;
		if(contain(flags, "b") != -1 && is_user_alive(i)) continue;
		if(contain(flags, "c") != -1 && is_user_bot(i)) continue;
		if(contain(flags, "d") != -1 && !is_user_bot(i)) continue;
		if(contain(flags, "e") != -1 && iTeam != -1)
			if(fm_get_user_team(i) != iTeam) continue;

		if(contain(flags, "f") != -1)
		{
			get_user_name(i, szName, charsmax(szName));
			if(containi(szName, team) == -1) continue;
		}

		if(contain(flags, "h") != -1 && is_user_hltv(i)) continue;
		
		players[xnum++] = i;
	}
	
	num = xnum;
	return num;
}
#endif
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
