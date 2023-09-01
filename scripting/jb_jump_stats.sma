/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <fakemeta>
#include <xs>
#include <hamsandwich>
#include <jailbreak_core>

#define PLUGIN  "[JB] JUMP STATS"
#define AUTHOR  "Natsheh"

#define PLAYER_STANDING_OFFSET 36.0
#define PLAYER_CROUCHING_OFFSET 18.0
#define PLAYER_MINIMUM_JUMP_DISTANCE 150.0
#define PLAYER_FRONT_MAXSIZE 16.0

new g_lr_longjump, g_LR_LJ_MENU_OPTIONS, g_lr_contest_option, g_PlayerJumped, Float:g_fPlayerJumpDistanceCache[MAX_PLAYERS+1],
 Float:g_fJumpStart[MAX_PLAYERS+1][3], g_player_jump_attempts[MAX_PLAYERS+1], g_player_opponent[MAX_PLAYERS+1],
 g_player_in_air, g_IsPlayerAlive, g_bFirstSpawn = -1, HamHook:g_HamHookPlayerPostThinkPost;

enum any:JUMP_CONTEST_OPTIONS(+=1)
{
    CONTEST_NONE = -1,
    CONTEST_LONGEST_JUMP,
    CONTEST_LONGEST_JUMPS_COLLECTION,
    CONTEST_SHORTEST_JUMP
}

new const g_szJumpContestOptions[][] =
{
    "Longest Jump #3 Attempts",
    "Longest #3 Jumps Collection",
    "Shortest Jump"
}

const Invalid_NewMenu = -1;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    RegisterHam(Ham_Spawn, "player", "fw_player_spawn_post", .Post=true);
    RegisterHam(Ham_Killed, "player", "fw_player_killed_post", .Post=true);
    DisableHamForward( (g_HamHookPlayerPostThinkPost = RegisterHam(Ham_Player_PostThink, "player", "fw_player_postthink_post", .Post=true)) );

    g_lr_longjump = register_jailbreak_lritem("Jumping Contest");

    g_LR_LJ_MENU_OPTIONS = menu_create("Choose an option!", "mhandler");

    if(g_LR_LJ_MENU_OPTIONS != Invalid_NewMenu)
    {
        for(new i; i < sizeof g_szJumpContestOptions; i++)
        {
            menu_additem(g_LR_LJ_MENU_OPTIONS, g_szJumpContestOptions[i]);
        }
    }
}

public plugin_end()
{
    if(g_LR_LJ_MENU_OPTIONS != Invalid_NewMenu)
    {
        menu_destroy(g_LR_LJ_MENU_OPTIONS);
    }
}

public mhandler(id, menu, item)
{
    if(item <= -1)
    {
        return PLUGIN_HANDLED;
    }

    g_lr_contest_option = item;
    jb_lr_show_targetsmenu(id, g_lr_longjump);
    return PLUGIN_HANDLED;
}

public jb_lr_duel_selected(id, itemid)
{
    if(itemid == g_lr_longjump)
    {
        menu_display(id, g_LR_LJ_MENU_OPTIONS);
        return JB_LR_OTHER_MENU;
    }

    return JB_IGNORED;
}

public jb_lr_duel_start(prisoner, guard, duelid)
{
    if(duelid == g_lr_longjump)
    {
        if(g_lr_contest_option == CONTEST_NONE)
        {
            g_lr_contest_option = CONTEST_LONGEST_JUMP;
        }

        cprint_chat(0, _, "Jumping Contest : !g%s", g_szJumpContestOptions[g_lr_contest_option]);
    }
}

public jb_lr_duel_started(prisoner, guard, duelid)
{
    if(duelid == g_lr_longjump)
    {
        g_player_opponent[prisoner] = guard;
        g_player_opponent[guard   ] = prisoner;
        g_fPlayerJumpDistanceCache[prisoner] = 0.0;
        g_fPlayerJumpDistanceCache[guard   ] = 0.0;
        g_player_jump_attempts[prisoner] = 0;
        g_player_jump_attempts[guard   ] = 0;
        EnableHamForward(g_HamHookPlayerPostThinkPost);
        set_pev(prisoner, pev_gravity, 1.0);
        set_pev(guard   , pev_gravity, 1.0);
    }
}

public jb_lr_duel_ended(prisoner, guard, duelid)
{
    if(duelid == g_lr_longjump)
    {
        g_lr_contest_option = CONTEST_NONE;
        g_player_opponent[prisoner] = 0;
        g_player_opponent[guard   ] = 0;
    }
}

public client_disconnected(id)
{
    remove_flag(g_IsPlayerAlive,id);
    remove_flag(g_PlayerJumped,id);
    set_flag(g_bFirstSpawn,id);
}

public fw_player_killed_post(id)
{
    remove_flag(g_IsPlayerAlive,id);
    remove_flag(g_PlayerJumped,id);
}

public fw_player_spawn_post(id)
{
    if(check_flag(g_bFirstSpawn,id))
    {
        remove_flag(g_bFirstSpawn,id);
        return;
    }

    set_flag(g_IsPlayerAlive,id);
    remove_flag(g_PlayerJumped,id);
}

