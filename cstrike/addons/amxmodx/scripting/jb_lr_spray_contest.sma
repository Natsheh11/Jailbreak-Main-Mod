#include < amxmodx >
#include < fun >
#include < fakemeta >
#include < jailbreak_core >
#include < xs >

#define TASK_SPRAY_COUNTING 3500

new g_iGameId, g_iEvent_PlayerDecal, g_iPlayer_sprayed[33];

new g_iMode, g_iPrisoner, g_iGuard, Float:g_fDistance[2];

enum (+=1)
{
	MODE_HIGHEST_WIN = 0,
	MODE_LOWEST_WIN,
	MODE_FIRSTSPRAY_WIN,
	MODE_SPRAY_COUNTER
}

new const g_szMode[][] = {
	"Highest Wins", 
	"Lowest Wins",
	"First Spray Wins",
	"Spray Counter"
}

new bool:g_bOptional;
new bool:g_bStart;
new g_iSprays = 10;

const m_flNextDecalTime = 486;

native register_jailbreak_cmitem(const itemname[]);
native unregister_jailbreak_cmitem(const item_index);
forward jb_cmenu_item_postselect(id, item);

new g_iItem_SprayMeter, g_iItem_ResetSpray, bool:g_bSprayMeterEnabled;

public plugin_init( )
{
	register_plugin( "[LR] Spray Contest", "1.0", "Natsheh" );
	g_iItem_SprayMeter = register_jailbreak_cmitem("ENABLE_SPRAY_METER");
	g_iItem_ResetSpray = register_jailbreak_cmitem("RESET_PLAYER_SPRAYS");
	g_iGameId = register_jailbreak_lritem("Spray Contest");
	g_iEvent_PlayerDecal = register_event("23", "fw_spray_event", "a", "1=112")	// SVC_TEMPENTITY=23 (TE_PLAYERDECAL=112)
}

public jb_cmenu_item_postselect(id, item)
{
	if(g_iItem_SprayMeter == item)
	{
		g_bSprayMeterEnabled = !g_bSprayMeterEnabled;
		
		unregister_jailbreak_cmitem(g_iItem_SprayMeter);
		switch( g_bSprayMeterEnabled )
		{
			case true: g_iItem_SprayMeter = register_jailbreak_cmitem("DISABLE_SPRAY_METER");
			default: g_iItem_SprayMeter = register_jailbreak_cmitem("ENABLE_SPRAY_METER");
		}
		
		#if AMXX_VERSION_NUM > 182
		g_bSprayMeterEnabled ? enable_event(g_iEvent_PlayerDecal):disable_event(g_iEvent_PlayerDecal);
		#endif
	}
	else if(g_iItem_ResetSpray == item)
	{
		new players[32], pnum;
		get_players(players, pnum, "ch");
		
		for(new i; i < pnum; i++)
		{
			set_pdata_float( players[i], m_flNextDecalTime, 0.1 );
		}
		
		new name[32];
		get_user_name(id, name, charsmax(name));
		cprint_chat(0, _, "Commander %s has reset all players spray's ability!", name);
	}
}

