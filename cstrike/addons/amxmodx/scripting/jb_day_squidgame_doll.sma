/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <xs>
#include <jailbreak_core>
#include <soundinfo>

#define PLUGIN  "[JB] Squid Games [doll]"
#define AUTHOR  "Natsheh"

#define DOLL_POV 180.0
#define DOLL_RED_LIGHT_LEN 5.0
#define ATTN_LOW 0.10

#define PEV_IDENTITY pev_iuser4
#define PEV_ANIM_TASK pev_iuser1
#define PEV_ANIMATION_COOLDOWN pev_fuser2
#define PEV_PHASE pev_iuser2
#define PEV_DOLL_RED_LIGHT_DURATION pev_fuser3
#define PEV_DOLL_TURN_FRAMERATE pev_fuser4
#define PEV_LEVEL_SPEED pev_iuser3

#define DOLL_MAX_SPEED 1250
#define DOLL_MINIMUM_SPEED 75
#define DOLL_DEFAULT_ACCELERATION 50
#define DOLL_ID 909069

native jb_get_commander();
native register_jailbreak_cmitem(const itemname[]);
native unregister_jailbreak_cmitem(const item_index);

forward jb_cmenu_item_postselect(id, item);

new const DOLL_CUSTOM_CLASSNAME[] = "squidgames_doll";
new const DOLL_CLASSNAME[] = "info_target";
new const g_szDollModel[] = "models/jailbreak/squidgames_doll.mdl";
new const g_szDOLLPreparationSound[] = "jailbreak/squidgames_doll.wav";

enum _:ANIMATION_DATA (+=1)
{
    ANIMATION_NAME[32] = 0,
    ANIMATION_SEQUENCE,
    ANIMATION_FRAMES,
    Float:ANIMATION_FPS,
    ANIMATION_FLAGS,
    ANIMATION_ACTION,
    ANIMATION_ACTION_WEIGHT,
    ANIMATION_EVENTS,
    ANIMATION_EVENT_ID,
    ANIMATION_EVENT_ARRAY
}

enum _:ANIMATION_EVENTS (+=1)
{
    EVENT_FRAMES,
    EVENT_NUMBER,
    EVENT_TYPE,
    EVENT_OPTION[64]
}

enum any:ANIME_DOLL(+=1)
{
    ANIME_RED_LIGHT = 0,
    ANIME_GREEN_LIGHT_PREP,
    ANIME_GREEN_LIGHT,
    ANIME_RED_LIGHT_PREP
}

enum 
{
    PHASE_DEACTIVATED,
    PHASE_GREEN_LIGHT,
    PHASE_GREEN_LIGHT_PREP,
    PHASE_RED_LIGHT,
    PHASE_RED_LIGHT_PREP
}

new g_iPlayers[32], g_iPlayersNum, g_iLaserBeam_Spr, g_iJBWardenMenuItem = INVALID_HANDLE, g_aSoundFData[SParam],
    g_iDollAcceleration = DOLL_DEFAULT_ACCELERATION, g_user_doll[MAX_PLAYERS+1];

// LANG KEYS :-
    new const LANG_KEY_CREATE_DOLL[] = "CM_ITEM_CREATE_DOLL";
    new const LANG_KEY_REMOVE_DOLL[] = "CM_ITEM_REMOVE_DOLL";

public plugin_precache()
{
    g_iLaserBeam_Spr = precache_model("sprites/laserbeam.spr");
    precache_model(g_szDollModel);
    precache_sound(g_szDOLLPreparationSound);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    register_think(DOLL_CUSTOM_CLASSNAME, "doll_think");
    RegisterHam(Ham_Use, DOLL_CLASSNAME, "doll_use_post", .Post = true);

    AddTranslation("en", CreateLangKey(LANG_KEY_CREATE_DOLL), "Create the SQUIDGAME DOLL!");
    AddTranslation("en", CreateLangKey(LANG_KEY_REMOVE_DOLL), "Remove the SQUIDGAME DOLL!");
    g_iJBWardenMenuItem = register_jailbreak_cmitem(LANG_KEY_CREATE_DOLL);

    new szFile[ MAX_RESOURCE_PATH_LENGTH ];
    formatex(szFile, charsmax(szFile), "sound/%s", g_szDOLLPreparationSound);

    if(sfile_loaddata(szFile, g_aSoundFData) != SRES_OK)
    {
        server_print("Error sound ('%s') file is courrpted!", g_szDOLLPreparationSound);
        log_amx("Error sound ('%s') file is courrpted!", g_szDOLLPreparationSound);
    }

    register_clcmd("doll_acceleration", "clcmd_doll_acceleration");

    register_jailbreak_logmessages("LR_Activated", "Last request is activated!");
}

