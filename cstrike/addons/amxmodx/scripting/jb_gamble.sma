#include <amxmodx>
#include <amxmisc>
#include <jailbreak_core>

#define PLUGIN "[JB] Gamble"
#define AUTHOR "Natsheh"

new MINAMMOUNT, MAXAMMOUNT, cv[4], Float:gamble_time[33];

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_clcmd("say", "cmd_Say")
	register_clcmd("say_team", "cmd_Say")
	
	cv[0] = register_cvar("jb_gamble_maxammount", "1000000")
	cv[1] = register_cvar("jb_gamble_minammount", "1000")
	cv[2] = register_cvar("jb_gamble_cooldown", "5")
	cv[3] = register_cvar("jb_gamble_advertising_cash", "10000")
}


public cmd_Say(iPlayer) 
{ 
	new sString[32];
	read_args(sString, charsmax(sString)) 
	remove_quotes(sString) 
	
	new cmd[16], szValue[16]
	strtok(sString, cmd,charsmax(cmd), szValue,charsmax(szValue), ' ')
	
	if(equali(cmd, "/gamble")) 
	{ 
		new iAmmount = str_to_num(szValue);
		MINAMMOUNT = get_pcvar_num(cv[1]); 
		MAXAMMOUNT = get_pcvar_num(cv[0]); 
		
		new Float:gtime = get_gametime();
		
		
		if(gamble_time[iPlayer] > gtime)
		{
			cprint_chat(iPlayer, _, "You try again gambling in !g%.2f seconds!t!", (gamble_time[iPlayer]-gtime))
			return 1;
		}
		if(!iAmmount) 
		{ 
			cprint_chat(iPlayer, _, "Usage: /gamble < ammount >") 
			return 1
		} 
		new jbcash = jb_get_user_cash(iPlayer);
		if( jbcash < MINAMMOUNT) 
		{ 
			cprint_chat(iPlayer, _, "You should have at least %i before gamble.", MINAMMOUNT) 
			return 1
		} 
		
		if( iAmmount < MINAMMOUNT) 
		{ 
			cprint_chat(iPlayer, _, "You have reached minumum ammount ( %i ).", MINAMMOUNT) 
			return 1
		} 
		
		if( iAmmount > MAXAMMOUNT ) 
		{ 
			cprint_chat(iPlayer, _, "You have reached maxiumum ammount ( %i )", MAXAMMOUNT) 
			return 1
		} 
		
		if ( jbcash < iAmmount ) 
		{ 
			cprint_chat(iPlayer, _, "You have only %i", jbcash) 
			return  1
		}
		
		gamble_time[iPlayer] = gtime + get_pcvar_float(cv[2]);
		
		new woncash = iAmmount * 2, szName[32], ad_cash = get_pcvar_num(cv[3]); 
		get_user_name(iPlayer, szName, charsmax(szName))
		switch( random(4) ) 
		{ 
			case 0,3:  
			{ 
				jb_set_user_cash(iPlayer, (jbcash + woncash))
				cprint_chat(iPlayer, _, "Congratulations!, You have won $%i!", woncash)
				
				if(ad_cash <= iAmmount)
					cprint_chat(0, _, "%s gambled %i, and won $%i!", szName, iAmmount, woncash) 
			} 
			
			case 1,2: 
			{ 
				jb_set_user_cash(iPlayer,( jbcash - iAmmount ))
				cprint_chat(iPlayer, _, "Oh no... You lost %i.", iAmmount)  
				
				if(ad_cash <= iAmmount)
					cprint_chat(0, _, "%s gambled $%i, and lost them.", szName, iAmmount) 
			} 
		} 
		return 1
	}
	
	if(equali(cmd, "/gambleall") || equali(cmd, "/allin")) 
	{ 
		new jbcash = jb_get_user_cash(iPlayer) , szName[32]
		
		if ( jbcash <= MINAMMOUNT ) 
		{ 
			cprint_chat(iPlayer, _, "You should have at least %i to gamble your cash.", MINAMMOUNT) 
			return 1
		} 
		get_user_name(iPlayer, szName, charsmax(szName)) 
		
		switch( random_num(1, 2) ) 
		{ 
			case 1:  
			{ 
				jb_set_user_cash(iPlayer, jbcash += jbcash) 
				cprint_chat(iPlayer, _, "Congratulations!, You got doubles your cash !")  
				cprint_chat(0, _, "%s gambled all his cash, and got doubles!", szName) 
			} 
			
			case 2: 
			{ 
				jb_set_user_cash(iPlayer, (jbcash - jbcash)) 
				cprint_chat(iPlayer, _, "Oh no... You lost all your money.")  
				cprint_chat(0, _, "%s gambled all his cash, and lost them all...", szName) 
			} 
		}
		return 1
	}
	return 0
}  
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
