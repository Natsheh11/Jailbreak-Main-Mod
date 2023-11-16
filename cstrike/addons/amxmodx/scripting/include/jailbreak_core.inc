/*********************/
/* Jailbreak core.   */
/*********************/
/** Made By Natsheh **
 *********************
 *********************
 *********************/


#pragma reqlib jailbreak_core
#if !defined AMXMODX_NOAUTOLOAD
#pragma loadlib jailbreak_core
#endif
 
#if defined _jailbreak_core_included
  #endinput
#endif
#define _jailbreak_core_included

#include <amxmodx>
#include <jailbreak_const>

/*
@String		name[]			name of the class
@String		playermodel[]		player model.
@String		vknifemdl[]		v_knife model path...
@String		pknifemdl[]		p_knife model path...
@String		primarywpns[]	class primary's weapons > Example : "ak47,m4a1,m249" these will be primary wpns depends on these cvars "jb_give_guard_weapons","jb_give_prisoner_weapons"
@String		secondarywpns[]	class secondary weapons > same as above this could be rifle or shield / nade's
@Integer	team			in which team this class will be registered ( 0 - Both teams, 1 - Ts, 2 - CTs )
@Integer	flag			access flags...
@String		knifesounds[]		knife sounds path....
- Returns	-1 on fail otherwise it returns the class-id
*/
native register_jailbreak_class(const name[], const playermodel[], const priweapons[], const secweapons[], const flag=0, const team, const vknife[], const pknife[], const knifesounds[])

/*
@String		name[]		name of the item in the jailbreak main menu
@Integer	iAccess		Admin access to access to the item, 0 - for all.
@Integer	team		Item for team.
- Info		jailbreak main menu registering new items :)
- Returns	-1 on fail otherwise it returns the item-id in the menu
*/
native register_jailbreak_mmitem(const name[], iAccess=0, team)

/*
@String		name[]		name of the item in the last request menu
@Integer	iAccess		Admin access to access to the item, 0 - for all.
- Info		last request menu registering new items :)
- Returns	-1 on fail otherwise it returns the item-id in the menu
*/
native register_jailbreak_lritem(const name[], iAccess=0)

/*
@String		name[]		name of the item in the shop menu
@String		info[]		info of what is the item is about.
@Integer	cost		cost of the item
@Integer	team		Item for team.
@Integer	access		access level, ADMIN_KICK, ADMIN_BAN, etc....
@Bitsum		bitsum_days [IMPORTANT] * while shifting in a bitsum ADD +1 FOR Example:- THIS is Day NONE :- (1<<(-1+1)) = (1<<0)
						            * (1<<(Dayid+1))  * 
- Info		shop menu registering new items :)
- Returns	-1 on fail otherwise it returns the item-id in the menu
*/
native register_jailbreak_shopitem(const name[], const info[], const cost, const team, const access=0, const bitsum_days=0)

/*
@String		name[]		name of the item in the day menu
@Integer	iAccess		Admin access to access to the item, 0 - for all.
@Float		fDay_Length	Day length time to end.
- Info		day menu registering new items :)
- Returns	-1 on fail otherwise it returns the item-id in the menu
*/
native register_jailbreak_day(const name[], const iAccess, const Float:fDay_Length=0.0, const Day_EndType:DayEndTypo=DAY_GUARDS_VS_PRISONERS)


/*
@Integer	id		show the player with this id the target menu
@Integer	duelid		the duel id which will be played....
@Integer	iAccess		Admin access to access to the item, 0 - for all.
- Info		show the last request target menu to the last prisoner
- Returns	NoReturns
*/
native jb_lr_show_targetsmenu(id, duelid, iAccess=0)

/*
@Integer	guard		return the guard id if duel is started
@Integer	prisoner	return the prisoner id if duel is started
- Info		give info about the duel if the duel is started
- Returns	Return current duel id,  -1 on failure;
*/
native jb_get_current_duel(&guard=0, &prisoner=0)

// returns how many duels are available if none duels were registered will return 0.
native jb_get_duels_registered()

// returns the duel id that is given by name.. return -1 on failure.
native jb_get_duelid_byname(const duelname[])

