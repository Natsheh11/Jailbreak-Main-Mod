#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <npc_library>

#define VERSION 		"1.0"

#define PEV_ID pev_iuser3
#define PEV_VIEWERS pev_iuser2
#define HEALTH_BAR_ID 530001

new const HEALTH_BAR_MODEL[ ] = "sprites/health.spr";
new const HEALTH_BAR_CLASSNAME[ ] = "npc_healthbar";

new g_isAlive[ MAX_PLAYERS+1 ], g_showHB[ MAX_PLAYERS+1 ], g_playerBot[ MAX_PLAYERS+1 ];
new g_msg_SayText, g_fw_AddToFullPackPre = INVALID_HANDLE;

public plugin_init( ) 
{
	new iPluginID = register_plugin( "NPC Health Bar", VERSION, "Natsheh" );
	
	register_cvar( "Health_Bars", VERSION, FCVAR_SERVER | FCVAR_SPONLY );
	set_cvar_string( "Health_Bars", VERSION );
	
	register_event( "DeathMsg", "evDeathMsg", "a" );
	RegisterHam( Ham_Spawn, "player", "fwHamSpawn", true );
	
	register_clcmd( "say hb", "hbHandle" );
	register_clcmd( "say /hb", "hbHandle" );

	g_msg_SayText = get_user_msgid( "SayText" );

	new szFile[128], szBuffer[64];
	get_configsdir(szFile, charsmax(szFile));

	format(szFile, charsmax(szFile), "%s/npc_healthbar_entities.ini", szFile);

	new fp = fopen(szFile, "rt");

	if( fp > 0 )
	{
		while(fgets(fp, szBuffer, charsmax(szBuffer)))
		{
			trim(szBuffer);
			remove_quotes(szBuffer);

			if(!szBuffer[0] || szBuffer[0] == '/' && szBuffer[1] == '/' || szBuffer[0] == '#' || szBuffer[0] == ';')
			{
				continue;
			}

			NPC_Hook_Event(szBuffer, NPC_EVENT_TAKEDAMAGE, "fwNPCTakeDamage", iPluginID);
			NPC_Hook_Event(szBuffer, NPC_EVENT_DEATH, "fwNPCDeath", iPluginID);
		}
		fclose(fp);
	}

	register_think(HEALTH_BAR_CLASSNAME, "HealthBar_Think");
}

public fwNPCDeath(victim, killer)
{
	new ent = -1;
	while( (ent = find_ent_by_owner(ent, HEALTH_BAR_CLASSNAME, victim)) > 0)
	{
		set_pev(ent, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, ent);
	}
}

public HealthBar_Think(id)
{
	set_pev(id, pev_flags, FL_KILLME);
	dllfunc(DLLFunc_Think, id);

	if(g_fw_AddToFullPackPre != INVALID_HANDLE)
	{
		new ent = -1, hbar_count = 0;

		while( (ent = find_ent_by_class(ent, HEALTH_BAR_CLASSNAME)) > 0)
		{
			hbar_count ++;
		}

		if(hbar_count <= 1)
		{
			unregister_forward(FM_AddToFullPack, g_fw_AddToFullPackPre);
			g_fw_AddToFullPackPre = INVALID_HANDLE;
		}
	}
}

public fwNPCTakeDamage(id, inflictor, attacker, Float:fDamage, damagebits)
{
	if(!IsPlayer(attacker))
	{
		return;
	}

	DisplayNPCBarHealth(id, attacker, 5.0);
}

DisplayNPCBarHealth(npc, viewer, Float:fLength)
{
	static hbar;
	if(( hbar = CreateHealthBar(npc)))
	{
		set_pev(hbar, pev_nextthink, get_gametime() + fLength);
	}
	else
	{
		hbar = find_ent_by_owner(-1, HEALTH_BAR_CLASSNAME, npc);
	}

	static Float:fMaxHealth, Float:fHealth;
	pev(npc, pev_health, fHealth);
	pev(npc, pev_max_health, fMaxHealth);
	set_pev(hbar, PEV_VIEWERS, (1<<(viewer&31)));

	if(fMaxHealth <= fHealth)
	{
		set_pev(hbar, pev_frame, 99.0);
	}
	else
	{
		set_pev(hbar, pev_frame, 0.0 + ( ( ( fHealth - 1.0 ) * 100.0 ) / fMaxHealth ));
	}
}

