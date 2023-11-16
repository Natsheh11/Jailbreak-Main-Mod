/*
	PRECACHE KIT - Annoying 512 Precache Limit? You have the control now!
		https://forums.alliedmods.net/showthread.php?t=259880
		
- Description:
	. This plugin allows you to check how many files are precached per map and per type (Sounds/Models/Generic)
	You can also check wich files are precached.
	. Another tool that this plugin has is UnPrecache utility, wich allows you to unprecache any file that you want.
	Yet, be careful. If you unprecache one file that is used (for example models/v_knife.mdl), the server will crash.
	
- Requirements:
	. Orpheu -> There isn't any other efficient way to do all of this.
	
- Credits:
	. Hornet -> for orpheu signatures for precache counting and base plugin.
	. Arkshine -> scripting help
	
- Commands:
	. precache_view -> Prints a message to the admin's console with precache information
	
	. precache_viewfull -> Log all the names of precached files at the map
	(You can add this command at amxx.cfg if you want to generate the log at each map start)

- ChangeLogs:
	. v0.0.1 at 14/03/2015 - First Release
	. v0.0.2 at 15/03/2015 - Minor Fixes
	. v0.0.3 at * / * / 2020 - Fixed logging.
	. v0.0.4 at * / * / 2020 - Added auto unprecacher for over limits items + removing entities that requires unpreacached models, preventing crashes.
	. v0.0.5 at 11/07/2021 - Blocking sounds which got unprecached.
*/

#include <amxmodx>
#include <amxmisc>
#include <orpheu>
#include <orpheu_stocks>
#include <fakemeta>
#include <engine>

#define MAX_MODELS_PRECACHE 512
#define MAX_SOUNDS_PRECACHE 512
#define MAX_GENERIC_PRECACHE 512

new const Version[] = "0.0.5"

enum PrecacheData
{
	Sound,
	Model,
	Generic
}

new g_iPrecacheCount[PrecacheData], bool:LOGFILE_EXIST;

new g_szMapName[32], g_szLogsDir[70], g_iMsg_TEXTMSG = -1;

new Trie:g_tUnPrecache, Trie:g_tSound, Trie:g_tDuplicate, Trie:g_tModel, Trie:g_tGeneric;
new g_iExtra_Sounds, g_iExtra_Models, g_iExtra_Generic

enum RADIO_DATA
{
	RADIO_FILE[64],
	RADIO_CODE_FILE[32]
}

new const szRADIO_COMMANDS[][RADIO_DATA] = {
       { "radio/locknload.wav", "%!MRAD_LOCKNLOAD" },
       { "radio/moveout.wav", "%!MRAD_MOVEOUT" },
       { "radio/letsgo.wav", "%!MRAD_LETSGO" },
       { "radio/com_go.wav", "%!MRAD_GO" },
       { "radio/elim.wav", "%!MRAD_ELIM" },
       { "radio/getout.wav", "%!MRAD_GETOUT" },
       { "radio/vip.wav", "%!MRAD_VIP" },
       { "radio/rescued.wav", "%!MRAD_RESCUED" },
       { "radio/rounddraw.wav", "%!MRAD_rounddraw" },
       { "radio/ctwin.wav", "%!MRAD_ctwin" },
       { "radio/terwin.wav", "%!MRAD_terwin" }
}

new const szWeapons_World_Models[][] = {
	"models/w_knife.mdl",
	"models/w_usp.mdl",
	"models/w_glock18.mdl",
	"models/w_p228.mdl",
	"models/w_deagle.mdl",
	"models/w_fiveseven.mdl",
	"models/w_elite.mdl",
	"models/w_m3.mdl",
	"models/w_xm1014.mdl",
	"models/w_mp5.mdl",
	"models/w_ump45.mdl",
	"models/w_p90.mdl",
	"models/w_tmp.mdl",
	"models/w_mac10.mdl",
	"models/w_m4a1.mdl",
	"models/w_ak47.mdl",
	"models/w_awp.mdl",
	"models/w_sg550.mdl",
	"models/w_sg552.mdl",
	"models/w_scout.mdl",
	"models/w_aug.mdl",
	"models/w_galil.mdl",
	"models/w_famas.mdl",
	"models/w_g3sg1.mdl",
	"models/w_m249.mdl",
	"models/w_hegrenade.mdl",
	"models/w_flashbang.mdl"
}

static g_iMaxplayers;