/*
@Integer	id		user index.
@Integer	iAmount		the amount of cash to set for the player.
- Info		set player cash to a specificed amount
- Returns	Returns -1 on failure such as player is not connected or index isn't valid.
*/
native jb_set_user_cash(id, iAmount)

/*
@Integer	id		user index.
- Info		get player cash
- Returns	Returns -1 on failure otherwise the amount of cash that player has.
*/
native jb_get_user_cash(id)

/*
@Integer	id		user index.
@Float	fPercentage		the unit percentage of discount to set for the player.
- Info		set player purchase discount to a specificed percentage
- Returns	Returns -1 on failure such as player is not connected or index isn't valid.
*/
native jb_set_user_discount(id, Float:fPercentage);

/*
@Integer	id		user index.
- Info		get player purchase discount
- Returns	Returns a float ( discount unit percentage... )
*/
native Float:jb_get_user_discount(id);

/*
@Integer	itemid		id of the item in the shop to update.
@String		itemnewname	new name for the item.
@String		itemnewinfo	new info on the item.
@Integer	newcost		new cost for the item.
@Integer	newaccess	new access for the item.
@Integer	newteam		new team for the item.
@Bitsum		newbitsdays	new bitsdays for the item..
-Returns	-1 on failure, 0 on success.
*/
native jb_update_shop_item(itemid, const newname[]="", const newinfo[]="", const newcost=-1, const newaccess=-1, const newteam=-1, const newbitsdays=-1)

// returns how many items in the shop are available if none items were registered will return 0.
native jb_get_shop_items_registered()

/*
- Info		force to end the fun day.
- Returns	return 0 on failure.
*/
native jb_end_theduel()

/*
- Info	format the sduelname to the duel name by the giving duelid return 0 on failure.
*/
native jb_get_duel_name(duelid, sDuelname[], iLen)

/*
@Integer	Dayid		day index.
- Info		get day length by sec(timeleft).
- Returns	Return Float Day Length left time in seconds
*/
native Float:jb_get_day_length(Dayid)

/*
@Integer	Dayid		day index.
@Integer	seconds		Set fun day timer in seconds..
- Info		set fun day timer.
- Returns	NoReturns.
*/
native jb_set_day_length(dayid, Float:seconds)

/*
- Info		used to get current played day.
- Returns	Returns Day id otherwise -1 if there isnt an day inprogress.
*/
native jb_get_current_day()

// returns how many days are available if none days were registered will return 0.
native jb_get_days_registered()

// returns the day id that is given by name.. return -1 on failure.
native jb_get_dayid_byname(const dayname[])

/*
- Info	format the sdayname to the day name by the giving dayid return 0 on failure.
*/
native jb_get_day_name(dayid, sDayname[], iLen)

/*
@Integer	iDayid		day index >= 0
- Info		start a fun day if there is no funday inprogress....
- Returns	NoReturns
*/
native jb_start_theday(iDayid)

/*
- Info		ends the fun day if there is a funday inprogress....
- Returns	NoReturns
*/
native jb_end_theday()

/*
@Integer	id		user index.
- Info		get user class id of which team he is joined
- Returns	Return Classid of user index
*/
native jb_get_user_classid(id)

/*
@Integer	id		user index.
@Integer	classid		class index
- Info		set user class id of which team he is joined
- Returns	NoReturns
*/
native jb_set_user_classid(id, classid)

/*
@Integer	classid		class index
@String		szReturn[]	Outprinting the class name of the classid
@Integer	iLen		chars of max outprinting
- Info		get 
- Returns	Return 1 on success otherwise 0
*/
native jb_get_classname(classid, szReturn[], iLen)

/*
@Integer	classid		class index
@String		new_name[]	input the new name of the class
- Info		change the classname
- Returns	NoReturns
*/
native jb_set_class_newname(classid, const new_name[])

/* gets class data such as class team, flags etc.... */
native jb_get_classdata(const classid,
												&team=-1, &flags=-1, &primarys=-1, &secondarys=-1,
												vknifemdl[]="", vKLen=0, pknifemdl[]="", pKLen=0, KSounds[]="", sKLen=0,
												model[]="", mlen=0, &modelbody=-1, &modelskin=-1)

