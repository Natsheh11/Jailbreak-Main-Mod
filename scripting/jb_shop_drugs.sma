/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <jailbreak_core>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <soundinfo>

#define PLUGIN  "[JB] SHOP: DRUGS"
#define AUTHOR  "Natsheh"

#define TASK_DRUG_EFFECTS 2000

new const g_szDrugs_background_music[] = "jailbreak/drugs_bgm.wav"

new g_Drugs_MItem, Float:g_fDrugsTaken[MAX_PLAYERS+1] = { -1.0, -1.0, ... }, bool:g_bPlayerOverDose[MAX_PLAYERS+1], Float:g_fSoundLength,
    g_pCvarDamageReduction, g_pCvarOverDose;

public plugin_precache()
{
    PRECACHE_SOUND(g_szDrugs_background_music);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    g_Drugs_MItem = register_jailbreak_shopitem("Drugs", "Beware it might have some side effects!", 2500, TEAM_ANY);

    new szFile[ MAX_RESOURCE_PATH_LENGTH ], aSoundFData[SParam];
    formatex(szFile, charsmax(szFile), "sound/%s", g_szDrugs_background_music);

    if(sfile_loaddata(szFile, aSoundFData) != SRES_OK)
    {
        server_print("Error sound ('%s') file is courrpted!", g_szDrugs_background_music);
        log_amx("Error sound ('%s') file is courrpted!", g_szDrugs_background_music);
    }
    else
    {
        g_fSoundLength = get_duration(aSoundFData);
    }

    g_pCvarDamageReduction = register_cvar("jb_drugs_damage_reduction", "0.5");
    g_pCvarOverDose = register_cvar("jb_drugs_overdose_time", "15");

    RegisterHam(Ham_TakeDamage, "player", "fwHamPlayerTakeDamagePre", .Post=false);
    RegisterHam(Ham_TakeHealth, "player", "fwHamPlayerTakeHealthPost", .Post=true);
}

public fwHamPlayerTakeDamagePre(victim, inflictor, attacker, Float:fDamage, iDamageFlags)
{
    if( g_fDrugsTaken[victim] != -1.0 && ((get_gametime() - g_fDrugsTaken[victim]) <= g_fSoundLength) )
    {
        if(fDamage > 0.0)
        {
            SetHamParamFloat(4, fDamage * get_pcvar_float(g_pCvarDamageReduction));
            return HAM_HANDLED;
        }
    }
    return HAM_IGNORED;
}

public fwHamPlayerTakeHealthPost(victim, inflictor, attacker, Float:fDamage, iDamageFlags)
{
    if( g_fDrugsTaken[victim] != -1.0 && ((get_gametime() - g_fDrugsTaken[victim]) <= g_fSoundLength) )
    {
        if(fDamage < 0.0)
        {
            client_cmd(victim, "spk ^"Processing medical attention^"");
            stop_drugs_effects(victim);
        }
    }
    return HAM_IGNORED;
}


public jb_shop_item_bought(id, itemid)
{
    if(itemid == g_Drugs_MItem)
    {
        drug_injection( id );
    }
}

#if AMXX_VERSION_NUM > 182
#define client_disconnect client_disconnected
#endif

public client_disconnect(id)
    {
        g_bPlayerOverDose[id] = false;
        g_fDrugsTaken[id] = -1.0;
        remove_task( id + TASK_DRUG_EFFECTS );
    }