public plugin_init() {
	register_plugin("Precache Kit", Version, "Jhob94 & Natsheh")
	
	register_cvar("precache_kit", Version, FCVAR_SPONLY|FCVAR_SERVER)
	set_cvar_string("precache_kit", Version)
	
	register_concmd("precache_view", "View", ADMIN_RCON, ": View the amount of the precached files")
	register_concmd("precache_viewfull", "ViewFull", ADMIN_RCON, ": Log the amount and names of the precached files")
	
	g_iMsg_TEXTMSG = get_user_msgid("TextMsg");

	if(get_user_msgid("SendAudio") > 0)
		register_message(get_user_msgid("SendAudio"), "fw_SendAudio");

	register_forward(FM_EmitSound, "fw_EmitSound");
}

public plugin_end()
{
	TrieDestroy(g_tUnPrecache);
	TrieDestroy(g_tSound);
	TrieDestroy(g_tModel);
	TrieDestroy(g_tGeneric);
	TrieDestroy(g_tDuplicate);
}

public plugin_precache()
{
	get_mapname(g_szMapName, charsmax(g_szMapName));
	get_basedir(g_szLogsDir, charsmax(g_szLogsDir));
	add(g_szLogsDir, charsmax(g_szLogsDir), "/logs/Precache");
	
	if(!dir_exists(g_szLogsDir))
	{
		mkdir(g_szLogsDir);
	}
	
	g_tUnPrecache = TrieCreate();
	g_tSound = TrieCreate();
	g_tModel = TrieCreate();
	g_tGeneric = TrieCreate();
	g_tDuplicate = TrieCreate();
	
	UnPrecache_Prepare();

	g_iMaxplayers = get_maxplayers();
	OrpheuRegisterHook( OrpheuGetEngineFunction("pfnSetModel", "pfnSetModel"), "fw_SetModel_pre", OrpheuHookPre );
	
	new File[96];
	formatex(File, charsmax(File), "%s/%s.log", g_szLogsDir, g_szMapName);
	LOGFILE_EXIST = file_exists(File) ? true:false;
	
	if(LOGFILE_EXIST)
	{
		delete_file(File);
		LOGFILE_EXIST = false;
	}

	//OrpheuRegisterHook(OrpheuGetEngineFunction("pfnPrecacheGeneric", "pfnPrecacheGeneric"), "PrecacheGeneric");
	OrpheuRegisterHook(OrpheuGetEngineFunction("pfnPrecacheSound", "pfnPrecacheSound"), "PrecacheSound");
	OrpheuRegisterHook(OrpheuGetEngineFunction("pfnPrecacheModel", "pfnPrecacheModel"), "PrecacheModel");
	
	for(new i, maxloop = sizeof szWeapons_World_Models; i < maxloop; i++) precache_generic(szWeapons_World_Models[i]);
}

public plugin_cfg()
{
	DevotionLog("%d sounds are over limit, %d models are over limit and %d generic files are over limit!", g_iExtra_Sounds, g_iExtra_Models, g_iExtra_Generic);
}

