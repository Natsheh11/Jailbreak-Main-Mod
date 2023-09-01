/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <orpheu>
#include <orpheu_advanced>
#include <orpheu_memory>
#include <ROG>
#include <fun>
#include <cstrike>
#include <cs_player_models_api>
#include <npc_library>
#include <jailbreak_core>
#include <screenfade_util>
#include <reapi>

#define PLUGIN  "[JB] DAY : GUESS WHO?"
#define AUTHOR  "Natsheh"

#define TASK_INITIATE_NPC 35463
#define TASK_SEEKING_SESSION 15463
#define TASK_CVARS_RULES 10463
#define TASK_DISPLAY_ABILITY_COOLDOWN 43545
#define TASK_DISPLAY_SEEKER_RADAR 23545
#define TASK_ABILITY_INVIS 5325

#define Invalid_Task -1

#define NPC_RUNNING_ANIMATION 121
#define NPC_WALKING_ANIMATION 122

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif

#define NPC_CUSTOM_CLASSNAME "GUESSWHO_NPC"

forward OnSetAnimation(id, anim);

native give_item_mp5m203(const id, const M203Ammo = 10, const BackPack9MMAmmo = 250);

#define VIEW_BACK_100_UNITS -100.0
#define VIEW_FIRST_PERSON 0.0

native set_player_camera(const id, const Float:flViewOffset);

public g_BitsGuessWho_Seekers;
public g_BitsGuessWho_Hiders;

const Offset_m_flNextSBarUpdateTime = 449;
const Offset_m_pActiveItem = 373;

new const Float:g_fMAX_SIZE[3] = { 16.0, 16.0, 36.0 };
new const Float:g_fMIN_SIZE[3] = { -16.0, -16.0, -36.0 };
new const g_szShapeShiftSound[] = "warcraft3/PolymorphDone.wav";

new g_iPointerGuessWhoSpecialday, g_FW_FM_PlayerPreThink_Post, g_iMSG_Radar, g_iMSG_StatusValue, g_bDisguise[MAX_PLAYERS+1],
g_pcvar_seekers_ratio, HamHook:g_fw_player_killed_post, HamHook:g_fw_player_takedmg_pre, g_iSprite_blood, g_pcvar_ability_exp_radius,
g_iSprite_bloodspray, g_pcvar_npc_count, g_pcvar_npc_walkingspeed, g_pcvar_npc_runningspeed, g_pcvar_ability_exp_maxdmg,
BITS_ABILITIES:g_bitsUserAbility[MAX_PLAYERS+1], Float:g_fUserAbilityTimeActivasion[MAX_PLAYERS+1], g_RandomizedNPCAnimTask[2][100], g_iUserAnimeAction[MAX_PLAYERS+1], g_pMenuAnimeAction, g_iSprite_eexplo, g_pcvar_ability_cd, g_pcvar_ability_inv_duration;

enum NPC_DATA
{
    NPC_CLASS[32],
    NPC_NAME[32],
    NPC_MODEL[64],
    NPC_BODY_ID,
    NPC_SKIN_ID
}

enum NPC_ANIM_TASK_DATA
{
    ANIME_ACTION_NAME[32], ANIME_TASK_ID, ANIME_TASK_NAME[32], Float:ANIME_TASK_CHANCE, Float:ANIME_TASK_LENGTH
}

enum any:ANIME_TASK_VALUE (+=1)
{
    ANIME_TASK_WALK = 6200,
    ANIME_TASK_RUN,
    ANIME_TASK_WAVE,
    ANIME_TASK_SIT,
    ANIME_TASK_PUSH_UP,
    ANIME_TASK_MJ_BEAT_IT,
    ANIME_TASK_MEDITATE,
    ANIME_TASK_LAY,
    ANIME_TASK_FLIP,
    ANIME_TASK_FIST_PUMP,
    ANIME_TASK_DANCE,
    ANIME_TASK_CHEST_POUND
}

new const g_aNPC_Tasks[][NPC_ANIM_TASK_DATA] =
{
    { "Walk", ANIME_TASK_WALK, "npc_walk", 1.00, 0.0                    },
    { "Run", ANIME_TASK_RUN, "npc_run", 0.70, 0.0                      },
    { "Chest pound", ANIME_TASK_CHEST_POUND, "anim_chestpound", 0.02, 5.0      },
    { "Dance BStyle", ANIME_TASK_DANCE, "anim_danceB", 0.02, 3.0                },
    { "Fist pump", ANIME_TASK_FIST_PUMP, "anim_fistpump", 0.02, 10.0         },
    { "Flip", ANIME_TASK_FLIP,  "anim_flip", 0.02, 5.0                  },
    { "Lay on ground", ANIME_TASK_LAY,  "anim_lay", 0.02, 10.0                   },
    { "Meditation", ANIME_TASK_MEDITATE, "anim_meditate", 0.02, 10.0          },
    { "MJ Beat IT", ANIME_TASK_MJ_BEAT_IT, "anim_mjbeatit", 0.02, 0.0         },
    { "Push ups", ANIME_TASK_PUSH_UP, "anim_pushup", 0.02, 10.0             },
    { "Sit", ANIME_TASK_SIT,  "anim_sit2", 0.02, 5.0                   },
    { "Wave", ANIME_TASK_WAVE, "anim_wave", 0.02, 10.0                  }
}

enum any:BITS_ABILITIES (<<=1)
{
    ABILITY_NONE = 0,
    ABILITY_TELEPORTATION = 1,
    ABILITY_EXPLOSIVE,
    ABILITY_DECOYS,
    ABILITY_INVISIBLE,
    ABILITY_SHOCKER
}

enum any:ENUM_ABILITIES_TYPES (+=1)
{
    ABILITY_TYPE_RANDOM_TELE = 0,
    ABILITY_TYPE_EXPLOSIVE,
    ABILITY_TYPE_DECOY_CREATION,
    ABILITY_TYPE_INVISIBLITY,

    ABILITY_TYPE_MAX
}

enum any:ENUM_ABILITIES_DATA
{
    ABILITY_NAME[32],
    ABILITY_BIT_ID
}

new const g_aAbilities[][ENUM_ABILITIES_DATA] = {
    { "Random Teleportation", ABILITY_TELEPORTATION },
    { "Explosion", ABILITY_EXPLOSIVE },
    { "Decoys Creation", ABILITY_DECOYS },
    { "Invisiblity", ABILITY_INVISIBLE }
}