drug_injection( id )
{
    // Player has taken another shot less than 10 seconds ???
    if( g_fDrugsTaken[id] != -1.0 && (get_gametime() - g_fDrugsTaken[id]) <= (g_fSoundLength + get_pcvar_float(g_pCvarOverDose)) )
    {
        new szName[32];
        get_user_name(id, szName, 31);
        cprint_chat(0, _, "!g%s !thas taken a drugshot and got overdosed!", szName);

        g_bPlayerOverDose[id] = true;

        client_cmd(id, "spk ^"Required medical attention^"");
    }

    g_fDrugsTaken[id] = get_gametime();
    set_task(0.5, "task_drugs_effects", TASK_DRUG_EFFECTS + id, .flags="b");

    emit_sound(id, CHAN_STATIC, g_szDrugs_background_music, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

stop_drugs_effects( id )
{
    emit_sound(id, CHAN_STATIC, g_szDrugs_background_music, VOL_NORM, ATTN_NORM, SND_STOP, PITCH_NORM);
    g_bPlayerOverDose[id] = false;
}

public task_drugs_effects( taskid )
{
    new id = taskid - TASK_DRUG_EFFECTS;

    if( !is_user_alive(id) || (get_gametime() - g_fDrugsTaken[id]) >= g_fSoundLength )
    {
        stop_drugs_effects( id );
        remove_task(taskid);
        return;
    }

    static Float:fOrigin[3], iColor[3];
    pev(id, pev_origin, fOrigin);

    iColor[0] = random(255);
    iColor[1] = random(255);
    iColor[2] = random(255);

    elight(id, fOrigin, 200.0, iColor, 5, 100.0);
    dlight(fOrigin, 20, iColor, 5, 10);
    particle_burst(fOrigin, 200, random(255), 5);
    ScreenShake(10, 1, 10, MSG_ONE, id);

    if(g_bPlayerOverDose[id])
    {
        ExecuteHamB(Ham_TakeDamage, id, 0, 0, random_float(1.0, 5.0), DMG_POISON|DMG_SHOCK|DMG_BURN|DMG_FREEZE|DMG_NERVEGAS|DMG_ACID);

        if(get_user_health(id) <= 0)
        {
            stop_drugs_effects( id );
            remove_task(taskid);
        }
    }
}

elight(const target, const Float:fOrigin[3], Float:fRadius, const iColor[3], const life, const Float:fRate, const dest=MSG_BROADCAST, const host=0)
{
    engfunc(EngFunc_MessageBegin, dest, SVC_TEMPENTITY, fOrigin, host);
    write_byte(TE_ELIGHT)
    write_short(target);
    engfunc(EngFunc_WriteCoord, fOrigin[0]);
    engfunc(EngFunc_WriteCoord, fOrigin[1]);
    engfunc(EngFunc_WriteCoord, fOrigin[2]);
    engfunc(EngFunc_WriteCoord, fRadius);
    write_byte(iColor[0]);
    write_byte(iColor[1]);
    write_byte(iColor[2]);
    write_byte(life);
    engfunc(EngFunc_WriteCoord, fRate);
    message_end();
}

dlight(const Float:fOrigin[3], iRadius, const iColor[3], const life, const iRate, const dest=MSG_BROADCAST, const host=0)
{
    engfunc(EngFunc_MessageBegin, dest, SVC_TEMPENTITY, fOrigin, host);
    write_byte(TE_DLIGHT)
    engfunc(EngFunc_WriteCoord, fOrigin[0]);
    engfunc(EngFunc_WriteCoord, fOrigin[1]);
    engfunc(EngFunc_WriteCoord, fOrigin[2]);
    write_byte(iRadius);
    write_byte(iColor[0]);
    write_byte(iColor[1]);
    write_byte(iColor[2]);
    write_byte(life);
    write_byte(iRate);
    message_end();
}

particle_burst(const Float:fOrigin[3], const iRadius, const iColorByte, const life, dest=MSG_BROADCAST, const host=0)
{
    engfunc(EngFunc_MessageBegin, dest, SVC_TEMPENTITY, fOrigin, host);
    write_byte(TE_PARTICLEBURST)
    engfunc(EngFunc_WriteCoord, fOrigin[0]) // x
    engfunc(EngFunc_WriteCoord, fOrigin[1]) // y
    engfunc(EngFunc_WriteCoord, fOrigin[2]) // z
    write_short(iRadius)
    write_byte(iColorByte)
    write_byte(life)
    message_end();
}

ScreenShake(const Amplitude, const Duration, const Frequency, const dest = MSG_BROADCAST, const host=0, const Float:fOrigin[3] = {0.0,0.0,0.0})
{
    engfunc(EngFunc_MessageBegin, dest, get_user_msgid("ScreenShake"), fOrigin, host);
    write_short( min(Amplitude * 4096, 0xFFFF) ); // Amplitude
    write_short( min(Duration * 4096, 0xFFFF) ); // Duration
    write_short( min(Frequency * 4096, 0xFFFF) ); // Frequency
    message_end();
}