public fw_EmitSound(id, channel, const sample[])
{
	if(TrieKeyExists(g_tUnPrecache, sample))
	{
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

public fw_SendAudio(msgid, dest, id)
{
	static szArg2[32];
	get_msg_arg_string(2, szArg2, charsmax(szArg2));
	
	if(TrieKeyExists(g_tUnPrecache, szArg2))
	{
		if( get_msg_block(SVC_TEMPENTITY) == BLOCK_NOT )
		{
			set_msg_block(SVC_TEMPENTITY, BLOCK_ONCE);
		}
		if( g_iMsg_TEXTMSG > 0 && get_msg_block(g_iMsg_TEXTMSG) == BLOCK_NOT )
		{
			set_msg_block(g_iMsg_TEXTMSG, BLOCK_ONCE);
		}
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

block_radio_command_code(const szSound[])
{
	// block radio commands sequences...
	for(new i, mloop = sizeof szRADIO_COMMANDS; i < mloop; i++)
	{
		if(equal(szRADIO_COMMANDS[i][RADIO_FILE], szSound))
		{
			TrieSetCell(g_tUnPrecache, szRADIO_COMMANDS[i][RADIO_CODE_FILE], 1);
			break;
		}
	}
}

public OrpheuHookReturn:PrecacheSound(const szSound[])
{
	if(g_iPrecacheCount[Sound] >= MAX_SOUNDS_PRECACHE)
	{
		if(!TrieKeyExists(g_tDuplicate, szSound))
		{
			DevotionLog("[ PRECACHE KIT ] MAX SOUNDS PRECACHE REACHED %s UnPrecaching", szSound);
			TrieSetCell(g_tDuplicate, szSound, 1);
			TrieSetCell(g_tUnPrecache, szSound, 1);
			block_radio_command_code(szSound);
			g_iExtra_Sounds++;
		}
		return OrpheuSupercede
	}
	
	if(TrieKeyExists(g_tUnPrecache, szSound))
	{
		if(!TrieKeyExists(g_tDuplicate, szSound))
		{
			DevotionLog("[ PRECACHE KIT ] %s UnPrecaching", szSound);
			TrieSetCell(g_tDuplicate, szSound, 1);
			block_radio_command_code(szSound);
		}
		return OrpheuSupercede
	}
	
	if(!TrieKeyExists(g_tDuplicate, szSound))
	{
		g_iPrecacheCount[Sound]++;
		DevotionLog("*(%d) PRECACHING SND '%s' *", g_iPrecacheCount[Sound], szSound);
		TrieSetCell(g_tDuplicate, szSound, 1);
	
		static szNameTKey[6]
		num_to_str(g_iPrecacheCount[Sound], szNameTKey, charsmax(szNameTKey))
		
		TrieSetString(g_tSound, szNameTKey, szSound);
	}
	
	return OrpheuIgnored
}

public OrpheuHookReturn:PrecacheModel(const szModel[])
{
	if(g_iPrecacheCount[Model] >= MAX_MODELS_PRECACHE)
	{
		if(!TrieKeyExists(g_tDuplicate, szModel))
		{
			DevotionLog("[ PRECACHE KIT ] MAX MODELS PRECACHE REACHED %s UnPrecaching", szModel);
			TrieSetCell(g_tDuplicate, szModel, 1);
			TrieSetCell(g_tUnPrecache, szModel, 1);
			g_iExtra_Models ++;
		}
		return OrpheuSupercede;
	}
	
	if(TrieKeyExists(g_tUnPrecache, szModel))
	{
		if(!TrieKeyExists(g_tDuplicate, szModel))
		{
			DevotionLog("[ PRECACHE KIT ] %s UnPrecaching", szModel);
			TrieSetCell(g_tDuplicate, szModel, 1);
		}
		return OrpheuSupercede;
	}

	if(!TrieKeyExists(g_tDuplicate, szModel))
	{
		g_iPrecacheCount[Model]++;
		DevotionLog("*(%d) PRECACHING MDL '%s' *", g_iPrecacheCount[Model], szModel);
		TrieSetCell(g_tDuplicate, szModel, 1);
		
		static szNameTKey[6];
		num_to_str(g_iPrecacheCount[Model], szNameTKey, charsmax(szNameTKey));
		
		TrieSetString(g_tModel, szNameTKey, szModel);
	}
	
	return OrpheuIgnored;
}

public OrpheuHookReturn:PrecacheGeneric(const szGeneric[])
{
	if(g_iPrecacheCount[Generic] >= MAX_MODELS_PRECACHE)
	{
		if(!TrieKeyExists(g_tDuplicate, szGeneric))
		{
			DevotionLog("[ PRECACHE KIT ] MAX GENERIC PRECACHE REACHED %s UnPrecaching", szGeneric);
			TrieSetCell(g_tDuplicate, szGeneric, 1);
			TrieSetCell(g_tUnPrecache, szGeneric, 1);
			g_iExtra_Generic++;
		}
		return OrpheuSupercede;
	}
	
	if(TrieKeyExists(g_tUnPrecache, szGeneric))
	{
		if(!TrieKeyExists(g_tDuplicate, szGeneric))
		{
			DevotionLog("[ PRECACHE KIT ] %s UnPrecaching", szGeneric);
			TrieSetCell(g_tDuplicate, szGeneric, 1);
		}
		return OrpheuSupercede
	}
	
	if(!TrieKeyExists(g_tDuplicate, szGeneric))
	{
		g_iPrecacheCount[Generic]++;
		DevotionLog("*(%d) PRECACHING GEN '%s' *", g_iPrecacheCount[Generic], szGeneric);
		TrieSetCell(g_tDuplicate, szGeneric, 1);
		
	
		static szNameTKey[6]
		num_to_str(g_iPrecacheCount[Generic], szNameTKey, charsmax(szNameTKey))
		
		TrieSetString(g_tGeneric, szNameTKey, szGeneric)
	}
	
	return OrpheuIgnored
}

ENTINDEX(edict)
{
    static OrpheuFunction:function;

    if (!function)
    {
        function = OrpheuGetEngineFunction("pfnIndexOfEdict", "IndexOfEdict");
    }

    return OrpheuCall(function, edict);
}

public OrpheuHookReturn:fw_SetModel_pre(const edict, const szModel[])
{
	static ent;
	ent = ENTINDEX(edict);

	if(ent <= g_iMaxplayers) return OrpheuIgnored;

	if( TrieKeyExists(g_tUnPrecache, szModel) )
	{
		set_pev(ent, pev_flags, FL_KILLME);
		return OrpheuSupercede;
	}

	return OrpheuIgnored;
}

public View(id, lvl, cid)
{
	if(!cmd_access(id, lvl, cid, 1))
		return PLUGIN_HANDLED
	
	console_print(id, "*Current Map: %s ^n*Total Precached: %i ^n*Sounds Precached: %i ^n*Models Precached: %i ^n*Generic Precached: %i",
		g_szMapName, g_iPrecacheCount[Sound] + g_iPrecacheCount[Model] + g_iPrecacheCount[Generic],
			g_iPrecacheCount[Sound], g_iPrecacheCount[Model], g_iPrecacheCount[Generic])
	
	return PLUGIN_HANDLED
}

public ViewFull(id, lvl, cid)
{
	if(!cmd_access(id, lvl, cid, 1))
		return PLUGIN_HANDLED
	
	new File[96]
	formatex(File, charsmax(File), "%s/%s.log", g_szLogsDir, g_szMapName)
	LOGFILE_EXIST = file_exists(File) ? true:false;
	
	if(LOGFILE_EXIST)
	{
		delete_file(File);
		LOGFILE_EXIST = false;
	}
	
	new szNameTKey[6], szSound[101], szModel[101], szGeneric[101];
	DevotionLog("***** INITIALIZING VIEWFULL AT: %s *****", g_szMapName);
	
	DevotionLog("* SOUND PRECACHE ( %i Files ) *", g_iPrecacheCount[Sound]);
	for(new i=1; i<=g_iPrecacheCount[Sound]; i++)
	{
		num_to_str(i, szNameTKey, charsmax(szNameTKey))
		
		if(TrieGetString(g_tSound, szNameTKey, szSound, charsmax(szSound)))
			DevotionLog("%s", szSound);
	}
	
	DevotionLog("* MODEL PRECACHE ( %i Files ) *", g_iPrecacheCount[Model]);
	for(new i=1; i<=g_iPrecacheCount[Model]; i++)
	{
		num_to_str(i, szNameTKey, charsmax(szNameTKey));
		
		if(TrieGetString(g_tModel, szNameTKey, szModel, charsmax(szModel)))
			DevotionLog("%s", szModel);
	}
		
	DevotionLog("* GENERIC PRECACHE ( %i Files ) *", g_iPrecacheCount[Generic]);
	for(new i=1; i<=g_iPrecacheCount[Generic]; i++)
	{
		num_to_str(i, szNameTKey, charsmax(szNameTKey));
		
		if(TrieGetString(g_tGeneric, szNameTKey, szGeneric, charsmax(szGeneric)))
			DevotionLog("%s", szGeneric);
	}
	
	DevotionLog("%d sounds are over limit, %d models are over limit and %d generic files are over limit!", g_iExtra_Sounds, g_iExtra_Models, g_iExtra_Generic);
	console_print(id, "[ Precache Kit ] Precache logs has been created.");
	LOGFILE_EXIST = true;
	return PLUGIN_HANDLED;
}

UnPrecache_Prepare()
{
	static szFile[128];
	get_configsdir(szFile, charsmax(szFile));
	format(szFile, charsmax(szFile), "%s/unprecacher.ini", szFile);
	
	new File = fopen(szFile, "rt");
		
	if(File)
	{
		static szData[196], szSource[164], szMap[32];
		
		while( fgets(File, szData, charsmax(szData)) > 0 )
		{
			trim(szData);
			
			if(!szData[0] || (szData[0] == '/' && szData[1] == '/') || szData[0] == ';')
				continue;
			
			parse(szData, szSource, charsmax(szSource), szMap, charsmax(szMap));
			remove_quotes(szSource);
			remove_quotes(szMap);
			trim(szSource);
			trim(szMap);

			if( szMap[0] == EOS || containi(g_szMapName, szMap) != -1 )
			{
				TrieSetCell(g_tUnPrecache, szSource, 1);
			}
		}
		
		fclose(File);
	}
}

DevotionLog(const MessageToLog[], any:...)
{
	if(LOGFILE_EXIST) return;
	
	new Message[101], File[96]
	vformat(Message, charsmax(Message), MessageToLog, 2)
	formatex(File, charsmax(File), "%s/%s.log", g_szLogsDir, g_szMapName)
	
	new fp = fopen(File, "at+");
	if(fp)
	{
		add(Message, charsmax(Message), "^n");
		fputs(fp, Message);

		fclose(fp);
	}
}
