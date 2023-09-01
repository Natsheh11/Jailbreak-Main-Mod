/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <jailbreak_core>
#include <vip_core>

native jb_grant_voice_access(id);
forward jb_voice_access_reset();

#define PLUGIN  "[JB] VIP: VOICE ACCESS"
#define AUTHOR  "Natsheh"

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    // Add your code here...
}

public vip_flag_creation()
{
    register_vip_flag('a', "Access to use the microphone/voice chat!");
}

public jb_voice_access_reset()
{
    new players[32], pnum;
    get_players(players, pnum, "ch");

    for(new i, id, bitFlagA = read_flags("a"); i < pnum; i++)
    {
        id = players[ i ];

        if(get_user_vip(id) & bitFlagA)
        {
            jb_grant_voice_access(id);
        }
    }
}
