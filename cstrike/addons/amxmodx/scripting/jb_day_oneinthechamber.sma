#include <amxmodx>
#include <fun>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <jailbreak_core>

new const PLUGIN_NAME[] = "[JB] DAY: One In The Chamber";
new const PLUGIN_AUTH[] = "Natsheh";
new const PLUGIN_VERS[] = "v1.0";

// Day variables
new g_iDAY, HamHook:g_FW_PLAYER_KILLED_POST;

const DAY_WEAPONS = (1<<CSW_KNIFE)|(1<<CSW_DEAGLE);

public plugin_init()
{
  register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);

  // Register this day
  g_iDAY = register_jailbreak_day("One In The Chamber", 0, 500.0, DAY_ONE_SURVIVOR);

  // Track events
  DisableHamForward((g_FW_PLAYER_KILLED_POST=RegisterHam(Ham_Killed, "player", "Fw_Player_Killed_post", true)));
}

public jb_day_started(iDayID)
{
  if(iDayID != g_iDAY) return;

  EnableHamForward(g_FW_PLAYER_KILLED_POST);

  new players[32], playerID, playersCount;
  get_players(players, playersCount, "ah");

  for (new i = 0, ent; i < playersCount; i++)
  {
    playerID = players[i];
    strip_user_weapons(playerID);
    
    set_pev(playerID, pev_health, 1.0);

    give_item(playerID, "weapon_knife");
    if((ent = give_item(playerID, "weapon_deagle")) > 0)
      cs_set_weapon_ammo(ent, 1);

    cs_set_user_bpammo(playerID, CSW_DEAGLE, 0);
    jb_block_user_weapons(playerID, true, ~DAY_WEAPONS);
  }
}

public jb_day_end(iDayID)
{
  if(iDayID != g_iDAY) return;

  DisableHamForward(g_FW_PLAYER_KILLED_POST);

  new players[32], playerID, playersCount;
  get_players(players, playersCount, "h");

  for (new i = 0, fMaxHP; i < playersCount; i++)
  {
    playerID = players[i];

    if(is_user_alive(playerID))
    {
      strip_user_weapons(playerID);
      give_item(playerID, "weapon_knife");

      pev(playerID, pev_max_health, fMaxHP);
      set_pev(playerID, pev_health, fMaxHP);
    }

    jb_block_user_weapons(playerID, false);
  }
}

public Fw_Player_Killed_post(victim, killer, shouldgib)
{
  if(victim != killer && is_user_alive(killer))
  {
    new ent;
    if((ent=find_ent_by_owner(-1, "weapon_deagle", killer)))
    {
      cs_set_weapon_ammo(ent, 1);
      cs_set_user_bpammo(killer, CSW_DEAGLE, 0);
    }
  }
}