public fw_spray_event()
{
	new id = read_data(2);
	
	if(!is_user_alive(id) || (!g_bSprayMeterEnabled && jb_get_current_duel() == DUEL_NONE)) return;
	
	new Float:fSprayOrigin[3], Float:fGroundOrigin[3];
	read_data(3, fSprayOrigin[0]);
	read_data(4, fSprayOrigin[1]);
	read_data(5, fSprayOrigin[2]);
	
	xs_vec_copy(fSprayOrigin, fGroundOrigin);
	fGroundOrigin[2] -= 5000.0;
	
	new tr2 = create_tr2();
	engfunc(EngFunc_TraceLine, fSprayOrigin, fGroundOrigin, IGNORE_MISSILE|IGNORE_MONSTERS, read_data(6), tr2)
	get_tr2(tr2, TR_vecEndPos, fGroundOrigin);
	free_tr2(tr2);
	
	new Float:fDistance = get_distance_f(fSprayOrigin, fGroundOrigin), x;
	
	g_iPlayer_sprayed[id] ++;
	
	if((x=jb_get_current_duel()) == DUEL_NONE)
	{
		new name[32];
		get_user_name(id, name, charsmax(name));
		cprint_chat(0, _, "%s has sprayed %.2f units above the ground!", name, fDistance);
		return;
	}
	
	// its not spray duel? ignore the rest!
	if(x != g_iGameId) return;
	
	switch( g_iMode )
	{
		case MODE_SPRAY_COUNTER:
		{
			if(g_iPlayer_sprayed[id] >= g_iSprays)
			{
				if(id == g_iPrisoner)
				{
					user_kill(g_iGuard);
					jb_logmessage_action("has win in spray duel against", id, g_iGuard);
				}
				else
				{
					user_kill(g_iPrisoner);
					jb_logmessage_action("has win in spray duel against", id, g_iPrisoner);
				}
			}
			
			set_pdata_float( g_iGuard, m_flNextDecalTime, 0.1 );
			set_pdata_float( g_iPrisoner, m_flNextDecalTime, 0.1 );
		}
		case MODE_HIGHEST_WIN, MODE_LOWEST_WIN:
		{
			new name[32];
			get_user_name(id, name, charsmax(name));
			cprint_chat(0, _, "%s has sprayed %.2f units above the ground!", name, fDistance);
	
			g_fDistance[clamp(get_user_team(id), 1, 2)-1] = fDistance;
			
			if(g_iPlayer_sprayed[g_iGuard] > 0 && g_iPlayer_sprayed[g_iPrisoner] > 0) {
				new x,y;
				switch( g_iMode )
				{
					case MODE_HIGHEST_WIN: {x = 0; y = 1;}
					case MODE_LOWEST_WIN: {x = 1; y = 0;}
				}
				
				if(g_fDistance[x] > g_fDistance[y])
				{
					jb_logmessage_action("has win in spray duel against", g_iPrisoner, g_iGuard);
				}
				else if(g_fDistance[x] < g_fDistance[y])
				{
					jb_logmessage_action("has win in spray duel against", g_iGuard, g_iPrisoner);
				}
				else
				{
					jb_logmessage_action("has tied in spray duel against", g_iGuard, g_iPrisoner);
					g_iPlayer_sprayed[g_iGuard] = 0;
					g_iPlayer_sprayed[g_iPrisoner] = 0;
					
					cprint_chat(!g_bStart ? g_iPrisoner:g_iGuard, _, "^3Your spray has been reset^4!");
					set_pdata_float( !g_bStart ? g_iPrisoner:g_iGuard, m_flNextDecalTime, 0.1 );
					set_pdata_float( g_bStart ? g_iPrisoner:g_iGuard, m_flNextDecalTime, 9999.9 );
				}
			}
			else
			{
				set_pdata_float( g_iPrisoner == id ? g_iGuard:g_iPrisoner, m_flNextDecalTime, 0.1 );
				set_pdata_float( id, m_flNextDecalTime, 9999.9 );
			}
		}
		case MODE_FIRSTSPRAY_WIN:
		{
			g_iMode = MODE_HIGHEST_WIN;
			if(id == g_iPrisoner)
			{
				user_kill(g_iGuard);
				jb_logmessage_action("has win in spray duel against", id, g_iGuard);
			}
			else
			{
				user_kill(g_iPrisoner);
				jb_logmessage_action("has win in spray duel against", id, g_iPrisoner);
			}
		}
	}
}

public jb_lr_duel_ended( prisoner, guard, duelid )
{
	if(duelid != g_iGameId) return;
	
	if(task_exists(TASK_SPRAY_COUNTING)) remove_task(TASK_SPRAY_COUNTING);
	
	g_iMode = MODE_HIGHEST_WIN;
	g_bOptional = false;
	g_bStart = false;
	g_iSprays = 10;
	g_iPlayer_sprayed[prisoner] = 0;
	g_iPlayer_sprayed[guard] = 0;
	
	#if AMXX_VERSION_NUM > 182
	disable_event(g_iEvent_PlayerDecal);
	#endif
}

public jb_lr_duel_selected(id, itemid)
{
	if( itemid == g_iGameId )
	{
		HandleSprayMenu( id );
		return JB_LR_OTHER_MENU;
	}
	return PLUGIN_CONTINUE
}

