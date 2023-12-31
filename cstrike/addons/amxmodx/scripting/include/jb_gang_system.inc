/* Header generated by AMXX-Studio*/

enum GANG_STATUS(+=1)
{
	NOT_INGANG = 0,
	GANG_MEMBER,
	GANG_LEADER,
	GANG_OWNER
}

// return user gang status
native jb_get_user_gang_status(id)

// get user gang name if he is in gang.
native jb_get_user_gang_name(id, gangname[], len)

// return user gang kills.
native jb_get_user_gang_kills(id)

// set player with authid in a new gang.
native jb_set_user_gang(const authid[], gangid, GANG_STATUS:status)

// remove player with authid from his gang.
native jb_remove_user_fromgang(const authid[], gangid)

// set gang members max slots.
native jb_set_gang_maxslots(const gangid, const newkills)

// return gang members max slots.
native jb_get_gang_maxslots(const gangid)