public jb_day_started(iDayid)
{
    remove_dolls();
}

public LR_Activated(const log[])
{
    remove_dolls();
}

remove_dolls()
{
    new ent = -1;
    while ( (ent=find_ent_by_class(ent, DOLL_CUSTOM_CLASSNAME)) > 0 )
    {
        set_pev(ent, pev_flags, FL_KILLME);
        dllfunc(DLLFunc_Think, ent);
    }

    if( g_iJBWardenMenuItem != INVALID_HANDLE )
    {
        unregister_jailbreak_cmitem(g_iJBWardenMenuItem);
        g_iJBWardenMenuItem = register_jailbreak_cmitem(LANG_KEY_CREATE_DOLL);
    }
}

public clcmd_doll_acceleration(id)
{
    if(jb_get_commander() != id)
    {
        return PLUGIN_HANDLED;
    }

    new doll = g_user_doll[id];

    if(!pev_valid(doll))
    {
        return PLUGIN_HANDLED;
    }

    new szClassname[24];
    pev(doll, pev_classname, szClassname, charsmax(szClassname));

    if(!equal(szClassname, DOLL_CUSTOM_CLASSNAME))
    {
        return PLUGIN_HANDLED;
    }

    new szArgs[10];
    read_args(szArgs, charsmax(szArgs));
    remove_quotes(szArgs);

    g_iDollAcceleration = max( str_to_num(szArgs), 000 );
    doll_control_menu(id, doll);
    return PLUGIN_HANDLED;
}

public doll_use_post(id, caller, activator, use_type, Float:value)
{
    if(pev(id, PEV_IDENTITY) != DOLL_ID)
    {
        return HAM_IGNORED;
    }

    doll_control_menu(caller, id);
    return HAM_IGNORED;
}

public doll_objectcaps_pre(id)
{
    if(pev(id, PEV_IDENTITY) != DOLL_ID)
    {
        return HAM_IGNORED;
    }

    SetHamReturnInteger(FCAP_IMPULSE_USE);
    return HAM_OVERRIDE;
}

doll_control_menu(id, doll)
{
    if(jb_get_commander() != id)
    {
        return;
    }

    new szText[128], szName[32], Float:fHealth;
    pev(doll, pev_netname, szName, charsmax(szName));
    pev(doll, pev_health, fHealth);
    formatex(szText, charsmax(szText), "\yStatus \r'%s' ^n \wHealth: \r%.2f ^n Speed: %d", szName, fHealth, pev(doll, PEV_LEVEL_SPEED));
    new menu = menu_create(szText, "dollcontrol_m_handle");

    new szInfo[5];
    num_to_str(doll, szInfo, charsmax(szInfo));

    switch( pev(doll, PEV_PHASE) )
    {
        case PHASE_DEACTIVATED: menu_additem(menu, "Activate the doll!", szInfo, 0);
        default: menu_additem(menu, "Deactivate the doll!", szInfo, 0);
    }

    menu_additem(menu, "Increase the doll speed!", szInfo, 0);
    menu_additem(menu, "Decrease the doll speed!", szInfo, 0);

    formatex(szText, charsmax(szText), "Acceleration: \r%d units per sec squared!", g_iDollAcceleration);
    menu_additem(menu, szText, szInfo);

    menu_display(id, menu);
}