public fw_player_postthink_post( id )
{
    if(g_lr_contest_option == CONTEST_NONE)
    {
        DisableHamForward(g_HamHookPlayerPostThinkPost);
        return;
    }

    if(!check_flag(g_IsPlayerAlive,id)) return;

    static bool:bOnGround;
    bOnGround = ((pev(id, pev_flags) & FL_ONGROUND) && !(pev(id, pev_flags) & (FL_FLY|FL_SWIM|FL_FROZEN|FL_FLOAT|FL_ONTRAIN))) ? true : false;

    if(pev(id, pev_button) & IN_JUMP)
    {
        set_flag(g_PlayerJumped,id);
    }

    if(bOnGround)
    {
        if(check_flag(g_player_in_air,id))
        {
            player_landed(id);
            remove_flag(g_player_in_air,id);
        }

        pev(id, pev_origin, g_fJumpStart[id]);
        g_fJumpStart[id][2] -= (pev(id, pev_flags) & FL_DUCKING) ? PLAYER_CROUCHING_OFFSET : PLAYER_STANDING_OFFSET;
        return;
    }

    if(!bOnGround && !check_flag(g_player_in_air,id))
    {
        set_flag(g_player_in_air,id);
        return;
    }
}

player_landed( id )
{
    if( check_flag(g_PlayerJumped,id) )
    {
        remove_flag(g_PlayerJumped,id);

        static Float:fVelocity[3];
        pev(id, pev_velocity, fVelocity);

        if(xs_vec_len_2d(fVelocity) <= 1.0)
        {
            return;
        }

        new szName[32], Float:fDiff[3], Float:fEnd[3];
        pev(id, pev_origin, fEnd);
        get_user_name(id, szName, charsmax(szName));
        xs_vec_sub(g_fJumpStart[id], fEnd, fDiff);
        xs_vec_normalize(fDiff, fDiff);
        xs_vec_neg(fDiff, fDiff);
        vector_to_angle(fDiff, fDiff);

        fEnd[0] += PLAYER_FRONT_MAXSIZE * floatcos(fDiff[1],degrees);
        fEnd[1] += PLAYER_FRONT_MAXSIZE * floatsin(fDiff[1],degrees);
        fEnd[2] -= (pev(id, pev_flags) & FL_DUCKING) ? PLAYER_CROUCHING_OFFSET : PLAYER_STANDING_OFFSET;

        new Float:fJumpDistance = get_distance_f(g_fJumpStart[id], fEnd);

        switch( g_lr_contest_option )
        {
            case CONTEST_LONGEST_JUMP:
            {
                new target = g_player_opponent[id];

                if( target && g_player_jump_attempts[id] < 3 )
                {
                    if(g_fPlayerJumpDistanceCache[id] < fJumpDistance)
                    {
                        g_fPlayerJumpDistanceCache[id] = fJumpDistance;
                        cprint_chat(0, _, "%s has jumped %.2f units long!", szName, fJumpDistance);
                    }

                    if(++g_player_jump_attempts[id] >= 3)
                    {
                        if( target && g_player_jump_attempts[target] >= 3 )
                        {
                            if(g_fPlayerJumpDistanceCache[id] <= g_fPlayerJumpDistanceCache[target])
                            {
                                ExecuteHamB(Ham_Killed, id, target, GIB_ALWAYS);
                            }
                            else
                            {
                                ExecuteHamB(Ham_Killed, target, id, GIB_ALWAYS);
                            }
                        }
                    }
                }
            }
            case CONTEST_LONGEST_JUMPS_COLLECTION:
            {
                new target = g_player_opponent[id];

                if( target && g_player_jump_attempts[id] < 3 )
                {
                    g_fPlayerJumpDistanceCache[id] += fJumpDistance;
                    cprint_chat(0, _, "%s has jumped %.2f units long!", szName, fJumpDistance);

                    if(++g_player_jump_attempts[id] >= 3)
                    {
                        if( g_player_jump_attempts[target] >= 3 )
                        {
                            if(g_fPlayerJumpDistanceCache[id] <= g_fPlayerJumpDistanceCache[target])
                            {
                                ExecuteHamB(Ham_Killed, id, target, GIB_ALWAYS);
                            }
                            else
                            {
                                ExecuteHamB(Ham_Killed, target, id, GIB_ALWAYS);
                            }
                        }
                    }
                }
            }
            case CONTEST_SHORTEST_JUMP:
            {
                new target = g_player_opponent[id];

                if( target )
                {
                    if( g_fPlayerJumpDistanceCache[id] == 0.0 ||
                        g_fPlayerJumpDistanceCache[id] > fJumpDistance )
                    {
                        g_fPlayerJumpDistanceCache[id] = fJumpDistance;
                        cprint_chat(0, _, "%s has jumped %.2f units long!", szName, fJumpDistance);
                    }

                    if(g_fPlayerJumpDistanceCache[target] > 1.0 && g_fPlayerJumpDistanceCache[id] >= g_fPlayerJumpDistanceCache[target])
                    {
                        ExecuteHamB(Ham_Killed, id, target, GIB_ALWAYS);
                    }
                    else if(g_fPlayerJumpDistanceCache[id] > 1.0 && g_fPlayerJumpDistanceCache[id] < g_fPlayerJumpDistanceCache[target])
                    {
                        ExecuteHamB(Ham_Killed, target, id, GIB_ALWAYS);
                    }
                }
            }
        }
    }
}
