
#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <nvault>
#include <jailbreak_core>

#pragma dynamic 32768

#define PLUGIN	"BlackJack"
#define AUTHOR	"Albernaz o Carniceiro Demoniaco"

native jailbreak_reg_gambling_game(const func_target[], const gamble_gamename[], gamble_minimum_amount=1000, gamble_game_access=0);

new const CFG_FILENAME[] = "blackjack.ini";
new const CFG_DICTIONARY[] = "blackjack.txt";

const CFG_MAX_PARAM_SIZE = 64;
new CFG_SITE_URL[CFG_MAX_PARAM_SIZE];
new CFG_CARD_PATH[CFG_MAX_PARAM_SIZE];
new CFG_IMAGES_PATH[CFG_MAX_PARAM_SIZE];

enum CVARS_LIST
{
	BET_VALUE_MIN,
	CHAT_MESSAGES, // Chat messages announcing the results of the games played
	ENABLED		// 0 - game disabled , 1 - game enabled(Bad load of the cfg file sets it to 0
}

new CVARS[CVARS_LIST];
new CVARS_MIN[CVARS_LIST];
new CVARS_MAX[CVARS_LIST];

const N_CARDS_PER_SUIT = 13;
const N_SUITS = 4;

new cardFiguresNames[N_CARDS_PER_SUIT][] = { "Ace" , "Two", "Three", "Four", "Five" , "Six", "Seven", "Eight", "Nine", "Ten", "Jack","Queen","King" } ;
new cardSuitNames[N_SUITS][] = { "Hearts" ,"Diamonds","Clubs","Spades"};

enum CARD
{
	SUIT,
	VALUE,
	CARD_ID
}

const N_IDS = MAX_PLAYERS+1;
const N_CARDS = 52;

new decks[N_IDS][N_CARDS][CARD];
new decksCount[N_IDS];

const PER_PLAYER_MAX_CARDS = 21;

new decksCroupier[N_IDS][PER_PLAYER_MAX_CARDS][CARD];
new decksCroupierCount[N_IDS];

new decksPlayers[N_IDS][PER_PLAYER_MAX_CARDS][CARD];
new decksPlayersCount[N_IDS];

new betValues[N_IDS];

enum GameStatus (+=1)
{
	GameState_StartGame = 0,
	GameState_InGame,
	GameState_GameOver
}

new GameStatus:g_Player_GameState[N_IDS];

new g_szBuffer[1280];
new g_vault;

#define get_user_money(%1) jb_get_user_cash(%1)
#define set_user_money(%1,%2) jb_set_user_cash(%1,%2)

public plugin_cfg()
{	
	handleConfigFile();	
}

public plugin_end()
{
	if(g_vault != INVALID_HANDLE)
	{
		nvault_close(g_vault);
	}
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_dictionary(CFG_DICTIONARY);
	
	handleCvars();
	
	jailbreak_reg_gambling_game("blackjack_selected", "Black Jack", get_pcvar_num(CVARS[BET_VALUE_MIN]));
	
	g_vault = nvault_open("blackjack_temp");
	
	if(g_vault == INVALID_HANDLE)
	{
		log_error(AMX_ERR_GENERAL, "Couldn't open nvault file (blackjack_temp).");
	}
}

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif

public client_disconnect(id)
{
	if(g_Player_GameState[id] == GameState_InGame || g_Player_GameState[id] == GameState_GameOver)
	{
		SavePlayerBlackJackTable(id);
	}

	g_Player_GameState[id] = GameState_StartGame;
	betValues[id] = 0;
}