public dollcontrol_m_handle(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new null, sData[5];
    menu_item_getinfo(menu, item, null, sData, charsmax(sData), "", _, null);

    menu_destroy(menu);

    new doll = str_to_num(sData);

    if(!pev_valid(doll))
    {
        return PLUGIN_HANDLED;
    }

    new szClassname[24];
    pev(doll, pev_classname, szClassname, charsmax(szClassname));

    if(!equal(szClassname, DOLL_CUSTOM_CLASSNAME))
    {
        return PLUGIN_HANDLED;
    }

    if(jb_get_commander() != id)
    {
        return PLUGIN_HANDLED;
    }

    switch( item )
    {
        case 0:
        {
            switch( pev(doll, PEV_PHASE) )
            {
                case PHASE_DEACTIVATED: // Activating the doll...
                {
                    set_pev(doll, PEV_PHASE, PHASE_GREEN_LIGHT_PREP);
                    set_pev(doll, pev_nextthink, get_gametime() + 0.1 );
                }
                default: // Deactivating the doll...
                {
                    set_pev(doll, PEV_PHASE, PHASE_DEACTIVATED);
                    set_pev(doll, pev_nextthink, get_gametime() + 9999.0 );
                }
            }
        }
        case 1:
        {
            set_pev(doll, PEV_LEVEL_SPEED, min( pev(doll, PEV_LEVEL_SPEED) + g_iDollAcceleration, DOLL_MAX_SPEED));
            doll_control_menu(id, doll);
        }
        case 2:
        {
            set_pev(doll, PEV_LEVEL_SPEED, max( pev(doll, PEV_LEVEL_SPEED) - g_iDollAcceleration, DOLL_MINIMUM_SPEED));
            doll_control_menu(id, doll);
        }
        case 3:
        {
            g_user_doll[id] = doll;
            client_cmd(id, "messagemode doll_acceleration");
            doll_control_menu(id, doll);
        }
    }

    return PLUGIN_HANDLED;
}

public jb_cmenu_item_postselect(id, itemid)
{
    if(itemid == g_iJBWardenMenuItem)
    {
        if( g_iJBWardenMenuItem != INVALID_HANDLE )
        {
            if( find_ent_by_class(-1, DOLL_CUSTOM_CLASSNAME) )
            {
                remove_dolls();
            }
            else
            {
                static bool:bHookObjectCaps = false;

                if( !bHookObjectCaps )
                {
                    bHookObjectCaps = true;
                    RegisterHamFromEntity(Ham_ObjectCaps, spawndoll(id), "doll_objectcaps_pre");
                }
                else
                {
                    spawndoll(id);
                }

                unregister_jailbreak_cmitem(g_iJBWardenMenuItem);
                g_iJBWardenMenuItem = register_jailbreak_cmitem(LANG_KEY_REMOVE_DOLL);
            }
        }
    }
}

spawndoll(id)
{
    new Float:fOrigin[3], Float:fAngles[3], Float:fVelo[3];
    pev(id, pev_origin, fOrigin);
    pev(id, pev_v_angle, fAngles);
    fAngles[0] = fAngles[2] = 0.0;
    velocity_by_aim(id, 80, fVelo);
    fVelo[2] = 0.0;
    xs_vec_add(fOrigin, fVelo, fOrigin);

    return create_npc( "SQUID GAME DOLL", DOLL_CUSTOM_CLASSNAME, g_szDollModel, fOrigin, fAngles );
}

