#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
#include <fun>
#include <xs>

#define PLUGIN  "ADMIN GRAB"
#define VERSION "1.2"
#define AUTHOR  "Natsheh"

#if !defined MAX_PLAYERS
#define MAX_PLAYERS 32
#endif

#define IsPlayer(%1)    ( 1 <= %1 <= MAX_PLAYERS )
#define EntityExists(%1) ((IsPlayer(%1) && is_user_alive(%1)) || pev_valid(%1))

///////////////////////////
#define IsBrushEntity(%1,%2) \
pev(%1, pev_model, %2, 1);\
if(%2[0] == '*')
///////////////////////////
#define IsClonedEntity(%1,%2) \
pev(%1, pev_netname, %2, charsmax(%2));\
if(equal(%2, "CLONED_ENTITY"))
///////////////////////////
#define IsPointEntity(%1,%2) \
pev(%1, pev_model, %2, charsmax(%2));\
if(pev_valid(%1) && !IsPlayer(%1) && (%2[0] != '*'))
///////////////////////////

#define ADMIN_ACCESS ADMIN_IMMUNITY
#define TOGGLE_ACTIVATION_LENGTH    2.5
#define MAX_GRABBED_OBJECTS 16
#define MAX_SELECTED_OBJECTS 16
#define GRAB_KEY_PUSH IN_ATTACK
#define GRAB_KEY_PULL IN_ATTACK2
#define OBJECTS_DESELECTION_INTERVAL 0.5

enum any:RENDERING_DATA(+=1)
{
    RENDER_MODE,
    RENDER_FX,
    Float:RENDER_COLOR[3],
    Float:RENDER_AMOUNT
}

enum any:TARGET_PROPERTIES(+=1)
{
    TARGET_ID,
    TARGET_SLOT
}

enum any:ENTITY_TYPES(+=1)
{
    ENTITY_TYPE_PLAYER = 0,
    ENTITY_TYPE_BRUSHENTITY,
    ENTITY_TYPE_POINTENTITY,
    ENTITY_TYPE_CLONES,
    ENTITY_MAX_TYPES
}

new const g_szEntityTypes[][] = {
    "Player",
    "World Brush",
    "Point Entity",
    "Cloned Entity"
}

enum any:GRAB_MENU_PROPS(+=1)
{
    GRAB_MENU_ID,
    ENTITY_TYPES:GRAB_MENU_TYPE
}

new g_user_target[MAX_PLAYERS+1][MAX_SELECTED_OBJECTS][TARGET_PROPERTIES],
    g_iGrabbedObjectsCount[MAX_PLAYERS+1],
    g_user_grabber[MAX_PLAYERS+1],
    Float:g_fuser_grabdistance[MAX_PLAYERS+1][MAX_GRABBED_OBJECTS],
      bool:g_bUser_grab_access[MAX_PLAYERS+1],
      Float:g_fUser_inuse_lasttime[MAX_PLAYERS+1] = {-1.0, -1.0, ... },
      g_pcvar_grab_force, g_pcvar_throw_force,
      g_iPlayerGrabMenuProps[MAX_PLAYERS+1][GRAB_MENU_PROPS], bool:g_bUser_grab_authorized[MAX_PLAYERS+1],
    g_iTargetRenderData[MAX_PLAYERS+1][MAX_SELECTED_OBJECTS][RENDERING_DATA],
    g_iSelectedObjects[MAX_PLAYERS+1][MAX_SELECTED_OBJECTS], g_iSelectedObjectsCount[MAX_PLAYERS+1],
    g_iReloadKeyPressedCount[MAX_PLAYERS+1], Float:g_fReloadKeyFirstTimePressed[MAX_PLAYERS+1];

new Float:g_fTargetMaxs[MAX_PLAYERS+1][MAX_SELECTED_OBJECTS][3],
 Float:g_fTargetMins[MAX_PLAYERS+1][MAX_SELECTED_OBJECTS][3],
 g_iOldMoveType[MAX_PLAYERS+1][MAX_SELECTED_OBJECTS],
 g_iOldSolidType[MAX_PLAYERS+1][MAX_SELECTED_OBJECTS],
 Float:g_fVecShift[MAX_PLAYERS+1][MAX_GRABBED_OBJECTS][3];

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    register_forward(FM_CmdStart, "fw_cmdstart_post", true);
    register_impulse(100, "hook_flashlight");
    RegisterHam(Ham_Killed, "player", "fw_player_killed_post", true);
    register_clcmd("drop", "clcmd_drop");
    register_clcmd("set_entity_speed", "clcmd_set_vehicle_props");
    register_clcmd("set_entity_acceleration", "clcmd_set_vehicle_props");
    register_concmd("amx_authorize_grab", "concmd_auth_grab", ADMIN_IMMUNITY);
    register_concmd("amx_strip_grab", "concmd_strip_grab", ADMIN_IMMUNITY);

    register_cvar("ADMIN_GRAB_V", VERSION, .flags = FCVAR_SERVER);
    g_pcvar_grab_force = register_cvar("agrab_grabforce", "4");
    g_pcvar_throw_force = register_cvar("agrab_throwforce", "2000");

    SaveBrushEntitiesSpawnLocation();
}

SaveBrushEntitiesSpawnLocation()
{
    new Float:fOrigin[3], i = MAX_PLAYERS, szModel[2], MaxEntities = global_get(glb_maxEntities);
    while(++i <= MaxEntities)
    {
        if(pev_valid(i))
        {
            IsBrushEntity(i,szModel)
            {
                pev(i, pev_origin, fOrigin);
                set_pev(i, pev_oldorigin, fOrigin);
            }
        }
    }
}

public clcmd_set_vehicle_props(id, level, cid)
{
    if(g_iPlayerGrabMenuProps[id][GRAB_MENU_ID] == -1)
    {
        return PLUGIN_HANDLED;
    }

    new szValue[10];
    read_args(szValue, charsmax(szValue));
    remove_quotes(szValue);

    if(!is_str_num(szValue))
    {
        client_print(id, print_center, "Enter only digits!");
        client_cmd(id, "messagemode set_entity_speed");
        return PLUGIN_HANDLED;
    }

    new iTarget, aTargets[MAX_GRABBED_OBJECTS][TARGET_PROPERTIES], aTargetsCount = 0, GrabbedObjectsCount = g_iGrabbedObjectsCount[id], any:iEntityType = g_iPlayerGrabMenuProps[id][GRAB_MENU_TYPE];
    for(new i, szName[32]; i < GrabbedObjectsCount; i++)
    {
        iTarget = g_user_target[id][i][TARGET_ID];

        if(!pev_valid(iTarget)) continue;

        switch(iEntityType)
        {
            case ENTITY_TYPE_BRUSHENTITY:
            {
                IsBrushEntity(iTarget,szName)
                {
                    aTargets[aTargetsCount][TARGET_SLOT] = g_user_target[id][i][TARGET_SLOT];
                    aTargets[aTargetsCount++][TARGET_ID] = iTarget;
                }
            }
            case ENTITY_TYPE_CLONES:
            {
                IsClonedEntity(iTarget,szName)
                {
                    aTargets[aTargetsCount][TARGET_SLOT] = g_user_target[id][i][TARGET_SLOT];
                    aTargets[aTargetsCount++][TARGET_ID] = iTarget;
                }
            }
        }
    }

    new szCommand[16];
    read_argv(0, szCommand, charsmax(szCommand));

    for(new i; i < aTargetsCount; i++)
    {
        iTarget = aTargets[i][TARGET_ID];

        switch( szCommand[11] )
        {
            case 's':
            {
                set_ent_data_float(iTarget, "CFuncVehicle", "m_speed", floatstr(szValue));
                set_pev(iTarget, pev_speed, floatstr(szValue));
            }
            case 'a':
            {
                set_ent_data(iTarget, "CFuncVehicle", "m_acceleration", str_to_num(szValue));
            }
        }
    }

    hook_flashlight(id);
    return PLUGIN_HANDLED;

}