LoadPlayerBlackJackTable(id)
{
	new szKey[64], szAuthID[32], iTimeStamp;
	get_user_authid(id, szAuthID, charsmax(szAuthID));

	formatex(szKey, charsmax(szKey), "%s_GAMESTATE", szAuthID);
	g_Player_GameState[id] = any:nvault_get(g_vault, szKey);

	if(g_Player_GameState[id] == GameState_StartGame)
	{
		return;
	}

	formatex(szKey, charsmax(szKey), "%s_BetValue", szAuthID);
	betValues[id] = nvault_get(g_vault, szKey);

	formatex(szKey, charsmax(szKey), "%s_CROUPIER_DECK_C", szAuthID);
	decksCroupierCount[id] = nvault_get(g_vault, szKey);

	formatex(szKey, charsmax(szKey), "%s_PLAYER_DECK_C", szAuthID);
	decksPlayersCount[id] = nvault_get(g_vault, szKey);

	new szCard[32], szSuit[16];

	const SizeOfCardFiguresNames = sizeof cardFiguresNames;
	const SizeOfCardSuitNames = sizeof cardSuitNames;

	formatex(szKey, charsmax(szKey), "%s_CROUPIER_DECK", szAuthID);
	if(nvault_lookup(g_vault, szKey, g_szBuffer, charsmax(g_szBuffer), iTimeStamp))
	{
		for(new i, x, iCroupierSum, maxloop = decksCroupierCount[id]; i < maxloop; i++)
		{
			argbreak(g_szBuffer, szCard, charsmax(szCard), g_szBuffer, charsmax(g_szBuffer));

			trim(szCard);
			remove_quotes(szCard);

			if(szCard[0] != EOS)
			{
				strtok(szCard, szCard, charsmax(szCard), szSuit, charsmax(szSuit), .token = '.');

				for(x = 0; x < SizeOfCardFiguresNames; x++)
				{
					if(equal(szCard, cardFiguresNames[x])) break;
				}

				if( (0 <= x < SizeOfCardFiguresNames) )
				{
					decksCroupier[id][i][CARD_ID] = x;
				}
				else
				{
					log_error(AMX_ERR_NATIVE, "Error Invalid Card name : '%s'", szCard);
				}

				switch( x )
				{
					case 0:
					{
						if(iCroupierSum > 10)
						{
							for(x = 0; x < i; x++)
							{
								if(decksCroupier[id][x][CARD_ID] == 0 /* ACE */)
								{
									decksCroupier[id][x][VALUE] =  1;
								}
							}

							decksCroupier[id][i][VALUE] =  1;
						}
						else
						{
							decksCroupier[id][i][VALUE] =  11;
						}

					}
					case 1..9: decksCroupier[id][i][VALUE] = x + 1;
					case 10..12: decksCroupier[id][i][VALUE] = 10;
				}

				iCroupierSum += decksCroupier[id][i][VALUE];

				for(x = 0; x < SizeOfCardSuitNames; x++)
				{
					if(equal(szSuit, cardSuitNames[x])) break;
				}

				if( (0 <= x < SizeOfCardSuitNames) )
				{
					decksCroupier[id][i][SUIT] = x;
				}
				else
				{
					log_error(AMX_ERR_NATIVE, "Error Invalid Card Suit name : '%s'", szSuit);
				}
			}
		}
	}

	formatex(szKey, charsmax(szKey), "%s_PLAYER_DECK", szAuthID);
	if(nvault_lookup(g_vault, szKey, g_szBuffer, charsmax(g_szBuffer), iTimeStamp))
	{
		for(new i, x, iPlayerSum, maxloop = decksPlayersCount[id]; i < maxloop; i++)
		{
			argbreak(g_szBuffer, szCard, charsmax(szCard), g_szBuffer, charsmax(g_szBuffer));

			trim(szCard);
			remove_quotes(szCard);

			if(szCard[0] != EOS)
			{
				strtok(szCard, szCard, charsmax(szCard), szSuit, charsmax(szSuit), .token = '.');

				for(x = 0; x < SizeOfCardFiguresNames; x++)
				{
					if(equal(szCard, cardFiguresNames[x])) break;
				}

				if( (0 <= x < SizeOfCardFiguresNames) )
				{
					decksPlayers[id][i][CARD_ID] = x;
				}
				else
				{
					log_error(AMX_ERR_NATIVE, "Error Invalid Card name : '%s'", szCard);
				}

				switch( x )
				{
					case 0:
					{
						if(iPlayerSum > 10)
						{
							for(x = 0; x < i; x++)
							{
								if(decksPlayers[id][x][CARD_ID] == 0 /* ACE */)
								{
									decksPlayers[id][x][VALUE] =  1;
								}
							}

							decksPlayers[id][i][VALUE] =  1;
						}
						else
						{
							decksPlayers[id][i][VALUE] =  11;
						}

					}
					case 1..9: decksPlayers[id][i][VALUE] = x + 1;
					case 10..12: decksPlayers[id][i][VALUE] = 10;
				}

				iPlayerSum += decksPlayers[id][i][VALUE];

				for(x = 0; x < SizeOfCardSuitNames; x++)
				{
					if(equal(szSuit, cardSuitNames[x])) break;
				}

				if( (0 <= x < SizeOfCardSuitNames) )
				{
					decksPlayers[id][i][SUIT] = x;
				}
				else
				{
					log_error(AMX_ERR_NATIVE, "Error Invalid Card Suit name : '%s'", szSuit);
				}
			}
		}
	}

	LoadRemainingDeck(id);
}