create_npc( const name[], const classname[], const szModel[], Float:fOrigin[3], Float:fAngles[3], const owner=0, Float:fHealth=9999.0 )
{
    new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, DOLL_CLASSNAME));

    if(!ent) return 0;

    set_pev(ent, pev_classname, classname);
    set_pev(ent, pev_netname, name);

    set_pev(ent, pev_max_health, fHealth);
    set_pev(ent, pev_health, fHealth);

    set_pev(ent, pev_takedamage, DAMAGE_YES);
    set_pev(ent, pev_solid, SOLID_SLIDEBOX);
    set_pev(ent, pev_owner, owner);
    set_pev(ent, pev_movetype, MOVETYPE_NONE);
    set_pev(ent, pev_gravity, 1.0);
    set_pev(ent, pev_angles, fAngles);
    set_pev(ent, pev_controller_0, 127);
    set_pev(ent, pev_flags, (FL_MONSTER|FL_ALWAYSTHINK|FL_MONSTERCLIP));
    set_pev(ent, PEV_DOLL_TURN_FRAMERATE, 1.0);
    set_pev(ent, PEV_LEVEL_SPEED, DOLL_MINIMUM_SPEED);
    set_pev(ent, PEV_IDENTITY, DOLL_ID);

    engfunc(EngFunc_SetModel, ent, szModel);

    engfunc(EngFunc_SetSize, ent, Float:{-16.0, -16.0, 0.0}, Float:{16.0, 16.0, 100.0});
    set_pev(ent, pev_view_ofs, Float:{ 0.0, 0.0, 85.0 } );

    engfunc(EngFunc_SetOrigin, ent, fOrigin);

    set_pev(ent, PEV_PHASE, PHASE_DEACTIVATED);
    set_pev(ent, pev_nextthink, get_gametime() + 1.0);

    return ent;
}

public doll_think( ent )
{
    switch( pev(ent, PEV_PHASE) )
    {
        case PHASE_DEACTIVATED:
        {

        }
        case PHASE_GREEN_LIGHT:
        {
            static xArray[ANIMATION_DATA], Float:fSNDLength, Float:fLength, Float:fSNDuration, Float:fFrameRate = 1.0, iPITCHByte;
            fSNDuration = get_duration(g_aSoundFData);
            fSNDLength = fLength = (100.0 / float( pev(ent, PEV_LEVEL_SPEED) )) * fSNDuration;
            fFrameRate = random_float(1.0, 2.0);
            set_pev(ent, PEV_DOLL_TURN_FRAMERATE, fFrameRate);

            getSequenceData(g_szDollModel, ANIME_RED_LIGHT_PREP, xArray);
            fSNDLength += ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS],1.0) ) / fFrameRate;

            if( fSNDuration <= 0.0 )
            {
                fSNDuration = 1.0;
            }

            PlayAnimation(ent, ANIME_GREEN_LIGHT, 1.0, _, 0.0, 0.0, true);

            iPITCHByte = clamp( floatround( 255.0 - (((fSNDLength / fSNDuration) * 155.0)) ), 0, 0xFF );

            // Play the sound.
            emit_sound(ent, CHAN_BODY, g_szDOLLPreparationSound, VOL_NORM, ATTN_LOW, 0, iPITCHByte);
            //client_cmd(0, "spk ^"%s(t%d)^"", g_szDOLLPreparationSound, floatround(100.0 - ((fSNDuration / fSNDLength) * 100.0)));

            set_pev(ent, PEV_PHASE, PHASE_RED_LIGHT_PREP);
            set_pev(ent, pev_nextthink, get_gametime() + fLength);
            return;
        }
        case PHASE_GREEN_LIGHT_PREP:
        {
            static xArray[ANIMATION_DATA], Float:fLength, Float:fFrameRate = 1.0;
            pev(ent, PEV_DOLL_TURN_FRAMERATE, fFrameRate);
            getSequenceData(g_szDollModel, ANIME_GREEN_LIGHT_PREP, xArray);
            fLength = ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS],1.0) ) / fFrameRate;
            PlayAnimation(ent, ANIME_GREEN_LIGHT_PREP, fFrameRate, _, 0.0, fLength, false);

            static DollSPEED;
            DollSPEED = pev(ent, PEV_LEVEL_SPEED);

            if( DollSPEED < DOLL_MAX_SPEED )
            {
                set_pev(ent, PEV_LEVEL_SPEED, min(DollSPEED + g_iDollAcceleration, DOLL_MAX_SPEED) );
            }

            set_pev(ent, PEV_PHASE, PHASE_GREEN_LIGHT);
            set_pev(ent, pev_nextthink, get_gametime() + fLength);
            return;
        }
        case PHASE_RED_LIGHT_PREP:
        {
            static xArray[ANIMATION_DATA], Float:fLength, Float:fFrameRate = 1.0, Float:fGametime;
            pev(ent, PEV_DOLL_TURN_FRAMERATE, fFrameRate);
            getSequenceData(g_szDollModel, ANIME_RED_LIGHT_PREP, xArray);
            fLength = ( xArray[ANIMATION_FRAMES] / floatmax(xArray[ANIMATION_FPS],1.0) ) / fFrameRate;
            PlayAnimation(ent, ANIME_RED_LIGHT_PREP, fFrameRate, _, 0.0, fLength, false);

            fGametime = get_gametime();
            set_pev(ent, PEV_PHASE, PHASE_RED_LIGHT);
            set_pev(ent, pev_nextthink, get_gametime() + fLength);
            set_pev(ent, PEV_DOLL_RED_LIGHT_DURATION, fGametime + fLength + DOLL_RED_LIGHT_LEN);
            return;
        }
        case PHASE_RED_LIGHT:
        {
            PlayAnimation(ent, ANIME_RED_LIGHT, 1.0, _, 0.0, 0.0, true);

            static Float:fOrigin[3], Float:fAngles[3], Float:fPOVEndSight[3];
            pev(ent, pev_origin, fOrigin);
            pev(ent, pev_angles, fAngles);

            // Adding the height of the doll :)
            fOrigin[2] += 128.0;

            get_players(g_iPlayers, g_iPlayersNum, "ah");
            for(new i, target; i < g_iPlayersNum; i++)
            {
                target = g_iPlayers[ i ];

                if(IsPlayerInFOV(fOrigin, fAngles, target, DOLL_POV))
                {
                    if(IsPlayerVisible(fOrigin, fPOVEndSight, target, ent))
                    {
                        if(IsPlayerMoving(target))
                        {
                            LaserBeam(fOrigin, fPOVEndSight, target, 1.0, ent, 125.0);
                        }
                    }
                }
            }

            if( pev(ent, PEV_DOLL_RED_LIGHT_DURATION) < get_gametime() )
            {
                set_pev(ent, PEV_DOLL_TURN_FRAMERATE, random_float(1.0, 2.0));
                set_pev(ent, PEV_PHASE, PHASE_GREEN_LIGHT_PREP);
            }
        }
    }

    set_pev(ent, pev_nextthink, get_gametime() + 0.1);
}