public concmd_strip_grab(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    new szArg[32], players[MAX_PLAYERS], pnum;
    read_argv(1, szArg, charsmax(szArg));
    remove_quotes(szArg);

    if(szArg[0] == '@')
    {
        switch( szArg[1] )
        {
            case 'C', 'c': get_players(players, pnum, "che", "CT");
            case 'T', 't': get_players(players, pnum, "che", "TERRORIST");
            case 'S', 's': get_players(players, pnum, "che", "SPECTATOR");
            case 'A', 'a': get_players(players, pnum, "ch");
            default:
            {
                console_cmd(id, "Team / group is undefined!");
                return PLUGIN_HANDLED;
            }
        }
    }
    else
    {
        pnum = 1;
        players[ 0 ] = cmd_target(id, szArg, .flags = CMDTARGET_NO_BOTS);

        if( !players[ 0 ] )
        {
            return PLUGIN_HANDLED;
        }
    }

    for(new i, player; i < pnum; i++)
    {
        player = players[ i ];
        g_bUser_grab_authorized[ player ] = false;
        g_bUser_grab_access[ player ] = false;

        if(g_iGrabbedObjectsCount[player] > 0)
        {
            set_released(player, g_user_target[ player ], g_iGrabbedObjectsCount[ player ]);
        }

        if(g_iSelectedObjectsCount[player] > 0)
        {
            while( g_iSelectedObjectsCount[player] > 0 )
            {
                DeselectEntity(player, g_iSelectedObjects[player][0]);
            }
        }

        client_print(player, print_center, "Grabbing ability was Disabled!");
    }

    console_print(id, "Command was success!");
    return PLUGIN_HANDLED;
}

public concmd_auth_grab(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    new szArg[32], players[MAX_PLAYERS], pnum;
    read_argv(1, szArg, charsmax(szArg));
    remove_quotes(szArg);

    if(szArg[0] == '@')
    {
        switch( szArg[1] )
        {
            case 'C', 'c': get_players(players, pnum, "che", "CT");
            case 'T', 't': get_players(players, pnum, "che", "TERRORIST");
            case 'S', 's': get_players(players, pnum, "che", "SPECTATOR");
            case 'A', 'a': get_players(players, pnum, "ch");
            default:
            {
                console_cmd(id, "Team / group is undefined!");
                return PLUGIN_HANDLED;
            }
        }
    }
    else
    {
        pnum = 1;
        players[ 0 ] = cmd_target(id, szArg, .flags = CMDTARGET_NO_BOTS);

        if( !players[ 0 ] )
        {
            return PLUGIN_HANDLED;
        }
    }

    for(new i; i < pnum; i++)
    {
        g_bUser_grab_authorized[ players[ i ] ] = true;
    }

    console_print(id, "Command was success!");
    return PLUGIN_HANDLED;
}

#if AMXX_VERSION_NUM > 182
public client_disconnected(id)
#else
public client_disconnect(id)
#endif
{
    if(g_iGrabbedObjectsCount[id] > 0)
    {
        set_released(id, g_user_target[id], g_iSelectedObjectsCount[id]);
    }

    if(g_iSelectedObjectsCount[id] > 0)
    {
        for(new i, Count = g_iSelectedObjectsCount[id]; i < Count; i++)
        {
            DeselectEntity(id, g_iSelectedObjects[id][0]);
        }
    }

    if(g_user_grabber[id] > 0)
    {
        new aTargets[MAX_GRABBED_OBJECTS][TARGET_PROPERTIES];
        aTargets[0][TARGET_ID] = id;
        GetEntityGrabber(id, aTargets[0][TARGET_SLOT]);
        set_released(g_user_grabber[ id ], aTargets, 1);
    }

    g_iPlayerGrabMenuProps[id][GRAB_MENU_ID] = -1;
    g_bUser_grab_access[id] = g_bUser_grab_authorized[id] = false;
    g_fUser_inuse_lasttime[id] = -1.0;
    remove_task(id);
}

