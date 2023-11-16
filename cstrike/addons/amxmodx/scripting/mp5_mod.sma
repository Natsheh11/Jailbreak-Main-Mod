#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <jailbreak_core>
#include <vip_core>
#include <fun>
#include <fakemeta>
#include <engine>
#include <cstrike>
#include <xs>
#include <orpheu>
#include <orpheu_stocks>
#include <reapi>

#define IsPlayer(%1) (1 <= %1 <= 32)

#define PEV_WEAPON_TYPE pev_iuser4
#define WEAPON_TYPE_MP5M203 780
const PEV_OBSERVER_MODE = pev_iuser1;
const PEV_SPECTATOR_TARGET = pev_iuser2;

new const MP5M203_CLASSNAME[] = "weapon_mp5m203";
new const M203_NADE_CLASSNAME[] = "m203_grenade";
new const M203_AMMO_CLASSNAME[] = "ammo_m203";
new const M203_NADE_MODEL[] = "models/grenade.mdl";
new const MP5M203_WEAPON_VIEW_MODEL[] = "models/v_mp5m203.mdl";
new const MP5M203_WEAPON_PLAYER_MODEL[] = "models/p_9mmar.mdl";
new const MP5M203_WEAPON_WORLD_MODEL[] = "models/w_9mmar.mdl";
new const g_noammo_sounds[][] = {"weapons/dryfire_rifle.wav"};
const CSW_MP5M203 = CSW_MP5NAVY;
const ANIME_MP5M203_M203_NADE_FIRE = 3;
const MAX_MP5M203_CLIP = 50;
const CS_AMMO_ID_9MM = 10;
const CS_AMMO_ID_M203 = 15;

new g_bHasMP5M203, g_pJBShopItem, g_PlayerDroppedMp5M203[MAX_PLAYERS+1];
new g_pcvar_radius, g_pcvar_explosion_knockback, g_pcvar_maxdmg, g_pcvar_ff, g_msg_death;
new g_iCSW_ID = 0, g_szWeaponName[32], g_iArgumentsValues[8] = { 0, 0, ... }, g_iMsg_WeaponList;

//sprites
new g_Spr_Trail;
new g_Spr_xplode;

public plugin_natives()
{
  register_native("give_item_mp5m203", "_give_item_mp5m203", .style = 0);
}

public _give_item_mp5m203(plugin, argc)
{
  give_mp5m203( get_param( 1 ), get_param( 2 ), get_param( 3 ) );
}

public plugin_init() 
{
  register_plugin("MP5 + Grenade Launcher", "1.0", "Natsheh");

  register_event("CurWeapon", "fw_CurWeapon_event", "be", "1=1", "2=19");

  RegisterHam(Ham_Item_Drop, "weapon_mp5navy", "fw_PlayerDropItem_Pre", .Post = false);
  //RegisterHam(Ham_CS_Item_CanDrop, "weapon_mp5navy", "fw_PlayerDropItem_Pre", .Post = false);
  RegisterHam(Ham_Spawn, "weaponbox", "fw_WeaponBox_Spawned_Post", .Post = true);
  RegisterHam(Ham_Item_PostFrame, "weapon_mp5navy", "MP5_PostFrame_Pre");
  RegisterHam(Ham_Item_AttachToPlayer, "weapon_mp5navy", "MP5_AttachToPlayer_Post", .Post=true);
  RegisterHam(Ham_Item_AddToPlayer, "weapon_mp5navy", "MP5_AddToPlayer_Post", .Post=true);
  RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_mp5navy", "fw_mp5navy_secondary_attack_post", .Post=true);

  if(!is_regamedll())
  {
    OrpheuRegisterHook(OrpheuGetFunction("HasSecondaryAttack", "CBasePlayerWeapon"), "fw_Weapon_HasSecondaryWeapon", .phase = OrpheuHookPre);
  }

  register_touch(M203_NADE_CLASSNAME, "*", "m203_nade_touched");
  register_think(M203_NADE_CLASSNAME, "m203_nade_think");

  g_pcvar_maxdmg = register_cvar("mp5m203_nade_max_dmg", "300");
  g_pcvar_radius = register_cvar("mp5m203_nade_radius_dmg", "150");
  g_pcvar_explosion_knockback = register_cvar("mp5m203_nade_exp_knockback", "500");
  g_pcvar_ff = register_cvar("mp5m203_nade_ff", "1");

  g_msg_death = get_user_msgid("DeathMsg");

  register_concmd("jb_give_mp5m203", "concmd_give_mp5m203", ADMIN_IMMUNITY, "gives a mp5m203 to a player");

  g_pJBShopItem = register_jailbreak_shopitem("MP5M203", "MP5 + Nade launcher", 6000, TEAM_GUARDS);
}