LoadRemainingDeck(id)
{
	const SizeOfCardFiguresNames = sizeof cardFiguresNames;
	const SizeOfCardSuitNames = sizeof cardSuitNames;

	new szAuthID[32], szSuit[20], szValue[4], iTimeStamp;
	get_user_authid(id, szAuthID, charsmax(szAuthID));

	static szKey[64], szCard[32];
	formatex(szKey, charsmax(szKey), "%s_REMAINING_DECK_C", szAuthID);
	decksCount[id] = nvault_get(g_vault, szKey);

	formatex(szKey, charsmax(szKey), "%s_REMAINING_DECK", szAuthID);
	if(nvault_lookup(g_vault, szKey, g_szBuffer, charsmax(g_szBuffer), iTimeStamp))
	{
		for(new i, x, maxloop = decksCount[id]; i < maxloop; i++)
		{
			argbreak(g_szBuffer, szCard, charsmax(szCard), g_szBuffer, charsmax(g_szBuffer));

			trim(szCard);
			remove_quotes(szCard);

			if(szCard[0] != EOS)
			{
				strtok(szCard, szCard, charsmax(szCard), szSuit, charsmax(szSuit), .token = '.');
				strtok(szSuit, szSuit, charsmax(szSuit), szValue, charsmax(szValue), .token = '.');

				decks[id][i][VALUE] = str_to_num(szValue);

				for(x = 0; x < SizeOfCardFiguresNames; x++)
				{
					if(equal(szCard, cardFiguresNames[x])) break;
				}

				if( (0 <= x < SizeOfCardFiguresNames) )
				{
					decks[id][i][CARD_ID] = x;
				}

				for(x = 0; x < SizeOfCardSuitNames; x++)
				{
					if(equal(szSuit, cardSuitNames[x])) break;
				}

				if( (0 <= x < SizeOfCardSuitNames) )
				{
					decks[id][i][SUIT] = x;
				}
			}
		}
	}
}

SaveRemainingDeck(id)
{
	const iBufferMaxSize = charsmax(g_szBuffer);

	new iLen = formatex(g_szBuffer, iBufferMaxSize, "^"%s.%s.%d^"", cardFiguresNames[ decks[id][0][CARD_ID] ], cardSuitNames[ decks[id][0][SUIT] ], decks[id][0][VALUE]);

	for(new i = 1, maxloop = decksCount[id]; i < maxloop; i++)
	{
		iLen += formatex(g_szBuffer[iLen], iBufferMaxSize - iLen, " ^"%s.%s.%d^"", cardFiguresNames[ decks[id][i][CARD_ID] ], cardSuitNames[ decks[id][i][SUIT]], decks[id][i][VALUE]);
	}

	new szAuthID[32], szKey[64];
	get_user_authid(id, szAuthID, charsmax(szAuthID));

	formatex(szKey, charsmax(szKey), "%s_REMAINING_DECK", szAuthID);
	nvault_set(g_vault, szKey, g_szBuffer);

	formatex(szKey, charsmax(szKey), "%s_REMAINING_DECK_C", szAuthID);
	num_to_str(decksCount[id], g_szBuffer, iBufferMaxSize);
	nvault_set(g_vault, szKey, g_szBuffer);
}