public clcmd_drop(id)
{
    if(g_iGrabbedObjectsCount[id] > 0)
    {
        g_bUser_grab_access[id] = false;

        new aTargets[MAX_GRABBED_OBJECTS], GrabbedObjectsCount = g_iGrabbedObjectsCount[id];

        for(new i; i < GrabbedObjectsCount; i++)
        {
            aTargets[i] = g_user_target[id][i][TARGET_ID];
        }

        set_released(id, g_user_target[id], g_iGrabbedObjectsCount[id]);

        new Float:fVec[3];
        pev(id, pev_v_angle, fVec);
        angle_vector(fVec, ANGLEVECTOR_FORWARD, fVec);

        xs_vec_mul_scalar(fVec, get_pcvar_float(g_pcvar_throw_force), fVec);
        for(new j; j < GrabbedObjectsCount; j++) set_pev(aTargets[j], pev_velocity, fVec);
        client_print(id, print_center, "You've thrown your victim!");

        set_task(0.5, "task_throwing_done", id);
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public task_throwing_done(id)
{
    g_bUser_grab_access[id] = true;
}

public fw_player_killed_post(victim)
{
    new pSelector = GetEntitySelector(victim);

    if(pSelector > 0)
    {
        DeselectEntity(pSelector, victim);
    }

    if(g_user_grabber[ victim ] > 0)
    {
        new aTargets[MAX_GRABBED_OBJECTS][TARGET_PROPERTIES], Grabber = g_user_grabber[ victim ];
        aTargets[0][TARGET_ID] = victim;
        GetEntityGrabber(victim, aTargets[0][TARGET_SLOT]);
        set_released(Grabber, aTargets, 1);
    }
}

public hook_flashlight(id)
{
    new GrabbedObjectsCount = g_iGrabbedObjectsCount[id];

    if(!GrabbedObjectsCount)
    {
        return PLUGIN_CONTINUE;
    }

    new szText[96], szName[32], menu, bool:bMenuTypeSatisfied = false, ExistedTypes, any:MenuType = g_iPlayerGrabMenuProps[id][GRAB_MENU_TYPE];

    for(new i, target; i < GrabbedObjectsCount; i++)
    {
        target = g_user_target[id][i][TARGET_ID];

        if(IsPlayer(target))
        {
            ExistedTypes |= (1<<ENTITY_TYPE_PLAYER);
        }

        IsBrushEntity(target,szName)
        {
            ExistedTypes |= (1<<ENTITY_TYPE_BRUSHENTITY);
        }

        IsPointEntity(target,szName)
        {
            ExistedTypes |= (1<<ENTITY_TYPE_POINTENTITY);
        }
        else
        {
            IsClonedEntity(target,szName)
            {
                ExistedTypes |= (1<<ENTITY_TYPE_CLONES);
            }
        }

        switch( MenuType )
        {
            case ENTITY_TYPE_PLAYER:
            {
                if(IsPlayer(target))
                {
                    bMenuTypeSatisfied = true;
                }
            }
            case ENTITY_TYPE_BRUSHENTITY:
            {
                IsBrushEntity(target,szName)
                {
                    bMenuTypeSatisfied = true;
                }
            }
            case ENTITY_TYPE_POINTENTITY:
            {
                IsPointEntity(target,szName)
                {
                    bMenuTypeSatisfied = true;
                }

            }
            case ENTITY_TYPE_CLONES:
            {
                IsClonedEntity(target,szName)
                {
                    bMenuTypeSatisfied = true;
                }
            }
        }
    }

    new MaxAvailableTypes;
    for(new any:i; i < ENTITY_MAX_TYPES; i++)
    {
        if(ExistedTypes & (1<<i))
        {
            MaxAvailableTypes++;
        }
    }

    if(!bMenuTypeSatisfied)
    {
        for(new any:i; i < ENTITY_MAX_TYPES; i++)
        {
            MenuType = ++MenuType % ENTITY_MAX_TYPES;

            if(ExistedTypes & (1<<MenuType))
            {
                break;
            }
        }

        g_iPlayerGrabMenuProps[id][GRAB_MENU_TYPE] = MenuType;
    }

    if(!MaxAvailableTypes)
    {
        return PLUGIN_CONTINUE;
    }

    if(MenuType == ENTITY_TYPE_PLAYER)
    {
        if(GrabbedObjectsCount == 1)
        {
            new iTarget = g_user_target[id][0][TARGET_ID];
            get_user_name(iTarget, szName, charsmax(szName));

            formatex(szText, charsmax(szText), "ADMIN GRAB ^n \ytarget: \w[#%d] \r%s", iTarget, szName);
        }
        else
        {
            formatex(szText, charsmax(szText), "ADMIN GRAB ^n \yObjects Count: \r%d", GrabbedObjectsCount);
        }

        menu = menu_create(szText, "agrab_mhandler");

        const NO_ACCESS = (1<<26);
        formatex(szText, charsmax(szText), "\yEdit: \r%s^n", g_szEntityTypes[MenuType]);
        menu_additem(menu, szText, .paccess = (MaxAvailableTypes <= 1) ? NO_ACCESS:0);

        menu_additem(menu, "Heal player");

        menu_additem(menu, "\wSet \yplayer godmode!");
        menu_additem(menu, "\rRemove \yplayer godmode!");

        menu_additem(menu, "\rSet \yplayer nocliping");
        menu_additem(menu, "\wSet \yplayer clipping");

        menu_additem(menu, "\rFreeze \yplayer");
        menu_additem(menu, "\wUnfreeze \yplayer");
    }
    else if(MenuType == ENTITY_TYPE_BRUSHENTITY || MenuType == ENTITY_TYPE_POINTENTITY || MenuType == ENTITY_TYPE_CLONES)
    {
        new iTarget, bool:bBrush = false;

        IsBrushEntity(iTarget,szName)
        {
            bBrush = true;
        }

        if(GrabbedObjectsCount == 1)
        {
            iTarget = g_user_target[id][0][TARGET_ID];
            // szName here's the classname of an entity.
            pev(iTarget, pev_classname, szName, charsmax(szName));

            formatex(szText, charsmax(szText), "ADMIN GRAB ^n \r[\yWorldBrush: \r%s\w] \rtarget: \w[#%d] \r%s", bBrush ? "YES":"NO", iTarget, szName);
        }
        else
        {
            formatex(szText, charsmax(szText), "ADMIN GRAB ^n \yObjects Count: \r%d", GrabbedObjectsCount);
        }

        menu = menu_create(szText, "agrab_mhandler");

        formatex(szText, charsmax(szText), "\yEdit: \r%s^n", g_szEntityTypes[MenuType]);
        menu_additem(menu, szText);

        const NO_ACCESS = (1<<26);
        menu_additem(menu,"\rReset Object Origin", .paccess = (MenuType == ENTITY_TYPE_BRUSHENTITY) ? 0 : NO_ACCESS);

        menu_additem(menu, "\wRotate the object around Z Axis");
        menu_additem(menu, "\wRotate the object around X Axis");
        menu_additem(menu, "\wRotate the object around Y Axis^n");

        menu_additem(menu, "\wClone the object^n");

        menu_additem(menu, "\rRemove the object", .paccess = (MenuType == ENTITY_TYPE_CLONES) ? 0 : NO_ACCESS);

        if(GrabbedObjectsCount == 1)
        {
            if(equal(szName, "func_vehicle"))
            {
                formatex(szText, charsmax(szText), "\ySpeed: \r%.2f", get_ent_data_float(iTarget, "CFuncVehicle", "m_speed"));
                menu_additem(menu, szText);

                formatex(szText, charsmax(szText), "\yAcceleration: \r%d", get_ent_data(iTarget, "CFuncVehicle", "m_acceleration"));
                menu_additem(menu, szText);
            }
        }
    }

    if(!menu_display(id, menu))
    {
        menu_destroy(menu);
    }
    else
    {
        g_iPlayerGrabMenuProps[id][GRAB_MENU_ID] = menu;
    }

    return PLUGIN_HANDLED;
}

public agrab_mhandler(id, menu, item)
{
    if(!g_iGrabbedObjectsCount[id])
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new any:iEntityType = g_iPlayerGrabMenuProps[id][GRAB_MENU_TYPE];

    new iTarget, aTargets[MAX_GRABBED_OBJECTS][TARGET_PROPERTIES], aTargetsCount = 0, GrabbedObjectsCount = g_iGrabbedObjectsCount[id];
    for(new i, szName[32]; i < GrabbedObjectsCount; i++)
    {
        iTarget = g_user_target[id][i][TARGET_ID];

        if(!pev_valid(iTarget)) continue;

        switch(iEntityType)
        {
            case ENTITY_TYPE_PLAYER:
            {
                if(IsPlayer(iTarget))
                {
                    aTargets[aTargetsCount][TARGET_SLOT] = g_user_target[id][i][TARGET_SLOT];
                    aTargets[aTargetsCount++][TARGET_ID] = iTarget;
                }
            }
            case ENTITY_TYPE_BRUSHENTITY:
            {
                IsBrushEntity(iTarget,szName)
                {
                    aTargets[aTargetsCount][TARGET_SLOT] = g_user_target[id][i][TARGET_SLOT];
                    aTargets[aTargetsCount++][TARGET_ID] = iTarget;
                }
            }
            case ENTITY_TYPE_POINTENTITY:
            {
                IsPointEntity(iTarget,szName)
                {
                    aTargets[aTargetsCount][TARGET_SLOT] = g_user_target[id][i][TARGET_SLOT];
                    aTargets[aTargetsCount++][TARGET_ID] = iTarget;
                }
            }
            case ENTITY_TYPE_CLONES:
            {
                IsClonedEntity(iTarget,szName)
                {
                    aTargets[aTargetsCount][TARGET_SLOT] = g_user_target[id][i][TARGET_SLOT];
                    aTargets[aTargetsCount++][TARGET_ID] = iTarget;
                }
            }
        }
    }

    // No valid targets.
    if(!aTargetsCount)
    {
        return PLUGIN_HANDLED;
    }

    switch( item )
    {
        case MENU_MORE, MENU_BACK:
        {
            return PLUGIN_HANDLED;
        }
        case MENU_EXIT, MENU_TIMEOUT:
        {
            g_iPlayerGrabMenuProps[id][GRAB_MENU_ID] = -1;
            menu_destroy(menu);
            return PLUGIN_HANDLED;
        }
        case 0:
        {
            g_iPlayerGrabMenuProps[id][GRAB_MENU_TYPE] = (++g_iPlayerGrabMenuProps[id][GRAB_MENU_TYPE] % ENTITY_MAX_TYPES);
        }
        case 1:
        {
            if(iEntityType == ENTITY_TYPE_BRUSHENTITY)
            {
                if(g_iSelectedObjectsCount[id] > 0)
                {
                    for(new i; i < aTargetsCount; i++)
                    {
                        iTarget = aTargets[i][TARGET_ID];
                        DeselectEntity(id, iTarget);
                        ResetBrushEntity(iTarget);
                    }
                }
                else
                {
                    iTarget = aTargets[0][TARGET_ID]; aTargetsCount = 1;
                    ResetBrushEntity(iTarget);
                }

                set_released(id, aTargets, aTargetsCount);
                client_print(id, print_center, "Object was reset to its original place!");
            }
            else if(iEntityType == ENTITY_TYPE_PLAYER)
            {
                new Float:fHealth;
                for(new i; i < aTargetsCount; i++)
                {
                    iTarget = aTargets[i][TARGET_ID];
                    pev(iTarget, pev_max_health, fHealth);
                    set_pev(iTarget, pev_health, fHealth);

                    client_print(iTarget, print_center, "Your Maste Oggey has healed your wounds!");
                }
            }
        }
        case 2:
        {
            if(iEntityType == ENTITY_TYPE_PLAYER)
            {
                for(new i; i < aTargetsCount; i++)
                {
                    iTarget = aTargets[i][TARGET_ID];
                    set_user_godmode(iTarget, true);

                    client_print(iTarget, print_center, "Your Maste Oggey has set you on godmode!");
                }
            }
            else
            {
                // Rotation around Z axis
                new Float:fAngles[3];
                for(new i; i < aTargetsCount; i++)
                {
                    iTarget = aTargets[i][TARGET_ID];
                    pev(iTarget, pev_angles, fAngles);
                    fAngles[1] += 45.0;

                    if (fAngles[1] < 0.0)
                    {
                        fAngles[1] += 360.0;
                    } else if(fAngles[1] >= 360.0)
                    {
                        fAngles[1] -= 360.0;
                    }

                    SetEntityAngles(iTarget, fAngles);
                }
            }
        }
        case 3:
        {
            if(iEntityType == ENTITY_TYPE_PLAYER)
            {
                for(new i; i < aTargetsCount; i++)
                {
                    iTarget = aTargets[i][TARGET_ID];
                    set_user_godmode(iTarget, true);

                    client_print(iTarget, print_center, "Your Maste Oggey has removed you from godmode!");
                }
            }
            else
            {
                // Rotation around X axis
                new Float:fAngles[3];
                for(new i; i < aTargetsCount; i++)
                {
                    iTarget = aTargets[i][TARGET_ID];
                    pev(iTarget, pev_angles, fAngles);
                    fAngles[0] += 45.0;

                    if (fAngles[0] < 0.0)
                    {
                        fAngles[0] += 360.0;
                    } else if(fAngles[0] >= 360.0)
                    {
                        fAngles[0] -= 360.0;
                    }

                    SetEntityAngles(iTarget, fAngles);
                }
            }
        }
        case 4:
        {
            if(iEntityType == ENTITY_TYPE_PLAYER)
            {
                for(new i; i < aTargetsCount; i++)
                {
                    iTarget = aTargets[i][TARGET_ID];
                    set_user_noclip(iTarget, true);

                    client_print(iTarget, print_center, "Your Maste Oggey has set you noclipping!");
                }
            }
            else
            {
                // Rotation around Y axis
                new Float:fAngles[3];
                for(new i; i < aTargetsCount; i++)
                {
                    iTarget = aTargets[i][TARGET_ID];
                    pev(iTarget, pev_angles, fAngles);
                    fAngles[2] += 45.0;

                    if (fAngles[2] < 0.0)
                    {
                        fAngles[2] += 360.0;
                    } else if(fAngles[2] >= 360.0)
                    {
                        fAngles[2] -= 360.0;
                    }

                    SetEntityAngles(iTarget, fAngles);
                }
            }
        }
        case 5:
        {
            if(iEntityType == ENTITY_TYPE_PLAYER)
            {
                for(new i; i < aTargetsCount; i++)
                {
                    iTarget = aTargets[i][TARGET_ID];
                    set_user_noclip(iTarget, false);

                    client_print(iTarget, print_center, "Your Maste Oggey has removed you from noclipping!");
                }
            }
            else
            {
                set_released(id, aTargets, aTargetsCount);

                if(g_iSelectedObjectsCount[id] > 0)
                {
                    new iDecrement;
                    for(new i, ClonedEntity; i < aTargetsCount; i++)
                    {
                        iTarget = aTargets[i][TARGET_ID];
                        DeselectEntity(id, iTarget);
                        ClonedEntity = CloneEntity(iTarget);
                        SelectEntity(id, ClonedEntity);

                        if(ClonedEntity > 0)
                        {
                            aTargets[i][TARGET_ID] = ClonedEntity;
                        }
                        else
                        {
                            iDecrement++;
                        }
                    }

                    aTargetsCount -= iDecrement;
                }
                else
                {
                    new iDecrement;
                    for(new i, ClonedEntity; i < aTargetsCount; i++)
                    {
                        iTarget = aTargets[i][TARGET_ID];
                        ClonedEntity = CloneEntity(iTarget);

                        if(ClonedEntity > 0)
                        {
                            aTargets[i][TARGET_ID] = ClonedEntity;
                        }
                        else
                        {
                            iDecrement++;
                        }
                    }

                    aTargetsCount -= iDecrement;
                }

                set_grabbed(id, aTargets, aTargetsCount);
            }
        }
        case 6:
        {
            if(iEntityType == ENTITY_TYPE_PLAYER)
            {
                for(new i; i < aTargetsCount; i++)
                {
                    iTarget = aTargets[i][TARGET_ID];
                    set_pev(iTarget, pev_flags, pev(iTarget, pev_flags) | FL_FROZEN);
                    client_print(iTarget, print_center, "Your Maste Oggey has froze you!");
                }
            }
            else if(iEntityType == ENTITY_TYPE_CLONES)
            { // lets kill the cloned entity.
                set_released(id, aTargets, aTargetsCount);
                for(new i; i < aTargetsCount; i++)
                {
                    iTarget = aTargets[i][TARGET_ID];

                    if(aTargetsCount > 1)
                    {
                        DeselectEntity(id, iTarget);
                    }

                    set_pev(iTarget, pev_flags, FL_KILLME);
                    dllfunc(DLLFunc_Think, iTarget);
                }
            }
        }
        case 7:
        {
            if(iEntityType == ENTITY_TYPE_PLAYER)
            {
                for(new i; i < aTargetsCount; i++)
                {
                    iTarget = aTargets[i][TARGET_ID];
                    set_pev(iTarget, pev_flags, pev(iTarget, pev_flags) & ~FL_FROZEN);
                    client_print(iTarget, print_center, "Your Maste Oggey has defreeze you!");
                }
            }
            else if(iEntityType == ENTITY_TYPE_BRUSHENTITY || iEntityType == ENTITY_TYPE_CLONES)
            {
                client_cmd(id, "messagemode set_entity_speed");
            }
        }
        case 8:
        {
            if(iEntityType == ENTITY_TYPE_BRUSHENTITY || iEntityType == ENTITY_TYPE_CLONES)
            {
                client_cmd(id, "messagemode set_entity_acceleration");
            }
        }
    }

    menu_destroy(menu);
    hook_flashlight(id);
    return PLUGIN_HANDLED;
}

ResetBrushEntity(const ent)
{
    set_pev(ent, pev_velocity, Float:{0.0, 0.0, 0.0});
    set_pev(ent, pev_angles, Float:{0.0, 0.0, 0.0});
    engfunc(EngFunc_SetOrigin, ent, Float:{0.0, 0.0, 0.0});

    new Float:fOrigin[3];
    fOrigin = GetEntityOrigin(ent);

    if(fOrigin[1] == 0.0)
    {
        pev(ent, pev_oldorigin, fOrigin);
        engfunc(EngFunc_SetOrigin, ent, fOrigin);
    }
}

CloneEntity(const ent)
{
    new szClassName[32];
    pev(ent, pev_classname, szClassName, charsmax(szClassName));
    new clone = create_entity(szClassName);

    if(!clone)
    {
        return 0;
    }

    new szModel[64], Float:fOrigin[3], Float:fOldOrigin[3], Float:fAngles[3], Float:fMins[3], Float:fMaxs[3], Float:fHealth, Float:fMaxHealth, Float:flTakeDamage;
    pev(ent, pev_origin, fOrigin);
    pev(ent, pev_oldorigin, fOldOrigin);
    pev(ent, pev_angles, fAngles);
    pev(ent, pev_model, szModel, charsmax(szModel));
    pev(ent, pev_maxs, fMaxs);
    pev(ent, pev_mins, fMins);
    pev(ent, pev_health, fHealth);
    pev(ent, pev_max_health, fMaxHealth);
    pev(ent, pev_takedamage, flTakeDamage);

    set_pev(clone, pev_netname, "CLONED_ENTITY");

    set_pev(clone, pev_solid, pev(ent, pev_solid));
    set_pev(clone, pev_movetype, pev(ent, pev_movetype));

    engfunc(EngFunc_SetOrigin, clone, fOrigin);
    set_pev(clone, pev_oldorigin, fOldOrigin);
    set_pev(clone, pev_angles, fAngles);
    engfunc(EngFunc_SetModel, clone, szModel);
    engfunc(EngFunc_SetSize, clone, fMins, fMaxs);
    set_pev(clone, pev_health, fHealth);
    set_pev(clone, pev_max_health, fMaxHealth);
    set_pev(clone, pev_takedamage, flTakeDamage);
    set_pev(clone, pev_modelindex, pev(ent, pev_modelindex));
    set_pev(clone, pev_flags, pev(ent, pev_flags));
    set_pev(clone, pev_spawnflags, pev(ent, pev_spawnflags));
    set_pev(clone, pev_rendermode, pev(ent, pev_rendermode));

    new Float:fValue, Float:fColor[3];
    pev(ent, pev_renderamt, fValue);
    pev(ent, pev_rendercolor, fColor);
    set_pev(clone, pev_renderfx, pev(ent, pev_renderfx));
    set_pev(clone, pev_renderamt, fValue);

    new szClass[32];
    pev(ent, pev_classname, szClass, charsmax(szClass));

    if(equal(szClass, "func_vehicle"))
    {
        new Float:fvControlMaxs[3], Float:fvControlMins[3];
        get_ent_data_vector(ent, "CFuncVehicle", "m_controlMaxs", fvControlMaxs);
        get_ent_data_vector(ent, "CFuncVehicle", "m_controlMaxs", fvControlMins);
        set_ent_data_vector(clone, "CFuncVehicle", "m_controlMaxs", fvControlMaxs);
        set_ent_data_vector(clone, "CFuncVehicle", "m_controlMaxs", fvControlMins);


        set_ent_data_float(clone, "CFuncVehicle", "m_speed", get_ent_data_float(ent, "CFuncVehicle", "m_speed"));
        set_ent_data_float(clone, "CFuncVehicle", "m_length", get_ent_data_float(ent, "CFuncVehicle", "m_length"));
        set_ent_data_float(clone, "CFuncVehicle", "m_width", get_ent_data_float(ent, "CFuncVehicle", "m_width"));
        set_ent_data_float(clone, "CFuncVehicle", "m_height", get_ent_data_float(ent, "CFuncVehicle", "m_height"));
        set_ent_data(clone, "CFuncVehicle", "m_sounds", get_ent_data(ent, "CFuncVehicle", "m_sounds"));
    }

    return clone;
}

SetEntityAngles(ent, const Float:angles[3])
{
    new Float:origin[3];
    origin = GetEntityOrigin(ent);

    set_pev(ent, pev_angles, angles);
    set_pev(ent, pev_origin, Float:{0.0, 0.0, 0.0});

    new Float:newOrigin[3];
    newOrigin = GetEntityOrigin(ent);

    origin[0] -= newOrigin[0];
    origin[1] -= newOrigin[1];
    origin[2] -= newOrigin[2];

    engfunc(EngFunc_SetOrigin, ent, origin);
}

Float:GetEntityOrigin(ent)
{
    new Float:origin[3];
    pev(ent, pev_origin, origin);

    new Float:center[3];
    {
        new Float:mins[3], Float:maxs[3];
        pev(ent, pev_mins, mins);
        pev(ent, pev_maxs, maxs);
        center[0] = (mins[0] + maxs[0])/2.0;
        center[1] = (mins[1] + maxs[1])/2.0;
        center[2] = (mins[2] + maxs[2])/2.0;
    }

    new Float:rotatedCenter[3];
    {
        new Float:angles[3];
        pev(ent, pev_angles, angles);

        engfunc(EngFunc_MakeVectors, angles);
        new Float:fwd[3], Float:left[3], Float:up[3];
        global_get(glb_v_forward, fwd);
        {
            new Float:right[3];
            global_get(glb_v_right, right);
            left[0] = -right[0];
            left[1] = -right[1];
            left[2] = -right[2];
        }
        global_get(glb_v_up, up);

        // rotatedCenter = fwd*center.x + left*center.y + up*center.z
        rotatedCenter[0] = fwd[0]*center[0] + left[0]*center[1] + up[0]*center[2];
        rotatedCenter[1] = fwd[1]*center[0] + left[1]*center[1] + up[1]*center[2];
        rotatedCenter[2] = fwd[2]*center[0] + left[2]*center[1] + up[2]*center[2];
    }

    origin[0] += rotatedCenter[0];
    origin[1] += rotatedCenter[1];
    origin[2] += rotatedCenter[2];

    return origin;
}

SaveEntityRender(const ent, const id, const slot)
{
    g_iTargetRenderData[id][slot][RENDER_MODE] = pev(ent, pev_rendermode);
    g_iTargetRenderData[id][slot][RENDER_FX] = pev(ent, pev_renderfx);
    pev(ent, pev_rendercolor, g_iTargetRenderData[id][slot][RENDER_COLOR]);
    pev(ent, pev_renderamt, g_iTargetRenderData[id][slot][RENDER_AMOUNT]);
}

SelectEntity(const id, const ent)
{
    if(g_iSelectedObjectsCount[id] >= MAX_SELECTED_OBJECTS)
    {
        client_print(id, print_center, "Maximum selected objects has been reached!");
        return;
    }

    new slot;
    g_iSelectedObjects[id][(slot=g_iSelectedObjectsCount[id]++)] = ent;
    if(pev_valid(ent))
    {
        SaveEntityRender(ent, id, slot);
        SetEntityRender(ent, .fColor = Float:{0.0,200.0,0.0});
    }
}

DeselectEntity(const id, const ent)
{
    if(g_iSelectedObjectsCount[id] <= 0)
    {
        return;
    }

    new slot;
    if(GetEntitySelector(ent, slot) == id)
    {
        g_iSelectedObjects[id][slot] = g_iSelectedObjects[id][--g_iSelectedObjectsCount[id]];
        if(pev_valid(ent)) RestoreEntityRender(ent, id, slot);
    }
}

UserPrintObjectAction(const id, const object, const target, const action[], const byteColor[3]={255, 255, 255})
{
    static szName[32];
    get_user_name(target, szName, 31);
    set_hudmessage(byteColor[0], byteColor[1], byteColor[2], 0.45, 0.65, .effects = 1 , .holdtime= 0.35);
    show_hudmessage(id, "Object [#%d] %s by %s!", object, action, szName);
}

public fw_cmdstart_post(id, uc_handle, seed)
{
    static iButton, iOldButtons, iFlags;
    iButton = get_uc(uc_handle ,UC_Buttons);
    iOldButtons = pev(id, pev_oldbuttons);
    iFlags = get_user_flags(id);

    if((iButton & IN_RELOAD) && !(iOldButtons & IN_RELOAD)) // button pressed.
    {
        static Float:fGameTime, iSelector, iGrabber, iTarget;
        iTarget = find_target_by_aim(id);
        fGameTime = get_gametime();
        iSelector = GetEntitySelector(iTarget);
        iGrabber = GetEntityGrabber(iTarget);

        g_fUser_inuse_lasttime[id] = fGameTime + TOGGLE_ACTIVATION_LENGTH;

        if(!g_bUser_grab_access[id])
        {
            if(iSelector > 0)
            {
                UserPrintObjectAction(id, iTarget, iSelector, "Selected");
            }

            return;
        }

        if((fGameTime - g_fReloadKeyFirstTimePressed[id]) > OBJECTS_DESELECTION_INTERVAL)
        {
            g_iReloadKeyPressedCount[id] = 0;
        }

        if(++g_iReloadKeyPressedCount[id] >= 3)
        {
            if(g_iSelectedObjectsCount[id])
            {
                while( g_iSelectedObjectsCount[id] > 0 )
                {
                    DeselectEntity(id, g_iSelectedObjects[id][0]);
                }

                client_print(id, print_center, "All Selected objects were deselected!");
                return;
            }
        }
        else if(g_iReloadKeyPressedCount[id] == 1)
        {
            g_fReloadKeyFirstTimePressed[id] = fGameTime;
        }

        if( (IsPlayer(iTarget) && g_user_grabber[ iTarget ] == 0) || iTarget && !IsPlayer(iTarget) )
        {
            if(!iSelector && !iGrabber)
            {
                SelectEntity(id, iTarget);
                iSelector = id;
            }
            else if(iSelector == id)
            {
                UserPrintObjectAction(id, iTarget, iSelector, "Deselected", .byteColor = {255,0,0});
                DeselectEntity(id, iTarget);
                iSelector = 0;
            }
        }

        if(iSelector > 0)
        {
            UserPrintObjectAction(id, iTarget, iSelector, "Selected");
        }

        return;
    }
    else if((iButton & IN_USE) && (iOldButtons & IN_USE)) // button pushed.
    {
        if(!g_bUser_grab_access[id])
        {
            return;
        }

        static iTarget, Float:fSight[3], iAim[3], aTargets[MAX_SELECTED_OBJECTS][TARGET_PROPERTIES], aTargetsCount,
        aInvalidTargets[MAX_SELECTED_OBJECTS][TARGET_PROPERTIES], aInvalidTargetsCount, i;

        if( g_iGrabbedObjectsCount[id] > 0)
        {
            static Float:fIDOrigin[3], Float:fOrigin[3], szModel[2], slot;

            for(i = aTargetsCount = aInvalidTargetsCount = 0; i < g_iGrabbedObjectsCount[id]; i++)
            {
                iTarget = g_user_target[id][i][TARGET_ID];
                slot = g_user_target[id][i][TARGET_SLOT];

                if(!EntityExists(iTarget))
                {
                    aInvalidTargets[aInvalidTargetsCount][TARGET_SLOT] = slot;
                    aInvalidTargets[aInvalidTargetsCount++][TARGET_ID] = iTarget;
                    continue;
                }

                if((iButton & GRAB_KEY_PULL) && (iOldButtons & GRAB_KEY_PULL))
                {
                    g_fuser_grabdistance[id][slot] = floatmax(g_fuser_grabdistance[id][slot] - 5.0, 100.0);
                }
                else if((iButton & GRAB_KEY_PUSH) && (iOldButtons & GRAB_KEY_PUSH))
                {
                    g_fuser_grabdistance[id][slot] = floatmin(g_fuser_grabdistance[id][slot] + 5.0, 2000.0);
                }

                aTargets[aTargetsCount][TARGET_SLOT] = slot;
                aTargets[aTargetsCount++][TARGET_ID] = iTarget;

                pev(id, pev_origin, fIDOrigin);
                pev(id, pev_view_ofs, fSight);
                xs_vec_add(fIDOrigin, fSight, fIDOrigin);

                IsBrushEntity(iTarget,szModel)
                {
                    fOrigin = GetEntityOrigin(iTarget);
                }
                else
                {
                    pev(iTarget, pev_origin, fOrigin);
                }

                xs_vec_add(fOrigin, g_fVecShift[id][slot], fOrigin);
                get_user_origin(id, iAim, Origin_AimEndEyes);
                IVecFVec(iAim, fSight);
                xs_vec_sub(fSight, fIDOrigin, fSight);
                xs_vec_normalize(fSight, fSight);
                xs_vec_mul_scalar(fSight, g_fuser_grabdistance[id][slot], fSight);
                xs_vec_add(fSight, fIDOrigin, fSight);

                static Float:fDistance;
                fDistance = get_distance_f(fSight, fOrigin);

                xs_vec_sub(fSight, fOrigin, fSight);

                if(xs_vec_len(fSight) <= 1.0)
                {
                    set_pev(iTarget, pev_velocity, Float:{0.0,0.0,0.0});
                }
                else if(!xs_vec_equal(fSight, Float:{0.0,0.0,0.0}))
                {
                    IsBrushEntity(iTarget,szModel)
                    {
                        pev(iTarget, pev_origin, fOrigin);
                        xs_vec_add(fOrigin, fSight, fOrigin);
                        set_pev(iTarget, pev_origin, fOrigin);
                    }
                    else
                    {
                        xs_vec_normalize(fSight, fSight);
                        xs_vec_mul_scalar(fSight, fDistance * get_pcvar_float(g_pcvar_grab_force), fSight);
                        set_pev(iTarget, pev_velocity, fSight);
                    }
                }
            }

            if(aInvalidTargetsCount > 0)
            {
                if(g_iSelectedObjectsCount[id] > 0)
                {
                    for(i = 0; i < aInvalidTargetsCount; i++)
                    {
                        DeselectEntity(id, aInvalidTargets[i][TARGET_ID]);
                    }
                }

                set_released(id, aInvalidTargets, aInvalidTargetsCount);
            }

            return;
        }

        if(g_iSelectedObjectsCount[id] > 0)
        {
            for(i = aTargetsCount = aInvalidTargetsCount = 0; i < g_iSelectedObjectsCount[id]; i++)
            {
                iTarget = g_iSelectedObjects[id][i];

                if(!EntityExists(iTarget))
                {
                    aInvalidTargets[aInvalidTargetsCount][TARGET_SLOT] = i;
                    aInvalidTargets[aInvalidTargetsCount++][TARGET_ID] = iTarget;
                    continue;
                }

                aTargets[aTargetsCount][TARGET_SLOT] = i;
                aTargets[aTargetsCount++][TARGET_ID] = iTarget;
            }

            if(aInvalidTargetsCount > 0)
            {
                for(i = 0; i < aInvalidTargetsCount; i++)
                {
                    DeselectEntity(id, aInvalidTargets[i][TARGET_ID]);
                }
            }

            set_grabbed(id, aTargets, aTargetsCount);
        }
        else
        {
            iTarget = find_target_by_aim(id);

            if( ((IsPlayer(iTarget) && g_user_grabber[ iTarget ] == 0) || iTarget && !IsPlayer(iTarget)) && !GetEntitySelector(iTarget) && !GetEntityGrabber(iTarget) )
            {
                aTargets[0][TARGET_ID] = iTarget;
                aTargets[0][TARGET_SLOT] = 0;
                SaveEntityRender(iTarget, id, 0);
                set_grabbed(id, aTargets, 1);
            }
        }
    }
    else if(!(iButton & IN_RELOAD) && (iOldButtons & IN_RELOAD)) // button released.
    {
        if(!(iFlags & ADMIN_ACCESS))
        {
            if(!g_bUser_grab_authorized[id])
            {
                return;
            }
        }

        if(g_fUser_inuse_lasttime[id] != -1.0 && g_fUser_inuse_lasttime[id] <= get_gametime())
        {
            g_fUser_inuse_lasttime[id] = -1.0;
            g_bUser_grab_access[id] = !g_bUser_grab_access[id];
            client_print(id, print_center, "Grabbing ability was %sabled!", g_bUser_grab_access[id] ? "en":"dis");

            return;
        }
    }
    else if(!(iButton & IN_USE) && (iOldButtons & IN_USE)) // button released.
    {
        if(g_iGrabbedObjectsCount[id] > 0)
        {
            set_released(id, g_user_target[ id ], g_iGrabbedObjectsCount[id]);
        }
    }
}

GetEntitySelector(const ent, &slot=0)
{
    static players[32], pnum, i, id, x;
    get_players(players, pnum, "ch");

    for(i = 0; i < pnum; i++)
    {
        id = players[ i ];
        for(x = 0; x < g_iSelectedObjectsCount[id]; x++)
        {
            if(g_iSelectedObjects[ id ][ x ] == ent)
            {
                slot = x;
                return id;
            }
        }
    }

    return 0;
}

GetEntityGrabber(const ent, &slot=0)
{
    static players[32], pnum, i, id, x;
    get_players(players, pnum, "ch");

    for(i = 0; i < pnum; i++)
    {
        id = players[ i ];
        for(x = 0; x < g_iGrabbedObjectsCount[id]; x++)
        {
            if(g_user_target[ id ][ x ][TARGET_ID] == ent)
            {
                slot = g_user_target[ id ][ x ][TARGET_SLOT];
                return id;
            }
        }
    }

    return 0;
}

find_target_by_aim(id)
{
    static Float:fSight[3], iAim[3], iTarget;
    get_user_aiming(id, iTarget);

    if( !iTarget )
    {
        static Float:fEntityOrigin[3], szModel[2], Float:fDistance, iClosestTarget;
        fDistance = 50.0; iClosestTarget = 0;
        get_user_origin(id, iAim, Origin_AimEndEyes);
        IVecFVec(iAim, fSight);

        while( (iTarget = find_ent_in_sphere(iTarget, fSight, 3.0)) )
        {
            if(pev(iTarget, pev_movetype) != MOVETYPE_NONE)
            {
                IsBrushEntity(iTarget, szModel)
                {
                    fEntityOrigin = GetEntityOrigin(iTarget);
                }
                else
                {
                    pev(iTarget, pev_origin, fEntityOrigin);
                }

                if(fDistance > get_distance_f(fEntityOrigin, fSight))
                {
                    iClosestTarget = iTarget;
                    fDistance = get_distance_f(fEntityOrigin, fSight);
                }
            }
        }

        iTarget = iClosestTarget;
    }

    return iTarget;
}

RestoreEntityRender(const ent, const id, const slot)
{
    set_pev(ent, pev_rendermode, g_iTargetRenderData[id][slot][RENDER_MODE]);
    set_pev(ent, pev_renderfx, g_iTargetRenderData[id][slot][RENDER_FX]);
    set_pev(ent, pev_rendercolor, g_iTargetRenderData[id][slot][RENDER_COLOR]);
    set_pev(ent, pev_renderamt, g_iTargetRenderData[id][slot][RENDER_AMOUNT]);
}

SetEntityRender(const ent, const Float:fColor[3] = {0.0,0.0,0.0})
{
    new szModel[2];
    IsBrushEntity(ent, szModel)
    {
        set_pev(ent, pev_rendermode, kRenderTransColor);
        set_pev(ent, pev_rendercolor, fColor);
        set_pev(ent, pev_renderamt, 200.0);
    }
    else
    {
        set_pev(ent, pev_rendermode, kRenderNormal);
        set_pev(ent, pev_renderfx, kRenderFxGlowShell);
        set_pev(ent, pev_rendercolor, fColor);
        set_pev(ent, pev_renderamt, 100.0);
    }
}

set_grabbed(id, aTargets[MAX_GRABBED_OBJECTS][TARGET_PROPERTIES], const aTargetsCount)
{
    if(!g_bUser_grab_access[id] || aTargetsCount == 0)
    {
        return false;
    }

    g_fUser_inuse_lasttime[id] = -1.0;

    static szGrabbername[32], szTargetname[32];

    for(new i, target, slot, GrabbedObjectsCount = g_iGrabbedObjectsCount[id]; i < aTargetsCount; i++)
    {
        target = aTargets[ i ][TARGET_ID];
        slot = aTargets[ i ][TARGET_SLOT];

        g_user_target[id][GrabbedObjectsCount][TARGET_ID] = target;
        g_user_target[id][GrabbedObjectsCount][TARGET_SLOT] = GrabbedObjectsCount;
        GrabbedObjectsCount = ++g_iGrabbedObjectsCount[id];

        if( IsPlayer(target) )
        {
            g_fuser_grabdistance[id][slot] = entity_range(id, target);

            xs_vec_set(g_fVecShift[id][slot], 0.0, 0.0, 0.0);
            get_user_name(id, szGrabbername, charsmax(szGrabbername));
            get_user_name(target, szTargetname, charsmax(szTargetname));
            g_user_grabber[ target ] = id;
            client_print(id, print_chat, "Now you're grabbing onto %s", szTargetname);
            client_print(target, print_chat, "%s held onto you!", szGrabbername);

            SetEntityRender(target, .fColor = Float:{200.0,0.0,0.0});
        }
        else if( target > 0 )
        {
            static Float:fOrigin[3], Float:fBrushOrigin[3], Float:fAim[3], Float:fViewOFS[3], szModel[2];
            pev(id, pev_origin, fOrigin);
            pev(id, pev_v_angle, fAim);
            pev(id, pev_view_ofs, fViewOFS);
            xs_vec_add(fOrigin, fViewOFS, fOrigin);
            angle_vector(fAim, ANGLEVECTOR_FORWARD, fAim);
            pev(target, pev_model, szModel, charsmax(szModel));
            pev(target, pev_maxs, g_fTargetMaxs[id][slot]);
            pev(target, pev_mins, g_fTargetMins[id][slot]);
            g_iOldSolidType[id][slot] = pev(target, pev_solid);
            g_iOldMoveType[id][slot] = pev(target, pev_movetype);

            if(szModel[0] == '*')
            {
                fBrushOrigin = GetEntityOrigin(target);
                //set_pev(target, pev_movetype, MOVETYPE_PUSH);
            }
            else
            {
                pev(target, pev_origin, fBrushOrigin);
            }

            //set_pev(target, pev_solid, SOLID_NOT);

            g_fuser_grabdistance[id][slot] = get_distance_f(fOrigin, fBrushOrigin);
            xs_vec_mul_scalar(fAim, g_fuser_grabdistance[id][slot], fAim);
            xs_vec_add(fOrigin, fAim, fAim);
            xs_vec_sub(fAim, fBrushOrigin, g_fVecShift[id][slot]);

            new szTargetname[32];
            pev(target, pev_classname, szTargetname, charsmax(szTargetname));
            client_print(id, print_chat, "Now you're grabbing onto %s", szTargetname);

            SetEntityRender(target, .fColor = Float:{200.0,0.0,0.0});
        }
    }

    return true;
}

set_released(const id, const aTargets[MAX_GRABBED_OBJECTS][TARGET_PROPERTIES], const ReleasedObjectsCount)
{
    g_fUser_inuse_lasttime[id] = -1.0;

    for(new szGrabbername[32], szTargetname[32], szModel[64], i, slot, target, GrabbedObjectsCount; i < ReleasedObjectsCount; i++)
    {
        target = aTargets[ i ][ TARGET_ID   ];
        slot   = aTargets[ i ][ TARGET_SLOT ];

        GrabbedObjectsCount = --g_iGrabbedObjectsCount[id];
        g_user_target[ id ][ slot ][ TARGET_ID ]   = g_user_target[ id ][ GrabbedObjectsCount ][ TARGET_ID ];
        g_user_target[ id ][ slot ][ TARGET_SLOT ] = g_user_target[ id ][ GrabbedObjectsCount ][ TARGET_SLOT ];

        if( IsPlayer(target) )
        {
            g_user_grabber[ target ] = 0;

            if(is_user_connected(target))
            {
                if(pev(target, pev_solid) != SOLID_SLIDEBOX)
                {
                    set_pev(target, pev_solid, SOLID_SLIDEBOX);
                }

                get_user_name(id, szGrabbername, charsmax(szGrabbername));
                client_print(target, print_chat, "%s is nolonger grabbing you!", szGrabbername);

                if(!GetEntitySelector(target))
                {
                    RestoreEntityRender(target, id, .slot = slot);
                }
                else
                {
                    SetEntityRender(target, .fColor = Float:{0.0,200.0,0.0});
                }
            }

            if(is_user_connected(id))
            {
                get_user_name(target, szTargetname, charsmax(szTargetname));
                client_print(id, print_chat, "You've released your grab around %s", szTargetname);
            }
        }
        else if(pev_valid(target))
        {
            pev(target, pev_classname, szTargetname, charsmax(szTargetname));
            pev(target, pev_model, szModel, charsmax(szModel));
            client_print(id, print_chat, "You've released your grab around %s ( %s )", szTargetname, szModel);

            if(szModel[0] == '*')
            {
                set_pev(target, pev_movetype, g_iOldMoveType[id][slot]);
                g_iOldMoveType[id][slot] = g_iOldMoveType[id][GrabbedObjectsCount];
            }

            set_pev(target, pev_solid, g_iOldSolidType[id][slot]);
            g_iOldMoveType[id][slot] = g_iOldMoveType[id][GrabbedObjectsCount];

            engfunc(EngFunc_SetSize, target, g_fTargetMins[id][slot], g_fTargetMaxs[id][slot]);
            g_fTargetMaxs[id][slot] = g_fTargetMaxs[id][GrabbedObjectsCount];
            g_fTargetMins[id][slot] = g_fTargetMins[id][GrabbedObjectsCount];

            if(!GetEntitySelector(target))
            {
                RestoreEntityRender(target, id, .slot = slot);
            }
            else
            {
                SetEntityRender(target, .fColor = Float:{0.0,200.0,0.0});
            }
        }
    }

    new iNull, iNewMenu;
    if(player_menu_info(id, iNull, iNewMenu, iNull) && g_iPlayerGrabMenuProps[id][GRAB_MENU_ID] == iNewMenu)
    {
        menu_cancel(id);
        show_menu(id, 0, " ^n ");
        g_iPlayerGrabMenuProps[id][GRAB_MENU_ID] = -1;
    }
}