public fw_message_WeaponList(msgid, dest, id)
{
  if( g_iCSW_ID != CSW_MP5NAVY && get_msg_arg_int( 8 ) == CSW_MP5NAVY )
  {
    get_msg_arg_string( 1, g_szWeaponName, charsmax(g_szWeaponName) );
    for(new i = 2; i <= 9; i++) g_iArgumentsValues[ i - 2 ] = get_msg_arg_int( i );

    g_iCSW_ID = g_iArgumentsValues[ 6 ];
  }
}

set_default_mp5navy_huds(id)
{
  if( g_iCSW_ID == CSW_MP5NAVY )
  {
    message_begin( MSG_ONE, g_iMsg_WeaponList, .player = id );
    write_string( g_szWeaponName );     // WeaponName
    for(new i = 0, size = sizeof g_iArgumentsValues; i < size; i++) write_byte( g_iArgumentsValues[ i ] );
    message_end();
  }
}

public fw_WeaponBox_Spawned_Post(const ent)
{
  new id = pev(ent, pev_owner);

  if(!is_user_connected(id)) return;

  if(g_PlayerDroppedMp5M203[id])
  {
    engfunc(EngFunc_SetModel, ent, MP5M203_WEAPON_WORLD_MODEL);
    g_PlayerDroppedMp5M203[id] = false;
  }
}

public fw_PlayerDropItem_Pre(const ent)
{
  if(IsWeaponMP5M203(ent))
  {
    new id = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");

    if(!is_user_connected(id)) return;

    g_PlayerDroppedMp5M203[id] = true;
  }
}

public vip_flag_creation()
{
  register_vip_flag('d', "Access to Mp5M203");
}

public jb_shop_item_preselect(id, itemid)
{
  if(g_pJBShopItem == itemid)
  {
    if(get_user_vip(id) & read_flags("d"))
    {
      return JB_IGNORED;
    }
    return JB_MENU_ITEM_UNAVAILABLE;
  }
  return JB_IGNORED;
}

public jb_shop_item_bought(id, itemid)
{
  if(g_pJBShopItem == itemid)
  {
    give_mp5m203(id);
  }
}

public concmd_give_mp5m203(id, level, cid)
{
  if(!cmd_access(id, level, cid, 1))
    return PLUGIN_HANDLED;

  new sTarget[32], szArgs[8], iNadeAmmo = 10, iBPAMMO = 250;
  read_argv(1, sTarget, 31);
  remove_quotes(sTarget);
  read_argv(2, szArgs, charsmax(szArgs));
  remove_quotes(szArgs);
  if(strlen(szArgs) > 0) iNadeAmmo = str_to_num(szArgs);
  read_argv(3, szArgs, charsmax(szArgs));
  remove_quotes(szArgs);
  if(strlen(szArgs) > 0) iBPAMMO = str_to_num(szArgs);

  if(sTarget[0] == '@')
  {
    new players[32], pnum;
    switch( sTarget[1] )
    {
      case 'C', 'c': get_players(players, pnum, "ae", "CT");
      case 'T', 't': get_players(players, pnum, "ae", "TERRORIST");
      default: get_players(players, pnum, "a");
    }

    for(new i = 0, player; i < pnum; i++)
    {
      player = players[i];

      give_mp5m203(player, iNadeAmmo, iBPAMMO);
    }

    console_print(id, "You have given %c%c MP5M203", sTarget[0], sTarget[1]);
    return PLUGIN_HANDLED;
  }

  new target = cmd_target(id, sTarget, CMDTARGET_ALLOW_SELF|CMDTARGET_ONLY_ALIVE);
  if(!target) return PLUGIN_HANDLED;

  get_user_name(target, sTarget, 31);

  give_mp5m203(target, iNadeAmmo, iBPAMMO);
  cprint_chat(id, _, "You gave ^3%s ^1a ^4MP5M203!", sTarget);
  console_print(id, "You gave %s a MP5M203!", sTarget);

  return PLUGIN_HANDLED;
}

