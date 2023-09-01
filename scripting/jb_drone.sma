/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <xs>
#include <jailbreak_core>
#include <hamsandwich>

#define PLUGIN "[JB] SHOP: Drone"
#define AUTHOR "Natsheh"

#define DRONE_OWNER EV_INT_iuser3
#define DRONE_CURRENT_STATUS EV_INT_iuser4
#define DRONE_ROTATION_ROLL EV_FL_fuser4
#define DRONE_ROTATION_UPWARDS EV_FL_fuser3
#define DRONE_CAMERA pev_iuser2

#define CRASH_SPEED 125.0

new const drone_entity_classname[] = "Drone"
new const drone_entity_oldclassname[] = "info_target"

enum any:Vector(+=1)
{
    x = 0,
    y,
    z
}

enum _:DRONE_STATUS (+=1)
{
	DRONE_STANDBY = 0,
	DRONE_CONTROL,
	DRONE_KILL
}

enum ROTATE_ORDER(+=1) {
	ROTATE_ORDER_PYR = 0,
	ROTATE_ORDER_RPY
}

enum _:DRONE_CVARS (+=1)
{
	CVAR_DRONE_SPEED = 0,
	CVAR_DRONE_GRAVITY,
	CVAR_DRONE_HEALTH
}

new const szCvars_data[][][] = {
	{ "jb_drone_speed", "400.0" },
	{ "jb_drone_gravity", "0.8" },
	{ "jb_drone_health", "300.0" }
}

new _:g_iCvars[DRONE_CVARS], boom, smoke, g_iTrailSprite, g_itemid, g_user_drone[33], DRONE_MODEL[64] = "models/jailbreak/drone.mdl";

new Float:g_user_rotation_angle[33][3];

public plugin_precache()
{
	smoke = precache_model("sprites/smoke.spr")
	boom = precache_model("sprites/zerogxplode.spr")
	g_iTrailSprite = precache_model("sprites/laserbeam.spr")
	jb_ini_get_keyvalue("DRONE", "DRONE_MODEL", DRONE_MODEL, charsmax(DRONE_MODEL))
	precache_model(DRONE_MODEL);
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	g_itemid = register_jailbreak_shopitem("Drone", "a flying drone", 25000, TEAM_GUARDS);
	
	register_think(drone_entity_classname, "fw_drone_brain");
	register_touch(drone_entity_classname, "worldspawn", "fw_drone_touch");
	
	RegisterHam(Ham_Think, "trigger_camera", "Camera_Think")
	RegisterHam(Ham_Killed, drone_entity_oldclassname, "fw_drone_killed_post", 1);
	
	for(new i; i < sizeof szCvars_data; i++)
	{
		g_iCvars[ i ] = register_cvar(szCvars_data[i][0], szCvars_data[i][1]);
	}
	
	//RegisterHam(Ham_ObjectCaps, drone_entity_oldclassname, "drone_objectcaps_pre");
	//RegisterHam(Ham_Use, drone_entity_oldclassname, "drone_use_pre");
	
	register_clcmd("drop", "clcmd_drop");
}

public clcmd_drop(id)
{
	if(g_user_drone[id] > 0)
	{
		new ent = g_user_drone[id];
		
		if(pev_valid(ent))
			entity_set_int(ent, DRONE_CURRENT_STATUS, DRONE_STANDBY);
		
		attach_view(id, id);
		g_user_drone[id] = 0;
		return 1;
	}
	return 0;
}

public fw_drone_touch(ent, toucher)
{
	if(pev_valid(ent))
	{
		static Float:fVelocity[3];
		entity_get_vector(ent, EV_VEC_velocity, fVelocity);
		if(pev(ent, pev_takedamage) != DAMAGE_NO && xs_vec_len(fVelocity) >= CRASH_SPEED)
		{
			ExecuteHamB(Ham_TakeDamage, ent, toucher, toucher, 25.0, DMG_CRUSH);
		}
	}
}