// returns how many classes registered.
native jb_get_classes_count()

/* set client model to his class model */
native jb_set_user_class_model(index)

/*
@Integer	id		client index.
@Integer	iClassid	class index.
- Info		check whether the class index is correct or false
- Returns	Return true/false
*/
native jb_is_user_class_valid(id, iClassid)

/*
@Integer	id	user-id ( if userid is invalid the native will return -1
@Bitsum		wpn_bitsum	if = 0, will check if all wpns are blocked and will return wpns arent blocked
- Returns	return true if user weapons all are blocked otherwise wise will return bitsum of wpns which arent blocked.
*/
native jb_is_user_weapons_blocked(id, wpn_bitsum=0)

/*
@Integer	id	user-id
@Boolean	block	true to block user from getting weapons otherwise false
@Bitsum		bitsum_wpns	allow/disallow weapons by using bitsum if = 0 will block all wpns.
- Returns	NoReturns
*/
native jb_block_user_weapons(id, bool:block, bitsum=0)

/* open/close the cells and/or returns the cells entity index */
enum JB_CELLS_STATE(+=1)
{
	JB_CELLS_ENTITY_INDEX = -1,
	JB_CELLS_CLOSE,
	JB_CELLS_OPEN
}

native jb_cells(JB_CELLS_STATE:iState=JB_CELLS_OPEN)

enum (+=1) {
	FILE_ERROR = 0,
	FILE_CATEGORY_CREATED,
	FILE_KEYVALUE_BUFFERED,
	FILE_KEYVALUE_UPDATED,
	FILE_KEYVALUE_CREATED,
	FILE_KEYVALUE_EMPTY
}

// get key value...
native jb_ini_get_keyvalue(const category[], const key[], value[], len)

// hook jailbreak logmessages /* return logmessage index */
native register_jailbreak_logmessages(const function[], const logmessage[])

// write a jailbreak logmessage its catchable by hooking with register_jailbreak_logmessages
native jb_logmessage(const logmessage[], any:...)

// write a jailbreak log action message its catchable by hooking with register_jailbreak_logmessages
/* message format will be ( "Butcher<5><BOT><TERRORIST>" did an action upon "Jermy<5><BOT><TERRORIST>" ) */
/*                        ( "Taker" szAction upon aka victim ) */
native jb_logmessage_action(const szAction[], taker, upon=0)

// return today of  the week (game days).
native jb_whats_today()

// gets the name of the indexed day (game days)
native jb_get_weekdays_name(index, szDay[], iLength)

enum (+=1)
{
	JB_DISPLAY_RADAR_ALL = -1,
	JB_DISPLAY_RADAR_DEFAULT
}

// set players radar to detect anyone.
native jb_display_on_player_radar(const player, const bitsOthers);

// set user friendlies and enemies, if players_bits set to JB_ALLIES_DEFAULT(0) everything will goes back to normal.
// if players_bits is set to JB_ALLIES_NONE(-1) user will be able to shoot/kill everyone.
native jb_set_user_allies(id, players_bits);
native jb_get_user_allies(id);
native jb_bind_user_allies_var(id, const public_var[]);

// set user friendlies and enemies, if players_bits set to JB_ENEMIES_DEFAULT(0) everything will goes back to normal.
// if players_bits is set to JB_ENEMIES_EVERYONE(-1) user will be able to shoot/kill everyone.
native jb_set_user_enemies(id, players_bits);
native jb_get_user_enemies(id);
native jb_bind_user_enemies_var(id, const public_var[]);

/* Called when use touch a weaponbox pre pre */
forward jb_pretouch_wpnbox(wEnt, player, bool:block)

/* Called when the player opens the main menu - Passing player index, and all available items - */
forward jb_mm_itemadded(id, itemid)

/* Called when user select item from the jailbreak main menu, pass id & itemid */
forward jb_mm_itemselected(id, itemid)

/* Called before a last request item been added inside the menu */
/* you can return JB_MENU_ITEM_DONT_SHOW to not add to the menu or JB_MENU_ITEM_UNAVAILABLE to lock the item */
/* return JB_IGNORED to continue... */
forward jb_lr_duel_select(id, itemid)