public OrpheuHookReturn:fw_Weapon_HasSecondaryWeapon( const weapon )
{
  if(IsWeaponMP5M203(weapon))
  {
    OrpheuSetReturn(true);
    return OrpheuSupercede;
  }
  return OrpheuIgnored;
}

public fw_CurWeapon_event( id )
{
  static bool:bWeaponIsActive;
  bWeaponIsActive = bool:read_data( 1 );

  if( bWeaponIsActive && read_data( 2 ) == CSW_MP5M203 && IsWeaponMP5M203( get_ent_data_entity(id, "CBasePlayer", "m_pActiveItem") ) )
  {
    set_pev(id, pev_viewmodel2, MP5M203_WEAPON_VIEW_MODEL);
    set_pev(id, pev_weaponmodel2, MP5M203_WEAPON_PLAYER_MODEL);
  }
}

public MP5_AddToPlayer_Post( const entity, const id )
{
  if( pev_valid(entity) && is_user_alive( id ) ) // just for safety.
  {
    if(!check_flag(g_bHasMP5M203,id))
    {
      set_default_mp5navy_huds(id);
      return HAM_IGNORED;
    }

    set_pev(entity, PEV_WEAPON_TYPE, WEAPON_TYPE_MP5M203);

    static MsgIndexWeaponList = 0; MsgIndexWeaponList = !MsgIndexWeaponList ? get_user_msgid("WeaponList") : MsgIndexWeaponList;
    message_begin( MSG_ONE, MsgIndexWeaponList, .player = id );
    write_string( MP5M203_CLASSNAME );      // WeaponName
    write_byte( CS_AMMO_ID_9MM );            // PrimaryAmmoID
    write_byte( 200 );                   // PrimaryAmmoMaxAmount
    write_byte( CS_AMMO_ID_M203 );     // SecondaryAmmoID
    write_byte( 255 );                   // SecondaryAmmoMaxAmount
    write_byte( 0 );                    // SlotID (0...N)
    write_byte( 1 );                    // NumberInSlot (1...N)
    write_byte( CSW_MP5M203 );          // WeaponID
    write_byte( ITEM_FLAG_EXHAUSTIBLE | ITEM_FLAG_NOAUTORELOAD );                    // Flags
    message_end();
  }
  return HAM_IGNORED;
}

public MP5_PostFrame_Pre(iEnt)
{
  if(pev(iEnt, PEV_WEAPON_TYPE) != WEAPON_TYPE_MP5M203)
  {
    return;
  }

  static Float:flNextAttack, fInReload, id, iClip;

  id = get_ent_data_entity(iEnt, "CBasePlayerItem", "m_pPlayer");
  iClip = get_ent_data(iEnt, "CBasePlayerWeapon", "m_iClip");
  fInReload = get_ent_data(iEnt, "CBasePlayerWeapon", "m_fInReload");
  flNextAttack = get_ent_data_float(id, "CBaseMonster", "m_flNextAttack");

  if( (pev(id, pev_button) & IN_RELOAD) > 0 )
  {
    // Gun's clip already full and more, why bother reload ?
    if( iClip >= MAX_MP5M203_CLIP )
    {
      fInReload = false;
      set_ent_data(iEnt, "CBasePlayerWeapon", "m_fInReload", 0);
    }
  }

  // Reloading..
  if( fInReload && flNextAttack <= get_gametime() )
  {
    static iAmmoType, iBpAmmo, j;

    iAmmoType = get_ent_data(iEnt, "CBasePlayerWeapon", "m_iPrimaryAmmoType");
    iBpAmmo = get_ent_data(id, "CBasePlayer", "m_rgAmmo", iAmmoType);

    j = min(MAX_MP5M203_CLIP - iClip, iBpAmmo);

    set_ent_data(iEnt, "CBasePlayerWeapon", "m_iClip", iClip + j);
    set_ent_data(iEnt, "CBasePlayerWeapon", "m_fInReload", false);

    set_ent_data(id, "CBasePlayer", "m_rgAmmo", iBpAmmo-j, iAmmoType);

    fInReload = false;
  }
}

