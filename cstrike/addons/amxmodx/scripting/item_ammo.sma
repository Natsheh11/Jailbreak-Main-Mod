/* Sublime AMXX Editor v2.2 */

#define REGAMEDLL

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <cstrike>
#if defined REGAMEDLL
#include <reapi>
#else
#include <orpheu>
#endif

#define PLUGIN  "ITEM AMMO"
#define VERSION "1.0"
#define AUTHOR  "Natsheh"

const MAX_AMMO_TYPES = 32;

new const AMMO_MODEL[] = "models/w_ammo_fixed.mdl";

#if defined REGAMEDLL
new const g_szAmmoTypes[][] = {
    "", // NULL
    "ammo_338magnum",
    "ammo_762nato",
    "ammo_556natobox",
    "ammo_556nato",
    "ammo_buckshot",
    "ammo_45acp",
    "ammo_57mm",
    "ammo_50ae",
    "ammo_357sig",

    "ammo_9mm",
    "", // flashbang
    "", // hegrenade
    "", // smokegrenade
    "", // c4
    "",
    "",
    "",
    "",
    "",

    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",

    ""
}
#else
new Trie:g_trie_AmmoName = Invalid_Trie, g_iAmmoIndexesCount = 0;
#endif

new g_iMsgAmmoPickUp;

public plugin_end()
{
#if !defined REGAMEDLL
    if(g_trie_AmmoName != Invalid_Trie)
        TrieDestroy(g_trie_AmmoName);
#endif
}

public plugin_precache()
{
#if !defined REGAMEDLL
    g_trie_AmmoName = TrieCreate();
    OrpheuRegisterHook(OrpheuGetFunction("AddAmmoNameToAmmoRegistry", "CBaseEntity"), "fw_AddAmmoNameToAmmoRegistryPost", .phase = OrpheuHookPost);
#endif
    precache_model(AMMO_MODEL);
}

#if !defined REGAMEDLL
public fw_AddAmmoNameToAmmoRegistryPost(ent, const szAmmoName[])
{
    if(TrieKeyExists(g_trie_AmmoName, szAmmoName))
    {
        return;
    }

    new szKey[4];
    num_to_str(++g_iAmmoIndexesCount, szKey, charsmax(szKey));
    TrieSetString(g_trie_AmmoName, szKey, szAmmoName);
    TrieSetString(g_trie_AmmoName, szAmmoName, szKey);
}
#endif

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    RegisterHam(Ham_Killed, "player", "fw_player_killed_post", 1);
    register_touch("ammo_box", "player", "ammo_box_touched");

    register_event("HLTV", "event_HLTV", "a", "1=0", "2=0");

    g_iMsgAmmoPickUp = get_user_msgid("AmmoPickup");
}

public event_HLTV()
{
    DestroyAllAmmoPacks();
}

DestroyAllAmmoPacks()
{
    new ent = -1;
    while( (ent = find_ent_by_class(ent, "ammo_box")) > 0 )
    {
        set_pev(ent, pev_flags, FL_KILLME);
        dllfunc(DLLFunc_Think, ent);
    }
}

public ammo_box_touched(const this, const other)
{
    ammo_pickedup(.id = other, .ammo_ent = this);
}

ammo_pickedup(id, const ammo_ent)
{
  new iAdd = pev(ammo_ent, pev_iuser1);
  new iAmmoType = pev(ammo_ent, pev_body);

  set_pev(ammo_ent, pev_flags, FL_KILLME);
  dllfunc(DLLFunc_Think, ammo_ent);

  set_ent_data(id, "CBasePlayer", "m_rgAmmo", get_ent_data(id, "CBasePlayer", "m_rgAmmo", iAmmoType) + iAdd, iAmmoType);

  // Send the message that ammo has been picked up
  message_begin(MSG_ONE, g_iMsgAmmoPickUp, _, id);
  write_byte(iAmmoType); // ammo ID
  write_byte(iAdd); // amount
  message_end();

  emit_sound(id, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public fw_player_killed_post(victim)
{
    DropPlayerAmmunition(victim);
}

DropPlayerAmmunition(const id)
{
    new Float:fRandomVelo[3] = { 0.0, 0.0, 32.0 };

    for(new i, iAmmoCount, Float:fOrigin[3]; i < MAX_AMMO_TYPES; i++)
    {
        iAmmoCount = get_ent_data(id, "CBasePlayer", "m_rgAmmo", i);

        if(iAmmoCount > 0)
        {
            pev(id, pev_origin, fOrigin);
            set_ent_data(id, "CBasePlayer", "m_rgAmmo", 0, i);

            fRandomVelo[0] = random_float(-16.0, 16.0);
            fRandomVelo[1] = random_float(-16.0, 16.0);
            create_ammobox(i, iAmmoCount, fOrigin, .fVelocity = fRandomVelo, .pPrevOwner = id);
        }
    }
}

create_ammobox(const ammotype, const ammocount, const Float:fOrigin[3], const Float:fAngles[3] = {0.0,0.0,0.0}, const Float:fVelocity[3] = {0.0,0.0,0.0}, const pPrevOwner = 0)
{
#if !defined REGAMEDLL
    new szAmmoName[32], szKey[4];
    num_to_str(ammotype, szKey, charsmax(szKey));
    TrieGetString(g_trie_AmmoName, szKey, szAmmoName, charsmax(szAmmoName));
#else
    new szAmmoName[32];
    copy(szAmmoName, charsmax(szAmmoName), g_szAmmoTypes[ammotype]);
#endif

    new ammo_entity = create_entity("info_target")

    if(ammo_entity > 0)
    {
        set_pev(ammo_entity, pev_classname, "ammo_box");
        set_pev(ammo_entity, pev_netname, szAmmoName);

        set_pev(ammo_entity, pev_spawnflags, pev(ammo_entity, pev_spawnflags) | SF_NORESPAWN);
        set_pev(ammo_entity, pev_movetype, MOVETYPE_TOSS);
        set_pev(ammo_entity, pev_solid, SOLID_TRIGGER);
        set_pev(ammo_entity, pev_body, ammotype);
        set_pev(ammo_entity, pev_iuser1, ammocount);
        set_pev(ammo_entity, pev_owner, pPrevOwner);
        set_pev(ammo_entity, pev_angles, fAngles);
        set_pev(ammo_entity, pev_velocity, fVelocity);

        engfunc(EngFunc_SetOrigin, ammo_entity, fOrigin);
        engfunc(EngFunc_SetModel, ammo_entity, AMMO_MODEL);
        engfunc(EngFunc_SetSize, ammo_entity, Float:{ -16.0, -16.0, -0.0 }, Float:{ 16.0, 16.0, 16.0 });

        //dllfunc(DLLFunc_Spawn, ammo_entity);
    }

    return ammo_entity;
}