public jb_lr_duel_started(prisoner, guard, duelid)
{
	if(duelid != g_iGameId) return;
	
	g_iGuard = guard;
	g_iPrisoner = prisoner;
	
	switch( g_iMode )
	{
		case MODE_HIGHEST_WIN, MODE_LOWEST_WIN: {
			cprint_chat(!g_bStart ? prisoner:guard, _, "^3Your spray has been reset^4!");
			set_pdata_float( !g_bStart ? prisoner:guard, m_flNextDecalTime, 0.1 );
			set_pdata_float( g_bStart ? prisoner:guard, m_flNextDecalTime, 9999.9 );
		}
		default: {
			
			if(g_iMode == MODE_SPRAY_COUNTER)
			{
				set_task(0.1, "task_spray_counting", TASK_SPRAY_COUNTING, _, _, "b");
			}
			
			set_pdata_float(guard, m_flNextDecalTime, 0.1 );
			set_pdata_float(prisoner, m_flNextDecalTime, 0.1);
		}
	}
	

	g_iPlayer_sprayed[prisoner] = 0;
	g_iPlayer_sprayed[guard] = 0;
	
	#if AMXX_VERSION_NUM > 182
	enable_event(g_iEvent_PlayerDecal);
	#endif
}

public task_spray_counting(taskid)
{
	static szMessage[32];
	formatex(szMessage, charsmax(szMessage), "Spray Counter: %i/%i", g_iPlayer_sprayed[g_iGuard], g_iSprays);
	
	UTIL_DirectorMessage(
		.index       = g_iGuard, 
		.message     = szMessage,
		.red         = 0,
		.green       = 0,
		.blue        = 200,
		.x           = -1.0,
		.y           = 0.25,
		.effect      = 0,
		.fxTime      = 5.0,
		.holdTime    = 0.1,
		.fadeInTime  = 0.5,
		.fadeOutTime = 0.3
	);
	
	formatex(szMessage, charsmax(szMessage), "Spray Counter: %i/%i", g_iPlayer_sprayed[g_iPrisoner], g_iSprays);
	
	UTIL_DirectorMessage(
		.index       = g_iPrisoner, 
		.message     = szMessage,
		.red         = 200,
		.green       = 0,
		.blue        = 0,
		.x           = -1.0,
		.y           = 0.25,
		.effect      = 0,
		.fxTime      = 5.0,
		.holdTime    = 0.1,
		.fadeInTime  = 0.5,
		.fadeOutTime = 0.3
	);
	
	static players[32], pnum, i, id, iSpec;
	get_players(players, pnum, "dch");
	
	for(i = 0; i < pnum; i++)
	{
		id = players[i];
		
		if((iSpec=pev(id, pev_iuser2)) != g_iPrisoner && iSpec != g_iGuard) continue;
		
		UTIL_DirectorMessage(
			.index       = iSpec, 
			.message     = szMessage,
			.red         = iSpec == g_iPrisoner ? 200:0,
			.green       = 0,
			.blue        = iSpec != g_iPrisoner ? 200:0,
			.x           = -1.0,
			.y           = 0.25,
			.effect      = 0,
			.fxTime      = 5.0,
			.holdTime    = 0.1,
			.fadeInTime  = 0.5,
			.fadeOutTime = 0.3
		);
	}
}

public HandleSprayMenu( id )
{
	new hMenu = menu_create( "Choose the options", "HandleStart" );
	
	new szMessage[ 32 ];
	formatex( szMessage, charsmax( szMessage ), "Mode: %s", g_szMode[g_iMode]);
	menu_additem( hMenu, szMessage, "1" );
	
	switch( g_iMode )
	{
		case MODE_HIGHEST_WIN, MODE_LOWEST_WIN: {
			formatex( szMessage, charsmax( szMessage ), "Starting: %s", !g_bStart ? "You" : "Him" );
			menu_additem( hMenu, szMessage, "2" );
			
			formatex( szMessage, charsmax( szMessage ), "Spray Cut: %s", g_bOptional ? "Not Allowed" : "Allowed" );
			menu_additem( hMenu, szMessage, "3" );
		}
		case MODE_SPRAY_COUNTER:
		{
			formatex( szMessage, charsmax( szMessage ), "Spray Counter: %i Sprays", g_iSprays );
			menu_additem( hMenu, szMessage, "4" );
		}
	}
	
	menu_additem( hMenu, "Continue", "5" );
	
	menu_display( id, hMenu);
}