public task_show_seeker_radar(taskid)
{
    new id = taskid - TASK_DISPLAY_SEEKER_RADAR, target = id;

    if(!is_user_alive(target))
    {
        target = pev(id, pev_iuser2);

        if( !is_user_alive(target) )
        {
            return;
        }
    }

    const MAXChars = 20;
    const Float:MAXfRadius = 300.0

    new szText[MAXChars * 4], ent = -1, iCharged, Float:fOrigin[3], Float:fTargetOrigin[3], Float:fDist, Float:fMinDistance = MAXfRadius;
    pev(id, pev_origin, fOrigin);

    while( 1 <= (ent = find_ent_in_sphere(ent, fOrigin, MAXfRadius)) <= MAX_PLAYERS )
    {
        if(!is_user_alive(ent) || !check_flag(g_BitsGuessWho_Hiders,ent))
        {
            continue;
        }

        pev(ent, pev_origin, fTargetOrigin);
        if((fDist = get_distance_f(fOrigin, fTargetOrigin)) <= fMinDistance)
        {
            fMinDistance = fDist;
        }
    }

    iCharged = floatround((floatclamp((300.0 - fMinDistance), 0.0, MAXfRadius) / MAXfRadius) * MAXChars);

    const Float:fOneByteRatio = 12.75;
    new iGreen = floatround(iCharged * fOneByteRatio);
    new iRed = 255 - iGreen;

    for( new i, iLen, iFirstHalf = floatround(float(MAXChars - iCharged) * 0.5); i < MAXChars; i++ )
    {
        if( iFirstHalf <= i < (iFirstHalf + iCharged) )
            iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%-2c", '#');
        else
            iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%-2c", '-');
    }

    set_hudmessage(.red = iRed, .green = iGreen, .blue = 0, .x = -1.0, .y = 0.90, .holdtime = 1.0, .channel = -1);
    show_hudmessage(id, "[%s]", szText);
}

public task_show_ability_cooldown(taskid)
{
    new id = taskid - TASK_DISPLAY_ABILITY_COOLDOWN, target = id;

    if(!is_user_alive(target))
    {
        target = pev(id, pev_iuser2);

        if( !is_user_alive(target) )
        {
            return;
        }
    }

    if(g_bitsUserAbility[target] == ABILITY_NONE)
    {
        return;
    }

    const MAXChars = 20;

    new Float:fCoolDown = get_pcvar_float(g_pcvar_ability_cd), szText[MAXChars * 4], Float:fGameTime = get_gametime(),
    iCharged = floatround((floatclamp((fGameTime - g_fUserAbilityTimeActivasion[target]), 0.0, fCoolDown) / fCoolDown) * MAXChars);
    for( new i, iLen, iFirstHalf = floatround(float(MAXChars - iCharged) * 0.5); i < MAXChars; i++ )
    {
        if( iFirstHalf <= i < (iFirstHalf + iCharged) )
            iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%-2c", '|');
        else
            iLen += formatex(szText[iLen], charsmax(szText) - iLen, "%-2c", '-');
    }

    set_hudmessage(.red = 0, .green = 200, .blue = 0, .x = -1.0, .y = 0.90, .holdtime = 1.0, .channel = -1);
    show_hudmessage(id, "[%s]", szText);
}

Invisiblity(id)
{
    set_rendering(id, .render=kRenderTransAlpha, .amount=000);

    set_task(get_pcvar_float(g_pcvar_ability_inv_duration), "InvisiblityOff", id+TASK_ABILITY_INVIS);
}

public InvisiblityOff(id)
{
    id -= TASK_ABILITY_INVIS;

    if(is_user_connected(id))
    {
        set_rendering(id);
    }
}

Create_Decoys(id)
{
    new Float:fOrigin[3], Array:pArrDecoysLocations = Invalid_Array, arrSize;
    pev(id, pev_origin, fOrigin);

    arrSize = find_location_around_origin(fOrigin, g_fMAX_SIZE, g_fMIN_SIZE, 200.0, .pArrayLocations = pArrDecoysLocations);

    new Float:fNPCLocation[3], ent, szModel[64], iBody, iSkin, iItem, iCount;
    get_user_info(id, "model", szModel, charsmax(szModel));
    format(szModel, charsmax(szModel), "models/player/%s/%s.mdl", szModel, szModel);
    iBody = pev(id, pev_body);
    iSkin = pev(id, pev_skin);

    while( arrSize-- > 0 )
    {
        ArrayGetArray(pArrDecoysLocations, (iItem = random(arrSize + 1)), fNPCLocation);
        ent = CreateNPC(fNPCLocation, NPC_CUSTOM_CLASSNAME,
        "DECOY",
        szModel);

        set_pev(ent, pev_body, iBody);
        set_pev(ent, pev_skin, iSkin);

        ArrayDeleteItem(pArrDecoysLocations, iItem);

        if(++iCount >= 5)
        {
            break;
        }
    }

    if(pArrDecoysLocations != Invalid_Array)
    {
        ArrayDestroy(pArrDecoysLocations);
    }
}

Teleport_Randomly(id)
{
    new Float:fOrigin[3];
    ROGGetOrigin(fOrigin);

    teleport_entity(id, fOrigin, g_fMAX_SIZE, g_fMIN_SIZE, .bHasTeleportTransmitter=true);
}

Explosion(id)
{
    new Float:fOrigin[3], Float:flTakeDamage;
    pev(id, pev_origin, fOrigin);
    pev(id, pev_takedamage, flTakeDamage);

    if(flTakeDamage != DAMAGE_NO)
    {
        ExecuteHamB(Ham_Killed, id, id, GIB_ALWAYS);
    }

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, fOrigin, 0);
    write_byte(TE_EXPLOSION);
    engfunc(EngFunc_WriteCoord, fOrigin[0]);
    engfunc(EngFunc_WriteCoord, fOrigin[1]);
    engfunc(EngFunc_WriteCoord, fOrigin[2]);
    write_short(g_iSprite_eexplo);
    write_byte(5);
    write_byte(50);
    write_byte(TE_EXPLFLAG_NONE);
    message_end();

    new iEnt = -1, Float:fHealth, Float:fRadius, Float:fMAXDamage, Float:fPosition[3];
    fMAXDamage = get_pcvar_float(g_pcvar_ability_exp_maxdmg);
    fRadius =    get_pcvar_float(g_pcvar_ability_exp_radius);
    while((iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, fRadius)) > 0)
    {
        pev(iEnt, pev_health, fHealth);
        pev(iEnt, pev_takedamage, flTakeDamage);
        if(flTakeDamage == DAMAGE_NO || fHealth <= 0.0)
        {
            continue;
        }

        if(pev(iEnt, pev_solid) == SOLID_BSP)
            get_brush_entity_origin(iEnt, fPosition);
        else
            pev(iEnt, pev_origin, fPosition);

        ExecuteHamB(Ham_TakeDamage, iEnt, id, id, (fMAXDamage * ( 1.0 - ( get_distance_f(fOrigin, fPosition) / fRadius ) )), DMG_BLAST | DMG_ALWAYSGIB);
    }
}

CreateMenuAnimeActions()
{
    new MActions = menu_create("Select an action", "m_anime_action_handler"),

    iCallback = menu_makecallback("MenuAnimeActionItemsCallBack");

    for(new i, szData[16], maxloop = sizeof g_aNPC_Tasks; i < maxloop; i++)
    {
        num_to_str(g_aNPC_Tasks[i][ANIME_TASK_ID], szData, charsmax(szData));
        menu_additem(MActions, g_aNPC_Tasks[i][ANIME_ACTION_NAME], szData, .callback = iCallback);
    }

    return MActions;
}

public MenuAnimeActionItemsCallBack(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        return ITEM_IGNORE;
    }

    new szData[16];
    menu_item_getinfo(menu, item, .info = szData, .infolen = charsmax(szData));
    if(g_iUserAnimeAction[id] == str_to_num(szData))
    {
        return ITEM_DISABLED;
    }

    return ITEM_ENABLED;
}

