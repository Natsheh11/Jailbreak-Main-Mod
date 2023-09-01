
#if defined _jailbreak_minigames_included
	#endinput
#endif

#define _jailbreak_minigames_included

enum _:MINIGAMES_MODES (+=1)
{
	MODE_TEAM_VS_TEAM = 0,
	MODE_FREE_FOR_ALL
}

#define MINIGAME_NO_WINNER 0

// checks if the minigame is active.
native jb_is_minigame_active(minigameid);

// returns minigame id if the current id is in a minigame, -1 otherwise
native jb_is_user_inminigame(id);

// forward function < > ( minigame_index, minigame_mode, minigame_players[33], teams[MAX_MINIGAMES_TEAMS], maxteams, players_num, bits_players )
// returns minigame item menu id in the minigames menu.
native register_jb_minigame(const name[], const function[]);

// retrieves the minigame team players in an array. return 1 on success
native jb_minigame_get_team_players(const minigame[], const minigame_team, team[32], &count);

// called when a minigame has ended
forward jb_minigame_ended(const Minigame_Index, const MINIGAMES_MODES:Minigame_Mode, const Winner, players_bits)

/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
