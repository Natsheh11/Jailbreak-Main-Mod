#if defined _round_terminator_included
  #endinput
#endif
#define _round_terminator_included

#pragma reqlib round_terminator


enum TR_RoundEndType(+=1)/* Round End Type */
{
    TR_RoundEndType_Timer = 0,
    TR_RoundEndType_TeamExterminate,
    TR_RoundEndType_Objective,
    TR_RoundEndType_Draw
};

enum (+=1)/* Team Winning */
{
    TeamWinning_Terrorist = 1,
    TeamWinning_Ct,
    TeamWinning_None
};

enum (+=1)/* Map Type */
{ 
    MapType_AutoDetect = 0,
    MapType_VipAssasination,
    MapType_Bomb,
    MapType_Hostage,
    MapType_PrisonEscape
};

/**
 *  Force a round to end whatever the conditions.
 * 
 *  Here all the possibilities of this native, 
 *  to avoid further questions : 
 *
 *      // Time is up / round draw.
 *
 *      TerminateRound( RoundEndType_Timer );
 *      TerminateRound( RoundEndType_Draw );
 *   
 *      // One of the team has been exterminated.
 *
 *      TerminateRound( RoundEndType_TeamExtermination, TeamWinning_Terrorist );
 *      TerminateRound( RoundEndType_TeamExtermination, TeamWinning_Ct );
 *
 *      // The current map objective of the team has been completed.
 *
 *      TerminateRound( RoundEndType_Objective, TeamWinning_Terrorist );
 *      TerminateRound( RoundEndType_Objective, TeamWinning_Ct );
 *   
 *      // The provided map objective of the team has been completed. (will work only if the related entity is present)
 *
 *      TerminateRound( RoundEndType_Objective, TeamWinning_Terrorist, MapType_VipAssasination );
 *      TerminateRound( RoundEndType_Objective, TeamWinning_Terrorist, MapType_Bomb );
 *      TerminateRound( RoundEndType_Objective, TeamWinning_Terrorist, MapType_PrisonEscape );
 *      TerminateRound( RoundEndType_Objective, TeamWinning_Ct, MapType_VipAssasination );
 *      TerminateRound( RoundEndType_Objective, TeamWinning_Ct, MapType_Bomb );
 *      TerminateRound( RoundEndType_Objective, TeamWinning_Ct, MapType_Hostage );
 *      TerminateRound( RoundEndType_Objective, TeamWinning_Ct, MapType_PrisonEscape );
 *
 *  @param roundEndType     The round end type you want to force.
 *  @param teamWinning      The team winning if the round type end is either team extermination or objective.
 *  @param mapType          The map type if there are severals objectives on the map.
 */
native TerminateRound( const TR_RoundEndType:roundEndType, const teamWinning = TeamWinning_None, const mapType = MapType_AutoDetect );

/**
    Call CheckWinConditions
 */
native CheckWinConditions();