/* Called when user select duel from the lastrequest menu, pass id & itemid */
forward jb_lr_duel_selected(id, itemid)

/* Called when user pre start the duel from the lastrequest menu, pass prisoner=lastteror & guard id & duelid */
// returns JB_LR_NOT_AVAILABLE to block the last request duel or JB_CONTINUE to continue.
forward jb_lr_duel_start(prisoner, guard, duelid)

/* Called when user post start the duel from the lastrequest menu, pass prisoner=lastteror & guard id & duelid */
forward jb_lr_duel_started(prisoner, guard, duelid)

/* Called before ending the lr duel return JB_HANDLED to block the lr duel from ending */
forward jb_lr_duel_end(prisoner, guard, duelid)

/* Called when duel ended, pass prisoner=lastteror & guard id & duelid */
forward jb_lr_duel_ended(prisoner, guard, duelid)

/* Called when user opens the shop menu , pass id & itemid */
forward jb_shop_item_preselect(id, itemid)

/* Called when user select the item from the shop menu before actualy get the item , pass id & itemid */
forward jb_shop_item_postselect(id, itemid)

/* Called when user bought the item from the shop menu (give the item here) , pass id & itemid */
forward jb_shop_item_bought(id, itemid)

/* Called when the admin/user open/gets a fun day menu , pass id & itemid */
forward jb_day_preselected(id, Dayid, iAccess)

/* Called when the admin/user select item in the fun day menu , pass id & itemid */
forward jb_day_postselected(id, Dayid, iAccess)

/* Called before the funday start return JB_HANDLED to block the funday from starting */
forward jb_day_start(iDayid)

/* Called when the fun day started */
forward jb_day_started(iDayid)

/* Called before the fun day ends (pre end) return JB_HANDLED to block the day from ending */
forward jb_day_end(iDayid)

/* Called when the fun day ends */
forward jb_day_ended(iDayid)

/* Called on round pre start */
forward jb_round_start_pre()

/* Called when round start */
forward jb_round_start()

/* Called on round pre end return JB_HANDLED to block the round from ending */
forward jb_round_end_pre()

/* Called when round end */
forward jb_round_end()

/* Called at plugin_precache, its the best/only way to use 'register_jailbreak_class' native */
forward jb_class_creation()

/* Called when player gets his team selection menu.... */
forward jb_team_join(id)

/* print colorful chat :) */
stock cprint_chat(id, team='n', const message[], any:...)
{
	static sBuffer[MAX_CHAT_MESSAGE_LENGTH+1];
	vformat(sBuffer, charsmax(sBuffer), message, 4);
	replace_all(sBuffer, charsmax(sBuffer), "!g", "^4");
	replace_all(sBuffer, charsmax(sBuffer), "!y", "^1");
	replace_all(sBuffer, charsmax(sBuffer), "!n", "^1");
	replace_all(sBuffer, charsmax(sBuffer), "!t", "^3");
	format(sBuffer, charsmax(sBuffer), "%s %s", TAG, sBuffer);
	
	sBuffer[MAX_CHAT_MESSAGE_LENGTH] = 0;
	
	static iMsgID_SayText = 0;
	if(!iMsgID_SayText) iMsgID_SayText = get_user_msgid("SayText");

	if(!id) // when id is 0 or negative the team parameter has - effect.
	{
		static players[32], num, i; i = 0;
		
		switch( team ) 
		{
			case 'C', 'c': get_players(players, num, "che", "CT");
			case 'T', 't': get_players(players, num, "che", "TERRORIST");
			case 'S', 's': get_players(players, num, "che", "SPECTATOR");
			default: get_players(players, num, "ch");
		}

		while( i < num )
		{
			id = players[i++];
			
			message_begin(MSG_ONE, iMsgID_SayText, _, id);
			write_byte(id);
			write_string(sBuffer);
			message_end();
		}
	}
	else
	{
		if(is_user_connected(id)) // to a specified player...
		{
			message_begin(MSG_ONE, iMsgID_SayText, _, id);
			write_byte(id);
			write_string(sBuffer);
			message_end();
		}
	}
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang11265\\ f0\\ fs16 \n\\ par }
*/