public MP5_AttachToPlayer_Post( const Weapon, const id )
{
  if(!check_flag(g_bHasMP5M203, id))
  {
    return;
  }

  set_pev(Weapon, PEV_WEAPON_TYPE, WEAPON_TYPE_MP5M203);
  set_pev(Weapon, pev_classname, MP5M203_CLASSNAME);
  remove_flag(g_bHasMP5M203,id);
  set_ent_data(Weapon, "CBasePlayerWeapon", "m_iClip", MAX_MP5M203_CLIP);
  set_ent_data(Weapon, "CBasePlayerWeapon", "m_iSecondaryAmmoType", CS_AMMO_ID_M203);

  if(is_regamedll())
  {
    set_member(Weapon, m_Weapon_bHasSecondaryAttack, true);
  }
}

IsWeaponMP5M203(const EntWeapon)
{
  if(pev_valid(EntWeapon) && pev(EntWeapon, PEV_WEAPON_TYPE) == WEAPON_TYPE_MP5M203)
  {
    return true;
  }

  return false;
}

public fw_mp5navy_secondary_attack_post( const ent )
{
  if(IsWeaponMP5M203(ent))
  {
    new id = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");

    new iAmmo = get_ent_data(id, "CBasePlayer", "m_rgAmmo" , CS_AMMO_ID_M203);

    if(iAmmo > 0)
    {
      if(launch_nade( ent ))
      {
        set_ent_data(id, "CBasePlayer", "m_rgAmmo", iAmmo - 1, CS_AMMO_ID_M203);
      }
    }
    else
    {
      emit_sound(ent, CHAN_WEAPON, g_noammo_sounds[random(sizeof g_noammo_sounds)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    }

    set_ent_data_float(ent, "CBasePlayerWeapon", "m_flNextSecondaryAttack", 0.35);
  }
}

give_mp5m203(const id, const M203NadeAmmo = 10, const iBPAMMO = 250)
{
  set_flag(g_bHasMP5M203,id);

  set_ent_data(id, "CBasePlayer", "m_rgAmmo", M203NadeAmmo, CS_AMMO_ID_M203);

  if(pev(id, pev_weapons) & (1<<CSW_MP5M203))
  {
    new ent;
    while( (ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "weapon_mp5navy")) && pev(ent, pev_owner) != id ) { }

    if( pev_valid(ent) )
    {
      ExecuteHamB(Ham_Item_AttachToPlayer, ent, id);
    }
  }
  else
  {
    give_item(id, "weapon_mp5navy");
  }

  cs_set_user_bpammo(id, CSW_MP5M203, iBPAMMO);
}

launch_nade( const ent, const Float:fSpeed = 1000.0, Float:fMaxDamage = 100.0 )
{
  new id = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");

  entity_set_int(id, EV_INT_weaponanim, ANIME_MP5M203_M203_NADE_FIRE);
  UTIL_SendWeaponAnim(id, ANIME_MP5M203_M203_NADE_FIRE);

  new Float: fVecStart[3], Float: fViewOFS[3], Float: fDirection[3];

  entity_get_vector(id, EV_VEC_origin, fVecStart)
  entity_get_vector(id, EV_VEC_view_ofs, fViewOFS);
  xs_vec_add(fVecStart, fViewOFS, fVecStart);

  new pGranda = CreateProjectile(.szClass = M203_NADE_CLASSNAME,
    .fStartOrigin = fVecStart,
    .fProjectileMaxSpeed = fSpeed,
    .fDamage = fMaxDamage,
    .iBitsDamage = DMG_BLAST,
    .owner = id,
    .szProjectileModel = M203_NADE_MODEL,
    .fMaxS = Float:{1.0, 1.0, 1.0},
    .fMinS = Float:{-1.0, -1.0, -1.0} );

  entity_get_vector(id, EV_VEC_v_angle, fDirection);
  set_pev(pGranda, pev_angles, fDirection);
  angle_vector(fDirection, ANGLEVECTOR_FORWARD, fDirection);
  FireProjectile(pGranda, fDirection, fSpeed);

  set_pev(pGranda, pev_fuser4, get_gametime());
  set_pev(pGranda, pev_flags, pev(pGranda, pev_flags) | FL_ALWAYSTHINK);
  set_pev(pGranda, pev_nextthink, get_gametime() + 0.1);
	
  emit_sound(id, CHAN_WEAPON, "misc/glauncher.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);

  trail(pGranda, g_Spr_Trail);

  return pGranda;
}

public m203_nade_think(id)
{
  if(!pev_valid(id))
  {
    return;
  }

  static Float:fLaunchtime;
  pev(id, pev_fuser4, fLaunchtime);

  if((get_gametime() - fLaunchtime) < 0.5)
  {
    if(pev(id, pev_flags) & FL_ONGROUND)
    {
      m203nade_explode(id);
    }
  }

  static Float:fVelocity[3];
  pev(id, pev_velocity, fVelocity);

  if(xs_vec_len(fVelocity) > 0.0)
  {
    xs_vec_normalize(fVelocity, fVelocity);
    vector_to_angle(fVelocity, fVelocity);
    set_pev(id, pev_angles, fVelocity);
  }

  set_pev(id, pev_nextthink, get_gametime() + 0.1);
}

public m203_nade_touched(pM203Nade, pTouched)
{
  if(!pev_valid(pM203Nade)) return;

  static Float:fLaunchtime;
  pev(pM203Nade, pev_fuser4, fLaunchtime);

  if((get_gametime() - fLaunchtime) < 0.5)
  {
    return;
  }

  m203nade_explode(pM203Nade);
}

m203nade_explode(const pM203Nade)
{
  new Float:EndOrigin[3], Float:fDamageradius = floatclamp(get_pcvar_float(g_pcvar_radius), 1.0, 5000.0);
  pev(pM203Nade, pev_origin, EndOrigin);
  Create_Explosion(EndOrigin, get_pcvar_float(g_pcvar_maxdmg), fDamageradius, pev(pM203Nade, pev_owner));

  play_sprite(EndOrigin, .pSprite = g_Spr_xplode, .iScale = 20, .iBrightness = 200)
  emit_sound(pM203Nade, CHAN_WEAPON, "misc/a_exm2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

  // Kill the m203 on nextthink!
  set_pev(pM203Nade, pev_flags, FL_KILLME);
  dllfunc(DLLFunc_Think, pM203Nade);

  new ent, iEntMoveType, Float:flKnockBackPower = get_pcvar_float(g_pcvar_explosion_knockback);

  new ent2 = -1, Float:fOrigin[3], Float:fVicOrigin[3], Float:fDistOrigin[3];

  while( (ent=find_ent_in_sphere(ent, EndOrigin, fDamageradius)) )
  {
    if( (pev(ent, pev_solid) != SOLID_BSP) &&
      ( (iEntMoveType=pev(ent, pev_movetype)) == MOVETYPE_TOSS || iEntMoveType == MOVETYPE_WALK || iEntMoveType == MOVETYPE_STEP ||
        iEntMoveType == MOVETYPE_PUSH || iEntMoveType == MOVETYPE_BOUNCE || iEntMoveType == MOVETYPE_PUSHSTEP || iEntMoveType == MOVETYPE_FLY )
      )
    {
      if(IsPlayer(ent))
      {
        // Means player is on a ladder.
        if(pev(ent, pev_movetype) == MOVETYPE_FLY)
        {
          pev(ent, pev_origin, fVicOrigin);

          while( (ent2 = find_ent_by_class(ent2, "func_ladder")) > 0)
          {
            get_brush_entity_origin(ent2, fOrigin);
            xs_vec_sub(fVicOrigin, fOrigin, fDistOrigin);

            if(xs_vec_len_2d(fDistOrigin) <= 36.0)
            {
              set_pev(ent2, pev_origin, Float:{ 0.0, 0.0, 4096.0});
              set_task(1.0, "task_retrieve_ladder", ent2);
            }
          }
        }
      }

      entity_explosion_knockback(ent, EndOrigin, fDamageradius, flKnockBackPower);
    }
  }
}

public task_retrieve_ladder(const ent)
{
  set_pev(ent, pev_origin, Float:{ 0.0, 0.0, 0.0});
}

/////////////////////
//Thantik's he-conc functions
stock get_velocity_from_origin( ent, Float:fOrigin[3], Float:fSpeed, Float:fVelocity[3] )
{
    new Float:fEntOrigin[3];
    entity_get_vector( ent, EV_VEC_origin, fEntOrigin );

    // Velocity = Distance / Time

    new Float:fDistance[3];
    fDistance[0] = fEntOrigin[0] - fOrigin[0];
    fDistance[1] = fEntOrigin[1] - fOrigin[1];
    fDistance[2] = fEntOrigin[2] - fOrigin[2];

    new Float:fTime = ( vector_distance( fEntOrigin,fOrigin ) / fSpeed );

    fVelocity[0] = fDistance[0] / fTime;
    fVelocity[1] = fDistance[1] / fTime;
    fVelocity[2] = fDistance[2] / fTime;

    return ( fVelocity[0] && fVelocity[1] && fVelocity[2] );
}


// Sets velocity of an entity (ent) away from origin with speed (speed)

stock set_velocity_from_origin( ent, Float:fOrigin[3], Float:fSpeed )
{
    new Float:fVelocity[3];
    get_velocity_from_origin( ent, fOrigin, fSpeed, fVelocity )

    entity_set_vector( ent, EV_VEC_velocity, fVelocity );

    return ( 1 );
} 

play_sprite(const Float:vLocation[3], pSprite, iScale = 20, iBrightness = 200)
{
  message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
  write_byte( TE_SPRITE );
  engfunc( EngFunc_WriteCoord, vLocation[0] );
  engfunc( EngFunc_WriteCoord, vLocation[1] );
  engfunc( EngFunc_WriteCoord, vLocation[2] );
  write_short( pSprite );
  write_byte( iScale );
  write_byte( iBrightness );
  message_end();
}

trail(const ent, pTrailSprite)
{
  message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
  write_byte( TE_BEAMFOLLOW );
  write_short( ent ) // entity
  write_short( pTrailSprite )  // model
  write_byte( 10 )       // life
  write_byte( 5 )        // width
  write_byte( 255 )      // r, g, b
  write_byte( 255 )    // r, g, b
  write_byte( 255 )      // r, g, b
  write_byte( 100 ) // brightness

  message_end() // move PHS/PVS data sending into here (SEND_ALL, SEND_PVS, SEND_PHS)
}

public plugin_precache()
{
  precache_model(MP5M203_WEAPON_VIEW_MODEL);
  precache_model(MP5M203_WEAPON_PLAYER_MODEL);
  precache_model(MP5M203_WEAPON_WORLD_MODEL);
  precache_model(M203_NADE_MODEL);
  precache_sound("misc/glauncher.wav");
  precache_sound("misc/a_exm2.wav");
  precache_sound("items/gunpickup2.wav");

  g_Spr_Trail = precache_model("sprites/smoke.spr");
  g_Spr_xplode = precache_model("sprites/zerogxplode2.spr");

  for(new i; i < sizeof g_noammo_sounds; i++)
  {
    precache_sound(g_noammo_sounds[i]);
  }

  precache_generic("sprites/weapon_mp5m203.txt");

  new iEntity = create_entity("info_target");
  set_pev(iEntity, pev_classname, M203_AMMO_CLASSNAME);
  OrpheuCallSuper(OrpheuGetFunction("AddAmmoNameToAmmoRegistry", "CBaseEntity"), iEntity, M203_AMMO_CLASSNAME);
  set_pev(iEntity, pev_flags, FL_KILLME);
  dllfunc(DLLFunc_Think, iEntity);

  //OrpheuCallSuper(OrpheuGetFunction("UTIL_PrecacheOther"), M203_AMMO_CLASSNAME);

  register_message((g_iMsg_WeaponList=get_user_msgid("WeaponList")), "fw_message_WeaponList");
}

stock CreateProjectile( const szClass[], const Float:fStartOrigin[3], Float:fProjectileMaxSpeed,
    const Float:fDamage, const iBitsDamage, const owner=0, const szProjectileModel[]="",
    const Float:fMaxS[3]={1.0,1.0,1.0}, const Float:fMinS[3]={-1.0,-1.0,-1.0} )
{
    new bool:bMDLSprite = (contain(szProjectileModel, ".spr") != -1),
        ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, bMDLSprite ? "env_sprite" : "info_target"));

    if(!ent)
    {
        return 0;
    }

    set_pev(ent, pev_classname, szClass);
    set_pev(ent, pev_netname, szClass);
    set_pev(ent, pev_max_health, 1.0);
    set_pev(ent, pev_health, 1.0);
    set_pev(ent, pev_takedamage, DAMAGE_NO);
    set_pev(ent, pev_solid, SOLID_TRIGGER);
    set_pev(ent, pev_movetype, MOVETYPE_TOSS);
    set_pev(ent, pev_gravity, 1.0);
    set_pev(ent, pev_friction, 0.0);
    set_pev(ent, pev_maxspeed, fProjectileMaxSpeed);
    set_pev(ent, pev_owner, owner);
    set_pev(ent, pev_dmg, float(iBitsDamage));
    set_pev(ent, pev_dmg_save, fDamage);
    set_pev(ent, pev_flags, FL_ALWAYSTHINK|FL_MONSTERCLIP);

    if(szProjectileModel[0] != EOS)
    {
        set_pev(ent, pev_model, szProjectileModel);

        if( !bMDLSprite )
        {
            engfunc(EngFunc_SetModel, ent, szProjectileModel);
        }
    }

    engfunc(EngFunc_SetOrigin, ent, fStartOrigin);

    if(bMDLSprite)
        {
            set_pev(ent, pev_scale, 1.0);
            set_pev(ent, pev_framerate, 1.0);
            set_pev(ent, pev_animtime, get_gametime());
            set_pev(ent, pev_spawnflags, SF_SPRITE_STARTON);
            dllfunc(DLLFunc_Spawn, ent);

            set_pev(ent, pev_solid, SOLID_TRIGGER);
            set_pev(ent, pev_movetype, MOVETYPE_TOSS);
            engfunc(EngFunc_SetSize, ent, fMinS, fMaxS);
        }
    else
    {
        engfunc(EngFunc_SetSize, ent, fMinS, fMaxS);
    }


    return ent;
}

stock FireProjectile( const ent, const Float:fDirection[3], const Float:fProjectileSpeed )
{
    new Float:fVelocity[3], Float:fProjectileMaxSpeed;
    pev(ent, pev_maxspeed, fProjectileMaxSpeed);
    xs_vec_mul_scalar(fDirection, floatmin(fProjectileSpeed, fProjectileMaxSpeed), fVelocity);
    set_pev(ent, pev_velocity, fVelocity);
}

stock Create_Explosion(const Float:vecCenter[3], Float:fMaxDamage, Float:fMagnitude, iInfluencer=0)
{
  if(fMagnitude == 0.0) fMagnitude = 1.0;

  new iTeam = 0;
  if(iInfluencer != 0)
  {
    if(IsPlayer(iInfluencer))
    {
      iTeam = get_user_team(iInfluencer);
    }
    else
    {
      iTeam = pev(iInfluencer, pev_team);
    }
  }

  new iVictim, Float:fDamage, Float:fHealth, Float:fDistance, Float:vecVictimOrigin[3], bool:bFriendlyfire = (get_pcvar_num(g_pcvar_ff) > 0) ? true:false, iOldDeathMsgValue = get_msg_block(g_msg_death);
  while((iVictim = engfunc(EngFunc_FindEntityInSphere, iVictim, vecCenter, fMagnitude)) > 0)
  {
    pev(iVictim, pev_health, fHealth);
    if(entity_take_damage(iVictim) == DAMAGE_NO || fHealth <= 0.0 || (iInfluencer != 0 && iInfluencer != iVictim && !bFriendlyfire && iTeam == ( IsPlayer(iVictim) ? get_user_team(iVictim) : pev(iVictim, pev_team) )))
    {
      continue;
    }

    if(pev(iVictim, pev_solid) == SOLID_BSP)
    {
      get_brush_entity_origin(iVictim, vecVictimOrigin);
    }
    else
    {
      pev(iVictim, pev_origin, vecVictimOrigin);
    }

    fDistance = floatmin(get_distance_f(vecVictimOrigin, vecCenter), fMagnitude);

    fDamage = fMaxDamage - floatmul(fMaxDamage, floatdiv(fDistance, fMagnitude));

    if(fDamage < fHealth)
    {
      ExecuteHamB(Ham_TakeDamage, iVictim, iInfluencer, iInfluencer, fDamage, (DMG_BLAST|DMG_BURN|DMG_SHOCK));
    }
    else
    {
      if(IsPlayer(iVictim))
      {
        set_msg_block(g_msg_death, BLOCK_SET);
        ExecuteHamB(Ham_TakeDamage, iVictim, iInfluencer, iInfluencer, fDamage,
        ((fDamage / floatmax(fMaxDamage,1.0)) >= 0.75) ? (DMG_BLAST|DMG_BURN|DMG_SHOCK|DMG_ALWAYSGIB) : (DMG_BLAST|DMG_BURN|DMG_SHOCK));
        set_msg_block(g_msg_death, iOldDeathMsgValue);

        if(get_user_health(iVictim) <= 0)
        {
          deathmsg_player_m203_killed(iVictim, iInfluencer);
        }
      }
      else
      {
        ExecuteHamB(Ham_TakeDamage, iVictim, iInfluencer, iInfluencer, fDamage, (DMG_BLAST|DMG_BURN|DMG_SHOCK));
      }
    }
  }
}

stock deathmsg_player_m203_killed(victim, killer)
{
  if(!is_user_connected(killer)) killer = victim;

  static kname[32], vname[32], kauthid[32], vauthid[32], kteam[10], vteam[10];

  get_user_name(killer, kname, 31);
  get_user_team(killer, kteam, 9);
  get_user_authid(killer, kauthid, 31);

  get_user_name(victim, vname, 31);
  get_user_team(victim, vteam, 9);
  get_user_authid(victim, vauthid, 31);

  log_message("^"%s<%d><%s><%s>^" killed ^"%s<%d><%s><%s>^" with ^"%s^"",
    kname, get_user_userid(killer), kauthid, kteam,
    vname, get_user_userid(victim), vauthid, vteam, "M203");

  emessage_begin(MSG_ALL, g_msg_death, {0,0,0}, 0);
  ewrite_byte(killer);
  ewrite_byte(victim);
  ewrite_byte(true);
  ewrite_string("M203");
  emessage_end();
}

stock entity_explosion_knockback(victim, Float:fExpOrigin[3], Float:fExpShockwaveRadius=500.0, Float:fExpShockwavePower=500.0)
{
  new Float:fOrigin[3], Float:fDistVec[3];
  if(pev(victim, pev_solid) == SOLID_BSP)
  {
    get_brush_entity_origin(victim, fOrigin);
  }
  else
  {
    pev(victim, pev_origin, fOrigin);
  }

  xs_vec_sub(fOrigin, fExpOrigin, fDistVec);

  new Float:fTemp;
  // victim is in the range of the shockwave explosion!
  if((fTemp=xs_vec_len(fDistVec)) <= fExpShockwaveRadius)
  {
    new Float:fPower = fExpShockwavePower * ( 1.0 - ( fTemp / floatmax(fExpShockwaveRadius, 1.0) ) ), Float:fVelo[3], Float:fKnockBackVelo[3];
    if(fTemp == 0.0)
    {
      xs_vec_set(fDistVec, random_float(-1.0,1.0), random_float(-1.0,1.0), 1.0);
    }

    pev(victim, pev_velocity, fVelo);
    xs_vec_normalize(fDistVec, fKnockBackVelo);
    xs_vec_mul_scalar(fKnockBackVelo, fPower, fKnockBackVelo);
    xs_vec_add(fVelo, fKnockBackVelo, fVelo);
    set_pev(victim, pev_velocity, fVelo);
  }
}

stock Float:entity_take_damage(target)
{
  static Float:flTakeDamage;
  pev(target, pev_takedamage, flTakeDamage);
  return flTakeDamage;
}


UTIL_SendWeaponAnim(pPlayer, iAnim, body=0)
{
    if( !is_user_alive(pPlayer) )
    {
        log_error(AMX_ERR_NATIVE, "Player #%d is not alive or not connected!", pPlayer);
        return;
    }

    message_begin(MSG_ONE, SVC_WEAPONANIM, _, pPlayer);
    write_byte(iAnim);
    write_byte(body);
    message_end();

    static iPlayers[MAX_PLAYERS], pnum, i, target;
    get_players(iPlayers, pnum, "bch");

    for(i = 0; i < pnum; i++)
    {
        target = iPlayers[ i ];

        if( pev(target, PEV_OBSERVER_MODE) == OBS_IN_EYE && pev(target, PEV_SPECTATOR_TARGET) == pPlayer )
        {
            message_begin(MSG_ONE, SVC_WEAPONANIM, _, target);
            write_byte(iAnim);
            write_byte(body);
            message_end();
        }
    }
}
