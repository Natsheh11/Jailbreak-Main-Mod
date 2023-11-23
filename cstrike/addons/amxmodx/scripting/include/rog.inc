#if defined _rog_included
#endinput
#endif
#define _rog_included

#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <fun>
#include <xs>

#define ROG_MAX_LOCATIONS 256

new Array:FoundOriginsArray, CurrentPositionInArray, g_FoundOriginsArraySize;

stock ROGInitialize(Float:MinDistance, const CheckFunction[] = "")
{
	new Float:RefOrigin[3] = {0.0,0.0,0.0};
	if(FoundOriginsArray == Invalid_Array)
	{
		FoundOriginsArray = ArrayCreate(3);
		g_FoundOriginsArraySize = 0;
	}
	else
	{
		//Support for multiple calls for ROGInitialize
		ArrayClear(FoundOriginsArray);
		g_FoundOriginsArraySize = 0;
	}

	for(new Float:fYOffset = 4096.0, Float:fMinHeight = (-4096.0 + 72.0); fYOffset > fMinHeight; fYOffset -= 256.0)
	{
		RefOrigin[2] = fYOffset;
		SearchForOrigins(RefOrigin, 4096.0, CheckFunction, Float:MinDistance);
	}
}

stock ROGOriginsCount()
{
	return ArraySize(FoundOriginsArray);
}

stock ROGGetOrigin(Float:Origin[3])
{
	if(CurrentPositionInArray >= ArraySize(FoundOriginsArray))
	{
		CurrentPositionInArray = 0
	}
	
	ArrayGetArray(FoundOriginsArray, CurrentPositionInArray, Origin)
	CurrentPositionInArray = CurrentPositionInArray + 1
}

stock ROGShuffleOrigins()
{
	new Size = ArraySize(FoundOriginsArray), j, Float:FirstOrigin[3], Float:SecondOrigin[3]
	for (new i = Size - 1; i > 0; i--)
	{
		j = random_num(0, i)
		ArrayGetArray(FoundOriginsArray, i, FirstOrigin)
		ArrayGetArray(FoundOriginsArray, j, SecondOrigin)
		ArraySetArray(FoundOriginsArray, i, SecondOrigin)
		ArraySetArray(FoundOriginsArray, j, FirstOrigin)
	}

	CurrentPositionInArray = 0;
}

stock ROGDumpOriginData()
{
	new Float:EntityOrigin[3], i
	new Size = ArraySize(FoundOriginsArray)
	
	for(i = 0; i < Size; i++)
	{
		ArrayGetArray(FoundOriginsArray, i, EntityOrigin)
		server_print("[%d] %f %f %f", i, EntityOrigin[0], EntityOrigin[1], EntityOrigin[2])
	}
	
	server_print("Generated %d random origins", i)
}

stock AddEntityIfFound(const ClassName[])
{
	new Entity = find_ent_by_class(-1, ClassName)
	if(pev_valid(Entity))
	{
		ArrayPushCell(DefaultMapEntitiesArray, Entity)
		return 1
	}
	
	return 0
}