public fw_drone_killed_post(victim, attacker, gib)
{
	new classname[16];
	entity_get_string(victim, EV_SZ_classname, classname, charsmax(classname))
	
	if(!equal(drone_entity_classname, classname)) return HAM_IGNORED;
	
	new Float:fOrigin[3];
	pev(victim, pev_origin, fOrigin);
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	write_coord(floatround(fOrigin[0]))
	write_coord( floatround(fOrigin[1]))
	write_coord(  floatround(fOrigin[2]))
	write_short(boom)
	write_byte(50)
	write_byte(15)
	write_byte(0)
	message_end()
	
	if(pev_valid(victim))
	{
		new id = entity_get_int(victim, DRONE_OWNER);
		attach_view(id, id);
		g_user_drone[id] = 0;
	}
	
	return HAM_IGNORED;
}

public drone_use_pre(id, caller, activator, use_type, Float:value)
{
	new classname[16];
	entity_get_string(id, EV_SZ_classname, classname, charsmax(classname))
	
	if(!equal(drone_entity_classname, classname)) return HAM_IGNORED;
	
	attach_drone_player(caller, id)
	return HAM_SUPERCEDE;
}

attach_drone_player(iOwner, ent)
{
	entity_set_int(ent, DRONE_CURRENT_STATUS, DRONE_CONTROL);
	
	new ent2 = pev(ent, DRONE_CAMERA);
	//if(ent2 > 0) ExecuteHam(Ham_Use, ent2, iOwner, iOwner, USE_TOGGLE, 1.0)
	g_user_drone[iOwner] = ent;
	set_pev(iOwner, pev_maxspeed, -1.0);
	cprint_chat(iOwner, _, "You're driving the drone remotely!");
}

public drone_objectcaps_pre(id)
{
	new classname[16];
	entity_get_string(id, EV_SZ_classname, classname, charsmax(classname))
	
	if(!equal(drone_entity_classname, classname)) return HAM_IGNORED;
	
	SetHamReturnInteger(FCAP_IMPULSE_USE);
	return HAM_SUPERCEDE;
}

public jb_shop_item_bought(id, itemid)
{
	if(itemid == g_itemid)
	{
		g_user_rotation_angle[id][0] = g_user_rotation_angle[id][1] = g_user_rotation_angle[id][2] = 0.0;

		new ent = create_entity("info_target");
		
		if(!ent ) return;
		
		new Float:fSpawnOrigin[3], Float:fTemp[3];
		velocity_by_aim(id, 100, fTemp);
		fTemp[2] = 0.0;
		entity_get_vector(id, EV_VEC_origin, fSpawnOrigin);
		xs_vec_add(fSpawnOrigin, fTemp, fSpawnOrigin);

		xs_vec_normalize(fTemp, fTemp);
		vector_to_angle(fTemp, fTemp);
		entity_set_vector(ent, EV_VEC_angles, fTemp);
		
		entity_set_string(ent, EV_SZ_classname, drone_entity_classname);
		entity_set_vector(ent, EV_VEC_origin, fSpawnOrigin);
		entity_set_model(ent, DRONE_MODEL);
		entity_set_size(ent, Float:{-3.0,-3.0,-3.0}, Float:{3.0,3.0,3.0});
		entity_set_float(ent, EV_FL_takedamage, DAMAGE_YES);
		entity_set_float(ent, EV_FL_health, get_pcvar_float(g_iCvars[CVAR_DRONE_HEALTH]));
		entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
		entity_set_float(ent, EV_FL_maxspeed, get_pcvar_float(g_iCvars[CVAR_DRONE_SPEED]));
		set_pev(ent, pev_controller_0, 125);
		
		entity_set_int(ent, DRONE_CURRENT_STATUS, DRONE_STANDBY);
		
		entity_set_int(ent, DRONE_OWNER, id);
		
		entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.01);
		
		static iszTriggerCamera 
		if( !iszTriggerCamera ) 
		{ 
			iszTriggerCamera = engfunc(EngFunc_AllocString, "trigger_camera") 
		} 
		
		new iEnt = engfunc(EngFunc_CreateNamedEntity, iszTriggerCamera);
		
		if(iEnt > 0)
		{
			set_pev(iEnt, pev_globalname, "drone_camera");
			set_kvd(0, KV_ClassName, "trigger_camera") 
			set_kvd(0, KV_fHandled, 0) 
			set_kvd(0, KV_KeyName, "wait") 
			set_kvd(0, KV_Value, "999999") 
			dllfunc(DLLFunc_KeyValue, iEnt, 0) 
		
			set_pev(iEnt, pev_spawnflags, SF_CAMERA_PLAYER_TARGET|SF_CAMERA_PLAYER_POSITION) 
			set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_ALWAYSTHINK) 
		
			dllfunc(DLLFunc_Spawn, iEnt)

			set_pev(ent, DRONE_CAMERA, iEnt);
			
			set_pev(iEnt, pev_owner, ent);
			entity_set_edict(ent, EV_ENT_owner, iEnt);
			
			attach_drone_player(id, ent)
		}
	}
}