SavePlayerBlackJackTable(id)
{
	new iLen = formatex(g_szBuffer, charsmax(g_szBuffer), "^"%s.%s^"", cardFiguresNames[ decksCroupier[id][0][CARD_ID]], cardSuitNames[ decksCroupier[id][0][SUIT]]);

	for(new i = 1, maxloop = decksCroupierCount[id]; i < maxloop; i++)
	{
		iLen += formatex(g_szBuffer[iLen], charsmax(g_szBuffer) - iLen, " ^"%s.%s^"", cardFiguresNames[ decksCroupier[id][i][CARD_ID]], cardSuitNames[ decksCroupier[id][i][SUIT]]);
	}

	new szAuthID[32], szKey[64];
	get_user_authid(id, szAuthID, charsmax(szAuthID));

	formatex(szKey, charsmax(szKey), "%s_CROUPIER_DECK", szAuthID);
	nvault_set(g_vault, szKey, g_szBuffer);

	formatex(szKey, charsmax(szKey), "%s_CROUPIER_DECK_C", szAuthID);
	num_to_str(decksCroupierCount[id], g_szBuffer, charsmax(g_szBuffer));
	nvault_set(g_vault, szKey, g_szBuffer);

	iLen = formatex(g_szBuffer, charsmax(g_szBuffer), "^"%s.%s^"", cardFiguresNames[ decksPlayers[id][0][CARD_ID]], cardSuitNames[ decksPlayers[id][0][SUIT]]);

	for(new i = 1, maxloop = decksPlayersCount[id]; i < maxloop; i++)
	{
		iLen += formatex(g_szBuffer[iLen], charsmax(g_szBuffer) - iLen, " ^"%s.%s^"", cardFiguresNames[ decksPlayers[id][i][CARD_ID]], cardSuitNames[ decksPlayers[id][i][SUIT]]);
	}

	formatex(szKey, charsmax(szKey), "%s_PLAYER_DECK", szAuthID);
	nvault_set(g_vault, szKey, g_szBuffer);

	formatex(szKey, charsmax(szKey), "%s_PLAYER_DECK_C", szAuthID);
	num_to_str(decksPlayersCount[id], g_szBuffer, charsmax(g_szBuffer));
	nvault_set(g_vault, szKey, g_szBuffer);

	formatex(szKey, charsmax(szKey), "%s_BetValue", szAuthID);
	num_to_str(betValues[id], g_szBuffer, charsmax(g_szBuffer));
	nvault_set(g_vault, szKey, g_szBuffer);

	formatex(szKey, charsmax(szKey), "%s_GAMESTATE", szAuthID);
	num_to_str(any:g_Player_GameState[id], g_szBuffer, charsmax(g_szBuffer));
	nvault_set(g_vault, szKey, g_szBuffer);

	SaveRemainingDeck(id);
}

public client_putinserver(id)
{
	g_Player_GameState[id] = GameState_StartGame;
	betValues[id] = 0;

	LoadPlayerBlackJackTable(id);
}

public blackjack_selected(id, gambling_amount, minimum_amount, paccess)
{
	if(!access(id, paccess))
	{
		client_print(id, print_center, "Access denied!");
		return;
	}
	
	if(g_Player_GameState[id] == GameState_InGame)
	{
		showMenuBlackJack(id);
	}
	else
	{
		if(gambling_amount < minimum_amount)
		{
			client_print(id, print_center, "Insufficient funds!");
			return;
		}
		
		betValues[id] = gambling_amount;
		startGame(id);
		showMenuBlackJack(id);
		motdShowTable(id);
	}

}

handleCvars()
{
	CVARS[BET_VALUE_MIN] = register_cvar("bj_min_bet_val", "100");
	CVARS[CHAT_MESSAGES] = register_cvar("bj_chat_msgs", "1");
	CVARS[ENABLED]		 = register_cvar("bj_enabled", "1");
	
	CVARS_MIN[BET_VALUE_MIN] = 100;
	CVARS_MIN[CHAT_MESSAGES] = 0;
	CVARS_MIN[ENABLED] = 0;
	
	CVARS_MAX[BET_VALUE_MIN] = 100000;
	CVARS_MAX[CHAT_MESSAGES] = 1;
	CVARS_MAX[ENABLED] = 1;
}

handleConfigFile()
{
	const configsDirLastIndex = 49;
	new configsDir[configsDirLastIndex+1];
	
	get_configsdir(configsDir,configsDirLastIndex);
	
	const fileNameLastIndex = configsDirLastIndex + 15;
	new fileName[fileNameLastIndex+1];
	formatex(fileName, charsmax(fileName), "%s/%s", configsDir, CFG_FILENAME);

	new sucess = 0;		
	
	if(file_exists(fileName))
	{
		new file = fopen(fileName,"rt");
		
		if(!file) 
		{
			set_fail_state("%s cannot open the file for reading!", CFG_FILENAME);
			return;
		}

		if( !feof(file) )
		{
			fgets (file, CFG_SITE_URL, CFG_MAX_PARAM_SIZE-1);
			trim(CFG_SITE_URL);
			sucess = 1;
		}
		
		if( !feof(file) )
		{
			fgets (file, CFG_CARD_PATH, CFG_MAX_PARAM_SIZE-1)
			trim(CFG_CARD_PATH);
		}
		else
			formatex(CFG_CARD_PATH,CFG_MAX_PARAM_SIZE-1,"");
		
		if( !feof(file) )
		{
			fgets (file, CFG_IMAGES_PATH, CFG_MAX_PARAM_SIZE-1);
			trim(CFG_IMAGES_PATH);
		}
		else
			formatex(CFG_IMAGES_PATH,CFG_MAX_PARAM_SIZE-1,"");

		fclose(file);
				
	}
	else
	{
		set_fail_state("%s file doesn't exist!", fileName);
	}
	
	set_pcvar_num(CVARS[ENABLED],sucess);
	
}