stock ROGFindLocationAroundOrigin(Float:fOrigin[3], const Float:fMaxs[3], const Float:fMins[3], const Float:fDistance, const bool:bRandom=false, &Array:pArrayLocations = any:-1)
{
	fOrigin[2] += floatabs(fMins[2]);

	static iTr2, Float:fTestOrigin[3], Float:fStart[3], Float:fEnd[3], Float:fYShift, Float:fXShift, i, d, iSafe;

	static iOrder[][][3] =
	{
		{ {  0,  0,  1 }, {  0,  0, -1 } }, // Inner line
		{ {  1,  1,  1 }, {  1,  1, -1 } }, // 4 square lines SIDES
		{ { -1, -1,  1 }, { -1, -1, -1 } },
		{ { -1,  1,  1 }, { -1,  1, -1 } },
		{ {  1, -1,  1 }, {  1, -1, -1 } },
		{ {  1,  1,  1 }, { -1,  1,  1 } }, // 4 square lines TOP
		{ {  1,  1,  1 }, {  1, -1,  1 } },
		{ { -1, -1,  1 }, { -1,  1,  1 } },
		{ { -1, -1,  1 }, {  1, -1,  1 } },
		{ {  1,  1, -1 }, { -1,  1, -1 } }, // 4 square lines BOTTOM
		{ {  1,  1, -1 }, {  1, -1, -1 } },
		{ { -1, -1, -1 }, { -1,  1, -1 } },
		{ { -1, -1, -1 }, {  1, -1, -1 } },
		{ {  1,  1,  1 }, { -1,  1, -1 } }, // front cross
		{ {  1,  1, -1 }, { -1,  1,  1 } },
		{ {  1, -1,  1 }, { -1, -1, -1 } }, // back cross
		{ {  1, -1, -1 }, { -1, -1,  1 } },
		{ {  1,  1,  1 }, {  1, -1, -1 } }, // right cross
		{ {  1,  1, -1 }, {  1, -1,  1 } },
		{ { -1,  1,  1 }, { -1, -1, -1 } }, // left cross
		{ { -1,  1, -1 }, { -1, -1,  1 } },
		{ {  1,  1,  1 }, { -1, -1,  1 } }, // up cross
		{ {  1, -1,  1 }, { -1,  1,  1 } },
		{ {  1,  1, -1 }, { -1, -1, -1 } }, // down cross
		{ {  1, -1, -1 }, { -1,  1, -1 } }
	};

	fXShift = (fMaxs[0] - fMins[0]) ;
	fYShift = (fMaxs[1] - fMins[1]) ;

	const sizeofOrder = sizeof iOrder;

	iTr2 = create_tr2();

	fTestOrigin[1] = fOrigin[1] + fDistance;
	fTestOrigin[2] = fOrigin[2];

	static Float:flFraction, Float:fAngle, Float:fvBegin[3], Array:pTempArray=Invalid_Array;

	if(bRandom || pArrayLocations != Array:-1)
	{
		pTempArray = ArrayCreate(3, 1);
	}

	while( floatabs(fTestOrigin[1] - fOrigin[1]) <= fDistance  )
	{
		fAngle = floatasin( (fTestOrigin[1] - fOrigin[1]) / fDistance, degrees );
		fvBegin[0] = floatcos(fAngle,degrees) * fDistance;
		fvBegin[1] = floatsin(fAngle,degrees) * fDistance;
		fTestOrigin[0] = fOrigin[0] + fvBegin[0];

		while( get_distance_f(fTestOrigin, fOrigin) <= fDistance )
		{
			for( i = iSafe = 0; i < sizeofOrder; i++ )
			{
				for( d = 0; d < 3; d++ )
				{
					switch( iOrder[i][0][d] )
					{
						case -1: fStart[d] = fTestOrigin[d] + fMins[d];
						case 0: fStart[d] = fTestOrigin[d];
						case 1: fStart[d] = fTestOrigin[d] + fMaxs[d];
					}

					switch( iOrder[i][1][d] )
					{
						case -1: fEnd[d] = fTestOrigin[d] + fMins[d];
						case 0: fEnd[d] = fTestOrigin[d];
						case 1: fEnd[d] = fTestOrigin[d] + fMaxs[d];
					}
				}

				// Traces...
				engfunc(EngFunc_TraceLine, fStart, fEnd, DONT_IGNORE_MONSTERS, -1, iTr2);
				get_tr2(iTr2, TR_flFraction, flFraction);
				if(flFraction == 1.0 && get_tr2(iTr2, TR_InOpen) && !get_tr2(iTr2, TR_StartSolid) && !get_tr2(iTr2, TR_AllSolid))
				{
					iSafe++;
					continue;
				}

				break;
			}

			if(iSafe >= sizeofOrder)
			{
				if(pTempArray == Invalid_Array)
				{
					xs_vec_copy(fTestOrigin, fOrigin);
					free_tr2(iTr2);
					return 1;
				}

				ArrayPushArray(pTempArray, fTestOrigin);
			}

			fTestOrigin[0] -= fXShift;
		}

		fTestOrigin[1] -= fYShift;
	}

	if(pTempArray != Invalid_Array)
	{
		if((i=ArraySize(pTempArray)) && bRandom)
		{
			ArrayGetArray(pTempArray, random(i), fOrigin);
		}

		if(pArrayLocations == any:-1)
		{
			ArrayDestroy(pTempArray);
		}
		else
		{
			pArrayLocations = pTempArray;
		}

		pTempArray = Invalid_Array;
		free_tr2(iTr2);
		return i;
	}

	free_tr2(iTr2);
	return 0;
}