CreateHealthBar(const pOwner)
{
	if( (find_ent_by_owner(-1, HEALTH_BAR_CLASSNAME, pOwner)) > 0 )
	{
		return 0;
	}

	new ent = engfunc( EngFunc_CreateNamedEntity, engfunc( EngFunc_AllocString, "env_sprite" ) );

	if( pev_valid( ent ) )
	{
		set_pev( ent, pev_classname, HEALTH_BAR_CLASSNAME );
		set_pev( ent, PEV_OWNER, pOwner );
		set_pev( ent, pev_owner, pOwner );
		set_pev( ent, PEV_ID, HEALTH_BAR_ID );
		set_pev( ent, pev_movetype, MOVETYPE_NOCLIP );
		set_pev( ent, pev_solid, SOLID_NOT );
		set_pev( ent, pev_scale, 0.1 );
		engfunc( EngFunc_SetModel, ent, HEALTH_BAR_MODEL );

		new Float:fNPCOrigin[ 3 ], Float:fViewOFS[ 3 ];
		pev( pOwner, pev_origin, fNPCOrigin );
		pev( pOwner, pev_view_ofs, fViewOFS );
		fNPCOrigin[ 2 ] = fNPCOrigin[ 2 ] + fViewOFS[ 2 ] + 30.0;
		engfunc(EngFunc_SetOrigin, ent, fNPCOrigin);

		dllfunc(DLLFunc_Spawn, ent);
	}

	if(g_fw_AddToFullPackPre == INVALID_HANDLE)
	{
		g_fw_AddToFullPackPre = register_forward(FM_AddToFullPack, "fwAddToFullPack");
	}

	return ent;
}

public plugin_precache( )
{
	precache_model( HEALTH_BAR_MODEL );
}

public client_putinserver( id )
{
	g_isAlive[ id ] = 0;
	g_playerBot[ id ] = is_user_bot( id );
	g_showHB[ id ] = true;
}

#if AMXX_VERSION_NUM < 183
public client_disconnect( id )
#else
public client_disconnected(id)
#endif
{
	g_isAlive[ id ] = 0;
	g_playerBot[ id ] = 0;
	g_showHB[ id ] = false;
}

public hbHandle( id ) // [ ^4 = GREEN ] [ ^3 = Team Color ] [ ^1 = client con_color value ]
{
	g_showHB[ id ] = !g_showHB[ id ];
	
	message_begin( MSG_ONE_UNRELIABLE, g_msg_SayText, .player = id );
	write_byte( id );
	write_string
	( 
		g_showHB[ id ] ?
		"^4[ HEALTH BARS ]^3 Enabled for you^1 ! Write /hb to^4 disable^1 it"
		:
		"^4[ HEALTH BARS ]^3 Disabled for you^1 ! Write /hb to^4 enable^1 it" 
	);
	message_end( );
}

public fwAddToFullPack( es, e, ent, host, host_flags, player, p_set )
{
	if( !player && !g_playerBot[ host ] && g_isAlive[ host ] )
	{
		if( pev(ent, PEV_ID) == HEALTH_BAR_ID )
		{	
			static npc, Float:fNPCOrigin[ 3 ], Float:fViewOFS[ 3 ];
			npc = pev( ent, PEV_OWNER );

			if(pev_valid( npc ) <= 0)
			{
				return FMRES_IGNORED;
			}

			pev( npc, pev_origin, fNPCOrigin );
			pev( npc, pev_view_ofs, fViewOFS );
			fNPCOrigin[ 2 ] = fNPCOrigin[ 2 ] + fViewOFS[ 2 ] + 30.0;

			if( g_showHB[ host ] && (pev(ent, PEV_VIEWERS) & (1<<(host&31))) )
			{
				set_pev( ent, pev_origin, fNPCOrigin );
				set_es( es, ES_Origin, fNPCOrigin );
			}
			else
			{
				return FMRES_SUPERCEDE;
			}
		}
	}

	return FMRES_IGNORED;
}

public evDeathMsg( )
{
	new id = read_data( 2 );
	
	g_isAlive[ id ] = 0;
}

public fwHamSpawn(id)
{
	if(is_user_alive(id))
	{
		g_isAlive[id] = 1;
	}
}