bool:IsPlayerMoving(id)
{
    static Float:fVelocity[3];
    pev(id, pev_velocity, fVelocity);

    return !xs_vec_equal(fVelocity, Float:{0.0, 0.0, 0.0});
}

bool:IsPlayerInFOV(Float:fPOV[3], Float:fAngles[3], const target, Float:fViewField=60.0)
{
    new Float:fOrigin[3], Float:fDiff[3], Float:fvNormal[3], Float:fDotProduct;
    pev(target, pev_origin, fOrigin);

    angle_vector(fAngles, ANGLEVECTOR_FORWARD, fvNormal);
    xs_vec_sub(fOrigin, fPOV, fDiff);
    xs_vec_normalize(fDiff, fDiff)

    if( (fDotProduct=xs_vec_dot(fDiff, fvNormal)) < 0.0 )
    {
        return false;
    }

    if(xs_rad2deg(xs_acos(fDotProduct, radian)) > fViewField)
    {
        return false;
    }
    return true;
}

bool:IsPlayerVisible(const Float:fPointView[3], Float:fPOVEndSight[3], const id, const ignore_ent)
{
    static const Float:fShiftVector[][3] = {
        { 0.0, 0.0, 0.0 },
        { 0.0, 0.0, 34.0 },
        { 0.0, 0.0, -34.0 },
        { 16.0, 0.0, 34.0 },
        { -16.0, 0.0, 34.0 },
        { 16.0, 0.0, -34.0 },
        { -16.0, 0.0, -34.0 }
    }

    new tr2 = create_tr2(), Float:fPOrigin[3], Float:fEndTrace[3], Float:fAngles[3], pHit;

    pev(id, pev_origin, fPOrigin);
    xs_vec_sub(fPOrigin, fPointView, fAngles);
    xs_vec_normalize(fAngles, fAngles);
    vector_to_angle(fAngles, fAngles);

    fAngles[0] = 0.0;

    const iMaxShifting = sizeof fShiftVector;

    for(new i; i < iMaxShifting; i++)
    {
        fEndTrace[0] = fPOrigin[0] + floatcos(fAngles[1],degrees) * fShiftVector[i][0];
        fEndTrace[1] = fPOrigin[1] + floatsin(fAngles[1],degrees) * fShiftVector[i][1];
        fEndTrace[2] = fPOrigin[2] + fShiftVector[i][2];

        engfunc(EngFunc_TraceLine, fPointView, fEndTrace, DONT_IGNORE_MONSTERS, ignore_ent, tr2);

        pHit = get_tr2(tr2, TR_pHit);

        if(pHit == id)
        {
            fPOVEndSight[0] = fEndTrace[0];
            fPOVEndSight[1] = fEndTrace[1];
            fPOVEndSight[2] = fEndTrace[2];
            break;
        }
    }

    free_tr2(tr2);

    return bool:(pHit == id);
}