getCvar(CVARS_LIST:CVAR)
{
	new cvarValue = get_pcvar_num(CVARS[CVAR]);
	
	if(cvarValue < CVARS_MIN[CVAR])
		cvarValue = CVARS_MIN[CVAR];
	
	else if(cvarValue > CVARS_MAX[CVAR])
		cvarValue = CVARS_MAX[CVAR];
	
	set_pcvar_num(CVARS[CVAR],cvarValue);
		
	return cvarValue;
}

motdShowTable(id)
{
	const motdLast = 1500;
	new motd[motdLast+1];

	const styleLast = 512;
	new style[styleLast+1];	
	
	formatex(style,styleLast,"<html>^n<head>^n<style>\
	body{\
	font-family:Verdana, Arial, Helvetica, sans-serif;\
	background-image:url('%s%sbackground.png');\
	width:60%%;\
	text-align:center;\
	margin:auto;\
	margin-top:2%%;\
	}^n.pi{\
	text-align:right;\
	padding:1px;\
	font-size:11px;\
	display:inline;\
	}^n.m{\
	text-align:center;\
	padding:3%%;\
	}^n.c{\
	display:inline;\
	}</style></head><body>",CFG_SITE_URL,CFG_IMAGES_PATH);
	
	formatex(motd,motdLast,"%s",style);
	
	format(motd,motdLast,"%s%s",motd,"<div class='c'>");
	
	if(g_Player_GameState[id] != GameState_GameOver)
		format(motd,motdLast,"%s<i>Croupier</i>",motd);
	else
		format(motd,motdLast,"%s<i>Croupier</i>: %d points",motd,getCroupierCardsSum(decksCroupier[id],decksCroupierCount[id]));
		
	format(motd,motdLast,"%s%s",motd,"</div>");
	
	format(motd,motdLast,"%s%s",motd,"<div>");
	
	if(g_Player_GameState[id] != GameState_GameOver)
		format(motd,motdLast,"%s<div class='c'><img src='%s%sback.png'></div>",motd,CFG_SITE_URL,CFG_CARD_PATH);	
	else
		format(motd,motdLast,"%s<div class='c'><img src='%s%s%sOf%s.png'></div>",motd,CFG_SITE_URL,CFG_CARD_PATH,cardFiguresNames[ decksCroupier[id][0][CARD_ID]], cardSuitNames[ decksCroupier[id][0][SUIT] ]);	
	
	for(new i=1; i< decksCroupierCount[id]; i++)
	{	
		format(motd,motdLast,"%s<div class='c'><img src='%s%s%sOf%s.png'></div>",motd,CFG_SITE_URL,CFG_CARD_PATH,cardFiguresNames[ decksCroupier[id][i][CARD_ID]], cardSuitNames[ decksCroupier[id][i][SUIT] ]);	
	}
	
	format(motd,motdLast,"%s%s",motd,"</div>");
	
	format(motd,motdLast,"%s%s",motd,"<div class='m'> ");
	
	const MSG_LAST_INDEX=19;
	new msg[MSG_LAST_INDEX+1];
	
	if(g_Player_GameState[id] == GameState_GameOver)
	{
		switch(gameResult(id))
		{
			case -1:
			{
				format(msg,MSG_LAST_INDEX,"%L",id,"MSG_MOTD_LOST");
			}
			case 0:
			{
				format(msg,MSG_LAST_INDEX,"%L",id,"MSG_MOTD_DRAW");
			}
			case 1:
			{
				format(msg,MSG_LAST_INDEX,"%L",id,"MSG_MOTD_WIN");
			}
			case 2:
			{
				format(msg,MSG_LAST_INDEX,"%L",id,"MSG_MOTD_BLACKJACK");
			}
		}
	}
	
	format(motd,motdLast,"%s%s",motd,msg);
	
	format(motd,motdLast,"%s%s",motd,"</div>");
	
	format(motd,motdLast,"%s%s",motd,"<div>");
	
	for(new i=0; i< decksPlayersCount[id]; i++)
	{	
		format(motd,motdLast,"%s<div class='pi'><img src='%s%s%sOf%s.png'></div>",motd,CFG_SITE_URL,CFG_CARD_PATH,cardFiguresNames[ decksPlayers[id][i][CARD_ID]], cardSuitNames[ decksPlayers[id][i][SUIT] ]);	
	}
		
	format(motd,motdLast,"%s%s",motd,"</div>");
	
	new name[32];
	get_user_name(id,name,31);
	
	format(motd,motdLast,"%s%s",motd,"<div class='pi'>");
	format(motd,motdLast,"%s<i>%s</i>: %d %L",motd,name,getPlayerCardsSum(decksPlayers[id],decksPlayersCount[id]),id,"POINTS");
	format(motd,motdLast,"%s%s",motd,"</div></body></html>");
	
	show_motd(id,motd);
}

