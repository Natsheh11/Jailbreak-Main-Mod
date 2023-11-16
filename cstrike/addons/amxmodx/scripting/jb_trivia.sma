/* Sublime AMXX Editor v2.2 */

#pragma dynamic 32768

#include <amxmodx>
#include <amxmisc>
#include <curl>
#include <json>
#include <jailbreak_core>
#include <fakemeta>
#include <hamsandwich>

#define CURL_BUFFER_SIZE_LEN 8192

#define PLUGIN  "[JB] TRIVIA NIGHT"
#define AUTHOR  "Natsheh"

#define json_is_integer(%1) (json_is_number(%1) || json_is_bool(%1))

#define MAX_CATEGORY_NAME 64
#define MAX_QUESTION_LENGTH 128
#define MAX_ANSWER_LENGTH 64
#define SPECIAL_DAY_MAX_QUESTIONS 20
#define TASK_RETRIEVE_HARD_Q 69693
#define TASK_RETRIEVE_MEDIUM_Q 69963
#define TASK_RETRIEVE_EASY_Q 96693

native jailbreak_reg_gambling_game(const func_target[], const gamble_gamename[], gamble_minimum_amount=1000, gamble_game_access=0);

native jb_get_commander();
native register_jailbreak_cmitem(const itemname[]);
native unregister_jailbreak_cmitem(const item_index);
forward jb_cmenu_item_postselect(id, item);

enum any:TRIVIA_DATA_CATEGORIES
{
    TRIVIA_CATEGORY_ID,
    TRIVIA_CATEGORY_NAME[MAX_CATEGORY_NAME]
}

enum any:TRIVIA_QUESTION_TYPES(+=1)
{
    TRIVIA_Q_TYPE_ANY = 0,
    TRIVIA_Q_TYPE_CHOICE,
    TRIVIA_Q_TYPE_LOGIC
}

enum any:TRIVIA_QUESTION_DIFFICULTIES(+=1)
{
    TRIVIA_QUESTION_DIFFICULTY_ANY = -1,
    TRIVIA_QUESTION_DIFFICULTY_EASY,
    TRIVIA_QUESTION_DIFFICULTY_MEDIUM,
    TRIVIA_QUESTION_DIFFICULTY_HARD
}

enum any:TRIVIA_DATA
{
    TRIVIA_QUESTION_CATEGORY_ID,
    TRIVIA_QUESTION_CATEGORY[MAX_CATEGORY_NAME],
    TRIVIA_QUESTION_TYPES:TRIVIA_QUESTION_TYPE,
    TRIVIA_QUESTION_DIFFICULTIES:TRIVIA_QUESTION_DIFFICULTY,
    TRIVIA_QUESTION[MAX_QUESTION_LENGTH],
    TRIVIA_QUESTION_CORRECT_ANSWER[MAX_ANSWER_LENGTH],
    Array:TRIVIA_QUESTION_INCORRECT_ANSWERS
}

enum any:PLAYER_DATA
{
    PLAYER_CORRECT_ANSWER_ID,
    PLAYER_CORRECT_ANSWERS_COUNT,
    PLAYER_INCORRECT_ANSWERS_COUNT,
    PLAYER_QUESTION_ID,
    PLAYER_INCORRECT_ANSWERS_INROW,
    PLAYER_QUESTION_TIME
}