public m_anime_action_handler(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        return PLUGIN_HANDLED;
    }

    new szData[16];
    menu_item_getinfo(menu, item, .info = szData, .infolen = charsmax(szData));
    g_iUserAnimeAction[id] = str_to_num(szData);

    new iMenu, iNewMenu, iPage;
    player_menu_info(id, iMenu, iNewMenu, .menupage = iPage);
    menu_display(id, menu, iPage);
    return PLUGIN_HANDLED;
}

RetrieveNPCAnimeTaskPointer(const iAnimeTaskID)
{
    const sizeof_NPCTasks = sizeof g_aNPC_Tasks;
    for(new i; i < sizeof_NPCTasks; i++)
    {
        if(g_aNPC_Tasks[i][ANIME_TASK_ID] == iAnimeTaskID)
        {
            return i;
        }
    }

    log_error(AMX_ERR_GENERAL, "Animation task id #%d is not found or does not exist!", iAnimeTaskID);
    return Invalid_Task;
}

new g_SeekersModel[NPC_DATA] =
    { "Seeker", "Stormtrooper", "jb_pack6", 20, 0 };


new g_NPC_DEFAULT_CLASSES_DATA[][NPC_DATA] =
{
    { NPC_CUSTOM_CLASSNAME, "Banana", "models/player/jb_pack6/jb_pack6.mdl", 17, 0 },
    { NPC_CUSTOM_CLASSNAME, "Droid", "models/player/jb_pack6/jb_pack6.mdl", 21, 0 },
    { NPC_CUSTOM_CLASSNAME, "Kermit", "models/player/jb_pack6/jb_pack6.mdl", 8, 0 },
    { NPC_CUSTOM_CLASSNAME, "Jar Jar", "models/player/jb_pack6/jb_pack6.mdl", 18, 0 },
    { NPC_CUSTOM_CLASSNAME, "Jawa", "models/player/jb_pack6/jb_pack6.mdl", 19, 0 }
}

public plugin_precache()
{
    new szKey[64], szValue[32];

    for(new i ; i < sizeof g_NPC_DEFAULT_CLASSES_DATA; i++)
    {
        jb_ini_get_keyvalue("GUESS WHO?", g_NPC_DEFAULT_CLASSES_DATA[i][NPC_NAME], g_NPC_DEFAULT_CLASSES_DATA[i][NPC_MODEL], charsmax(g_NPC_DEFAULT_CLASSES_DATA[][NPC_MODEL]));
        PRECACHE_PLAYER_MODEL(g_NPC_DEFAULT_CLASSES_DATA[i][NPC_MODEL]);

        num_to_str(g_NPC_DEFAULT_CLASSES_DATA[i][NPC_BODY_ID], szValue, charsmax(szValue));
        formatex(szKey, charsmax(szKey), "%s_BODY", g_NPC_DEFAULT_CLASSES_DATA[i][NPC_NAME]);
        jb_ini_get_keyvalue("GUESS WHO?", szKey, szValue, charsmax(szValue));
        g_NPC_DEFAULT_CLASSES_DATA[i][NPC_BODY_ID] = str_to_num(szValue);

        num_to_str(g_NPC_DEFAULT_CLASSES_DATA[i][NPC_SKIN_ID], szValue, charsmax(szValue));
        formatex(szKey, charsmax(szKey), "%s_SKIN", g_NPC_DEFAULT_CLASSES_DATA[i][NPC_NAME]);
        jb_ini_get_keyvalue("GUESS WHO?", szKey, szValue, charsmax(szValue));
        g_NPC_DEFAULT_CLASSES_DATA[i][NPC_SKIN_ID] = str_to_num(szValue);
    }

    new szModel[64];
    jb_ini_get_keyvalue("GUESS WHO?", g_SeekersModel[NPC_CLASS], g_SeekersModel[NPC_MODEL], charsmax(g_SeekersModel[NPC_MODEL]));
    formatex(szModel, charsmax(szModel), "models/player/%s/%s.mdl", g_SeekersModel[NPC_MODEL], g_SeekersModel[NPC_MODEL]);
    PRECACHE_PLAYER_MODEL(szModel);

    PRECACHE_SOUND(g_szShapeShiftSound);
    PRECACHE_SOUND("jailbreak/nc_teleport.wav");

    g_iSprite_blood = precache_model("sprites/blood.spr");
    g_iSprite_bloodspray = precache_model("sprites/bloodspray.spr");
    g_iSprite_eexplo = precache_model("sprites/eexplo.spr");
    precache_model("sprites/b-tele1.spr");
}

new Array:g_animArrays[NPC_ACTIVITY], g_sizeAnimArrays[NPC_ACTIVITY];

new bool:g_bReGameDLL = false;

public plugin_end()
{
    NPC_FREE_HOOKS(NPC_CUSTOM_CLASSNAME);
    MDL_STUDIO_FREE_DATA(g_animArrays, g_sizeAnimArrays);
    MDL_STUDIO_DESTROY_HOOKS(engfunc(EngFunc_ModelIndex, g_NPC_DEFAULT_CLASSES_DATA[0][NPC_MODEL]));
    menu_destroy(g_pMenuAnimeAction);
}

