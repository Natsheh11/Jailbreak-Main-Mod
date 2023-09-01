#include <amxmodx> 
#include <fakemeta> 
#include <engine>
#include <hamsandwich> 
#include <xs>

#define VERSION "0.0.3" 

#define USE_TOGGLE 3

#define MAX_BACKWARD_UNITS	-200.0
#define MAX_FORWARD_UNITS	200.0
#define UNITS_DEFAULT 50.0

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif

new g_iPlayerCamera[MAX_PLAYERS+1], Float:g_camera_fPosition[MAX_PLAYERS+1];

#define VIEW_BACK_200_UNITS -200.0
#define VIEW_BACK_150_UNITS -150.0
#define VIEW_BACK_100_UNITS -100.0
#define VIEW_BACK_050_UNITS -050.0
#define VIEW_FIRST_PERSON 0.0
#define VIEW_FRONT_050_UNITS 0.50
#define VIEW_FRONT_100_UNITS 100.0
#define VIEW_FRONT_150_UNITS 150.0
#define VIEW_FRONT_200_UNITS 200.0

public plugin_natives()
{
	// native set_player_camera(const id, const VIEW_CAMERA_OFFSETS:flViewOffset);
	register_native("set_player_camera", "native_set_player_camera");
}

public plugin_init()
{
	register_plugin("Camera View Menu", VERSION, "ConnorMcLeod & Natsheh") ;
	
	register_clcmd("say /cam", "camera_menu", ADMIN_KICK);
	register_clcmd("say_team /cam", "camera_menu", ADMIN_KICK);
	
	register_forward(FM_SetView, "SetView");
	RegisterHam(Ham_Think, "trigger_camera", "Camera_Think");
}

public native_set_player_camera(plugin, argc)
{
	new id = get_param( 1 ),
	Float:fCameraView = get_param_f( 2 );

	if(!is_user_connected(id))
	{
		log_error(AMX_ERR_NATIVE, "Invalid Player ID #%d or player is not connected!", id);
		return -1;
	}

	if(fCameraView == VIEW_FIRST_PERSON)
	{
		engfunc(EngFunc_SetView, id, id);
		DestroyPlayerCamera(id);
	}
	else
	{
		g_camera_fPosition [id] = fCameraView;
		CreatePlayerCamera(id);
	}

	return 0;
}

public camera_menu(id, level)
{
	if(level && !(get_user_flags(id) & level))
	{
		client_print(id, print_center, "You've no access!");
		return 1;
	}

	new menu = menu_create("Choose an option!", "cam_m_handler"), sText[48], bool:mode = (g_iPlayerCamera[id] > 0) ? true:false;
	
	formatex(sText, charsmax(sText), "%s \r3RD Person camera!", (mode) ? "\dDisable":"\yEnable");
	menu_additem(menu, sText);
	
	if(mode)
	{
		menu_additem(menu, "Forward Further!");
		menu_additem(menu, "Backward Further!");
	}
	
	menu_display(id, menu);
	return 1;
}

public cam_m_handler(id, menu, item)
{
	if(item == MENU_EXIT || !is_user_connected(id))
	{
		menu_destroy(menu);
		return 1;
	}
	
	menu_destroy(menu);
	
	switch ( item )
	{
		case 0:
		{
			if(g_iPlayerCamera[id] > 0)
			{
				engfunc(EngFunc_SetView, id, id);
				DestroyPlayerCamera(id);
			}
			else
			{
				g_camera_fPosition [id] = VIEW_BACK_100_UNITS;
				CreatePlayerCamera(id);
			}
		}
		case 1: if(g_camera_fPosition [id] < MAX_FORWARD_UNITS) g_camera_fPosition [id] += UNITS_DEFAULT;
		case 2: if(g_camera_fPosition [id] > MAX_BACKWARD_UNITS) g_camera_fPosition [id] -= UNITS_DEFAULT;
	}
	
	camera_menu(id, 000);
	return 1;
}

CreatePlayerCamera(id)
{
	new iEnt = g_iPlayerCamera[id];
	if(!pev_valid(iEnt))
	{
		static iszTriggerCamera 
		if( !iszTriggerCamera ) 
		{ 
			iszTriggerCamera = engfunc(EngFunc_AllocString, "trigger_camera") ;
		} 
		
		iEnt = engfunc(EngFunc_CreateNamedEntity, iszTriggerCamera);
		set_kvd(0, KV_ClassName, "trigger_camera") ;
		set_kvd(0, KV_fHandled, 0) ;
		set_kvd(0, KV_KeyName, "wait") ;
		set_kvd(0, KV_Value, "9999999") ;
		dllfunc(DLLFunc_KeyValue, iEnt, 0) ;
	
		set_pev(iEnt, pev_spawnflags, SF_CAMERA_PLAYER_TARGET | SF_CAMERA_PLAYER_POSITION);
		set_pev(iEnt, pev_groupinfo, pev(id, pev_groupinfo));
		set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_ALWAYSTHINK);
		//set_pev(iEnt, pev_owner, id);

		DispatchSpawn(iEnt);

		g_iPlayerCamera[id] = iEnt;
		
		new Float:flMaxSpeed, bitsFlags = pev(id, pev_flags);
		pev(id, pev_maxspeed, flMaxSpeed);
		
		ExecuteHam(Ham_Use, iEnt, id, id, USE_TOGGLE, 1.0);
		
		set_pev(id, pev_flags, bitsFlags);
		// depending on mod, you may have to send SetClientMaxspeed here. 
		// engfunc(EngFunc_SetClientMaxspeed, id, flMaxSpeed) 
		set_pev(id, pev_maxspeed, flMaxSpeed);
	}

	return iEnt;
}