stock SearchForOrigins(Float:ReferenceOrigin[3], Float:Radius, const CheckFunction[], const Float:MinDistance)
{
	new Float:RandomOrigin[3], Float:SkyOrigin[3], Float:FloorOrigin[3], Float:PlaneNormal[3], Float:BackupOrigin[3];
	new CallState, CallReturnValue;
	
	new Array:test = ArrayCreate(3);
	new iLocations = ROGFindLocationAroundOrigin(ReferenceOrigin, Float:{16.0,16.0,36.0}, Float:{-16.0,-16.0,-36.0}, Radius, .pArrayLocations=test);

	//Don't add the origin if it's too close to another origin
	new OriginsCount,
	Float:OriginToCompare[3],
	bool:IsTooClose, bool:IsVisible,
	Float:ClosestOrigin[3], Float:MinimumDistance, Float:Distance;
	
	for(new i = 0, j, Item; i < iLocations; i++)
	{
		ArrayGetArray(test, (Item=random(iLocations)), RandomOrigin);
		
		//Detect the floor, so we don't spawn the player in air
		FloorOrigin[0] = RandomOrigin[0];
		FloorOrigin[1] = RandomOrigin[1];
		FloorOrigin[2] = -8192.0
		
		BackupOrigin = RandomOrigin;
		
		engfunc(EngFunc_TraceLine, RandomOrigin, FloorOrigin, DONT_IGNORE_MONSTERS, 0, 0);
		get_tr2(0, TR_vecEndPos, RandomOrigin);
		RandomOrigin[2] += 38.0;

		get_tr2(0, TR_vecPlaneNormal, PlaneNormal) 
		if(PlaneNormal[2] < 0.7) 
		{
			//ground is too steep, player will start sliding down most likely
			//also if it's that steep players shouldn't be able to climb it, could be an unreachable spot
			//0.7 seems to be used in the bot navigation code from regamedll
			ArrayDeleteItem(test, Item);
			iLocations--; i--;
			continue;
		}
		
		engfunc(EngFunc_TraceHull, BackupOrigin, RandomOrigin, IGNORE_MONSTERS, HULL_HUMAN, -1, 0)

		if(pev_valid( get_tr2(0, TR_pHit) ))
		{
			ArrayDeleteItem(test, Item);
			iLocations--; i--;
			continue;
		}
		
		if(PointContents(RandomOrigin) == CONTENTS_EMPTY)
		{
			if(ValidSpotFound(RandomOrigin))
			{
				//Find where the sky/roof is
				SkyOrigin[0] = RandomOrigin[0];
				SkyOrigin[1] = RandomOrigin[1];
				SkyOrigin[2] = 8192.0
				
				engfunc(EngFunc_TraceLine, RandomOrigin, SkyOrigin, DONT_IGNORE_MONSTERS, -1, 0);
				get_tr2(0, TR_vecEndPos, SkyOrigin);
				
				if(PointContents(SkyOrigin) == CONTENTS_SKY)
				{
					if(get_distance_f(RandomOrigin, SkyOrigin) < 250)
					{
						//On maps like de_dust2 players could spawn on the map texture
						//All this points are less than 249 units from the sky
						//By detecting where the sky is and checking the distance we avoid this scenario
						ArrayDeleteItem(test, Item);
						iLocations--; i--;
						continue;
					}
				}

				IsTooClose = IsVisible = false;
				MinimumDistance = 9999.9

				for(j = 0, OriginsCount = ArraySize(FoundOriginsArray); j < OriginsCount; j++)
				{
					ArrayGetArray(FoundOriginsArray, j, OriginToCompare)
					
					Distance = get_distance_f(RandomOrigin, OriginToCompare)
					if(Distance < MinDistance)
					{
						IsTooClose = true;
						break;
					}
					
					if(Distance < MinimumDistance)
					{
						MinimumDistance = Distance;
						ClosestOrigin = OriginToCompare
					}
					
				}
				
				if(!IsTooClose)
				{
					if(MinimumDistance == 9999.9)
					{
						ClosestOrigin = ReferenceOrigin;
					}
					
					if(CheckPointsForVisibility(RandomOrigin, ClosestOrigin))
					{
						IsVisible = true;
					}
					
					if(IsVisible)
					{
						if(CheckFunction[0] != EOS)
						{
							CallState = callfunc_begin(CheckFunction);
							if(CallState == 1)
							{
								callfunc_push_array(_:RandomOrigin, sizeof(RandomOrigin));
								CallReturnValue = callfunc_end();
								if(!CallReturnValue)
								{
									ArrayDeleteItem(test, Item);
									iLocations--; i--;
									continue;
								}
							}
						}

						ArrayPushArray(FoundOriginsArray, RandomOrigin);

						if(++g_FoundOriginsArraySize >= ROG_MAX_LOCATIONS)
						{
							break;
						}
					}
				}
			}
		}

		ArrayDeleteItem(test, Item);
		iLocations--; i--;
	}
	
	ArrayDestroy(test);
}