public plugin_init()
{
    new iPluginID = register_plugin(PLUGIN, VERSION, AUTHOR);
    NPC_Hook_Event(NPC_CUSTOM_CLASSNAME, NPC_EVENT_TRACEATTACK, "npc_traceattack", iPluginID);
    NPC_Hook_Event(NPC_CUSTOM_CLASSNAME, NPC_EVENT_DEATH, "npc_killed", iPluginID);
    MDL_STUDIO_LOAD_ANIMATIONS(g_NPC_DEFAULT_CLASSES_DATA[0][NPC_MODEL], g_animArrays, g_sizeAnimArrays);
    register_think(NPC_CUSTOM_CLASSNAME, "npc_think");
    g_pMenuAnimeAction = CreateMenuAnimeActions();

    new any:xArray[ANIMATION_DATA], X = g_sizeAnimArrays[ACT_WALK];

    while( X-- > 0 )
    {
        ArrayGetArray(Array:g_animArrays[ACT_WALK], X, xArray);
        xArray[ANIMATION_SEQUENCE] = NPC_WALKING_ANIMATION;
        ArraySetArray(Array:g_animArrays[ACT_WALK], X, xArray);
    }

    X = g_sizeAnimArrays[ACT_RUN];

    while( X-- > 0 )
    {
        ArrayGetArray(Array:g_animArrays[ACT_RUN], X, xArray);
        xArray[ANIMATION_SEQUENCE] = NPC_RUNNING_ANIMATION;
        ArraySetArray(Array:g_animArrays[ACT_RUN], X, xArray);
    }

    g_pcvar_seekers_ratio = register_cvar("jb_day_guesswho_seekers_ratio", "25");
    g_pcvar_npc_count = register_cvar("jb_day_guesswho_npc_count", "50");
    g_pcvar_npc_walkingspeed = register_cvar("jb_day_guesswho_npc_walkingspeed", "100.0");
    g_pcvar_npc_runningspeed = register_cvar("jb_day_guesswho_npc_runningspeed", "250.0");
    g_pcvar_ability_exp_maxdmg = register_cvar("jb_sd_guesswho_ability_exp_dmg", "300.0");
    g_pcvar_ability_exp_radius = register_cvar("jb_sd_guesswho_ability_exp_rad", "150.0");
    g_pcvar_ability_cd = register_cvar("jb_sd_guesswho_ability_cooldown", "30.0");
    g_pcvar_ability_inv_duration = register_cvar("jb_sd_guesswho_ability_invis_dur", "10.0");
    g_iPointerGuessWhoSpecialday = register_jailbreak_day("Guess Who?", 0, 5.0 * 60.0, DAY_TIMER);

    DisableHamForward( (g_fw_player_killed_post = RegisterHam(Ham_Killed, "player", "fw_player_killed_post", .Post = true)));
    DisableHamForward( (g_fw_player_takedmg_pre = RegisterHam(Ham_TakeDamage, "player", "fw_player_takedamage_pre", .Post = false)));

    ROGInitialize(250.0);

    g_iMSG_Radar = get_user_msgid("Radar");
    g_iMSG_StatusValue = get_user_msgid("StatusValue");

    arrayset(g_iUserAnimeAction, ANIME_TASK_WALK, sizeof g_iUserAnimeAction);

    if(is_regamedll())
    {
        RegisterHookChain(RG_CBasePlayer_SetAnimation, "OnSetAnimation", .post = 0);
        g_bReGameDLL = true;
    }
    else
    {
        OrpheuRegisterHook(OrpheuGetFunction("PM_Duck"), "OnPM_Duck");
    }

    // Called usually when a player en/disable his/her flashlight in cstrike/half-life...
    register_impulse(100, "fw_impulse_100");
}

// Called usually when a player en/disable his/her flashlight in cstrike/half-life...
public fw_impulse_100(id, impulse)
{
    if(!is_user_alive(id) || g_bitsUserAbility[id] == ABILITY_NONE)
    {
        return PLUGIN_CONTINUE;
    }

    new Float:fGameTime = get_gametime();

    if(g_fUserAbilityTimeActivasion[id] + 30.0 >= fGameTime)
    {
        client_print(id, print_center, "Ability is in cooldown!");
        return PLUGIN_HANDLED;
    }

    if(g_bitsUserAbility[id] & ABILITY_DECOYS)
    {
        Create_Decoys(id);
    }

    if(g_bitsUserAbility[id] & ABILITY_EXPLOSIVE)
    {
        Explosion(id);
    }

    if(g_bitsUserAbility[id] & ABILITY_TELEPORTATION)
    {
        Teleport_Randomly(id);
    }

    if(g_bitsUserAbility[id] & ABILITY_INVISIBLE)
    {
        Invisiblity(id);
    }

    g_fUserAbilityTimeActivasion[id] = get_gametime();
    return PLUGIN_HANDLED;
}

public OrpheuHookReturn:OnPM_Duck()
{
    new OrpheuStruct:ppmove = get_ppmove();

    new id = OrpheuGetStructMember(ppmove, "player_index") + 1;

    if(g_bDisguise[id])
    {
        return OrpheuSupercede;
    }

    return OrpheuIgnored;
}

OrpheuStruct:get_ppmove()
{
    return OrpheuGetStructFromAddress(OrpheuStructPlayerMove, OrpheuMemoryGet("ppmove"));
}

PrepareNPCBrainActivity()
{
    const sizeofRandomizedNPCAnimTask = sizeof g_RandomizedNPCAnimTask[];

    arrayset(g_RandomizedNPCAnimTask[0], ANIME_TASK_WALK, sizeofRandomizedNPCAnimTask);
    arrayset(g_RandomizedNPCAnimTask[1], ANIME_TASK_WALK, sizeofRandomizedNPCAnimTask);

    const sizeofAnimeTasks = sizeof g_aNPC_Tasks;

    for(new i, x, j, nloop; i < sizeofAnimeTasks; i++)
    {
        nloop = floatround( floatclamp( (g_aNPC_Tasks[i][ANIME_TASK_CHANCE] * 100.0) / float( sizeofAnimeTasks ), 1.0, 99.0 ) );

        for(j = 0; j < nloop; j++)
        {
            g_RandomizedNPCAnimTask[0][min(x + j, 99)] = g_aNPC_Tasks[i][ANIME_TASK_ID];
        }

        x += nloop;
    }

    SortIntegers(g_RandomizedNPCAnimTask[0],  sizeofRandomizedNPCAnimTask, Sort_Random);
    SortIntegers(g_RandomizedNPCAnimTask[0],  sizeofRandomizedNPCAnimTask, Sort_Random);
    SortIntegers(g_RandomizedNPCAnimTask[0],  sizeofRandomizedNPCAnimTask, Sort_Random);

    for(new x; x < 100; x++)
    {
        g_RandomizedNPCAnimTask[1][x] = RetrieveNPCAnimeTaskPointer(g_RandomizedNPCAnimTask[0][x]);
    }
}

public npc_traceattack(id, attacker, Float:fDamage, Float:fDirection[3], trace_handle, damagebits)
{
    if(IsPlayer(attacker))
    {
        ExecuteHamB(Ham_TakeDamage, attacker, id, id, fDamage, DMG_GENERIC);
    }

    if(fDamage > 0.0)
    {
        fDirection[0] *= fDamage;
        fDirection[1] *= fDamage;
        fDirection[2] *= fDamage;

        static Float:fHit[3];
        get_tr2(trace_handle, TR_vecEndPos, fHit);
        EFF_SPILL_BLOOD(fHit, fDirection, g_iSprite_bloodspray, g_iSprite_blood);
    }
}

public client_disconnect(id)
{
    CheckGuessWhoGameWinStatus();

    remove_task(id + TASK_DISPLAY_ABILITY_COOLDOWN);
    remove_task(id + TASK_DISPLAY_SEEKER_RADAR);
    remove_task(id + TASK_ABILITY_INVIS);
}

public fw_player_takedamage_pre(victim, inflictor, attacker, Float:fDamage, iDamageBits)
{
    if(!(iDamageBits & DMG_BLAST))
    {
        if(IsPlayer(attacker) && attacker != victim && check_flag(g_BitsGuessWho_Hiders,attacker) && check_flag(g_BitsGuessWho_Seekers,victim))
        {
            SetHamParamFloat( 4 , 10.0 );
            return HAM_IGNORED;
        }
    }
    return HAM_IGNORED;
}

public fw_player_killed_post(victim)
{
    g_bDisguise[victim] = false;

    new iMenu, iNewMenu, iPage;
    player_menu_info(victim, iMenu, iNewMenu, .menupage = iPage);
    if(g_pMenuAnimeAction == iNewMenu)
    {
        menu_cancel(victim);
        show_menu(victim, 0, " ^n ");
    }

    CheckGuessWhoGameWinStatus();
}

