/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <jailbreak_core>

#define PLUGIN  "[JB] Gamble: Double or Nothing"
#define AUTHOR  "Natsheh"

native jailbreak_reg_gambling_game(const func_target[], const gamble_gamename[], gamble_minimum_amount=1000, gamble_game_access=0);

new const g_szSoundDrumRoll[] = "jailbreak/drum_roll.wav";
new const g_szSoundYaY[] = "jailbreak/yay.wav";
new const g_szSoundFail[] = "jailbreak/fail.wav";

public plugin_precache()
{
    PRECACHE_SOUND(g_szSoundDrumRoll);
    PRECACHE_SOUND(g_szSoundYaY);
    PRECACHE_SOUND(g_szSoundFail);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    jailbreak_reg_gambling_game("jb_DoubleOrNothing", "Double Or NOTHING!", 10000);
}

#if AMXX_VERSION_NUM > 182
public client_disconnected(id)
#else
public client_disconnect(id)
#endif
{
    remove_task(id);
}

public jb_DoubleOrNothing(id, gambling_amount, minimum_amount, access)
{
    if(access > 0 && !(get_user_flags(id) & access))
    {
        cprint_chat(id, _, "You have no access to gamble in 'double or nothing'!");
        return;
    }

    if(gambling_amount < minimum_amount)
    {
        cprint_chat(id, _, "no enough cash to gamble!");
        return;
    }

    if(task_exists(id))
    {
        return;
    }

    new iChances[100];
    arrayset(iChances, 1, 35);
    SortIntegers(iChances, sizeof iChances, .order = Sort_Random);
    SortIntegers(iChances, sizeof iChances, .order = Sort_Random);
    SortIntegers(iChances, sizeof iChances, .order = Sort_Random);

    emit_sound(id, CHAN_AUTO, g_szSoundDrumRoll, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    new iParams[2];
    iParams[0] = iChances[random(100)];
    iParams[1] = gambling_amount;
    set_task(6.0, "task_announce_results", id, iParams, 2);
}

public task_announce_results(const Params[2], const id)
{
    enum (+=1)
    {
        RESULTS_LOSE = 0,
        RESULTS_WIN
    }

    new gamble_Amount = Params[1];

    switch( Params[0] )
    {
        case RESULTS_LOSE:
        {
            cprint_chat(id, _, "You've lost all your betting!");
            jb_set_user_cash(id, jb_get_user_cash(id) - gamble_Amount);

            emit_sound(id, CHAN_AUTO, g_szSoundFail, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        }
        case RESULTS_WIN:
        {
            new szName[32], iWinnings = gamble_Amount;
            get_user_name(id, szName, charsmax(szName));
            cprint_chat(0, _, "%s have doubled his money and won $%d!", szName, iWinnings);
            jb_set_user_cash(id, jb_get_user_cash(id) + gamble_Amount);

            emit_sound(id, CHAN_AUTO, g_szSoundYaY, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        }
    }
}