public Camera_Think(iEnt)
{
	static szGlobalname[32];
	pev(iEnt, pev_globalname, szGlobalname, charsmax(szGlobalname))
	if(!equal(szGlobalname, "drone_camera")) return ;
	
	static Float:fVecPlayerOrigin[3], Float:fVecCameraOrigin[3], Float:fVecAngles[3], Float:fVec[3], id;
	id = pev(iEnt, pev_owner);
	
	if(!pev_valid(id))
	{
		set_pev(iEnt, pev_flags, FL_KILLME);
		return;
	}
	
	pev(id, pev_origin, fVecPlayerOrigin) 
	pev(id, pev_angles, fVecAngles) 
	
	angle_vector(fVecAngles, ANGLEVECTOR_FORWARD, fVec);
	static Float:units; units = -50.0;
	
	//Move back/forward to see ourself
	fVecCameraOrigin[0] = fVecPlayerOrigin[0] + (fVec[0] * units)
	fVecCameraOrigin[1] = fVecPlayerOrigin[1] + (fVec[1] * units) 
	fVecCameraOrigin[2] = fVecPlayerOrigin[2] + (fVec[2] * units) + 5.0
	
	static tr2; tr2 = create_tr2();
	engfunc(EngFunc_TraceLine, fVecPlayerOrigin, fVecCameraOrigin, IGNORE_MONSTERS, id, tr2)
	static Float:flFraction
	get_tr2(tr2, TR_flFraction, flFraction)
	if( flFraction != 1.0 ) // adjust camera place if close to a wall 
	{
		flFraction *= units;
		fVecCameraOrigin[0] = fVecPlayerOrigin[0] + (fVec[0] * flFraction);
		fVecCameraOrigin[1] = fVecPlayerOrigin[1] + (fVec[1] * flFraction);
		fVecCameraOrigin[2] = fVecPlayerOrigin[2] + (fVec[2] * flFraction);
	}
	
	fVecAngles[0] *= -1;
	set_pev(iEnt, pev_origin, fVecCameraOrigin); 
	set_pev(iEnt, pev_angles, fVecAngles);
	
	free_tr2(tr2);
}

