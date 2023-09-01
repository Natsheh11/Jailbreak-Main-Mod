#include < amxmodx >
#include < jailbreak_core >

const TASK_TYPING_CONTEST = 192182;

new g_szWord[ 128 ];
new bool:g_bGameStarted;
new LR_Prisoner, LR_Guard, DUEL_ID;

new const RANDOM_WORDS[][] = {
	"I Love Newyork",
	"How Fast can you type!?",
	"Jailbreak Mod By Natsheh"
}

public plugin_init( ) {
	register_plugin( "[LR] Typing Const", "0.1", "master4life" );
	
	DUEL_ID = register_jailbreak_lritem("Typing Contest");
	
	register_clcmd( "say", "CmdHook" );
}

public jb_lr_duel_ended(prisoner, guard, duelid)
{
	if(DUEL_ID == duelid)
	{
		g_bGameStarted = false;
		LR_Prisoner = LR_Guard = 0;
		
		remove_task( TASK_TYPING_CONTEST );
	}
}

public jb_lr_duel_started(prisoner, guard, duelid)
{
	if(DUEL_ID == duelid)
	{
		remove_task( TASK_TYPING_CONTEST );
		LR_Prisoner = prisoner;
		LR_Guard = guard;
		
		new szPris[32], szGuar[32];
		get_user_name(prisoner, szPris, charsmax(szPris))
		get_user_name(guard, szGuar, charsmax(szGuar))
		cprint_chat(0, _, "^4%s ^1has challenged ^3%s ^1in a ^4Typing Contest!", szPris, szGuar)
		
		set_task( 3.0, "ReadWord", TASK_TYPING_CONTEST );
	}
}

public ReadWord( )
{
	new const szFile[ ] = "addons/amxmodx/configs/jailbreak_words.txt";
	
	if(!file_exists(szFile))
	{
		for(new i; i < sizeof RANDOM_WORDS; i++)
		{
			write_file(szFile, RANDOM_WORDS[i]);
		}	
	}
	
	new iLines = file_size( szFile, true );
	read_file( szFile, random_num( 0, iLines - 1 ), g_szWord, charsmax( g_szWord ),iLines );
	
	g_bGameStarted = true;
	
	new szMessage[ 196 ];
	formatex( szMessage, charsmax( szMessage ), "The Word is... ^n >> %s <<", g_szWord );		
	cprint_chat( 0, _, "The Word is >> ^4%s^1.", g_szWord );
	
	UTIL_DirectorMessage(
		.index       = 0, 
		.message     = szMessage,
		.red         = 90,
		.green       = 30,
		.blue        = 0,
		.x           = -1.0,
		.y           = 0.30,
		.effect      = 0,
		.fxTime      = 5.0,
		.holdTime    = 5.0,
		.fadeInTime  = 0.5,
		.fadeOutTime = 0.3
	);
}

public CmdHook( const id )
{
	if( g_bGameStarted )
	{
		if( id != LR_Guard && id != LR_Prisoner ) return;
		
		new szSaid[ 196 ];
		read_args( szSaid, charsmax(szSaid) );
		remove_quotes( szSaid );
		
		// string is empty
		if(!szSaid[0]) return;
		
		if( equali( g_szWord, szSaid ) ) {
			g_bGameStarted = false;
			
			FinishOver( id == LR_Prisoner ?  LR_Guard : LR_Prisoner , id )
		} 
		else {
			cprint_chat(id, _, "^3Your word is incorrect, ^4try again." );
		}
	}
}

public FinishOver( const iLooser, const iWinner )
{
	new szMessage[ 96 ], szName[ 2 ][ 32 ];
	
	get_user_name( iWinner, szName[ 0 ], charsmax(szName[]));
	get_user_name( iLooser, szName[ 1 ], charsmax(szName[]));
	
	formatex( szMessage, charsmax( szMessage ), "%s has won the typing Contest, ^n%s has lost!", szName[ 0 ], szName[ 1 ] );
	cprint_chat( 0, _, " ^4%s ^1has won the typing ^3Contest, ^4%s^1 Dies.", szName[ 0 ], szName[ 1 ] );
	
	UTIL_DirectorMessage(
		.index       = 0, 
		.message     = szMessage,
		.red         = 90,
		.green       = 30,
		.blue        = 0,
		.x           = -1.0,
		.y           = -1.0,
		.effect      = 0,
		.fxTime      = 5.0,
		.holdTime    = 5.0,
		.fadeInTime  = 0.5,
		.fadeOutTime = 0.3
	);
	
	user_kill( iLooser );
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