LaserBeam(const Float:fStart[3], Float:fEnd[3], const target, Float:fLength, Inflictor, Float:fDamage)
{
    engfunc(EngFunc_MessageBegin, MSG_BROADCAST, SVC_TEMPENTITY, Float:{0.0,0.0,0.0}, 0);
    write_byte(TE_BEAMPOINTS)
    engfunc(EngFunc_WriteCoord, fStart[ 0]);
    engfunc(EngFunc_WriteCoord, fStart[ 1]);
    engfunc(EngFunc_WriteCoord, fStart[ 2]);
    engfunc(EngFunc_WriteCoord, fEnd[ 0]);
    engfunc(EngFunc_WriteCoord, fEnd[ 1]);
    engfunc(EngFunc_WriteCoord, fEnd[ 2]);
    write_short(g_iLaserBeam_Spr)
    write_byte(0)
    write_byte(10)
    write_byte(min(floatround(fLength * 10.0), 0xFF))
    write_byte(50);
    write_byte(0);
    write_byte(225);
    write_byte(0);
    write_byte(0);
    write_byte(255);
    write_byte(10);
    message_end();

    ExecuteHamB(Ham_TakeDamage, target, Inflictor, Inflictor, fDamage, DMG_BURN|DMG_ENERGYBEAM);
}

PlayAnimation(const id, const iSeq=0, const Float:fFrameRate=1.0, const ACT_TYPE=-1, const Float:fDelay=0.0, const Float:anim_length=0.0, bool:bInLOOP=false)
{
    static Float:fAnimLength, Float:fGametime;
    pev(id, PEV_ANIMATION_COOLDOWN, fAnimLength);
    fGametime = get_gametime();

    if(pev(id, PEV_ANIM_TASK) == ACT_TYPE && fAnimLength > fGametime) return;

    if(pev(id, PEV_ANIM_TASK) != ACT_TYPE || ACT_TYPE == -1 || !bInLOOP)
    {
        set_pev(id, pev_sequence, iSeq);
        set_pev(id, pev_gaitsequence, iSeq);
        set_pev(id, pev_animtime, fGametime + fDelay);
        set_pev(id, pev_framerate, fFrameRate);

        set_pev(id, PEV_ANIMATION_COOLDOWN, fGametime + anim_length);
        set_pev(id, PEV_ANIM_TASK, ACT_TYPE);
    }
}