public fw_drone_brain(ent)
{
	static iOwner;
	iOwner = entity_get_int(ent, DRONE_OWNER);
	
	static iButtons, Float:fOrigin[3], Float:fvAngles[3], Float:fVector[3], Float:fVelocity[3] = {0.0, 0.0, 0.0}, Float:fSpeed, Float:fMaxSpeed, Float:fRotatedVector[3];
	fMaxSpeed = entity_get_float(ent, EV_FL_maxspeed);
	fSpeed = entity_get_float(ent, EV_FL_speed);
	iButtons = get_user_button(iOwner);
	entity_get_vector(ent, EV_VEC_velocity, fVelocity);
	entity_get_vector(ent, EV_VEC_angles, fvAngles);
	entity_get_vector(ent, EV_VEC_origin, fOrigin);
	
	if(xs_vec_len(fVelocity) > 0.0)
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(22)
		write_short(ent)
		write_short(smoke)
		write_byte(1)
		write_byte(10)
		write_byte(200)
		write_byte(200)
		write_byte(200)
		write_byte(128)
		message_end()
		
		set_pev(ent, pev_frame, 1);
		set_pev(ent, pev_framerate, 1.0);
	}
	else
	{
		set_pev(ent, pev_frame, 0);
		set_pev(ent, pev_framerate, 0.0);
	}
	
	switch( entity_get_int(ent, DRONE_CURRENT_STATUS) )
	{
		case DRONE_STANDBY:
		{
			static target;
			get_user_aiming(iOwner, target)
			if(target == ent && iButtons & IN_USE && !(pev(iOwner, pev_oldbuttons) & IN_USE))
			{
				attach_drone_player(iOwner, ent);
			}
			
			entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.01);
		}
		case DRONE_CONTROL:
		{
			if(iButtons & IN_FORWARD)
			{
				entity_set_float(ent, EV_FL_speed, (fSpeed = floatmin(fSpeed + 10.0, fMaxSpeed)));
			}
			else if(iButtons & IN_BACK)
			{
				entity_set_float(ent, EV_FL_speed, (fSpeed = floatmax(fSpeed - 10.0, 0.0)));
			}

			if(fSpeed > 0.0)
			{
				angle_vector(fvAngles, ANGLEVECTOR_FORWARD, fVector);
				xs_vec_mul_scalar(fVector, fSpeed, fVelocity);
			}

			static Float:fvForward[3], Float:fvBackward[3], Float:fvRight[3], Float:fvLeft[3], Float:fvUP[3];
			angle_vector(fvAngles, ANGLEVECTOR_FORWARD, fvForward);
			xs_vec_neg(fvForward, fvBackward);
			angle_vector(fvAngles, ANGLEVECTOR_RIGHT, fvRight);
			xs_vec_neg(fvRight, fvLeft);
			angle_vector(fvAngles, ANGLEVECTOR_UP, fvUP);

			draw_line(iOwner, fvForward[0], fvForward[1], fvForward[2], fvForward[0] * 50.0, fvForward[1] * 50.0, fvForward[2] * 50.0, {0,200,0}, fOrigin);
			draw_line(iOwner, fvRight[0], fvRight[1], fvRight[2], fvRight[0] * 50.0, fvRight[1] * 50.0, fvRight[2] * 50.0, {200,0,0}, fOrigin);
			draw_line(iOwner, fvUP[0], fvUP[1], fvUP[2], fvUP[0] * 50.0, fvUP[1] * 50.0, fvUP[2] * 50.0, {0,0,200}, fOrigin);

			if(iButtons & IN_MOVERIGHT || iButtons & IN_RIGHT)
			{
				fvAngles[2] += 5.0;
				entity_set_vector(ent, EV_VEC_angles, fvAngles);
			}
			else if(iButtons & IN_MOVELEFT || iButtons & IN_LEFT)
			{
				fvAngles[2] -= 5.0;
				entity_set_vector(ent, EV_VEC_angles, fvAngles);
			}
			else if (iButtons & IN_JUMP)
			{
				rotateVector3D(fvForward, 0.0, 5.0, 0.0, fRotatedVector);
				new Float:fAngle = xs_vec_angle(fvForward, fRotatedVector);
				fRotatedVector[0] = floatpower(floatcos(fAngle,degrees), 2.0) * fAngle;
				fRotatedVector[1] = floatpower(floatsin(fAngle,degrees), 2.0) * fAngle;
				xs_vec_add(fvAngles, fRotatedVector, fvAngles);
				entity_set_vector(ent, EV_VEC_angles, fvAngles);
			}
			else if (iButtons & IN_DUCK)
			{
				rotateVector3D(fvForward, 0.0, 5.0, 0.0, fRotatedVector);
				new Float:fAngle = xs_vec_angle(fvForward, fRotatedVector);
				fRotatedVector[0] = floatcos(fAngle,degrees) * fAngle;
				fRotatedVector[1] = floatsin(fAngle,degrees) * fAngle;
				xs_vec_add(fvAngles, fRotatedVector, fvAngles);
				entity_set_vector(ent, EV_VEC_angles, fvAngles);
			}

			// lets make sure the drone doesn't exceed the maximum speed limits.
			if(xs_vec_len(fVelocity) > fMaxSpeed)
			{
				xs_vec_normalize(fVelocity, fVelocity);
				xs_vec_mul_scalar(fVelocity, fMaxSpeed, fVelocity);
			}

			fVelocity[2] *= -1.0;
			//entity_set_vector(ent, EV_VEC_angles, fvAngles);
			entity_set_vector(ent, EV_VEC_velocity, fVelocity);
			entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.1);
		}
		case DRONE_KILL:
		{
			// more stuff to think about
		}
	}
}

