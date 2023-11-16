
#if defined _jailbreak_commander_included
	#endinput
#endif

#define _jailbreak_commander_included

enum any:WARDEN_ASSIGNED_STATES (+=1)
{
    WARDEN_ASSIGNED_STATE_LEGACY = 0,
    WARDEN_ASSIGNED_STATE_TRANSFERED,
    WARDEN_ASSIGNED_STATE_PROMOTED
}

enum any:WARDEN_DROP_STATES (+=1)
{
    WARDEN_DROP_STATE_QUIT = 0,
    WARDEN_DROP_STATE_KILLED,
    WARDEN_DROP_STATE_TRANSFERED,
    WARDEN_DROP_STATE_DEMOTED,
    WARDEN_DROP_STATE_DISCONNECTED
}

// returns the warden / commander index 0 if not found;
native jb_get_commander();

// set the new warden / commander Param newCommander is the new commander index
native jb_set_commander(newCommander, WARDEN_ASSIGNED_STATES:eState);

// register a new menu item into the warden / commander menu.
// returns item index, -1 on failure
native register_jailbreak_cmitem(const item_name[]);

// unregister a menu item in warden menu that was provided in itemid parameter
// return 0 on failure, 1 otherwise
native unregister_jailbreak_cmitem( const itemid );

// called when the warden select an item in the warden menu.
forward jb_cmenu_item_postselect(id, itemid);

forward jb_warden_assigned(id, WARDEN_ASSIGNED_STATES:eState);
forward jb_warden_dropped(id, WARDEN_DROP_STATES:eState);

/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset0 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