new Array:g_array_trivia_category, Array:g_array_trivia_quesdata, g_Trivia_specialday, HamHook:g_HamHookPlayerSpawnPost,
 curl_slist: g_cURLHeaders = SList_Empty, g_user_trivia_category[MAX_PLAYERS+1][TRIVIA_DATA], g_pcvar_sd_win_reward,
 g_player_answers[MAX_PLAYERS+1][PLAYER_DATA], g_szTOKEN[128], g_player_index, g_player_triviabetting[MAX_PLAYERS+1],
 g_CM_TriviaMenuItem;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    g_array_trivia_category = ArrayCreate(TRIVIA_DATA_CATEGORIES, 1);
    g_array_trivia_quesdata = ArrayCreate(TRIVIA_DATA, 1);

    register_concmd("trivia_random", "cmd_quest", ADMIN_KICK);
    register_concmd("trivia_get_categories", "cmd_get_categories", ADMIN_KICK);

    register_clcmd("say /trivia", "trivia_clcmd", ADMIN_KICK);

    g_Trivia_specialday = register_jailbreak_day("TRIVIA Night", 0, 0.0, DAY_ONE_SURVIVOR);

    AddTranslation("en", CreateLangKey("ASK_TRIVIA_QUESTION"), "Ask a Trivia question!");
    g_CM_TriviaMenuItem = register_jailbreak_cmitem("ASK_TRIVIA_QUESTION");
    jailbreak_reg_gambling_game("jb_trivia_gamble", "Trivia", 5000, ADMIN_IMMUNITY);

    register_menu( "TRIVIA_QMENU", -1, "qmhandler" );

    DisableHamForward( ( g_HamHookPlayerSpawnPost = RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", .Post = true) ) );

    g_pcvar_sd_win_reward = register_cvar("jb_trivia_specialday_reward", "10000");
}

public fw_PlayerSpawn_Post(id)
{
    if(!is_user_alive(id)) return;

    set_pev(id, pev_takedamage, DAMAGE_NO);
    question_menu(id, g_player_answers[id][PLAYER_QUESTION_ID]);
}

public plugin_cfg()
{
    curl_retrieve_trivia_categories();
    set_task(3.0, "task_retrieve_hard_questions", TASK_RETRIEVE_HARD_Q, _, _, "b");
    set_task(3.0, "task_retrieve_medium_questions", TASK_RETRIEVE_MEDIUM_Q, _, _, "b");
    set_task(3.0, "task_retrieve_easy_questions", TASK_RETRIEVE_EASY_Q, _, _, "b");
}

public task_retrieve_hard_questions()
{
    new aData[1]; aData[0] = TASK_RETRIEVE_HARD_Q;
    curl_retrieve_trivia_questions(
            .iAmount=SPECIAL_DAY_MAX_QUESTIONS,
            .iDifficulty=TRIVIA_QUESTION_DIFFICULTY_HARD,
            .QType=TRIVIA_Q_TYPE_ANY,
            .szWritefunction="hard_question_received_insertion",
            .data = aData, .size = 1 );
}

public task_retrieve_medium_questions()
{
    new aData[1]; aData[0] = TASK_RETRIEVE_MEDIUM_Q;
    curl_retrieve_trivia_questions(
            .iAmount=SPECIAL_DAY_MAX_QUESTIONS,
            .iDifficulty=TRIVIA_QUESTION_DIFFICULTY_MEDIUM,
            .QType=TRIVIA_Q_TYPE_ANY,
            .szWritefunction="medium_question_received_insertion",
            .data = aData, .size = 1 );
}

public task_retrieve_easy_questions()
{
    new aData[1]; aData[0] = TASK_RETRIEVE_EASY_Q;
    curl_retrieve_trivia_questions(
            .iAmount=SPECIAL_DAY_MAX_QUESTIONS,
            .iDifficulty=TRIVIA_QUESTION_DIFFICULTY_EASY,
            .QType=TRIVIA_Q_TYPE_ANY,
            .szWritefunction="easy_question_received_insertion",
            .data = aData, .size = 1 );
}

public jb_cmenu_item_postselect(id, itemid)
{
    if(g_CM_TriviaMenuItem == itemid)
    {
        // The warden is asking the question!
        trivia_menu(id);
        return JB_HANDLED;
    }
    return JB_IGNORED;
}

public jb_trivia_gamble(id, gambling_amount, minimum_amount, access)
{
    if(access > 0 && !(get_user_flags(id) & access))
    {
        cprint_chat(id, _, "You have no access to gamble in !gTrivia!");
        return;
    }

    if(gambling_amount < minimum_amount)
    {
        cprint_chat(id, _, "no enough cash to gamble in the Trivia");
        return;
    }

    if(!g_player_index)
    {
        g_player_index = id;
        g_user_trivia_category[id][TRIVIA_QUESTION_CATEGORY_ID] = -1;
        g_user_trivia_category[id][TRIVIA_QUESTION_DIFFICULTY] = TRIVIA_QUESTION_DIFFICULTY_HARD;
        g_user_trivia_category[id][TRIVIA_QUESTION_TYPE] = TRIVIA_Q_TYPE_CHOICE;
        g_player_triviabetting[id] = gambling_amount;

        curl_retrieve_trivia_questions(
                .iAmount=1,
                .iDifficulty=TRIVIA_QUESTION_DIFFICULTY_HARD,
                .QType=TRIVIA_Q_TYPE_CHOICE,
                .szWritefunction="question_received_player" );
    }
    else
    {
        cprint_chat(id, _, "Wait, Trivia is busy with someone else!");
    }
}

#if AMXX_VERSION_NUM <= 182
public client_disconnect(id)
#else
public client_disconnected(id)
#endif
{
    remove_task(id);
    g_player_answers[id][PLAYER_CORRECT_ANSWERS_COUNT] = 0;
    g_player_answers[id][PLAYER_INCORRECT_ANSWERS_COUNT] = 0;
    g_player_answers[id][PLAYER_QUESTION_ID] = 0;
    g_player_answers[id][PLAYER_INCORRECT_ANSWERS_INROW] = 0;
    g_player_triviabetting[id] = 0;
}

public jb_day_ended(iDAYID)
{
    if(iDAYID == g_Trivia_specialday)
    {
        DisableHamForward(g_HamHookPlayerSpawnPost);

        new players[32], pnum;
        get_players(players, pnum, "ah");
        for(new i, player; i < pnum; i++)
        {
            player = players[i];
            set_pev(player, pev_takedamage, DAMAGE_YES);
        }

        if(pnum == 1) // WE've a winner.
        {
            new id = players[ 0 ], szName[32];
            get_user_name(id, szName, charsmax(szName));
            cprint_chat(0, _, "!g%s !yhas won the !gTRIVIA DAY !yand answered !g%d !tquestions correctly !yand !g%d !tincorrect!y!",
                szName, g_player_answers[id][PLAYER_CORRECT_ANSWERS_COUNT], g_player_answers[id][PLAYER_INCORRECT_ANSWERS_COUNT]);

            new Float:fPercentage = ( float(g_player_answers[id][PLAYER_CORRECT_ANSWERS_COUNT]) / float(SPECIAL_DAY_MAX_QUESTIONS) ), iReward;

            if( (iReward = floatround(fPercentage * get_pcvar_float(g_pcvar_sd_win_reward))) > 0 )
            {
                cprint_chat(0, _, "%s has won $%d for answering %d%%%% of the questions correct!", szName, iReward, floatround(fPercentage * 100.0));
                jb_set_user_cash(id, jb_get_user_cash(id) + iReward);
            }
        }
    }
}

public jb_day_started(iDAYID)
{
    if(iDAYID == g_Trivia_specialday)
    {
        new players[32], pnum;
        get_players(players, pnum, "h");
        for(new i, id; i < pnum; i++)
        {
            id = players[i];
            g_player_answers[id][PLAYER_CORRECT_ANSWERS_COUNT] = 0;
            g_player_answers[id][PLAYER_INCORRECT_ANSWERS_COUNT] = 0;
            g_player_answers[id][PLAYER_QUESTION_ID] = 0;
            g_player_answers[id][PLAYER_INCORRECT_ANSWERS_INROW] = 0;
            g_player_answers[id][PLAYER_QUESTION_TIME] = 0;
            set_pev(id, pev_takedamage, DAMAGE_NO);
        }

        curl_retrieve_trivia_questions(.iAmount=SPECIAL_DAY_MAX_QUESTIONS, .szWritefunction="questions_response_received");
    }
}

question_menu(id, const iQuestionID, const iTime=10, Array:QArray=Invalid_Array)
{
    if(QArray == Invalid_Array)
    {
        QArray = g_array_trivia_quesdata;
    }

    static iSize = 0;
    if(!(iSize=ArraySize(QArray)) || iQuestionID >= iSize) return;

    new szText[512], xArray[TRIVIA_DATA], iKeys;
    ArrayGetArray(QArray, iQuestionID, xArray);

    new QuLen = strlen(xArray[TRIVIA_QUESTION]);

    for(new i, iStart, QCharsmax = charsmax(xArray[TRIVIA_QUESTION]), maxloop = floatround(QuLen / 64.0, floatround_tozero); i < maxloop; i++)
    {
        iStart = min(64 * ( i + 1 ), QCharsmax);
        replace(xArray[TRIVIA_QUESTION][iStart], QCharsmax - iStart, " ", "^n");
    }

    new iLen = formatex(szText, charsmax(szText), "\yCategory: \r%s^n \yQuestion: \w%s^n^n", xArray[TRIVIA_QUESTION_CATEGORY], xArray[TRIVIA_QUESTION]);

    switch( xArray[TRIVIA_QUESTION_TYPE] )
    {
        case TRIVIA_Q_TYPE_CHOICE:
        {
            new Array:pTempArray = ArrayClone(xArray[TRIVIA_QUESTION_INCORRECT_ANSWERS]), szAnswer[MAX_ANSWER_LENGTH];
            ArrayPushString(pTempArray, xArray[TRIVIA_QUESTION_CORRECT_ANSWER]);

            for(new i, x, maxloop = ArraySize(pTempArray); i < maxloop; i++)
            {
                ArrayGetString(pTempArray, (x=random(ArraySize(pTempArray))), szAnswer, charsmax(szAnswer));

                if(equal(szAnswer,xArray[TRIVIA_QUESTION_CORRECT_ANSWER]))
                {
                    g_player_answers[id][PLAYER_CORRECT_ANSWER_ID] = i;
                }

                iLen += formatex(szText[iLen], charsmax(szText) - iLen, "\r%d. \w%s^n", i + 1, szAnswer);
                iKeys |= (1<<i);

                ArrayDeleteItem(pTempArray, x);
            }
            ArrayDestroy(pTempArray);
        }
        case TRIVIA_Q_TYPE_LOGIC:
        {
            iKeys |= (MENU_KEY_1|MENU_KEY_2);
            iLen += formatex(szText[iLen], charsmax(szText) - iLen, "\w1. \yTrue^n");
            iLen += formatex(szText[iLen], charsmax(szText) - iLen, "\w2. \rFalse^n");

            switch( xArray[TRIVIA_QUESTION_CORRECT_ANSWER][0] )
            {
                case 'T', 't': g_player_answers[id][PLAYER_CORRECT_ANSWER_ID] = 0;
                case 'F', 'f': g_player_answers[id][PLAYER_CORRECT_ANSWER_ID] = 1;
            }
        }
    }

    show_menu(id, iKeys, szText, .title="TRIVIA_QMENU");

    remove_task(id);
    g_player_answers[id][PLAYER_QUESTION_TIME] = iTime;
    set_task(1.0, "task_question_length", id, _, _, "b");
}

public task_question_length(id)
{
    static iTime, szWord[16];
    iTime = g_player_answers[id][PLAYER_QUESTION_TIME]--;

    if( iTime >= 0 )
    {
        num_to_word(iTime, szWord, charsmax(szWord));
        client_cmd(id, "spk ^"%s^"", szWord);
        set_hudmessage(.red = 225, .green = 225, .blue = 0, .x = 0.10, .y = 0.65, .effects = 0, .fxtime = 1.0, .holdtime = 2.0, .fadeintime = 0.1, .fadeouttime = 0.2, .channel = 4, .alpha1 = 255);
        show_hudmessage(id, "%d Seconds left!", iTime);
    }
    else
    {
        remove_task(id);
        show_menu(id, 0, " ^n ");
        g_player_answers[id][PLAYER_QUESTION_ID]++;
        g_player_answers[id][PLAYER_INCORRECT_ANSWERS_COUNT] ++;
        player_answered_question(id, .bCorrectly=false);
        set_hudmessage(.red = 200, .green = 0, .blue = 0, .x = 0.10, .y = 0.65, .effects = 0, .fxtime = 1.0, .holdtime = 2.0, .fadeintime = 0.1, .fadeouttime = 0.2, .channel = 4, .alpha1 = 255);
        show_hudmessage(id, "You ran out of time!");
    }
}

public qmhandler(id, key)
{
    remove_task(id);

    if(!is_user_connected(id))
    {
        return PLUGIN_HANDLED;
    }

    g_player_answers[id][PLAYER_QUESTION_ID]++;

    if( key >= 0 )
    {
        // Player Answered correctly :)
        if(key == g_player_answers[id][PLAYER_CORRECT_ANSWER_ID])
        {
            g_player_answers[id][PLAYER_CORRECT_ANSWERS_COUNT] ++;
            player_answered_question(id, .bCorrectly=true);
        }
        else
        {
            g_player_answers[id][PLAYER_INCORRECT_ANSWERS_COUNT] ++;
            player_answered_question(id, .bCorrectly=false);
        }
    }
    else
    {
        g_player_answers[id][PLAYER_INCORRECT_ANSWERS_COUNT] ++;
        player_answered_question(id, .bCorrectly=false);
    }

    return PLUGIN_HANDLED;
}

player_answered_question(id, bool:bCorrectly)
{
    set_hudmessage(.red = bCorrectly ? 0:200, .green = bCorrectly ? 200:0, .blue = 0, .x = 0.10, .y = 0.65, .effects = 0, .fxtime = 1.0, .holdtime = 1.0, .fadeintime = 0.1, .fadeouttime = 0.2, .channel = 4, .alpha1 = 255);
    show_hudmessage(id, "Your answer was %s", bCorrectly ? "Correct":"Incorrect");

    switch(bCorrectly)
    {
        case true: g_player_answers[id][PLAYER_INCORRECT_ANSWERS_INROW] = 0;
        case false: g_player_answers[id][PLAYER_INCORRECT_ANSWERS_INROW]++;
    }

    if(g_player_triviabetting[id] > 0)
    {
        new bet_amount = g_player_triviabetting[id], szName[32];
        get_user_name(id, szName, charsmax(szName));

        g_player_triviabetting[id] = 0;

        switch(bCorrectly)
        {
            case true:
            {
                cprint_chat(0, _, "!g%s !yhas gambled !t%d!g$ !yand won playing !gTrivia!", szName, bet_amount);
                jb_set_user_cash(id, jb_get_user_cash(id) + bet_amount);
            }
            case false:
            {
                cprint_chat(0, _, "!g%s !yhas gambled !t%d!g$ !yand has !tlost !ythem all playing !gTrivia!", szName, bet_amount);
                jb_set_user_cash(id, jb_get_user_cash(id) - bet_amount);
            }
        }

        return;
    }

    if(jb_get_current_day() == g_Trivia_specialday)
    {
        if(g_player_answers[id][PLAYER_INCORRECT_ANSWERS_INROW] >= 3)
        {
            user_kill(id);

            new szName[32];
            get_user_name(id, szName, charsmax(szName));
            cprint_chat(0, _, "!g%s !yhas died for answering 3 questions wrong in a row, answered %d correct and %d incorrect!", szName, g_player_answers[id][PLAYER_CORRECT_ANSWERS_COUNT], g_player_answers[id][PLAYER_INCORRECT_ANSWERS_COUNT]);
            return;
        }

        if(g_player_answers[id][PLAYER_QUESTION_ID] < SPECIAL_DAY_MAX_QUESTIONS)
        {
            question_menu(id, g_player_answers[id][PLAYER_QUESTION_ID]);
            return;
        }
        // Player answered all the questions.
        static players[32], pnum;
        get_players(players, pnum, "ah");

        const PLAYRE_GIBS = 2;

        for(new i, loses = g_player_answers[id][PLAYER_INCORRECT_ANSWERS_COUNT], player; i < pnum; i++)
        {
            player = players[i];

            if(player == id) continue;

            if(g_player_answers[player][PLAYER_QUESTION_ID] >= SPECIAL_DAY_MAX_QUESTIONS)
            {
                if(g_player_answers[player][PLAYER_CORRECT_ANSWERS_COUNT] > loses)
                {
                    ExecuteHamB(Ham_Killed, player, id, PLAYRE_GIBS);
                }
                else if(is_user_alive(id))
                {
                    ExecuteHamB(Ham_Killed, id, player, PLAYRE_GIBS);
                }
            }
        }
    }
}

public trivia_clcmd(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED;

    trivia_menu(id);
    return PLUGIN_HANDLED;
}

trivia_menu(id)
{
    new iCategorySize = ArraySize(g_array_trivia_category);

    if(!iCategorySize) return PLUGIN_HANDLED;

    new iMenu = menu_create("[TRIVIA NIGHT] ^n Pick out a category!?", "trivia_category_mh");

    for( new i, xArray[TRIVIA_DATA_CATEGORIES]; i < iCategorySize; i++ )
    {
        ArrayGetArray(g_array_trivia_category, i, xArray);
        menu_additem(iMenu, xArray[TRIVIA_CATEGORY_NAME]);
    }

    menu_display(id, iMenu);
    return PLUGIN_HANDLED;
}

public trivia_category_mh(id, menu, item)
{
    menu_destroy(menu);

    if(item == MENU_EXIT || item < 0)
    {
        return PLUGIN_HANDLED;
    }

    if(is_user_connected(id))
    {
        new xArray[TRIVIA_DATA_CATEGORIES];
        ArrayGetArray(g_array_trivia_category, item, xArray);
        g_user_trivia_category[id][TRIVIA_QUESTION_CATEGORY_ID] = xArray[TRIVIA_CATEGORY_ID];
        copy(g_user_trivia_category[id][TRIVIA_QUESTION_CATEGORY], MAX_CATEGORY_NAME-1, xArray[TRIVIA_CATEGORY_NAME]);
        trivia_menu_difficulty(id);
    }

    return PLUGIN_HANDLED;
}

trivia_menu_difficulty(id)
{
    new iMenu = menu_create("[TRIVIA NIGHT] ^n Pick out difficulty!?", "trivia_difficulty_mh");

    menu_additem(iMenu, "Easy");
    menu_additem(iMenu, "Medium");
    menu_additem(iMenu, "Hard");

    menu_display(id, iMenu);
    return PLUGIN_HANDLED;
}

public trivia_difficulty_mh(id, menu, item)
{
    menu_destroy(menu);

    if(item == MENU_EXIT || item < 0)
    {
        return PLUGIN_HANDLED;
    }

    if(is_user_connected(id))
    {
        g_user_trivia_category[id][TRIVIA_QUESTION_DIFFICULTY] = any:item;
        trivia_menu_Qtype(id);
    }

    return PLUGIN_HANDLED;
}

trivia_menu_Qtype(id)
{
    new iMenu = menu_create("[TRIVIA NIGHT] ^n Pick out question type!?", "trivia_Qtype_mh");

    menu_additem(iMenu, "Any");
    menu_additem(iMenu, "Multiplie Choices");
    menu_additem(iMenu, "LOGIC ( true or false )");

    menu_display(id, iMenu);
    return PLUGIN_HANDLED;
}

public trivia_Qtype_mh(id, menu, item)
{
    menu_destroy(menu);

    if(item == MENU_EXIT || item < 0)
    {
        return PLUGIN_HANDLED;
    }

    if(is_user_connected(id))
    {
        if(!g_player_index)
        {
            if(jb_get_commander() == id)
            {
                g_player_index = id;
                g_user_trivia_category[id][TRIVIA_QUESTION_TYPE] = any:item;
                curl_retrieve_trivia_questions(
                    .iAmount = 1 ,
                    .iCategory = any:g_user_trivia_category[id][TRIVIA_QUESTION_CATEGORY_ID],
                    .iDifficulty = any:g_user_trivia_category[id][TRIVIA_QUESTION_DIFFICULTY],
                    .QType = g_user_trivia_category[id][TRIVIA_QUESTION_TYPE],
                    .szWritefunction = "question_received_warden" );
                return PLUGIN_HANDLED;
            }

            g_player_index = id;
            g_user_trivia_category[id][TRIVIA_QUESTION_TYPE] = any:item;
            curl_retrieve_trivia_questions(
                .iAmount = 1 ,
                .iCategory = any:g_user_trivia_category[id][TRIVIA_QUESTION_CATEGORY_ID],
                .iDifficulty = any:g_user_trivia_category[id][TRIVIA_QUESTION_DIFFICULTY],
                .QType = g_user_trivia_category[id][TRIVIA_QUESTION_TYPE],
                .szWritefunction = "question_received_player" );
        }
        else
        {
            cprint_chat(id, _, "Trivia currently is busy with someone else!");
        }
    }

    return PLUGIN_HANDLED;
}

public cmd_quest(id, level)
{
    if(id && !(get_user_flags(id) & level))
    {
        console_print(id, "No access to use this command!");
        return PLUGIN_HANDLED;
    }

    if(!ArraySize(g_array_trivia_quesdata))
    {
        return PLUGIN_HANDLED;
    }

    new xArray[TRIVIA_DATA];
    ArrayGetArray(g_array_trivia_quesdata, random(ArraySize(g_array_trivia_quesdata)), xArray);
    server_print("( TRIVIA QUESTION )^n[ CATEGORY: %s ] ^n Q : %s^n A : %s", xArray[TRIVIA_QUESTION_CATEGORY], xArray[TRIVIA_QUESTION], xArray[TRIVIA_QUESTION_CORRECT_ANSWER]);
    return PLUGIN_HANDLED
}

public cmd_get_categories(id, level)
{
    if(id && !(get_user_flags(id) & level))
    {
        console_print(id, "No access to use this command!");
        return PLUGIN_HANDLED;
    }

    new iCount = ArraySize(g_array_trivia_category);

    if(iCount > 0)
    {
        server_print("TRIVIA Categories Exists:- ^n");

        for(new i, enArray[TRIVIA_DATA_CATEGORIES]; i < iCount; i++)
        {
            ArrayGetArray(g_array_trivia_category, i, enArray);
            server_print("%d. %s", enArray[TRIVIA_CATEGORY_ID], enArray[TRIVIA_CATEGORY_NAME]);
        }

        server_print("^n * * *");

        return PLUGIN_HANDLED;
    }

    curl_retrieve_trivia_categories();
    return PLUGIN_HANDLED
}

curl_slist:CreateSListHeader()
{
    new curl_slist:SList = SList_Empty, curl_slist:SListUA = SList_Empty, curl_slist:SListKC = SList_Empty;

    SList = curl_slist_append(SList, "Content-Type: application/json");

    if(SList == SList_Empty)
    {
        log_amx("[Error] Cannot append cURL (Content-Type:) to slist.");
        return SList_Empty;
    }

    SListUA = curl_slist_append(SList, "User-Agent: TRIVIA-BOT"); // User-Agent

    if(SListUA == SList_Empty)
    {
        curl_slist_free_all(SList);
        log_amx("[Error] Cannot append cURL (User-Agent:) to slist.");
        return SList_Empty;
    }

    SListKC = curl_slist_append(SListUA, "Connection: Keep-Alive");

    if(SListKC == SList_Empty)
    {
        curl_slist_free_all(SListUA);
        curl_slist_free_all(SList);
        log_amx("[Error] Cannot append cURL (Connection:) to slist.");
        return SList_Empty;
    }

    return SListKC;
}

curl_retrieve_trivia_questions(
    const iAmount=25,
    const iCategory=-1,
    const TRIVIA_QUESTION_DIFFICULTIES:iDifficulty=TRIVIA_QUESTION_DIFFICULTY_ANY,
    const TRIVIA_QUESTION_TYPES:QType=TRIVIA_Q_TYPE_ANY,
    const szWritefunction[],
    data[]="", size=1 )
{
    // Connect
    new CURL:cURLHandle;

    if (!(cURLHandle = curl_easy_init()))
    {
        log_amx("[Fatal Error] Cannot Init cURL Handle.");
        return;
    }

    // Create headers;
    if(g_cURLHeaders == SList_Empty && (g_cURLHeaders = CreateSListHeader()) == SList_Empty)
    {
        return;
    }

    new szUrl[256], szDifficulty[16], szType[16],
    iLen = formatex(szUrl, charsmax(szUrl), "https://opentdb.com/api.php?amount=%d", iAmount);

    if(iCategory != -1)
    {
        iLen += formatex(szUrl[iLen], charsmax(szUrl)-iLen, "&category=%d", iCategory);
    }

    if(iDifficulty != TRIVIA_QUESTION_DIFFICULTY_ANY)
    {
        number_to_difficulty(iDifficulty, szDifficulty, charsmax(szDifficulty));
        iLen += formatex(szUrl[iLen], charsmax(szUrl)-iLen, "&difficulty=%s", szDifficulty);
    }

    if(QType != TRIVIA_Q_TYPE_ANY)
    {
        number_to_questiontype(QType, szType, charsmax(szType));
        iLen += formatex(szUrl[iLen], charsmax(szUrl)-iLen, "&type=%s", szType);
    }

    if(g_szTOKEN[0] != EOS)
    {
        iLen += formatex(szUrl[iLen], charsmax(szUrl)-iLen, "&token=%s", g_szTOKEN);
    }

    curl_easy_setopt( cURLHandle, CURLOPT_SSL_VERIFYPEER, false );
    curl_easy_setopt( cURLHandle , CURLOPT_URL , szUrl );
    curl_easy_setopt( cURLHandle , CURLOPT_BUFFERSIZE , CURL_BUFFER_SIZE_LEN );
    curl_easy_setopt( cURLHandle, CURLOPT_HTTPHEADER, g_cURLHeaders );
    curl_easy_setopt( cURLHandle , CURLOPT_WRITEFUNCTION , szWritefunction );

    curl_easy_perform( cURLHandle , "curl_questions_duty_complete", data, size );
}

curl_retrieve_trivia_categories()
{
    // Connect
    new CURL:cURLHandle;

    if (!(cURLHandle = curl_easy_init()))
    {
        log_amx("[Fatal Error] Cannot Init cURL Handle.");
        return;
    }

    // Create headers;
    if(g_cURLHeaders == SList_Empty && (g_cURLHeaders = CreateSListHeader()) == SList_Empty)
    {
        return;
    }

    curl_easy_setopt( cURLHandle, CURLOPT_SSL_VERIFYPEER, false );
    curl_easy_setopt( cURLHandle , CURLOPT_URL , "https://opentdb.com/api_category.php" );
    curl_easy_setopt( cURLHandle , CURLOPT_BUFFERSIZE , CURL_BUFFER_SIZE_LEN );
    curl_easy_setopt( cURLHandle, CURLOPT_HTTPHEADER, g_cURLHeaders );
    curl_easy_setopt( cURLHandle , CURLOPT_WRITEFUNCTION , "categories_response_received" );
    curl_easy_perform( cURLHandle , "curl_categories_duty_complete" );
}

curl_retrieve_trivia_token()
{
    // Connect
    new CURL:cURLHandle;

    if (!(cURLHandle = curl_easy_init()))
    {
        log_amx("[Fatal Error] Cannot Init cURL Handle.");
        return;
    }

    // Create headers;
    if(g_cURLHeaders == SList_Empty && (g_cURLHeaders = CreateSListHeader()) == SList_Empty)
    {
        return;
    }

    curl_easy_setopt( cURLHandle, CURLOPT_SSL_VERIFYPEER, false );
    curl_easy_setopt( cURLHandle , CURLOPT_URL , "https://opentdb.com/api_token.php?command=request" );
    curl_easy_setopt( cURLHandle , CURLOPT_BUFFERSIZE , CURL_BUFFER_SIZE_LEN );
    curl_easy_setopt( cURLHandle, CURLOPT_HTTPHEADER, g_cURLHeaders );
    curl_easy_setopt( cURLHandle , CURLOPT_WRITEFUNCTION , "token_response_received" );
    curl_easy_perform( cURLHandle , "curl_token_duty_complete" );
}

get_trivia_token( JSON:TokenJsonObject )
{
    // response code was success
    const RESPONSE_SUCCESS = 0;

    if(json_object_get_number(TokenJsonObject, "response_code") == RESPONSE_SUCCESS)
    {
        json_object_get_string(TokenJsonObject, "token", g_szTOKEN, charsmax(g_szTOKEN));
    }

    json_free(TokenJsonObject);
}

push_trivia_categories_inarray( JSON:TriviaCategoriesJsonObject )
{
    new szBuffer[64], xArray[TRIVIA_DATA_CATEGORIES], JSON:SecHandle = json_object_get_value(TriviaCategoriesJsonObject, "trivia_categories");

    for(new i, JSON:ThirdHandle, maxloop = json_array_get_count(SecHandle); i < maxloop; i++)
    {
        ThirdHandle = json_array_get_value(SecHandle, i);

        if( json_is_object(ThirdHandle) &&
            json_object_has_value(ThirdHandle, "id", .type = JSONNumber) &&
            json_object_has_value(ThirdHandle, "name", .type = JSONString)
            )
        {
            json_object_get_string(ThirdHandle, "name", szBuffer, charsmax(szBuffer));

            xArray[TRIVIA_CATEGORY_ID] = json_object_get_number(ThirdHandle, "id");
            copy(xArray[TRIVIA_CATEGORY_NAME], charsmax(xArray[TRIVIA_CATEGORY_NAME]), szBuffer);
            ArrayPushArray(g_array_trivia_category, xArray);
        }

        json_free(ThirdHandle);
    }

    json_free(SecHandle);

    if(TriviaCategoriesJsonObject != Invalid_JSON)
    {
        json_free(TriviaCategoriesJsonObject);
    }
}

push_trivia_questions_inarray( JSON:TriviaCategoriesJsonObject )
{
    new iErrorCode;
    // response code wasn't success
    if((iErrorCode=json_object_get_number(TriviaCategoriesJsonObject, "response_code")) != 0)
    {
        log_amx("Failed to retrieve results (Error code : %d)", iErrorCode);
        return;
    }

    new szBuffer[64], xArray[TRIVIA_DATA], JSON:SecHandle = json_object_get_value(TriviaCategoriesJsonObject, "results");

    for(new i, x, MaxIncorrects, Array:pArray, JSON:ThirdHandle, JSON:FourthHandle, maxloop = json_array_get_count(SecHandle); i < maxloop; i++)
    {
        ThirdHandle = json_array_get_value(SecHandle, i);

        if( json_is_object(ThirdHandle) &&
            json_object_has_value(ThirdHandle, "category", .type = JSONString) &&
            json_object_has_value(ThirdHandle, "type", .type = JSONString) &&
            json_object_has_value(ThirdHandle, "difficulty", .type = JSONString) &&
            json_object_has_value(ThirdHandle, "question", .type = JSONString) &&
            json_object_has_value(ThirdHandle, "correct_answer", .type = JSONString)
            )
        {
            json_object_get_string(ThirdHandle, "category", xArray[TRIVIA_QUESTION_CATEGORY], charsmax(xArray[TRIVIA_QUESTION_CATEGORY]));
            json_object_get_string(ThirdHandle, "type", szBuffer, charsmax(szBuffer));
            questiontype_to_number(szBuffer, any:xArray[TRIVIA_QUESTION_TYPE]);
            json_object_get_string(ThirdHandle, "difficulty", szBuffer, charsmax(szBuffer));
            difficulty_to_number(szBuffer, any:xArray[TRIVIA_QUESTION_DIFFICULTY]);
            json_object_get_string(ThirdHandle, "question", xArray[TRIVIA_QUESTION], charsmax(xArray[TRIVIA_QUESTION]));
            replace_all(xArray[TRIVIA_QUESTION], charsmax(xArray[TRIVIA_QUESTION]), "&quot;", "^"");
            replace_all(xArray[TRIVIA_QUESTION], charsmax(xArray[TRIVIA_QUESTION]), "&rsquo;", "^'");
            replace_all(xArray[TRIVIA_QUESTION], charsmax(xArray[TRIVIA_QUESTION]), "&lsquo;", "^'");
            replace_all(xArray[TRIVIA_QUESTION], charsmax(xArray[TRIVIA_QUESTION]), "&rdquo;", "^"");
            replace_all(xArray[TRIVIA_QUESTION], charsmax(xArray[TRIVIA_QUESTION]), "&ldquo,;", "^"");
            replace_all(xArray[TRIVIA_QUESTION], charsmax(xArray[TRIVIA_QUESTION]), "&#039;", "^'");
            replace_all(xArray[TRIVIA_QUESTION], charsmax(xArray[TRIVIA_QUESTION]), "&Eacute;", "E");
            replace_all(xArray[TRIVIA_QUESTION], charsmax(xArray[TRIVIA_QUESTION]), "&eacute;", "e");
            json_object_get_string(ThirdHandle, "correct_answer", xArray[TRIVIA_QUESTION_CORRECT_ANSWER], charsmax(xArray[TRIVIA_QUESTION_CORRECT_ANSWER]));

            xArray[TRIVIA_QUESTION_INCORRECT_ANSWERS] = Invalid_Array;
            if(xArray[TRIVIA_QUESTION_TYPE] == TRIVIA_Q_TYPE_CHOICE)
            {
                xArray[TRIVIA_QUESTION_INCORRECT_ANSWERS] = pArray = ArrayCreate(MAX_ANSWER_LENGTH,3);
                FourthHandle = json_object_get_value(ThirdHandle, "incorrect_answers");

                if(json_is_array(FourthHandle))
                {
                    for(x = 0, MaxIncorrects = json_array_get_count(FourthHandle); x < MaxIncorrects; x++)
                    {
                        json_array_get_string(FourthHandle, x, szBuffer, charsmax(szBuffer));
                        ArrayPushString(pArray, szBuffer);
                    }
                }

                json_free(FourthHandle);
            }

            ArrayPushArray(g_array_trivia_quesdata, xArray);
        }

        json_free(ThirdHandle);
    }

    json_free(SecHandle);

    if(TriviaCategoriesJsonObject != Invalid_JSON)
    {
        json_free(TriviaCategoriesJsonObject);
    }
}

public categories_response_received( const szBuffer[] , iSize , iNumMemb , sd )
{
    new JSON:JSONParse = json_parse(szBuffer);

    if(JSONParse != Invalid_JSON)
    {
        push_trivia_categories_inarray( JSONParse );
    }
    else
    {
        log_amx("Error Invalid JSON Structure (  %s ) !", szBuffer);
    }


    return (iSize * iNumMemb);
}

public questions_response_received( const szBuffer[] , iSize , iNumMemb , sd )
{
    new JSON:JSONParse = json_parse(szBuffer);

    if(JSONParse != Invalid_JSON)
        push_trivia_questions_inarray( JSONParse );
    else
    {
        log_amx("Error Invalid JSON Structure (  %s ) !", szBuffer);
    }

    if(jb_get_current_day() == g_Trivia_specialday)
    {
        EnableHamForward(g_HamHookPlayerSpawnPost);

        new players[32], pnum;
        get_players(players, pnum, "ach");

        for(new i, id; i < pnum; i++)
        {
            id = players[i];
            question_menu(id, g_player_answers[id][PLAYER_QUESTION_ID]);
        }

        if(ArraySize(g_array_trivia_quesdata))
        {
            ArraySort(g_array_trivia_quesdata, "sort_trivia_questarray_random");
        }
    }


    return (iSize * iNumMemb);
}

public question_received_warden( const szBuffer[] , iSize , iNumMemb , sd )
{
    new JSON:JSONParse = json_parse(szBuffer);

    if(JSONParse != Invalid_JSON)
        push_trivia_questions_inarray( JSONParse );
    else
    {
        log_amx("Error Invalid JSON Structure (  %s ) !", szBuffer);
    }

    if(is_user_connected(g_player_index))
    {
        new id = g_player_index;

        new xArray[TRIVIA_DATA], Array:pTempArray = ArrayCreate(TRIVIA_DATA,1);

        for(new i, maxloop = ArraySize(g_array_trivia_quesdata); i < maxloop; i++)
        {
            ArrayGetArray(g_array_trivia_quesdata, i, xArray);
            if( g_user_trivia_category[id][TRIVIA_QUESTION_CATEGORY_ID] == -1 ||
                equali(g_user_trivia_category[id][TRIVIA_QUESTION_CATEGORY],xArray[TRIVIA_QUESTION_CATEGORY]) )
            {
                if( g_user_trivia_category[id][TRIVIA_QUESTION_DIFFICULTY] == TRIVIA_QUESTION_DIFFICULTY_ANY ||
                    g_user_trivia_category[id][TRIVIA_QUESTION_DIFFICULTY] == xArray[TRIVIA_QUESTION_DIFFICULTY])
                {
                    if( g_user_trivia_category[id][TRIVIA_QUESTION_TYPE] == TRIVIA_Q_TYPE_ANY ||
                        g_user_trivia_category[id][TRIVIA_QUESTION_TYPE] == xArray[TRIVIA_QUESTION_TYPE])
                    {
                        ArrayPushArray(pTempArray, xArray);
                    }
                }
            }
        }

        new Quesid = g_player_answers[id][PLAYER_QUESTION_ID] = g_player_answers[id][PLAYER_QUESTION_ID] % max(ArraySize(pTempArray), 1);

        if( ArraySize(pTempArray) )
        {
            new szWardenName[32];
            get_user_name(id, szWardenName, 31);

            ArrayGetArray(pTempArray, Quesid, xArray);
            cprint_chat( 0, _, "* Warden !g%s !yhas asked a question!", szWardenName);
            cprint_chat( 0, _, "* !g%s", xArray[TRIVIA_QUESTION]);
            cprint_chat( id, _, "* Correct Answer is : !g%s", xArray[TRIVIA_QUESTION_CORRECT_ANSWER]);

            g_player_answers[id][PLAYER_QUESTION_ID]++;
        }

        if(pTempArray != Invalid_Array)
        {
            ArrayDestroy(pTempArray);
        }
    }

    g_player_index = 0;


    return (iSize * iNumMemb);
}

public hard_question_received_insertion( const szBuffer[] , iSize , iNumMemb , sd )
{
    new JSON:JSONParse = json_parse(szBuffer);

    if(JSONParse != Invalid_JSON)
    {
        push_trivia_questions_inarray( JSONParse );
        remove_task(TASK_RETRIEVE_HARD_Q);
    }
    else
    {
        log_amx("Error Invalid JSON Structure (  %s ) !", szBuffer);
    }


    return (iSize * iNumMemb);
}

public medium_question_received_insertion( const szBuffer[] , iSize , iNumMemb , sd )
{
    new JSON:JSONParse = json_parse(szBuffer);

    if(JSONParse != Invalid_JSON)
    {
        push_trivia_questions_inarray( JSONParse );
        remove_task(TASK_RETRIEVE_MEDIUM_Q);
    }
    else
    {
        log_amx("Error Invalid JSON Structure (  %s ) !", szBuffer);
    }


    return (iSize * iNumMemb);
}

public easy_question_received_insertion( const szBuffer[] , iSize , iNumMemb , sd )
{
    new JSON:JSONParse = json_parse(szBuffer);

    if(JSONParse != Invalid_JSON)
    {
        push_trivia_questions_inarray( JSONParse );
        remove_task(TASK_RETRIEVE_EASY_Q);
    }
    else
    {
        log_amx("Error Invalid JSON Structure (  %s ) !", szBuffer);
    }


    return (iSize * iNumMemb);
}

public question_received_player( const szBuffer[] , iSize , iNumMemb , sd )
{
    new JSON:JSONParse = json_parse(szBuffer);

    if(JSONParse != Invalid_JSON)
        push_trivia_questions_inarray( JSONParse );
    else
    {
        log_amx("Error Invalid JSON Structure (  %s ) !", szBuffer);
    }

    if(is_user_connected(g_player_index))
    {
        new id = g_player_index;

        new xArray[TRIVIA_DATA], Array:pTempArray = ArrayCreate(TRIVIA_DATA,1);

        for(new i, maxloop = ArraySize(g_array_trivia_quesdata); i < maxloop; i++)
        {
            ArrayGetArray(g_array_trivia_quesdata, i, xArray);
            if( g_user_trivia_category[id][TRIVIA_QUESTION_CATEGORY_ID] == -1 ||
                equali(g_user_trivia_category[id][TRIVIA_QUESTION_CATEGORY],xArray[TRIVIA_QUESTION_CATEGORY]) )
            {
                if( g_user_trivia_category[id][TRIVIA_QUESTION_DIFFICULTY] == TRIVIA_QUESTION_DIFFICULTY_ANY ||
                    g_user_trivia_category[id][TRIVIA_QUESTION_DIFFICULTY] == xArray[TRIVIA_QUESTION_DIFFICULTY])
                {
                    if( g_user_trivia_category[id][TRIVIA_QUESTION_TYPE] == TRIVIA_Q_TYPE_ANY ||
                        g_user_trivia_category[id][TRIVIA_QUESTION_TYPE] == xArray[TRIVIA_QUESTION_TYPE])
                    {
                        ArrayPushArray(pTempArray, xArray);
                    }
                }
            }
        }

        g_player_answers[id][PLAYER_QUESTION_ID] = g_player_answers[id][PLAYER_QUESTION_ID] % max(ArraySize(pTempArray), 1);
        question_menu(id, g_player_answers[id][PLAYER_QUESTION_ID], .QArray=pTempArray);

        if(pTempArray != Invalid_Array)
        {
            ArrayDestroy(pTempArray);
        }
    }

    g_player_index = 0;


    return (iSize * iNumMemb);
}

public sort_trivia_questarray_random()
{
    return random_num( -1 , 1 );
}

public token_response_received( const szBuffer[] , iSize , iNumMemb , sd )
{
    new JSON:JSONParse = json_parse(szBuffer);

    if(JSONParse != Invalid_JSON)
        get_trivia_token( JSONParse );
    else
    {
        log_amx("Error Invalid JSON Structure (  %s ) !", szBuffer);
    }


    return (iSize * iNumMemb);
}

public curl_categories_duty_complete( CURL:cURLHandle , CURLcode:code )
{
    new szError[64];
    curl_easy_strerror(code, szError, charsmax(szError));

    if(szError[0] != EOS)
    {
        server_print("Error: %s", szError);
    }

    server_print("[#%d] Trivia Categories data: %s", cURLHandle, code == CURLE_OK ? "OKAY" : "ERROR");

    new Float:ConnectionTime, statusCode;
    curl_easy_getinfo(cURLHandle, CURLINFO_RESPONSE_CODE, statusCode);
    curl_easy_getinfo(cURLHandle, CURLINFO_CONNECT_TIME, ConnectionTime);
    server_print("Time : %.2f, StatusCode: %d", ConnectionTime, statusCode);

    curl_easy_cleanup(cURLHandle);

    if(code == CURLE_OK)
    {
        curl_retrieve_trivia_token();
    }
    else if(code != CURLE_OK)
    {
        curl_retrieve_trivia_categories();
    }
}

public curl_questions_duty_complete( CURL:cURLHandle , CURLcode:code, data[] )
{
    new szError[64];
    curl_easy_strerror(code, szError, charsmax(szError));

    if(szError[0] != EOS)
    {
        server_print("Error: %s", szError);

        if( g_player_index > 0 )
        {
            g_player_triviabetting[ g_player_index ] = 0;
        }

        g_player_index = 0;
    }

    server_print("[#%d] Trivia Questions data: %s", cURLHandle, code == CURLE_OK ? "OKAY" : "ERROR");

    new Float:ConnectionTime, statusCode;
    curl_easy_getinfo(cURLHandle, CURLINFO_RESPONSE_CODE, statusCode);
    curl_easy_getinfo(cURLHandle, CURLINFO_CONNECT_TIME, ConnectionTime);
    server_print("Time : %.2f, StatusCode: %d", ConnectionTime, statusCode);

    curl_easy_cleanup(cURLHandle);

    if(code != CURLE_OK)
    {
        switch( data[ 0 ] )
        {
            case TASK_RETRIEVE_HARD_Q: task_retrieve_hard_questions();
            case TASK_RETRIEVE_MEDIUM_Q: task_retrieve_medium_questions();
            case TASK_RETRIEVE_EASY_Q: task_retrieve_easy_questions();
        }
    }
}

public curl_token_duty_complete( CURL:cURLHandle , CURLcode:code, data[] )
{
    new szError[64];
    curl_easy_strerror(code, szError, charsmax(szError));

    if(szError[0] != EOS)
    {
        server_print("Error: %s", szError);
    }

    server_print("[#%d] Token data: %s", cURLHandle, code == CURLE_OK ? "OKAY" : "ERROR");
    server_print("TOKEN:> '%s'", g_szTOKEN);

    new Float:ConnectionTime, statusCode;
    curl_easy_getinfo(cURLHandle, CURLINFO_RESPONSE_CODE, statusCode);
    curl_easy_getinfo(cURLHandle, CURLINFO_CONNECT_TIME, ConnectionTime);
    server_print("Time : %.2f, StatusCode: %d", ConnectionTime, statusCode);

    curl_easy_cleanup(cURLHandle);

    if(code != CURLE_OK)
    {
        curl_retrieve_trivia_token();
    }
}

public plugin_end()
{
    if(g_array_trivia_category != Invalid_Array)
    {
        ArrayDestroy(g_array_trivia_category);
    }

    if(g_array_trivia_quesdata != Invalid_Array)
    {
        new size = ArraySize(g_array_trivia_quesdata);

        for(new i, xArray[TRIVIA_DATA]; i < size; i++)
        {
            ArrayGetArray(g_array_trivia_quesdata, i, xArray);

            if(xArray[TRIVIA_QUESTION_INCORRECT_ANSWERS] != Invalid_Array)
            {
                ArrayDestroy(xArray[TRIVIA_QUESTION_INCORRECT_ANSWERS]);
            }
        }

        ArrayDestroy(g_array_trivia_quesdata);
    }

    if (g_cURLHeaders)
    {
        curl_slist_free_all(g_cURLHeaders);
    }
}

difficulty_to_number(const szDifficulty[], &TRIVIA_QUESTION_DIFFICULTY:retvalue)
{
    switch( szDifficulty[0] )
    {
        case 'E','e': retvalue = TRIVIA_QUESTION_DIFFICULTY_EASY;
        case 'M','m', 'N', 'n': retvalue = TRIVIA_QUESTION_DIFFICULTY_MEDIUM;
        case 'H','h', 'D', 'd': retvalue = TRIVIA_QUESTION_DIFFICULTY_HARD;
    }
}

questiontype_to_number(const szType[], &TRIVIA_QUESTION_TYPE:retvalue)
{
    switch( szType[0] )
    {
        case 'B','b', 'L', 'l': retvalue = TRIVIA_Q_TYPE_LOGIC;
        case 'M','m', 'C', 'c': retvalue = TRIVIA_Q_TYPE_CHOICE;
    }
}

number_to_difficulty(TRIVIA_QUESTION_DIFFICULTIES:iDifficulty, szDifficulty[], len)
{
    switch( iDifficulty )
    {
        case TRIVIA_QUESTION_DIFFICULTY_EASY: copy(szDifficulty, len, "easy");
        case TRIVIA_QUESTION_DIFFICULTY_MEDIUM: copy(szDifficulty, len, "medium");
        case TRIVIA_QUESTION_DIFFICULTY_HARD: copy(szDifficulty, len, "hard");
    }
}

number_to_questiontype(TRIVIA_QUESTION_TYPES:iType, szType[], len)
{
    switch( iType )
    {
        case TRIVIA_Q_TYPE_CHOICE: copy(szType, len, "multiple");
        case TRIVIA_Q_TYPE_LOGIC: copy(szType, len, "boolean");
    }
}