public jb_day_started(iDayId)
{
    if(iDayId == g_iPointerGuessWhoSpecialday)
    {
        set_msg_block(g_iMSG_Radar, BLOCK_SET);
        set_msg_block(g_iMSG_StatusValue, BLOCK_SET);
        if(!g_FW_FM_PlayerPreThink_Post)
            g_FW_FM_PlayerPreThink_Post = register_forward(FM_PlayerPreThink, "fw_PlayerPreThink_Post", ._post = true);
        EnableHamForward(g_fw_player_killed_post);
        EnableHamForward(g_fw_player_takedmg_pre);

        DivideRoles();
        BlindSeekers();
        set_task( InitiateCreatingNPCs(get_pcvar_num(g_pcvar_npc_count)) , "task_start_seeking_session", TASK_SEEKING_SESSION);

        set_task(1.0, "task_client_cvars_check", TASK_CVARS_RULES, _, _, "b");
    }
}

public task_client_cvars_check(taskid)
{
    new players[MAX_PLAYERS], pnum;
    get_players(players, pnum, "ach");

    for(new i; i < pnum; i++)
    {
        query_client_cvar(players[i], "cl_minmodels", "cvar_query");
    }
}

public cvar_query(const id, const cvar[], const value[], const param[])
{
    if(equal(cvar, "cl_minmodels"))
    {
        if(value[0] != '0')
        {
            user_kill(id);
            cprint_chat(id, _, "Using !gcl_minmodels !yis !tforbidden!y, set the CVar to !g0!y.");
            client_cmd(id, "cl_minmodels ^"0^"");
        }
    }
}

public task_start_seeking_session(taskid)
{
    RestoreVisionSeekers();
    GrantSeekersWeapons();
}

GrantSeekersWeapons()
{
    new players[32], pnum;
    get_players(players, pnum, "ah");

    for(new i, player; i < pnum; i++)
    {
        player = players[i];

        // Seekers...
        if( check_flag(g_BitsGuessWho_Seekers,player) )
        {
            give_item_mp5m203(player);
            cs_set_user_bpammo(player, CSW_DEAGLE, 90);
            give_item(player, "weapon_deagle");
        }
    }
}

RestoreVisionSeekers()
{
    new players[32], pnum;
    get_players(players, pnum, "ah");

    for(new i, player; i < pnum; i++)
    {
        player = players[i];

        //unBlind Seekers...
        if( check_flag(g_BitsGuessWho_Seekers,player) )
        {
            UTIL_ScreenFade(player, {0, 0, 0}, -1.0, 1.0, 0, FFADE_IN);
            set_user_godmode(player, .godmode = 0);
        }
    }
}

BlindSeekers()
{
    new players[32], pnum;
    get_players(players, pnum, "ah");

    for(new i, player; i < pnum; i++)
    {
        player = players[i];

        //Blind Seekers...
        if( check_flag(g_BitsGuessWho_Seekers,player) )
        {
            UTIL_ScreenFade(player, {0, 0, 0}, -1.0, 1.0, 255, FFADE_STAYOUT);
            set_user_godmode(player, .godmode = 1);
        }
    }
}

DivideRoles()
{
    new players[32], pnum;
    get_players(players, pnum, "ah");

    if(pnum < 2)
    {
        return;
    }

    new Seekers_ratio = clamp(floatround(pnum * (get_pcvar_float(g_pcvar_seekers_ratio) / 100.0), floatround_round), 1, pnum - 1);

    const SEEKERS_WEAPONS = (1<<CSW_KNIFE) | (1<<CSW_MP5NAVY) | (1<<CSW_DEAGLE);
    const HIDERS_WEAPONS = (1<<CSW_KNIFE);
    g_BitsGuessWho_Hiders = ~( 0 );

    for(new i, player, randomized, Float:fGameTime = get_gametime(); i < Seekers_ratio; i++)
    {
        player = players[(randomized=random(pnum))];
        players[ randomized ] = players[ --pnum ];

        //set seekers...
        set_flag(g_BitsGuessWho_Seekers,player);
        remove_flag(g_BitsGuessWho_Hiders,player);

        jb_block_user_weapons(player, true, ~( SEEKERS_WEAPONS ));
        cs_set_player_model(player, g_SeekersModel[NPC_MODEL]);
        set_pev(player, pev_body, g_SeekersModel[NPC_BODY_ID]);
        set_pev(player, pev_skin, g_SeekersModel[NPC_SKIN_ID]);
        set_pev(player, pev_health, 100.0);

        set_pdata_float(player, Offset_m_flNextSBarUpdateTime, fGameTime + 99999.0);
    }

    for(new i, player; i < pnum; i++)
    {
        player = players[i];
        set_pev(player, pev_health, 200.0);
    }

    // settup enemies...
    for(new player = 1, Float:fAbilityActivasion = get_gametime(); player <= MAX_PLAYERS; player++)
    {
        if(check_flag(g_BitsGuessWho_Hiders,player))
        {
            jb_set_user_enemies(player, g_BitsGuessWho_Seekers);
            jb_set_user_allies(player, g_BitsGuessWho_Hiders);
            jb_block_user_weapons(player, true, ~( HIDERS_WEAPONS ));

            // Setup hider ability...

            new iRandom = random(any:ABILITY_TYPE_MAX);
            cprint_chat(player, _, "Your ability is !g%s !tpress F to activate!",
                        g_aAbilities[ iRandom ][ABILITY_NAME]);
            g_fUserAbilityTimeActivasion[player] = fAbilityActivasion;
            g_bitsUserAbility[player] = any:g_aAbilities[ iRandom ][ABILITY_BIT_ID];

            if(is_user_alive(player))
            {
                set_task(1.0, "task_show_ability_cooldown", player + TASK_DISPLAY_ABILITY_COOLDOWN, _, _, "b");

                // Lets enable player 3rd person camera.
                set_player_camera(player, VIEW_BACK_100_UNITS);
            }
        }
        else if(check_flag(g_BitsGuessWho_Seekers,player))
        {
            jb_set_user_enemies(player, g_BitsGuessWho_Hiders);
            jb_set_user_allies(player, g_BitsGuessWho_Seekers);

            set_task(1.0, "task_show_seeker_radar", player + TASK_DISPLAY_SEEKER_RADAR, _, _, "b");
        }
    }
}

CheckGuessWhoGameWinStatus()
{
    if(jb_get_current_day() != g_iPointerGuessWhoSpecialday)
    {
        return;
    }

    new players[32], pnum, iHidersCount, iSeekersCount;
    get_players(players, pnum, "ah");

    for(new i, player; i < pnum; i++)
    {
        player = players[i];

        if( check_flag(g_BitsGuessWho_Hiders,player) )
        {
            iHidersCount ++;
        }
        else if( check_flag(g_BitsGuessWho_Seekers,player) )
        {
            iSeekersCount ++;
        }
    }

    if( !iHidersCount && !iSeekersCount )
    {
        // Game Draw.
        client_print(0, print_center, "Game Draw");
        jb_end_theday();
    }
    else if( !iHidersCount && iSeekersCount > 0 )
    {
        // Seekers have won.
        client_print(0, print_center, "Seekers win!");
        jb_end_theday();
    }
    else if( iHidersCount > 0 && (!iSeekersCount || jb_get_day_length(g_iPointerGuessWhoSpecialday) <= 0.0) )
    {
        // Hiders have won.
        client_print(0, print_center, "Hiders win!");
        jb_end_theday();
    }
}