stock bool:ValidSpotFound(Float:Origin[3])
{
	new HandleTraceHull 
	engfunc(EngFunc_TraceHull, Origin, Origin, DONT_IGNORE_MONSTERS, HULL_HUMAN, 0, HandleTraceHull)    
	if(get_tr2(HandleTraceHull, TR_InOpen) && !(get_tr2(HandleTraceHull, TR_StartSolid) || get_tr2(HandleTraceHull, TR_AllSolid))) 
	{
		return true
	}    
	
	return false
}

stock CheckPointsForVisibility(Float:RandomOrigin[3], Float:ReferenceOrigin[3])
{	
	new Float:CopyReferenceOrigin[3]; CopyReferenceOrigin = ReferenceOrigin
	new Float:CopyRandomOrigin[3]; CopyRandomOrigin = RandomOrigin
	new Float:InitialRandomOrigin[3], Float:InitialReferenceOrigin[3]
	InitialRandomOrigin = CopyRandomOrigin
	InitialReferenceOrigin = CopyReferenceOrigin
	
	new Float:Fraction, Float:TraceEndOrigin[3]
	for(new i = 0; i < 7; i++)
	{		
		CopyRandomOrigin[2] = CopyRandomOrigin[2] + 100.0
		CopyReferenceOrigin[2] = CopyReferenceOrigin[2] + 100.0
		
		engfunc(EngFunc_TraceLine, InitialRandomOrigin, CopyRandomOrigin, IGNORE_GLASS, -1, 0)
		get_tr2(0, TR_vecEndPos, TraceEndOrigin)
		if(PointContents(TraceEndOrigin) == CONTENTS_SKY)
		{
			break
		}
		
		
		engfunc(EngFunc_TraceLine, InitialReferenceOrigin, CopyReferenceOrigin, IGNORE_GLASS, -1, 0)
		get_tr2(0, TR_vecEndPos, TraceEndOrigin)
		if(PointContents(TraceEndOrigin) == CONTENTS_SKY)
		{
			break
		}
		
		engfunc(EngFunc_TraceLine, CopyRandomOrigin, CopyReferenceOrigin, IGNORE_GLASS, -1, 0)
		get_tr2(0, TR_flFraction, Fraction)
		
		if(Fraction == 1.0)
		{
			return true
		}
	}

	return false
}

ROGFree()
{
	ArrayDestroy(FoundOriginsArray);
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