renewDeck(deck[N_CARDS][CARD],&count)
{
	count = 0;
	
	for(new i=0, j=0, newCard[CARD];i<N_SUITS;i++)
	{
		newCard[SUIT] = i;
		newCard[CARD_ID] = 0;
		newCard[VALUE] = 11;
				
		deck[count++] = newCard;
		

		for(j=1;j<=9;j++)
		{
			newCard[SUIT] = i;
			newCard[CARD_ID] = j;
			newCard[VALUE] = j+1;
			deck[count++] = newCard;
		}
		
		for(j=10;j<=12;j++)
		{
			newCard[SUIT] = i;
			newCard[CARD_ID] = j;
			newCard[VALUE] = 10;
			deck[count++] = newCard;
		}
	}
	
}

public showMenuBlackJack(id)
{
	if(getCvar(ENABLED))
	{
		switch( g_Player_GameState[id] )
		{
			case GameState_StartGame:
			{
				return PLUGIN_HANDLED
			}
			case GameState_GameOver:
			{
				showMenuGameOver(id);
			}
			case GameState_InGame:
			{
				showMenuInGame(id);
			}
		}
	}
	return PLUGIN_HANDLED;
}
public showMenuGameOver(id)
{
	new menu = menu_create("","handleMenuGameOver");
	
	const TITLE_LAST_INDEX = 60 + CFG_MAX_PARAM_SIZE;
	new fullTitle[TITLE_LAST_INDEX+1];
	
	formatex(fullTitle,TITLE_LAST_INDEX,"%L^n^n",id,"TITLE_MENU");
	
	const MSG_LAST_INDEX = 39;
	new msg[MSG_LAST_INDEX+1];
	
	switch (gameResult(id))
	{
		case -1:
		{
			formatex(msg,MSG_LAST_INDEX,"%L",id,"MSG_MENU_LOST", betValues[id]);
		}
		case 0:
		{
			formatex(msg,MSG_LAST_INDEX,"%L",id,"MSG_MENU_DRAW");
		}
		case 1:
		{
			formatex(msg,MSG_LAST_INDEX,"%L",id,"MSG_MENU_WIN", betValues[id]);
		}
		case 2:
		{
			formatex(msg,MSG_LAST_INDEX,"%L",id,"MSG_MENU_BLACKJACK", betValues[id] * 2);
		}
	}
	
	format(fullTitle,TITLE_LAST_INDEX,"%s%s",fullTitle,msg);
	
	menu_setprop(menu,MPROP_TITLE,fullTitle);	
	
	const EXIT_LAST_INDEX = 10;
	new exitText[EXIT_LAST_INDEX+1];
	formatex(exitText,EXIT_LAST_INDEX,"%L",id,"MSG_MENU_EXIT");
		
	menu_setprop(menu, MPROP_EXITNAME, exitText);
	
	const SHOW_TABLE_LAST_INDEX = 15;
	new showTable[SHOW_TABLE_LAST_INDEX+1];
	
	formatex(showTable,SHOW_TABLE_LAST_INDEX,"%L",id,"MSG_MENU_SHOW_TABLE");
	
	const NEW_GAME_LAST_INDEX = 15;
	new newGame[NEW_GAME_LAST_INDEX+1];
	
	formatex(newGame,NEW_GAME_LAST_INDEX,"%L",id,"MSG_MENU_NEW_GAME");
	
	menu_additem(menu, showTable,"1");
	menu_additem(menu, newGame,"2");
		
	menu_display(id,menu,0);
}