public HandleStart( const id, menu, item  )
{
	if(item == MENU_EXIT || !is_user_alive( id ))
	{
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}
	
	new szKey[ 2 ], Trash, iKey;
	menu_item_getinfo( menu, item, Trash, szKey, 1, _, _, Trash );
	menu_destroy( menu );
	
	iKey = str_to_num( szKey );
	
	switch( iKey ) {
		case 1: g_iMode = (g_iMode == sizeof g_szMode-1) ? 0:++g_iMode;
		case 2: g_bStart = !g_bStart;
		case 3: g_bOptional = !g_bOptional;
		case 4: g_iSprays = (g_iSprays >= 50) ? 10:(g_iSprays + 10);
		case 5: {
			new szMessage[ 96 ];
			
			switch( g_iMode )
			{
				case MODE_HIGHEST_WIN, MODE_LOWEST_WIN: {
					formatex( szMessage, charsmax( szMessage ), "Spray Rules:^n%s^n%s^n%s",
					g_szMode[g_iMode],
					g_bOptional ? "No cutting the spray" : "Cutting the spray is allowed",
					!g_bStart ? "Prisoner Starts First" : "Guard Starts First" );
					
					cprint_chat( 0, _, "Spray Rules:^4%s^1 - ^4%s^1 - ^4%s^1!",
					g_szMode[g_iMode],
					g_bOptional ? "No cutting the spray" : "Cutting the spray is allowed",
					!g_bStart ? "Prisoner Starts First" : "Guard Starts First" );
				}
				case MODE_SPRAY_COUNTER: {
					formatex( szMessage, charsmax( szMessage ), "Spray Rules:^n%s^nFirst one to make %i sprays will win!",
					g_szMode[g_iMode],
					g_iSprays );
					
					cprint_chat( 0, _, "Spray Rules:^4%s^1 - ^4First one to make %i Sprays will win!^1!",
					g_szMode[g_iMode],
					g_iSprays );
				}
				case MODE_FIRSTSPRAY_WIN: {
					formatex( szMessage, charsmax( szMessage ), "Spray Rules:^n%s^nFirst one sprays wins!",
					g_szMode[g_iMode] );
					
					cprint_chat( 0, _, "Spray Rules:^4%s^1 - ^4First one sprays wins!^1!",
					g_szMode[g_iMode] );
				}
			}
			
			UTIL_DirectorMessage(
				.index       = 0, 
				.message     = szMessage,
				.red         = 90,
				.green       = 30,
				.blue        = 0,
				.x           = 0.77,
				.y           = 0.17,
				.effect      = 0,
				.fxTime      = 5.0,
				.holdTime    = 5.0,
				.fadeInTime  = 0.5,
				.fadeOutTime = 0.3
			);
			
			jb_lr_show_targetsmenu(id, g_iGameId)
		}
	}
	
	if(iKey != 5) HandleSprayMenu( id );
	return PLUGIN_HANDLED;
}


stock UTIL_DirectorMessage( const index, const message[], const red = 0, const green = 160, const blue = 0, 
					  const Float:x = -1.0, const Float:y = 0.65, const effect = 2, const Float:fxTime = 6.0, 
					  const Float:holdTime = 3.0, const Float:fadeInTime = 0.1, const Float:fadeOutTime = 1.5 )
{
	#define pack_color(%0,%1,%2) ( %2 + ( %1 << 8 ) + ( %0 << 16 ) )
	#define write_float(%0) write_long( _:%0 )
	
	message_begin( index ? MSG_ONE : MSG_BROADCAST, SVC_DIRECTOR, .player = index );
	{
		write_byte( strlen( message ) + 31 ); // size of write_*
		write_byte( DRC_CMD_MESSAGE );
		write_byte( effect );
		write_long( pack_color( red, green, blue ) );
		write_float( x );
		write_float( y );
		write_float( fadeInTime );
		write_float( fadeOutTime );
		write_float( holdTime );
		write_float( fxTime );
		write_string( message );
	}
	message_end( );
}