public SetView(id, iEnt) 
{ 
	new iCamera = g_iPlayerCamera[id];
	if( iCamera && iEnt != iCamera )
	{
			new szClassName[16] ;
			pev(iEnt, pev_classname, szClassName, charsmax(szClassName)) ;
			if(!equal(szClassName, "trigger_camera")) // should let real cams enabled 
			{
				engfunc(EngFunc_SetView, id, iCamera); // shouldn't be always needed
				return FMRES_SUPERCEDE ;
			}
	} 
	return FMRES_IGNORED 
}

public client_disconnect(id) 
{ 
	DestroyPlayerCamera(id);
} 

DestroyPlayerCamera(id)
{
	new iEnt = g_iPlayerCamera[id];

	if(pev_valid(iEnt))
	{
		set_pev(iEnt, pev_flags, FL_KILLME);
		dllfunc(DLLFunc_Think, iEnt);
	}

	g_iPlayerCamera[id] = 0;
	g_camera_fPosition [id] = VIEW_FIRST_PERSON;
}

public client_putinserver(id) 
{
	g_iPlayerCamera[id] = 0;
	g_camera_fPosition [id] = VIEW_BACK_100_UNITS;
} 

get_cam_owner(iEnt) 
{ 
	new players[32], pnum;
	get_players(players, pnum, "ch");
	
	for(new id, i; i < pnum; i++)
	{ 
		id = players[i];
		
		if(g_iPlayerCamera[id] == iEnt)
		{
			return id;
		}
	}
	
	return 0;
} 

public Camera_Think(iEnt)
{
	static id;
	if(!(id = get_cam_owner(iEnt))) return HAM_IGNORED;
	
	static Float:fVecPlayerOrigin[3], Float:fVecCameraOrigin[3], Float:fVecAngles[3], Float:fVec[3];
	
	pev(id, pev_origin, fVecPlayerOrigin);
	pev(id, pev_view_ofs, fVecAngles);
	fVecPlayerOrigin[2] += fVecAngles[2];
	
	pev(id, pev_v_angle, fVecAngles);
	
	angle_vector(fVecAngles, ANGLEVECTOR_FORWARD, fVec);
	static Float:fvUP[3], Float:fvRight[3], Float:units;
	units = g_camera_fPosition [id];
	fvUP[2] = 1.0;
	xs_vec_cross(fVec, fvUP, fvRight);
	
	//Move back/forward to see ourself
	fVecCameraOrigin[0] = fVecPlayerOrigin[0] + (fVec[0] * units) + fvRight[0] * 32.0;
	fVecCameraOrigin[1] = fVecPlayerOrigin[1] + (fVec[1] * units) + fvRight[1] * 32.0;
	fVecCameraOrigin[2] = fVecPlayerOrigin[2] + (fVec[2] * units) + (units <= 0.0 ? 10.0 : 0.0);
	
	static tr2; tr2 = create_tr2();
	engfunc(EngFunc_TraceLine, fVecPlayerOrigin, fVecCameraOrigin, IGNORE_MONSTERS, id, tr2);
	static Float:flFraction;
	get_tr2(tr2, TR_flFraction, flFraction);

	
	if( flFraction != 1.0 ) // adjust camera place if close to a wall 
	{
		flFraction = floatabs(flFraction - 0.1) * units;
		fVecCameraOrigin[0] = fVecPlayerOrigin[0] + (fVec[0] * flFraction);
		fVecCameraOrigin[1] = fVecPlayerOrigin[1] + (fVec[1] * flFraction);
		fVecCameraOrigin[2] = fVecPlayerOrigin[2] + (fVec[2] * flFraction);
	}
	
	engfunc(EngFunc_SetOrigin, iEnt, fVecCameraOrigin);

	static Float:fVecEnd[3];
	xs_vec_mul_scalar(fVec, 9999.0, fVecEnd);
	xs_vec_add(fVecPlayerOrigin, fVecEnd, fVecEnd);
	engfunc(EngFunc_TraceLine, fVecPlayerOrigin, fVecEnd, IGNORE_MONSTERS, id, tr2);
	get_tr2(tr2, TR_vecEndPos, fVecEnd);
	free_tr2(tr2);

	xs_vec_sub(fVecEnd, fVecCameraOrigin, fVecEnd);
	xs_vec_normalize(fVecEnd, fVecEnd);
	vector_to_angle(fVecEnd, fVecAngles);

	if(units > 0.0)
	{
		fVecAngles[0] *= (fVecAngles[0] >= 0.0) ? 1.0 : -1.0;
		fVecAngles[1] += (fVecAngles[1] >= 180.0) ? -180.0 : 180.0;
	}
	else
	{
		fVecAngles[0] *= fVecAngles[0] > 0.0 ? -1 : 1;
	}

	set_pev(iEnt, pev_angles, fVecAngles);

	pev(id, pev_velocity, fVec);
	set_pev(iEnt, pev_velocity, fVec);

	set_pev(iEnt, pev_nextthink, get_gametime() + 0.01);
	return HAM_SUPERCEDE;
}
