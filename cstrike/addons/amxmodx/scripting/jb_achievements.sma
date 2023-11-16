/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
// #include <amxmisc>
// #include <cstrike>
// #include <engine>
// #include <fakemeta>
// #include <hamsandwich>
// #include <fun>
// #include <xs>
// #include <sqlx>

#define PLUGIN  "JB ACHIEVEMENTS [CORE]"
#define VERSION "1.0"
#define AUTHOR  "Natsheh"

enum ACHIEVEMENTS_DATA
{
    ACHIEVEMENT_NAME[64],
    ACHIEVEMENT_MAX_TIMES,
    ACHIEVEMENT_INCREMENT,
    ACHIEVEMENT_ACTION[32],
    ACHIEVEMENT_ACTION_RESET[32],
    ARRAY:ACHIEVEMENT_CHECKS

}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    // Add your code here...
}

CreateAchievement(const achName[], const achAction, const achException)

public OnPlayerKilled(const victim, const killer, const shouldgib)
{
    static xArray[ACHIEVEMENTS_DATA];
    ArrayGetArray(g_pArray_OnPlayerKilled, iCounter, xArray);

    callfunc_begin(const func[], const plugin[] = "")
}
