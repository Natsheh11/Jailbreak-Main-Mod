/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <fakemeta>
#include <jailbreak_core>

#define PLUGIN  "[JB] SHOP: Heal"
#define AUTHOR  "Natsheh"

new const g_szItemName[] = "Heal";
new const g_szItemInfo[] = "Instantly cures injuries";

new const g_szSPRITE_HEAL[] = "sprites/heal.spr";
new const g_szSND_Heal[] = "jailbreak/heal.wav";

new g_iItemID, g_pSprite_heal;

public plugin_precache()
{
    g_pSprite_heal = PRECACHE_SPRITE(g_szSPRITE_HEAL);
    PRECACHE_SOUND(g_szSND_Heal);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    g_iItemID = register_jailbreak_shopitem(g_szItemName, g_szItemInfo, 7500, TEAM_ANY);
}

public jb_shop_item_bought(id, itemid)
{
    if(itemid == g_iItemID)
    {
        HealPlayer(id);
    }
}

HealPlayer(const id)
{
    new Float:fOrigin[3], Float:fViewOfs[3], Float:fHealth;
    pev(id, pev_origin, fOrigin);
    pev(id, pev_view_ofs, fViewOfs);
    fOrigin[2] += fViewOfs[2];
    pev(id, pev_max_health, fHealth);
    set_pev(id, pev_health, fHealth);

    emit_sound(id, CHAN_AUTO, g_szSND_Heal, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    EFF_PlayAdditiveSprite(fOrigin, g_pSprite_heal, .iDest = MSG_PVS);
}

EFF_PlayAdditiveSprite(const Float:fMSGOrigin[3], const mindex, Float:fScale = 1.0, Float:fBrightness = 255.0, iDest = MSG_BROADCAST, host = 0)
{
    engfunc(EngFunc_MessageBegin, iDest, SVC_TEMPENTITY, fMSGOrigin, host);
    write_byte(TE_SPRITE)
    engfunc(EngFunc_WriteCoord, fMSGOrigin[0] );
    engfunc(EngFunc_WriteCoord, fMSGOrigin[1] );
    engfunc(EngFunc_WriteCoord, fMSGOrigin[2] );
    write_short(mindex);
    write_byte(min( floatround( fScale * 10.0 ), 0xFF ));
    write_byte(min( floatround( fBrightness ), 0xFF ));
    message_end();
}
