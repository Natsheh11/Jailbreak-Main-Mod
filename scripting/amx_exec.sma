#include <amxmodx>
#include <amxmisc>

public amx_exec(id, level, cid)
{
	if(!cmd_access(id, level, cid, 2))
	{
		console_print(id, "[AMXX] Access Denied");
	 	return PLUGIN_HANDLED;
	}

	new szCommand[128], szTarget[32], player;
	read_argv(1, szTarget, charsmax(szTarget));
	read_argv(2, szCommand, charsmax(szCommand));
	remove_quotes(szTarget);
	remove_quotes(szCommand);
	trim(szTarget);
	trim(szCommand);

	replace_all(szCommand, charsmax(szCommand), "'", "^"");

	if(szTarget[0] == '@')
	{
		switch( szTarget[1] )
		{
			case 'A', 'a':
			{
				client_cmd(0, szCommand);
				console_print(id, "[AMXX] Succeeded");
			}
			case 'C', 'c':
			{
				new players[32], pnum;
				get_players(players, pnum, "e", "CT");
				for(new i; i < pnum; i++)
				{
					player = players[ i ];
					client_cmd(player, szCommand);
				}

				console_print(id, "[AMXX] Succeeded");
			}
			case 'T', 't':
			{
				new players[32], pnum;
				get_players(players, pnum, "e", "TERRORIST");
				for(new i; i < pnum; i++)
				{
					player = players[ i ];
					client_cmd(player, szCommand);
				}

				console_print(id, "[AMXX] Succeeded");
			}
			case 'S', 's':
			{
				new players[32], pnum;
				get_players(players, pnum, "e", "SPECTATOR");
				for(new i; i < pnum; i++)
				{
					player = players[ i ];
					client_cmd(player, szCommand);
				}

				console_print(id, "[AMXX] Succeeded");
			}
		}
	} 
	else if( (player = cmd_target(id, szTarget, CMDTARGET_ALLOW_SELF)) )
	{
		client_cmd(player, szCommand);
		console_print(id, "[AMXX] Succeeded");
	}

	return PLUGIN_HANDLED;
}

public plugin_init()
{
	register_plugin("AMXX EXEC", "1.0", "Natsheh");
	register_concmd("amx_exec", "amx_exec", ADMIN_IMMUNITY, "< name / @a / @team > < command >");

}