ResetGameSetting()
{
    // Reset players skin :)
    new players[32], pnum, Float:fGameTime = get_gametime();
    get_players(players, pnum, "h");

    for(new i, player, iMenu, iNewMenu, iPage, Float:fOrigin[3], ent; i < pnum; i++)
    {
        player = players[i];

        player_menu_info(player, iMenu, iNewMenu, .menupage = iPage);
        if(g_pMenuAnimeAction == iNewMenu)
        {
            menu_cancel(player);
            show_menu(player, 0, " ^n ");
        }

        jb_set_user_class_model(player);

        if(check_flag(g_BitsGuessWho_Seekers,player))
        {
            set_pdata_float(player, Offset_m_flNextSBarUpdateTime, fGameTime);
        }

        if(check_flag(g_BitsGuessWho_Hiders,player))
        {
            // Lets disable player 3rd person camera.
            set_player_camera(player, VIEW_FIRST_PERSON);

            if(g_bDisguise[player])
            {
                pev(player, pev_origin, fOrigin);
                while( (ent = find_ent_in_sphere(ent, fOrigin, 100.0)) > 0 )
                {
                    if(pev(ent, pev_aiment) == player)
                    {
                        set_pev(ent, pev_effects, pev(ent, pev_effects) & ~EF_NODRAW);
                    }
                }


                set_pev(player, pev_maxspeed, 250.0);
            }
        }

        remove_task(player + TASK_DISPLAY_ABILITY_COOLDOWN);
        remove_task(player + TASK_DISPLAY_SEEKER_RADAR);
    }

    g_BitsGuessWho_Hiders = g_BitsGuessWho_Seekers = 0;

    arrayset(g_bDisguise, false, sizeof g_bDisguise);
    arrayset(g_bitsUserAbility, ABILITY_NONE, sizeof g_bitsUserAbility);
    arrayset(g_iUserAnimeAction, ANIME_TASK_WALK, sizeof g_iUserAnimeAction);
}

public fw_PlayerPreThink_Post(id)
{
    static iButton, iOldButtons;
    iButton = pev(id, pev_button);
    iOldButtons = pev(id, pev_oldbuttons);

    if((iButton & IN_USE) && !(iOldButtons & IN_USE)) // button pressed.
    {
        if(check_flag(g_BitsGuessWho_Hiders, id))
        {
            static iTarget;
            if(get_user_aiming(id, iTarget) <= 100.0)
            {
                if(iTarget > 0 && pev(iTarget, pev_flags) & (FL_MONSTER|FL_CLIENT))
                {
                    ShapeShiftSkin(id, iTarget);
                }
            }
        }
    }
    if((iButton & IN_RELOAD) && !(iOldButtons & IN_RELOAD) && check_flag(g_BitsGuessWho_Hiders, id)) // button pressing.
    {
        g_bDisguise[id] = !g_bDisguise[id];
        client_print(id, print_center, "%sctivated NPC Imitation Mode!", g_bDisguise[id] ? "A":"Dea");

        if(g_bDisguise[id])
        {
            new Float:fOrigin[3], ent;
            pev(id, pev_origin, fOrigin);
            while( (ent = find_ent_in_sphere(ent, fOrigin, 100.0)) > 0 )
            {
                if(pev(ent, pev_aiment) == id && !(pev(ent, pev_effects) & EF_NODRAW))
                {
                    set_pev(ent, pev_effects, pev(ent, pev_effects) | EF_NODRAW);
                }
            }

            menu_display(id, g_pMenuAnimeAction);

            set_pev(id, pev_maxspeed, -1.0);
            set_pev(id, pev_weaponmodel, 0);
            set_pev(id, pev_viewmodel,   0);

            if(g_bReGameDLL)
            {
                set_pev(id, pev_iuser3, ( pev(id, pev_iuser3) | PLAYER_PREVENT_DUCK | PLAYER_PREVENT_JUMP ));
            }
        }
        else
        {
            new Float:fOrigin[3], ent;
            pev(id, pev_origin, fOrigin);
            while( (ent = find_ent_in_sphere(ent, fOrigin, 100.0)) > 0 )
            {
                if(pev(ent, pev_aiment) == id)
                {
                    set_pev(ent, pev_effects, pev(ent, pev_effects) & ~EF_NODRAW);
                }
            }

            set_pev(id, pev_maxspeed, get_pcvar_float(g_pcvar_npc_runningspeed));

            new iActiveItem = get_pdata_cbase(id, Offset_m_pActiveItem);

            if(iActiveItem > 0)
            {
                ExecuteHamB(Ham_Item_Deploy, iActiveItem);
            }

            if(g_bReGameDLL)
            {
                set_pev(id, pev_iuser3, ( pev(id, pev_iuser3) & ~(PLAYER_PREVENT_DUCK | PLAYER_PREVENT_JUMP) ));
            }
        }
    }

    if(g_bDisguise[id])
    {
        static Float:fAngle[3], Float:fVelo[3], Float:fSpeed;
        pev(id, pev_v_angle, fAngle);
        pev(id, pev_velocity, fVelo);
        set_pev(id, pev_maxspeed, -1.0);

        switch( g_iUserAnimeAction[id] )
        {
            case ANIME_TASK_WALK:
            {
                fSpeed = get_pcvar_float(g_pcvar_npc_walkingspeed);
                fVelo[0] = floatcos(fAngle[1], degrees) * fSpeed;
                fVelo[1] = floatsin(fAngle[1], degrees) * fSpeed;

                set_pev(id, pev_velocity, fVelo);
            }
            case ANIME_TASK_RUN:
            {
                fSpeed = get_pcvar_float(g_pcvar_npc_runningspeed);
                fVelo[0] = floatcos(fAngle[1], degrees) * fSpeed;
                fVelo[1] = floatsin(fAngle[1], degrees) * fSpeed;

                set_pev(id, pev_velocity, fVelo);
            }
        }
    }
}

public OnSetAnimation(player, anim)
{
    if(g_bDisguise[player])
    {
        static Float:fFrameRate, Float:fGroundSpeed, bool:bLoops;
        set_pev(player,
            pev_sequence,
            lookup_sequence(player, g_aNPC_Tasks[RetrieveNPCAnimeTaskPointer(g_iUserAnimeAction[player])][ANIME_TASK_NAME], fFrameRate, bLoops, fGroundSpeed)
            );
        set_ent_data(player, "CBaseAnimating", "m_fSequenceLoops", bLoops);
        set_ent_data_float(player, "CBaseAnimating", "m_flFrameRate", fFrameRate);
        set_ent_data_float(player, "CBaseAnimating", "m_flGroundSpeed", fGroundSpeed);
        return g_bReGameDLL ? HC_SUPERCEDE : PLUGIN_HANDLED;
    }

    return g_bReGameDLL ? HC_CONTINUE : PLUGIN_CONTINUE;
}