getSequenceData( const model[], const sequence, any:xArray[ANIMATION_DATA] )
{
    static sequencesNameCached;
    static sequenceCount;
    static Array:arraySequencesName;

    if( !sequencesNameCached )
    {
        new f = fopen( model, "rb" );

        if( f )
        {
            const studioHeader_NumSeq = 164;
            const mstudioseqdescSize  = 176;
            const sequenceNameLength  = 32;

            new sequenceIndex, tempArray[ANIMATION_DATA], EventArray[ANIMATION_EVENTS];

            fseek( f, studioHeader_NumSeq, SEEK_SET );
            {
                fread( f, sequenceCount, BLOCK_INT );
                fread( f, sequenceIndex, BLOCK_INT );
            }
            fseek( f, sequenceIndex, SEEK_SET );

            arraySequencesName = ArrayCreate( ANIMATION_DATA, sequenceCount );

            for( new i = 0, j, numframes, fileLine, Float:fps, seqflags, iActivity, iACTweight, numEvents, EventIndex; i < sequenceCount; i++ )
            {
                fread_blocks( f, tempArray[ANIMATION_NAME], sequenceNameLength, BLOCK_CHAR );

                fread(f, _:fps            , BLOCK_INT);
                fread(f, seqflags         , BLOCK_INT);
                fread(f, iActivity        , BLOCK_INT);
                fread(f, iACTweight       , BLOCK_INT);
                fread(f, numEvents        , BLOCK_INT);
                fread(f, EventIndex       , BLOCK_INT);
                fread(f, numframes        , BLOCK_INT);

                tempArray[ANIMATION_FRAMES] = numframes;
                tempArray[ANIMATION_FPS] = floatmax(fps,1.0);
                tempArray[ANIMATION_FLAGS] = seqflags;
                tempArray[ANIMATION_ACTION] = iActivity;
                tempArray[ANIMATION_ACTION_WEIGHT] = iActivity;
                tempArray[ANIMATION_EVENTS] = numEvents;
                tempArray[ANIMATION_EVENT_ID] = EventIndex;
                tempArray[ANIMATION_EVENT_ARRAY] = _:Invalid_Array;

                if( numEvents )
                {
                    fileLine = ftell(f);

                    fseek( f, EventIndex, SEEK_SET );
                    tempArray[ANIMATION_EVENT_ARRAY] = _:ArrayCreate(ANIMATION_EVENTS, 1);

                    for( j = 0; j < numEvents; j++ )
                    {
                        fread(f, EventArray[EVENT_FRAMES]      , BLOCK_INT);
                        fread(f, EventArray[EVENT_NUMBER]      , BLOCK_INT);
                        fread(f, EventArray[EVENT_TYPE]        , BLOCK_INT);
                        fread_blocks(f, EventArray[EVENT_OPTION], sequenceNameLength * 2, BLOCK_CHAR );

                        //log_to_file("test_read2.txt", "Seq #%d Event #%d EVENT FRAMES: %d EVENT NUM: %d EVENT TYPE: %d EVENT EVENT_OPTION: %s", i, j, EventArray[EVENT_FRAMES], EventArray[EVENT_NUMBER], EventArray[EVENT_TYPE], EventArray[EVENT_OPTION]);
                        ArrayPushArray( Array:tempArray[ANIMATION_EVENT_ARRAY], EventArray );
                    }

                    fseek(f, fileLine + (mstudioseqdescSize - 60), SEEK_SET );
                }
                else
                {
                    fseek(f, mstudioseqdescSize - 60, SEEK_CUR );
                }

                tempArray[ANIMATION_SEQUENCE] = i;
                //log_to_file("test_read.txt", "AnimName: %s Sequence: %d/%d Frames: %d FPS: %.2f ACTION: %d EVENTS: %d", tempArray[ANIMATION_NAME], i, sequenceCount, numframes, fps, iActivity, numEvents);
                ArrayPushArray( arraySequencesName, tempArray );
            }



            fclose( f );

            if( !( sequencesNameCached = !!ArraySize( arraySequencesName ) ) )
            {
                ArrayDestroy( arraySequencesName );
                return 0;
            }
        }
    }

    if( sequencesNameCached && 0 <= sequence < sequenceCount )
    {
        ArrayGetArray(arraySequencesName, sequence, _:xArray)
        return 1;
    }

    return 0;
}