public handleMenuGameOver(id , menu , item)
{
	if( item < 0 )
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;	
	}
	
	new access, callback; 
	
	new actionString[2];		
	menu_item_getinfo(menu, item, access, actionString, charsmax(actionString), _, _, callback);
	new action = str_to_num(actionString);	
	menu_destroy(menu);
	
	switch(action)
	{
		case 1:
		{
			showMenuGameOver(id);
			motdShowTable(id);
		}
		case 2:
		{
			if(!doReset(id))
			{
				startGame(id);
				showMenuBlackJack(id);
				motdShowTable(id);
			}
		}
	}
	
	return PLUGIN_HANDLED;
}
public showMenuInGame(id)
{
	new menu = menu_create(.title="", .handler="handleMenuInGame");
		
	const TITLE_LAST_INDEX = CFG_MAX_PARAM_SIZE + 1;
	
	new title[TITLE_LAST_INDEX+1], iLen;
	
	iLen = formatex(title,TITLE_LAST_INDEX,"%L^n^n",id,"TITLE_MENU");
	iLen += formatex(title[iLen], charsmax(title) - iLen, "^n\rAmount of Bet: $%d", betValues[id]);
		
	menu_setprop(menu,MPROP_TITLE,title);	
	
	const EXIT_LAST_INDEX = 10;
	new exitText[EXIT_LAST_INDEX+1];
	formatex(exitText,EXIT_LAST_INDEX,"%L",id,"MSG_MENU_EXIT");
	
	menu_setprop(menu, MPROP_EXITNAME, exitText);
	
	const SHOW_TABLE_LAST_INDEX = 15;
	new showTable[SHOW_TABLE_LAST_INDEX+1];
	
	formatex(showTable,SHOW_TABLE_LAST_INDEX,"%L",id,"MSG_MENU_SHOW_TABLE");
	
	const ASKCARD_LAST_INDEX = 20;
	new askCardText[ASKCARD_LAST_INDEX+1];
	
	formatex(askCardText,ASKCARD_LAST_INDEX,"%L",id,"MSG_MENU_ASK_CARD");
	
	const STOP_LAST_INDEX = 20;
	new stopText[STOP_LAST_INDEX+1];
	
	formatex(stopText,STOP_LAST_INDEX,"%L",id,"MSG_MENU_STOP");
	
	menu_additem(menu, showTable,"1");
	menu_additem(menu, askCardText,"2");
	menu_additem(menu, stopText,"3");
		
	menu_display(id,menu,0);
	
	
	return PLUGIN_CONTINUE;
}
public handleMenuInGame(id , menu , item)
{
	if( item < 0 ) 
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;	
	}
	
	new access, callback; 
	
	new actionString[2];		
	menu_item_getinfo(menu, item, access, actionString, charsmax(actionString), _, _, callback);
	new action = str_to_num(actionString);	
	menu_destroy(menu);
	
	switch(action)
	{
		case 1:
		{
			showMenuInGame(id);
			motdShowTable(id);
		}
		case 2:
		{
			askCard(id);
			showMenuBlackJack(id);
			motdShowTable(id);
		}
		case 3:
		{
			stop(id);
			showMenuBlackJack(id);
			motdShowTable(id);
		}
	}
	
	return PLUGIN_HANDLED;
}

card:getRandomCard(deck[N_CARDS][CARD],&count)
{	
	if(!count)
	{
		renewDeck(deck,count);	
	}

	new newCard[CARD];

	if( count > 0 )
	{
		new randIndex = random(count);

		newCard = deck[randIndex];

		deck[randIndex] = deck[--count];
	}

	return card:newCard;
}

getPlayerCardsSum(deckPlayer[PER_PLAYER_MAX_CARDS][CARD], const deckPlayerCount)
{
	new playerSum = 0;

	for(new i = 0; i < deckPlayerCount;i++)
	{
		playerSum += deckPlayer[i][VALUE];
	}
	
	if(playerSum > 21)
	{
		for(new j = 0; j < deckPlayerCount; j++)
		{
			if(deckPlayer[j][CARD_ID] == 0 && deckPlayer[j][VALUE] == 11)
			{
				playerSum -= deckPlayer[j][VALUE];
				deckPlayer[j][VALUE] = 1;
			}
			
			if(playerSum <= 21)
			{
				break;
			}
		}
	}
	
	return playerSum;
}

getCroupierCardsSum(deckCroupier[PER_PLAYER_MAX_CARDS][CARD], const deckCroupierCount)
{
	return getPlayerCardsSum(deckCroupier, deckCroupierCount);
}

giveCroupierCard(deck[N_CARDS][CARD],&deckCount,deckCroupier[PER_PLAYER_MAX_CARDS][CARD],&deckCroupierCount)
{
	deckCroupier[min(deckCroupierCount++, sizeof deckCroupier-1)] = getRandomCard(deck,deckCount);
}

givePlayerCard(deck[N_CARDS][CARD],&deckCount,deckPlayer[PER_PLAYER_MAX_CARDS][CARD],&deckPlayerCount)
{
	deckPlayer[min(deckPlayerCount++, sizeof deckPlayer-1)] = getRandomCard(deck,deckCount);
}