enum any:VECTOR(+=1)
{
    x = 0,
    y,
    z,
    VECTOR_SIZE
}

// Function to rotate a vector in 3D
rotateVector3D(const Float:vec[3], const Float:yaw, const Float:pitch, Float:roll, Float:rotatedVec[3])
{
		// Convert pitch and yaw angles to radians
		new Float:pitchRad = pitch * (M_PI / 180.0);
		new Float:yawRad = yaw * (M_PI / 180.0);
		new Float:rollRad = roll * (M_PI / 180.0);

		// Calculate the sine and cosine of the angles
		new Float:cy = floatcos(yawRad);
		new Float:sy = floatsin(yawRad);
		new Float:cp = floatcos(pitchRad);
		new Float:sp = -floatsin(pitchRad);
		new Float:cr = floatcos(rollRad);
		new Float:sr = floatsin(rollRad);

		// Calculate the elements of the rotation matrix

		new Float:matrix[4][4];
		xs_vec_set(matrix[0], cy * cp, cy * sp * sr - sy * cr, cy * sp * cr + sy * sr);
		xs_vec_set(matrix[1], sy * cp, sy * sp * sr + cy * cr, sy * sp * cr - cy * sr);
		xs_vec_set(matrix[2], -sp, cp * sr, cp * cr);
		matrix[3][3] = 1.0;

		// Extend the vector to a 4D vector with a homogeneous coordinate of 1
		new Float:vector_homogeneous[VECTOR_SIZE+1], Float:rotated_vector_homogeneous[VECTOR_SIZE+1];
		vector_homogeneous[x] = any:vec[x];
		vector_homogeneous[y] = any:vec[y];
		vector_homogeneous[z] = any:vec[z];
		vector_homogeneous[3] = 1.0;

		// Perform the matrix-vector multiplication
		for (new i = 0; i < 4; i++)
		{
		    rotated_vector_homogeneous[i] = 0.0;
		    for (new j = 0; j < 4; j++)
		    {
		        rotated_vector_homogeneous[i] += matrix[i][j] * vector_homogeneous[j];
		    }
		}

		// Normalize the resulting vector
		if(rotated_vector_homogeneous[3] != 0.0)
		{
		  rotatedVec[x] = rotated_vector_homogeneous[0] / rotated_vector_homogeneous[3];
		  rotatedVec[y] = rotated_vector_homogeneous[1] / rotated_vector_homogeneous[3];
		  rotatedVec[z] = rotated_vector_homogeneous[2] / rotated_vector_homogeneous[3];
		}
}

stock draw_line(id, Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, iColor[3], Float:fOrigin[3])
{
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, SVC_TEMPENTITY, _, id ? id : 0);

	write_byte(TE_BEAMPOINTS);

	write_coord(floatround(x1 + fOrigin[0]));
	write_coord(floatround(y1 + fOrigin[1]));
	write_coord(floatround(z1 + fOrigin[2]));

	write_coord(floatround(x2 + fOrigin[0]));
	write_coord(floatround(y2 + fOrigin[1]));
	write_coord(floatround(z2 + fOrigin[2]));

	write_short(g_iTrailSprite);
	write_byte(1); // frame
	write_byte(10); // framestart
	write_byte(3); // life
	write_byte(30);
	write_byte(0);

	write_byte(iColor[0]);
	write_byte(iColor[1]);
	write_byte(iColor[2]);

	write_byte(200);
	write_byte(0);

	message_end();
}

stock Float:RadiansToDegrees(Float:fRadians)
{
	return ((fRadians * 180.0) / M_PI);
}

stock Float:DegreesToRadians(Float:fDegrees)
{
	return (fDegrees * (M_PI / 180.0));
}