///////////////////////////////////////////////////////
////********************* /////////////////////////////
////* Jailbreak const.  * //////////**////////**///////
////********************* /////////////////////////////
////** Made By Natsheh ** /////*///////////////////*///
////********************* /////*///////////////////*///
///////////////////////////////*********************///
///////////////////////////////*********************///
///////////////////////////////////////////////////////

#if defined _jailbreak_const_included

	#endinput

#endif

#define _jailbreak_const_included

/*
============================= 
==< VERSION		  >==
=============================
*/

#define VERSION 	"2.7.0"
#define VERSION_NUM 	270

/*
============================= 
==< Days of the Week  	  >==
=============================
*/

#define TODAY_SATURDAY                0
#define TODAY_SUNDAY                  1
#define TODAY_MONDAY                  2
#define TODAY_TUESDAY                 3
#define TODAY_WEDNESDAY               4
#define TODAY_THURSDAY                5
#define TODAY_FRIDAY                  6

/*
============================= 
==< TASKS ID		  >==
=============================
*/

#define TASK_BEACON 80000
#define TASK_DAY_LENGTH 70000
#define TASK_VOTEDAY_TIMER 60000
#define TASK_LR_TIMER 3240400

/*
============================= 
==< Definitions		  >==
=============================
*/

#define player_flag(%1)			(1<<(%1 & 31))
#define set_flag(%1,%2)			(%1 |= player_flag(%2))
#define remove_flag(%1,%2)		(%1 &= ~player_flag(%2))
#define check_flag(%1,%2)		(%1 & player_flag(%2))

#define PRECACHE_PLAYER_MODEL 		precache_model
#define PRECACHE_WEAPON_VIEW_MODEL 	precache_model
#define PRECACHE_WEAPON_PLAYER_MODEL 	precache_model
#define PRECACHE_WEAPON_WORLD_MODEL 	precache_model
#define PRECACHE_SOUND 			precache_sound
#define PRECACHE_SPRITE 		precache_model
#define PRECACHE_SPRITE_I 		precache_model
#define PRECACHE_FILE			precache_generic
#define PRECACHE_WORLD_ITEM		precache_model
#define PRECACHE_WORLD_ITEM_I		precache_model

#define TAG "^1[ ^3Jailbreak ^1]"
#define JB_TAG TAG
#define JAILBREAK_TAG TAG

#define JB_DAY_VOTEDAY -2
#define JB_DAY_CAGEDAY -1

#define JB_DUEL_NONE -1
#define JB_LR_AVAILABLE -2

#define JB_MENU_ITEM_DONT_SHOW 3
#define JB_MENU_ITEM_UNAVAILABLE 2
#define JB_SHOP_ITEM_IGNORE_COST 1

#define JB_LR_OTHER_MENU 1
#define JB_LR_NOT_AVAILABLE 2

#define JB_LR_IN_COUNTDOWN -3
#define JB_LR_ACTIVATED -2
#define JB_LR_DEACTIVATED -1

#define JB_HANDLED 1
#define JB_IGNORED 0

#define JB_BLOCK_JOIN_GUARDS 2
#define JB_BLOCK_JOIN_PRISONERS 1
#define JB_BLOCK_JOIN_BOTH 3

#define MAX_WEAPONS 5
#define MAX_VOTEDAYS 5
#define MAX_MMITEM_NAME_LENGTH 64
#define MAX_DAYITEM_NAME_LENGTH 64
#define MAX_SHOPITEM_NAME_LENGTH 32
#define MAX_SHOPITEM_INFO_LENGTH 32
#define MAX_LRITEM_NAME_LENGTH 32
#define MAX_FILE_DIRECTORY_LEN 64
#define MAX_LOG_MESSAGE_LENGTH 264
#define MAX_CHAT_MESSAGE_LENGTH 191
#define MAX_CLASS_TEAM_NAME_LENGTH 12
#define MAX_CLASS_NAME_LENGTH 32
#define MAX_CLASS_PMODEL_LENGTH 32
#define MAX_CLASS_PRIM_WEAPONS_LEN 64
#define MAX_CLASS_SEC_WEAPONS_LEN 64
#define MAX_MINIGAMES_TEAMS 16

#define DAY_NONE 	-1
#define DUEL_NONE 	-1
#define VOTE_DAY	-2

#define JB_LR_OTHER_MENU 1		// used only in jb_lr_duel_selected forward.

#define JB_BLOCK_JOIN_GUARDS 2		// used only in jb_team_join forward.
#define JB_BLOCK_JOIN_PRISONERS 1 	// same as above...
#define JB_BLOCK_JOIN_BOTH 3		// same as above...

///////////////////////////////////////////
// jb_get/set_user_allies constant values /
///////////////////////////////////////////
#define JB_ALLIES_DEFAULT 0
#define JB_ALLIES_EVERYONE 0xFFFFFFFF

////////////////////////////////////////////
// jb_get/set_user_enemies constant values /
////////////////////////////////////////////
#define JB_ENEMIES_DEFAULT 0
#define JB_ENEMIES_EVERYONE 0xFFFFFFFF

enum Day_EndType (+=1)
{
	DAY_ONE_SURVIVOR = 0, /* AKA Free for all */
	DAY_GUARDS_VS_PRISONERS,
	DAY_TIMER
}

enum (+=1)
{
	DAY_SAT = 0,
	DAY_SUN,
	DAY_MON,
	DAY_TUE,
	DAY_WED,
	DAY_THU,
	DAY_FRI,
	
	MAX_DAYS
}

#define TEAM_ANY 0

enum _:(+=1)
{
	TEAM_UNASSIGNED = 0,
	TEAM_PRISONERS,
	TEAM_GUARDS,
	TEAM_SPECTATOR,

	TEAM_MAX
}

////////////////////////////////////////////////////////////////////////////////////////////////////
//////// PUBLIC VARIABLES //////////// * You can use these public variable with xvar natives *//////
////////////////////////////////////////////////////////////////////////////////////////////////////
//public Float:FUNDAY_TIMER_LENGTH;		    		//* the time countdown of a fun/special day   */
//public LR_TIMER_LENGTH;       		    		//* the time countdown of a lastrequest duel  */
//public VOTEDAY_TIMER_LENGTH   		    		//* the time countdown of a voteday			  */
//public Handle:JB_DB_TUPLE_HANDLER = Empty_Handle; //* Holds the database tuple				  */
//public CELLS_BUTTON = -1;			    			//* Holds the cell button entity index if set */
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
