#if defined _jailbreak_gangs_included

	#endinput

#endif

#define _jailbreak_gangs_included

// * UserGangStatus *//
#define NOT_INGANG  0 
#define GANG_NONE  0
#define GANG_MEMBER 1
#define GANG_LEADER 2
#define GANG_OWNER  3
// * ---------------*//

/*************
* @Param itemname 		*the item  name inside of the gang menu.
* @Param onitemadd_func	*the function to get called when adding the item to the menu.
* @Param onselect_func	*the function to get called when selecting the item.
* @Info Functions build:-
*	onitemadd_func < player_index, gang_index, const gang_name[], item_name[] >
*	onselect_func < player_index, gang_index, const gang_name[], item_name[] >
* Returns ItemID >= 0
***************/
native jb_gang_menu_additem(const itemname[], const onitemadd_func[], const onselect_func[])

// sets items new upgrade level
native jb_set_gang_item_upg_level(const gangname[], const upgrade_item[], const upg_level)

// returns item current upgrade level
native jb_get_gang_current_upg_level(const upgrade_item[], const gangname[])

/* if the @param max_upgrade is set to 0 the following function_upgrade[] function format will be taken
 *  function_upgrade[] < const id, const gangid, const gangname[], Upgrade_Index >
 * otherwise
 *  function_upgrade[] < const id, const gangid, const gangname[], CurrentUpgrade, MaxUpgrade, Upgrade_Index >
 * */
native jb_register_gang_upgrade(const skill_name[], const skill_info[], const max_upgrade, const function_upgrade[])

// Sets gang maxslots !!!
native jb_set_gang_maxslots(const GangID, const NewMaxSlots)

// retrieves gang maxslots !
native jb_get_gang_maxslots(const GangID)

// retrieve user gang kills!
native jb_get_user_gang_kills(const Index)

// Retrieve user position in the gang! Check out the defines in TOP!
native jb_get_user_gang_status(const Index)

// Retrieves user gang name!
native jb_get_user_gang_name(const Index, GangName[], Len)

// Add user to a gang / Update user gang status!
native jb_set_user_gang(const authid[], const GangID, const UserGangStatus)

// Remove a user from his gang!
native jb_remove_user_fromgang(const authid[], const GangID)

// Displays the gang menu for the id user!
native jb_show_user_gang_menu(const id)

// Called when a gang is getting created return PLUGIN_HANDLED to block the creation...
forward jb_gang_creating(const Gangname[], const GangSkin[], const Owner_authid[])

// Called when a gang is fully created!!!
forward jb_gang_created(const Gangname[], const GangSkin[], const Owner_authid[])

// Called when a gang is getting destroyed return PLUGIN_HANDLED to block the destruction...
forward jb_gang_destroying(const authid[], const GangID, const Gangname[])

// Called when a gang is fully destroyed!!!
forward jb_gang_destroyed(const authid[], const GangID, const Gangname[])

// Called when a player is leaving his gang, return PLUGIN_HANDLED to block the action!
forward jb_gang_user_leaving(const GangID, const GangName[], const UserAuthID[], const UserGangStatus)

// Called when a player has left his gang!
forward jb_gang_user_left(const GangID, const GangName[], const UserAuthID[], const UserGangStatus)

// Called when a player joins a gang, return PLUGIN_HANDLED to block the action!
forward jb_gang_user_joining(const GangID, const GangName[], const UserAuthID[], const UserGangStatus)

// Called when a player has joined a gang!
forward jb_gang_user_joined(const GangID, const GangName[], const UserAuthID[], const UserGangStatus)

/* Happy Coding :) */