startGame(id)
{
	new money = get_user_money(id);
	set_user_money(id, money - betValues[id]);
	
	g_Player_GameState[id] = GameState_InGame;
	
	decksCount[id] = 0;
	decksPlayersCount[id] = 0;
	decksCroupierCount[id] = 0;
	
	renewDeck(decks[id],decksCount[id]);
	
	giveCroupierCard(decks[id],decksCount[id],decksCroupier[id],decksCroupierCount[id]);
	giveCroupierCard(decks[id],decksCount[id],decksCroupier[id],decksCroupierCount[id]);

	givePlayerCard(decks[id],decksCount[id],decksPlayers[id],decksPlayersCount[id]);
	givePlayerCard(decks[id],decksCount[id],decksPlayers[id],decksPlayersCount[id]);
	
	new playerSum   = getPlayerCardsSum(decksPlayers[id],decksPlayersCount[id]);
	new croupierSum = getCroupierCardsSum(decksCroupier[id],decksCroupierCount[id]);
	
	if(playerSum == 22)
		decksPlayers[id][0][VALUE] = 1;
	if(croupierSum == 22)
		decksCroupier[id][0][VALUE] = 1;
		
	if ( (playerSum == 21) || (croupierSum == 21) )
	{
		doGameOver(id);
	}
	
}

askCard(id)
{
	givePlayerCard(decks[id],decksCount[id],decksPlayers[id],decksPlayersCount[id]);
	new playerSum  = getPlayerCardsSum(decksPlayers[id],decksPlayersCount[id]);
	
	if(playerSum >= 21)
	{
		doGameOver(id);
	}
	
}

stop(id)
{
	new playerSum = getPlayerCardsSum(decksPlayers[id],decksPlayersCount[id]);
	new croupierSum = getCroupierCardsSum(decksCroupier[id],decksCroupierCount[id]);
	
	if(playerSum <= 21)
	{
		while(croupierSum<playerSum)
		{
			giveCroupierCard(decks[id],decksCount[id],decksCroupier[id],decksCroupierCount[id]);
			croupierSum = getCroupierCardsSum(decksCroupier[id],decksCroupierCount[id]);
		}
		
		if( (croupierSum == playerSum) && (croupierSum <= 17) )
		{
			giveCroupierCard(decks[id],decksCount[id],decksCroupier[id],decksCroupierCount[id]);
		}
	}
	
	doGameOver(id);
}

gameResult(id)
{
	new playerSum = getPlayerCardsSum(decksPlayers[id],decksPlayersCount[id]);
	new croupierSum = getCroupierCardsSum(decksCroupier[id],decksCroupierCount[id]);
	
	if( (playerSum == croupierSum) || ( (playerSum > 21) && (croupierSum > 21)) )
	{
		return 0;
	}
	else if(playerSum == 21 && (decksPlayersCount[id] == 2) )
	{
		return 2;
	}
	else if (playerSum > croupierSum)
	{
		if(playerSum > 21)
			return -1
		else
			return 1;
	}
	else if (croupierSum > playerSum)
	{
		if(croupierSum > 21)
			return 1;
		else
			return -1;
	}
	
	return 0;	
}

doGameOver(id)
{
	g_Player_GameState[id] = GameState_GameOver;
	
	new money = get_user_money(id);
	
	new name[32];
	get_user_name(id,name,31);

	set_hudmessage(.red = 200, .green = 100, .blue = 0, .x = 0.15, .y = 0.85, .holdtime = 3.0, .channel = 4);

	switch (gameResult(id))
	{
		case -1:
		{
			show_hudmessage(0, "%L", id, "MSG_CHAT_LOST", name, betValues[id]);
		}
		case 0:
		{
			if(getCvar(CHAT_MESSAGES))
				show_hudmessage(0, "%L", id, "MSG_CHAT_DRAW", name);
			set_user_money(id, money + betValues[id]);
		}
		case 1:
		{
			if(getCvar(CHAT_MESSAGES))
				show_hudmessage(0, "%L", id, "MSG_CHAT_WIN", name, betValues[id]);
			set_user_money(id, money + 2 * betValues[id]);
		}
		case 2:
		{
			if(getCvar(CHAT_MESSAGES))
				show_hudmessage(0, "%L", id, "MSG_CHAT_BLACKJACK", name, betValues[id] * 2);
			set_user_money(id, money + 3 * betValues[id]);
		}
	}
}

doReset(id)
{
	g_Player_GameState[id] = GameState_StartGame;
	
	if(get_user_money(id) < betValues[id])
	{
		if(get_user_money(id) < getCvar(BET_VALUE_MIN))
		{
			return 1;
		}
		
		betValues[id] = getCvar(BET_VALUE_MIN);
	}
	
	return 0;
}