ShapeShiftSkin(const ShapeShifter, const iVictim)
{
    new szModel[64];

    if(IsPlayer(ShapeShifter))
    {
        if(IsPlayer(iVictim))
        {
            get_user_info(iVictim, "model", szModel, charsmax(szModel));
            cs_set_player_model(ShapeShifter, szModel);
        }
        else
        {
            pev(iVictim, pev_model, szModel, charsmax(szModel));

            // is it a player skin?
            if(contain(szModel, "/player/") != -1)
            {
                new iLen = strlen(szModel);

                while( iLen-- > 0 )
                {
                    if(szModel[iLen] == '\' || szModel[iLen] == '/')
                    {
                        szModel[ format(szModel, charsmax(szModel), szModel[iLen + 1]) - 4 ] = 0;
                        break;
                    }
                }

                cs_set_player_model(ShapeShifter, szModel);
            }
            else
            {
                engfunc(EngFunc_SetModel, ShapeShifter, szModel);
            }
        }
    }
    else
    {
        if(IsPlayer(iVictim))
        {
            get_user_info(iVictim, "model", szModel, charsmax(szModel));
            format(szModel, charsmax(szModel), "models/player/%s/%s.mdl", szModel, szModel);
        }
        else
        {
            pev(iVictim, pev_model, szModel, charsmax(szModel));
        }

        engfunc(EngFunc_SetModel, ShapeShifter, szModel);
    }

    set_pev(ShapeShifter, pev_body, pev(iVictim, pev_body));
    set_pev(ShapeShifter, pev_skin, pev(iVictim, pev_skin));

    emit_sound(ShapeShifter, CHAN_AUTO, g_szShapeShiftSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public jb_day_ended(iDayId)
{
    if(iDayId == g_iPointerGuessWhoSpecialday)
    {
        RestoreVisionSeekers();
        DestroyNPCs();

        set_msg_block(g_iMSG_Radar, BLOCK_NOT);
        set_msg_block(g_iMSG_StatusValue, BLOCK_NOT);
        remove_task(TASK_INITIATE_NPC);
        remove_task(TASK_CVARS_RULES);
        DisableHamForward(g_fw_player_killed_post);
        DisableHamForward(g_fw_player_takedmg_pre);
        unregister_forward(FM_PlayerPreThink, g_FW_FM_PlayerPreThink_Post, .post = true);
        g_FW_FM_PlayerPreThink_Post = 0;

        ResetGameSetting();
    }
}

stock Float:UTIL_PlayerAnimation(const id, const szAnimation[])
{
    static iAnimDesired, Float:fFrameRate, Float:fGroundSpeed, bool:bLoops;
    if((iAnimDesired = lookup_sequence(id, szAnimation, fFrameRate, bLoops, fGroundSpeed)) == -1) iAnimDesired = 0;
    static Float:fGameTime;
    fGameTime = get_gametime();
    set_pev(id, pev_frame, 0.0);
    set_pev(id, pev_framerate, 1.0);
    set_pev(id, pev_animtime, fGameTime);
    set_pev(id, pev_sequence, iAnimDesired);
    set_ent_data(id, "CBaseAnimating", "m_fSequenceLoops", bLoops);
    set_ent_data(id, "CBaseAnimating", "m_fSequenceFinished", false);
    set_ent_data_float(id, "CBaseAnimating", "m_flFrameRate", fFrameRate);
    set_ent_data_float(id, "CBaseAnimating", "m_flGroundSpeed", fGroundSpeed);
    set_ent_data_float(id, "CBaseAnimating", "m_flLastEventCheck", fGameTime);
    set_ent_data_float(id, "CBasePlayer", "m_flTimeWeaponIdle", fGameTime);
    set_pdata_int(id, 73, 28);
    set_pdata_int(id, 74, 28);
    set_pdata_float(id, 220, fGameTime);

    static xArray[ANIMATION_DATA], szModel[64];
    get_user_info(id, "model", szModel, charsmax(szModel));
    format(szModel, charsmax(szModel), "models/player/%s/%s.mdl", szModel, szModel);
    getSequenceData(szModel, iAnimDesired, xArray);

    return (xArray[ANIMATION_FRAMES] / xArray[ANIMATION_FPS]);
}

Float:InitiateCreatingNPCs(const iAmount)
{
    static iMsgBarTime = 0;
    if(!iMsgBarTime)
    {
        iMsgBarTime = get_user_msgid("BarTime");
    }

    message_begin(MSG_ALL, iMsgBarTime);
    write_short( min(floatround( float(iAmount) * 0.25), 0xFFFFFF) );
    message_end();

    PrepareNPCBrainActivity();
    ROGShuffleOrigins();

    set_task(0.25, "CreateRandomNPC", TASK_INITIATE_NPC, _, _, "a", iAmount);

    return (0.25 * float( iAmount ) );
}

DestroyNPCs()
{
    new ent;
    while( (ent = find_ent_by_class(ent, NPC_CUSTOM_CLASSNAME)) > 0)
    {
        set_pev(ent, pev_flags, FL_KILLME);
        dllfunc(DLLFunc_Think, ent);
    }
}

public CreateRandomNPC()
{
    new Float:fvRandomOrigin[3], X = random(sizeof g_NPC_DEFAULT_CLASSES_DATA);
    ROGGetOrigin(fvRandomOrigin);
    new ent = CreateNPC(fvRandomOrigin, g_NPC_DEFAULT_CLASSES_DATA[X][NPC_CLASS],
        g_NPC_DEFAULT_CLASSES_DATA[X][NPC_NAME],
        g_NPC_DEFAULT_CLASSES_DATA[X][NPC_MODEL]);

    set_pev(ent, pev_body, g_NPC_DEFAULT_CLASSES_DATA[X][NPC_BODY_ID]);
    set_pev(ent, pev_skin, g_NPC_DEFAULT_CLASSES_DATA[X][NPC_SKIN_ID]);

    client_print(0, print_center, "Creating an NPC...");
}

CreateNPC(const Float:fOrigin[3], const szClass[], const szName[], const szModel[])
{
    new ent = NPC_SPAWN(szClass,
                        szName,
                        szModel,
                        .fOrigin = fOrigin,
                        .fViewOFS = Float:{ 0.0, 0.0, 68.0 },
                        .fMaxSpeed = 1000.0,
                        .fMaxHealth = 100.0,
                        .task = NPC_SEEK_TARGET,
                        .fMaxS = g_fMAX_SIZE,
                        .fMinS = g_fMIN_SIZE);

    return ent;
}

public npc_killed(const id, const killer)
{
    new szClass[32];
    pev(id, PEV_WEAPON_INFLICTOR, szClass, charsmax(szClass));
    Initiate_NPC_DEATHMSG(id, killer, false, szClass);
}

public npc_think(const id)
{
    static Float:fOrigin[3], Float:fNPCViewAngles[3], any:iTask, Float:fGtime, Float:fNPCspeed,
        any:iNextTask, Float:fNPCJspeed, Float:fVelocity[3];
    pev(id, pev_origin, fOrigin);
    pev(id, pev_angles, fNPCViewAngles);
    pev(id, pev_velocity, fVelocity);
    fGtime = get_gametime();

    iNextTask = g_RandomizedNPCAnimTask[0][random(100)];
    iTask = pev(id, PEV_TASK);

    if(iNextTask != Invalid_Task && iTask != iNextTask)
    {
        set_pev(id, PEV_PREVIOUS_TASK, iTask);
        set_pev(id, PEV_TASK, iNextTask);
        iNextTask = Invalid_Task;
    }

    switch( iTask )
    {
        case NPC_DEATH:
        {
            remove_task(id);

            new Float:fLen = NPC_animation(id, g_animArrays, g_sizeAnimArrays);

            set_pev(id, PEV_TASK, NPC_KILLSELF);
            set_pev(id, pev_nextthink, fGtime + fLen + NPC_KILLSELF_THINK_LEN);
        }
        case NPC_KILLSELF:
        {
            set_pev(id, pev_flags, FL_KILLME);
            dllfunc(DLLFunc_Think, id);
        }
        case NPC_IDLE:
        {
            NPC_animation(id, g_animArrays, g_sizeAnimArrays);
            set_pev(id, pev_nextthink, fGtime + NPC_THINK_LEN);
        }
        case NPC_SEEK_TARGET, ANIME_TASK_RUN, ANIME_TASK_WALK:
        {
            switch( iTask )
            {
                case ANIME_TASK_WALK: fNPCspeed = fNPCJspeed = get_pcvar_float(g_pcvar_npc_walkingspeed);
                case ANIME_TASK_RUN: fNPCspeed = fNPCJspeed = get_pcvar_float(g_pcvar_npc_runningspeed);
            }

            static i, Float:fOriginDest[3], Float:vfTemp[3], Float:fvForward[3], Float:fvRight[3],
            Float:fvLeft[3], Float:fMaxDistance, Float:fChosenAngle, Float:fCurrAngle,
            Float:fDist, Float:fLeftDist, Float:fRightDist;

            fChosenAngle = 0.0;
            fMaxDistance = 0.0; // 1k unit should be enf for us to find the longest path.
            fOriginDest[2] = fOrigin[2];

            for ( i = 0, fCurrAngle = -45.0;  i < 3; i ++ )
            {
                fDist = fLeftDist = fRightDist = 9999.0;
                xs_vec_set(vfTemp, 0.0, fNPCViewAngles[1] + fCurrAngle, 0.0);
                angle_vector(vfTemp, ANGLEVECTOR_FORWARD, fvForward);
                angle_vector(vfTemp, ANGLEVECTOR_RIGHT, fvRight);
                angle_vector(vfTemp, ANGLEVECTOR_RIGHT, fvLeft);
                xs_vec_mul_scalar(fvForward, fDist, fvForward);
                xs_vec_mul_scalar(fvRight,  (g_fMAX_SIZE[1] - g_fMIN_SIZE[1]), fvRight);
                xs_vec_mul_scalar(fvLeft , -(g_fMAX_SIZE[1] - g_fMIN_SIZE[1]), fvLeft );

                fOriginDest[0] = fOrigin[0] + fvForward[0];
                fOriginDest[1] = fOrigin[1] + fvForward[1];
                NPC_traceattack(id, fOrigin, fOriginDest, fDist, .HullType=HULL_POINT);

                fOriginDest[0] = fOrigin[0] + fvRight[0] + fvForward[0];
                fOriginDest[1] = fOrigin[1] + fvRight[1] + fvForward[1];
                fvRight[0] += fOrigin[0];
                fvRight[1] += fOrigin[1];
                fvRight[2] += fOrigin[2];
                NPC_traceattack(id, fvRight, fOriginDest, fRightDist, .HullType=HULL_POINT);

                fOriginDest[0] = fOrigin[0] + fvLeft[0] + fvForward[0];
                fOriginDest[1] = fOrigin[1] + fvLeft[1] + fvForward[1];
                fvLeft[0] += fOrigin[0];
                fvLeft[1] += fOrigin[1];
                fvLeft[2] += fOrigin[2];
                NPC_traceattack(id, fvLeft, fOriginDest, fLeftDist, .HullType=HULL_POINT);

                fDist = floatmin(fDist, floatmin(fRightDist, fLeftDist));

                if(fDist > fMaxDistance)
                {
                    fMaxDistance = fDist;
                    fChosenAngle = fNPCViewAngles[1] + fCurrAngle;
                }

                fCurrAngle += 45.0;
            }

            if( fMaxDistance > ((g_fMAX_SIZE[1] - g_fMIN_SIZE[1]) * 0.5) )
            {
                vfTemp[ 0 ] = vfTemp[ 2 ] = 0.0;

                vfTemp[ 1 ] = fChosenAngle;
                angle_vector(vfTemp, ANGLEVECTOR_FORWARD, vfTemp);
                xs_vec_mul_scalar(vfTemp, fMaxDistance, vfTemp);
                fOriginDest[0] = fOrigin[0] + vfTemp[0];
                fOriginDest[1] = fOrigin[1] + vfTemp[1];
                fOriginDest[2] = fOrigin[2];
                LookAtOrigin(id, fOriginDest);
                MoveToOrigin(id, fOriginDest, fNPCspeed, fNPCJspeed, fVelocity);
            }
            else // no way to go ? lets turn ?? degrees.
            {
                xs_vec_set(vfTemp, 0.0, fNPCViewAngles[1] + 180.0, 0.0);
                angle_vector(vfTemp, ANGLEVECTOR_FORWARD, vfTemp);
                fOriginDest[0] = fOrigin[0] + vfTemp[0];
                fOriginDest[1] = fOrigin[1] + vfTemp[1];
                LookAtOrigin(id, fOriginDest);
            }

            NPC_animation(id, g_animArrays, g_sizeAnimArrays);
            set_pev(id, pev_nextthink, fGtime + NPC_THINK_LEN);

            switch( random(100) )
            {
                case 1..90: set_pev(id, PEV_TASK, iTask);
            }
        }
        default:
        {
            static any:xArray[ANIMATION_DATA], szModel[64], f, iSeq;

            f = RetrieveNPCAnimeTaskPointer(iTask);

            if(f == Invalid_Task)
            {
                iSeq = pev(id, pev_sequence);
            }
            else if(f > -1)
            {
                iSeq = lookup_sequence(id, g_aNPC_Tasks[ f ][ANIME_TASK_NAME]);
            }

            pev(id, pev_model, szModel, charsmax(szModel));
            getSequenceData(szModel, iSeq, xArray);
            PlayAnimation(id, xArray[ANIMATION_SEQUENCE],
                xArray[ANIMATION_FPS], 1.0, xArray[ANIMATION_FRAMES], iTask,
                .bInLOOP=false,
                .pArrayEvent=Array:xArray[ANIMATION_EVENT_ARRAY],
                .pArrayEventSize=xArray[ANIMATION_EVENTS]);

            set_pev(id, pev_nextthink, fGtime + ( (xArray[ANIMATION_FRAMES] + (g_aNPC_Tasks[ f ][ANIME_TASK_LENGTH] * xArray[ANIMATION_FPS])) / xArray[ANIMATION_FPS]) + ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS], 1.0) ));
        }
    }
}
