/*	Copyright (C) 2022 Mesharsky

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <discord>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.0.1"

#define REPORT_REASONS_SIZE 128
#define DISCORD_ROLE_ID_SIZE 128
#define MAX_REPORT_LENGTH 64
#define MAX_DISCORD_MSG_SIZE 1024

#if !defined MAX_AUTHID_LENGTH
#define MAX_AUTHID_LENGTH 64
#endif

enum struct ReportsData
{
	bool admin_notify;
	bool admin_sound;
	
	char admin_sound_path[PLATFORM_MAX_PATH];
	char server_name[32];
	char chat_prefix[64];
	
	int reports_cooldown;

	char blocked_chars[64];
}

enum struct DiscordData
{
	bool integration_enabled;
	int message_type;
	
	char message[MAX_DISCORD_MSG_SIZE];
	
	char webhook[128];
	char bot_name[64];
	char profile_url[128];
	
	char embed_title[64];
	char embed_field_name[64];
	char embed_color[64];
	char embed_footer[128];
	char embed_thmb_url[128];
}

enum struct DiscordReportData
{
	int client;
	char client_name[MAX_NAME_LENGTH];
	char client_auth[MAX_AUTHID_LENGTH];

	int reported_client;
	char reported_name[MAX_NAME_LENGTH];
	char reported_auth[MAX_AUTHID_LENGTH];
	char report_reason[REPORT_REASONS_SIZE];
}

ArrayList g_ReportReasons;
ArrayList g_DiscordMentionRoles;
ReportsData g_ReportsData;
DiscordData g_DiscordData;
Database g_DB;

ConVar g_Cvar_DatabaseName;

char GAMETYPE[32];
int g_ReportTarget[MAXPLAYERS + 1];
int g_ReportCooldown[MAXPLAYERS + 1];
bool g_ReportCustomReason = false;
bool g_WaitingForCustomReason[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Simple Report System", 
	author = "Mesharsky", 
	description = "Allows players to report people on the server with reasons that will be sent to admin", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/Mesharsky"
};

public void OnPluginStart()
{
	LoadTranslations("reports.phrases");
	
	RegConsoleCmd("sm_report", Command_ReportMenu, "Display main report menu");
	RegConsoleCmd("sm_zglos", Command_ReportMenu, "Display main report menu");
	
	RegAdminCmd("sm_reloadreports", Command_ReloadConfig, ADMFLAG_ROOT, "Reloads config file");
	
	g_Cvar_DatabaseName = CreateConVar("reports_db_name", "reports", "Reports database name.\nPlugin must be reloaded for changes to take effect.");
	
	IdentifyGameType(GAMETYPE, sizeof(GAMETYPE));
	
	g_ReportReasons = new ArrayList(ByteCountToCells(REPORT_REASONS_SIZE));
	g_DiscordMentionRoles = new ArrayList(ByteCountToCells(DISCORD_ROLE_ID_SIZE));
	
	LoadConfig();
}

public void OnConfigsExecuted()
{
	char name[32];
	
	if (g_DB == null)
	{
		g_Cvar_DatabaseName.GetString(name, sizeof(name));
		if (!Database_Init(name))
			SetFailState("Failed to connect to database '%s'.", name);
		PrintToServer("Connected to database: %s", name);
	}
}

public void OnMapStart()
{
	AutoExecConfig(true, "reports");
	PrecacheAndDownloadSound();
}

public void OnClientPutInServer(int client)
{
	g_WaitingForCustomReason[client] = false;
	g_ReportCooldown[client] = 0;
}

bool Database_Init(const char[] databaseName)
{
	if (!SQL_CheckConfig(databaseName))
		SetFailState("Missing configuration for database '%s' (in sourcemod/configs/databases.cfg).", databaseName);
	
	char error[512];
	g_DB = SQL_Connect(databaseName, false, error, sizeof(error));
	if (g_DB == null)
		return false;
	
	char driver[16];
	g_DB.Driver.GetIdentifier(driver, sizeof(driver));
	if (StrEqual(driver, "sqlite"))
		SetFailState("This plugin supports only MySQL Driver. SQLite is NOT Supported");
	
	SQL_Query(g_DB, "CREATE TABLE IF NOT EXISTS `reports` ("
		..."`id` INT(20) NOT NULL AUTO_INCREMENT,"
		..."`client_steamid` BIGINT NOT NULL,"
		..."`client_name` VARCHAR(127) NOT NULL,"
		..."`target_steamid` BIGINT NOT NULL,"
		..."`target_name` VARCHAR(127) NOT NULL,"
		..."`server_name` VARCHAR(32) NOT NULL,"
		..."`report_reason` VARCHAR(64) NOT NULL,"
		..."`game` VARCHAR(32) NOT NULL,"
		..."`time` INT(20) NOT NULL,"
		..."PRIMARY KEY (id)) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
	
	return true;
}

public Action Command_ReloadConfig(int client, int args)
{
	if (LoadConfig(false))
		CReplyToCommand(client, "%sConfig has been reloaded", g_ReportsData.chat_prefix);
	else
	{
		CReplyToCommand(client, "%shere is some problem with reloading config file. Check for error logs", g_ReportsData.chat_prefix);
		SetFailState("Failed to reload config file.");
	}	
	
	return Plugin_Handled;
}

public Action Command_ReportMenu(int client, int args)
{
	Menu menu = new Menu(Report_Handler, MENU_ACTIONS_ALL);
	
	menu.Pagination = true;
	
	char display[MAX_NAME_LENGTH];
	char userId[16];
	
	int players = 0;
	
	for (int i = 1; i < MaxClients; ++i)
	{
		if (!IsClientAuthorized(i) || IsFakeClient(i))
			continue;

		if (i == client)
			continue;	
		
		GetClientName(i, display, sizeof(display));
		IntToString(GetClientUserId(i), userId, sizeof(userId));
		
		menu.AddItem(userId, display);
		
		players++;
	}
	
	if (players == 0)
		menu.AddItem("", "No players on the server to report", ITEMDRAW_DISABLED);
	
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int Report_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Display:
		{
			char title[255];
			FormatEx(title, sizeof(title), "%T", "Reports Menu Title", param1);
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(title);
		}
		case MenuAction_Select:
		{
			char info[16];
			menu.GetItem(param2, info, sizeof(info));
			
			int target = GetClientOfUserId(StringToInt(info));
			CreateReasonsMenu(param1, target);
		}
	}
	
	return 0;
}

public void CreateReasonsMenu(int client, int target)
{
	if (target < 1 || target > MaxClients || !IsClientInGame(target))
	{
		CPrintToChat(client, "%s %t", g_ReportsData.chat_prefix, "Invalid Target Index");
		return;
	}
	
	g_ReportTarget[client] = GetClientUserId(target);
	
	Menu menu = new Menu(ReportReason_Handler, MENU_ACTIONS_ALL);
	menu.Pagination = true;
	menu.ExitBackButton = true;
	
	char report_reasons[REPORT_REASONS_SIZE];
	int len = g_ReportReasons.Length;
	for (int i = 0; i < len; ++i)
	{
		g_ReportReasons.GetString(i, report_reasons, sizeof(report_reasons));
		
		menu.AddItem("", report_reasons);
	}

	if (g_ReportCustomReason == true)
	{
		char buffer[32];
		Format(buffer, sizeof(buffer), "%t", "Custom Reason", client);
		menu.AddItem("custom_reason", buffer);
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int ReportReason_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				Command_ReportMenu(param1, 0);
			}
		}
		case MenuAction_Display:
		{
			char title[255];
			char target_name[MAX_NAME_LENGTH];
			int target = GetClientOfUserId(g_ReportTarget[param1]);
			
			if (target != 0)
				GetClientName(target, target_name, sizeof(target_name));
			else
				CPrintToChat(param1, "%s %t", g_ReportsData.chat_prefix, "Invalid Target Index");
			
			FormatEx(title, sizeof(title), "%T", "Reports Reasons Title", param1, "\n", target_name);
			
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(title);
		}
		case MenuAction_Select:
		{
			char info[16];
			char display[REPORT_REASONS_SIZE];
			
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
			
			if (StrEqual(info, "custom_reason"))
			{
				CPrintToChat(param1, "%s %t", g_ReportsData.chat_prefix, "Input Custom Reason");
				g_WaitingForCustomReason[param1] = true;
			}
			else
			{
				int target = GetClientOfUserId(g_ReportTarget[param1]);
				if (target != 0)
					ProcessReport(param1, target, display);
				else
					CPrintToChat(param1, "%s %t", g_ReportsData.chat_prefix, "Invalid Target Index");
			}
		}
	}
	
	return 0;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (!g_WaitingForCustomReason[client])
		return Plugin_Continue;

	int len = strlen(sArgs) + 1;
	char[] buffer = new char[len];

	strcopy(buffer, len, sArgs);
	TrimString(buffer);

	if (!buffer[0])
	{
		CPrintToChat(client, "%s %t", g_ReportsData.chat_prefix, "Entered Reason Is Empty");
		return Plugin_Handled;
	}	
	
	if (strlen(buffer) > MAX_REPORT_LENGTH)
	{
		CPrintToChat(client, "%s %t", g_ReportsData.chat_prefix, "Entered Reason Too Long");
		return Plugin_Handled;
	}

	if (ContainsBlockedCharacters(buffer, ';'))
	{
		// TODO Add list of blocked characters to the message
		CPrintToChat(client, "%s %t", g_ReportsData.chat_prefix, "Contains blocked chars");
		return Plugin_Handled;
	}
	
	g_WaitingForCustomReason[client] = false;

	if (StrEqual(buffer, "stop", false) || StrEqual(buffer, "cancel", false))
		return Plugin_Handled;

	int target = GetClientOfUserId(g_ReportTarget[client]);
	if (target != 0)
		ProcessReport(client, target, buffer);
	else
	{
		CPrintToChat(client, "%s %t", g_ReportsData.chat_prefix, "Invalid Target Index");
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
}

void ProcessReport(int client, int reported_client, const char[] report_reason)
{
	if (g_ReportCooldown[client] == 0 || g_ReportCooldown[client] <= GetTime())
	{
		DiscordReportData report;

		report.client = client;
		report.reported_client = reported_client;

		GetClientName(client, report.client_name, sizeof(DiscordReportData::client_name));
		GetClientName(reported_client, report.reported_name, sizeof(DiscordReportData::reported_name));

		GetClientAuthId(client, AuthId_SteamID64, report.client_auth, sizeof(DiscordReportData::client_auth));
		GetClientAuthId(reported_client, AuthId_SteamID64, report.reported_auth, sizeof(DiscordReportData::reported_auth));
		
		strcopy(report.report_reason, sizeof(DiscordReportData::report_reason), report_reason);
		
		char query[1024];
		g_DB.Format(query, sizeof(query), 
			"INSERT INTO `reports` ("
			..."client_steamid,"
			..."client_name,"
			..."target_steamid,"
			..."target_name,"
			..."server_name,"
			..."report_reason,"
			..."game,"
			..."time)"
			..." VALUES (%s, '%s', %s, '%s', '%s', '%s', '%s', '%d')", 
			report.client_auth, 
			report.client_name, 
			report.reported_auth, 
			report.reported_name, 
			g_ReportsData.server_name, 
			report_reason, 
			GAMETYPE, 
			GetTime());
		
		g_DB.SetCharset("utf8mb4");
		g_DB.Query(ProcessReportPost, query);
		
		CPrintToChat(client, "%s %t", g_ReportsData.chat_prefix, "Report Successfuly Sent", report.reported_name);
		
		// Send Data on Discord
		if (g_DiscordData.integration_enabled)
			DiscordSendData(report);
		
		// Notify Admin
		if (g_ReportsData.admin_notify)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientAdmin(i))
					NotifyAdmin(i, report);
			}
		}
		
		g_ReportCooldown[client] = GetTime() + g_ReportsData.reports_cooldown;
	}
	else
	{
		CPrintToChat(client, "%s %t", g_ReportsData.chat_prefix, "Report Is On Cooldown", g_ReportCooldown[client] - GetTime());
		return;
	}
}

void DiscordSendData(DiscordReportData report)
{
	DiscordWebHook hook = new DiscordWebHook(g_DiscordData.webhook);
	char message[MAX_DISCORD_MSG_SIZE * 2];
	
	hook.SetUsername(g_DiscordData.bot_name);
	hook.SetAvatar(g_DiscordData.profile_url);
	
	int len = g_DiscordMentionRoles.Length;
	int size = len * 32;
	char[] mentions = new char[size];
	MakeMentionsList(g_DiscordMentionRoles, mentions, size);
	
	if (g_DiscordData.message_type == 1) // embed
	{
		FormatDiscordMessage(true, report, mentions, message, sizeof(message));
		
		MessageEmbed Embed = new MessageEmbed();
		hook.SlackMode = true;
		
		Embed.SetColor(g_DiscordData.embed_color);
		Embed.SetThumb(g_DiscordData.embed_thmb_url);
		Embed.SetTitle(g_DiscordData.embed_title);
		Embed.AddField(g_DiscordData.embed_field_name, message, true);
		Embed.SetFooter(g_DiscordData.embed_footer);
		
		hook.Embed(Embed);
		hook.Send();
		
		delete hook;
	}
	else // normal message
	{
		FormatDiscordMessage(false, report, mentions, message, sizeof(message));
		
		hook.SlackMode = false;
		
		hook.SetContent(message);
		hook.Send();
		
		delete hook;
	}
}

void FormatDiscordMessage(
	bool isEmbed, 
	DiscordReportData report, 
	const char[] mentions, 
	char[] output,
	int size)
{
	strcopy(output, size, g_DiscordData.message);
	
	char ip[32];
	GetServerIp(ip, sizeof(ip));
	
	char buffer[MAX_AUTHID_LENGTH];
	
	ReplaceString(output, size, "{server_name}", g_ReportsData.server_name);
	ReplaceString(output, size, "{server_ip}", ip);
	
	ReplaceString(output, size, "{client_name}", report.client_name);
	MakeProfileLinkString(isEmbed, report.client_auth, buffer, sizeof(buffer));
	ReplaceString(output, size, "{client_profile}", buffer);
	ReplaceString(output, size, "{client_steamid64}", report.client_auth);

	GetClientAuthId(report.client, AuthId_Steam3, buffer, sizeof(buffer));
	ReplaceString(output, size, "{client_steamid3}", buffer);
	GetClientAuthId(report.client, AuthId_Steam2, buffer, sizeof(buffer));
	ReplaceString(output, size, "{client_steamid2}", buffer);
	
	ReplaceString(output, size, "{reported_name}", report.reported_name);
	MakeProfileLinkString(isEmbed, report.reported_auth, buffer, sizeof(buffer));
	ReplaceString(output, size, "{reported_profile}", buffer);
	ReplaceString(output, size, "{reported_steamid64}", report.reported_auth);

	GetClientAuthId(report.reported_client, AuthId_Steam3, buffer, sizeof(buffer));
	ReplaceString(output, size, "{reported_steamid3}", buffer);
	GetClientAuthId(report.reported_client, AuthId_Steam2, buffer, sizeof(buffer));
	ReplaceString(output, size, "{reported_steamid2}", buffer);

	ReplaceString(output, size, "{report_reason}", report.report_reason);
	ReplaceString(output, size, "{mentions_list}", mentions);
}

void MakeProfileLinkString(bool isEmbed, const char[] auth, char[] output, int size)
{
    if (isEmbed)
        FormatEx(output, size, "http://steamcommunity.com/profiles/%s", auth);
    else
        FormatEx(output, size, "<http://steamcommunity.com/profiles/%s>", auth);
}

void NotifyAdmin(int admin, DiscordReportData report)
{
	CPrintToChat(admin, "%t", "Admin MSG Title");
	CPrintToChat(admin, "%t", "Admin MSG Who Reported", report.client_name);
	CPrintToChat(admin, "%t", "Admin MSG Reported Player", report.reported_name);
	CPrintToChat(admin, "%t", "Admin MSG Report Reason", report.report_reason);
	CPrintToChat(admin, "%t", "Admin MSG Title");
	
	if (g_ReportsData.admin_sound)
		EmitSoundToClient(admin, g_ReportsData.admin_sound_path);
}

void MakeMentionsList(ArrayList Mentions, char[] output, int size)
{
	char id[DISCORD_ROLE_ID_SIZE];
	int len = Mentions.Length;
	
	for (int i = 0; i < len; ++i)
	{
		Mentions.GetString(i, id, sizeof(id));
		if (i == 0)
			FormatEx(output, size, "[ %s ]", id);
		else
			Format(output, size, "%s - [ %s ]", output, id);
	}
}

public void ProcessReportPost(Database db, DBResultSet results, const char[] error, any data)
{
	if (QueryErrored(db, results, error))
	{
		LogError("[ Reports ] Information could not be saved (error: %s)", error);
		return;
	}
}

bool LoadConfig(bool fatalError = true)
{
	KeyValues kv = new KeyValues("Reports");
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/reports.cfg");
	
	if (!kv.ImportFromFile(path))
	{
		if (fatalError)
			SetFailState("Can't find config file: %s", path);
		else
		{
			LogError("Can't find config file: %s", path);
			delete kv;
			return false;
		}
	}
	
	Config_GetMainData(kv);
	Config_GetReportReasons(kv);
	Config_GetDiscordData(kv);
	
	delete kv;
	return true;
}

void Config_GetMainData(KeyValues kv)
{
	if (!kv.JumpToKey("Main Configuration"))
		SetFailState("[ Reports ] Can't process Main Configuration structure");
	
	g_ReportsData.admin_notify = view_as<bool>(kv.GetNum("admin_notification"));
	g_ReportsData.admin_sound = view_as<bool>(kv.GetNum("admin_notification_sound"));
	
	kv.GetString("admin_sound_path", g_ReportsData.admin_sound_path, sizeof(ReportsData::admin_sound_path));
	kv.GetString("server_name", g_ReportsData.server_name, sizeof(ReportsData::server_name));
	kv.GetString("chat_prefix", g_ReportsData.chat_prefix, sizeof(ReportsData::chat_prefix));
	
	g_ReportsData.reports_cooldown = kv.GetNum("reports_cooldown");

	kv.GetString("blocked_characters", g_ReportsData.blocked_chars, sizeof(ReportsData::blocked_chars));

	kv.Rewind();
}

void Config_GetReportReasons(KeyValues kv)
{
	if (!kv.JumpToKey("Report Reasons"))
		SetFailState("[ Reports ] Can't process Reports Reasons structure");
	
	if (!kv.GotoFirstSubKey(false))
    {
        LogError("[ Reports ] Reasons are empty");
        return;
    }
	
	g_ReportReasons.Clear();
	
	char report_reasons[REPORT_REASONS_SIZE];
	do
	{
		kv.GetSectionName(report_reasons, sizeof(report_reasons));
		if (!StrEqual(report_reasons, "reason"))
			continue;
		
		kv.GetString(NULL_STRING, report_reasons, sizeof(report_reasons));
		
		g_ReportReasons.PushString(report_reasons);
	}
	while (kv.GotoNextKey(false));
	
	kv.GoBack();
	g_ReportCustomReason = view_as<bool>(kv.GetNum("custom_reason"));
	
	kv.Rewind();
}

void Config_GetDiscordData(KeyValues kv)
{
	if (!kv.JumpToKey("Discord Integration"))
		SetFailState("[ Reports ] Can't process discord data structure");
	
	g_DiscordData.integration_enabled = view_as<bool>(kv.GetNum("enabled"));
	kv.GetString("webhook", g_DiscordData.webhook, sizeof(DiscordData::webhook));
	if (g_DiscordData.integration_enabled && !g_DiscordData.webhook[0])
		SetFailState("[ Reports ] Webhook can't be empty");
	g_DiscordData.message_type = kv.GetNum("message_mode");
	kv.GetString("bot_name", g_DiscordData.bot_name, sizeof(DiscordData::bot_name));
	kv.GetString("bot_picture_url", g_DiscordData.profile_url, sizeof(DiscordData::profile_url));
	
	Config_GetDiscordMessage(kv);
	Config_GetDiscordMentionRoles(kv);
	Config_GetDiscordEmbedData(kv);
}

void Config_GetDiscordMessage(KeyValues kv)
{
    if (!kv.JumpToKey("Message Text"))
        SetFailState("[ Reports ] Can't process Message Text structure");
    
    if (!kv.GotoFirstSubKey(false))
    {
        LogError("[ Reports ] Discord message is empty");
        return;
    }

    g_DiscordData.message[0] = '\0';

    char line[128];
    do
    {
        kv.GetString(NULL_STRING, line, sizeof(line));

        StrCat(g_DiscordData.message, sizeof(DiscordData::message), line);
        ForceAppendNewLine(g_DiscordData.message, sizeof(DiscordData::message));
    }
    while(kv.GotoNextKey(false));

    RemoveLastNewLine(g_DiscordData.message, sizeof(DiscordData::message));

    kv.GoBack(); // Go back to "Message Text"
    kv.GoBack(); // Go back to Discord Integration
}

void Config_GetDiscordMentionRoles(KeyValues kv)
{
	if (!kv.JumpToKey("Mention Roles"))
		SetFailState("[ Reports ] Can't process Mention Roles structure");

	if (!kv.GotoFirstSubKey(false))
    {
        LogError("[ Reports ] Mention roles are empty");
        return;
    }
	
	g_DiscordMentionRoles.Clear();
	
	char id[DISCORD_ROLE_ID_SIZE];
	do
	{
		kv.GetString(NULL_STRING, id, sizeof(id));
		
		g_DiscordMentionRoles.PushString(id);
	}
	while (kv.GotoNextKey(false));
	
	kv.GoBack(); // Go back to Mention Roles
	kv.GoBack(); // Go back to Discord Integration
}

void Config_GetDiscordEmbedData(KeyValues kv)
{
	if (!kv.JumpToKey("Embed Mode"))
		SetFailState("[ Reports ] Can't process Embed Mode structure");
	
	kv.GetString("embed_title", g_DiscordData.embed_title, sizeof(DiscordData::embed_title));
	kv.GetString("embed_field_name", g_DiscordData.embed_field_name, sizeof(DiscordData::embed_field_name));
	kv.GetString("embed_color", g_DiscordData.embed_color, sizeof(DiscordData::embed_color));
	kv.GetString("embed_footer", g_DiscordData.embed_footer, sizeof(DiscordData::embed_footer));
	kv.GetString("embed_thumbnail_url", g_DiscordData.embed_thmb_url, sizeof(DiscordData::embed_thmb_url));
	
	kv.Rewind();
}

void PrecacheAndDownloadSound()
{
	// Aparently L4D2 does not support custom sounds or it has different method of doing that.
	// So let's skip it.
	if (GetEngineVersion() == Engine_Left4Dead2)
	{
		LogError("[ Reports ] L2D2 Game does not support admin sound. This functionality is disabled");
		return;
	}
	
	if (g_ReportsData.admin_sound)
	{
		char buffer[64];
		
		FormatEx(buffer, sizeof(buffer), "sound/%s", g_ReportsData.admin_sound_path);
		AddFileToDownloadsTable(buffer);
		
		FormatEx(buffer, sizeof(buffer), "*/%s", g_ReportsData.admin_sound_path);
		PrecacheSound(buffer, true);
	}
}

// Game type will be stored in database for integration with CMS plugins or any other web-panels etc.
void IdentifyGameType(char[] output, int size)
{
	switch (GetEngineVersion())
	{
		case Engine_CSGO:strcopy(output, size, "csgo");
		case Engine_CSS:strcopy(output, size, "cssource");
		case Engine_TF2:strcopy(output, size, "tf2");
		case Engine_Left4Dead2:strcopy(output, size, "l4d2");
		default:strcopy(output, size, "unknown");
	}
}

void GetServerIp(char[] output, int size)
{
	int pieces[4];
	int longip = GetConVarInt(FindConVar("hostip"));
	int port = GetConVarInt(FindConVar("hostport"));
	
	pieces[0] = (longip >>> 24) & 0xFF;
	pieces[1] = (longip >>> 16) & 0xFF;
	pieces[2] = (longip >>> 8) & 0xFF;
	pieces[3] = longip & 0xFF;
	
	FormatEx(output, size, "%d.%d.%d.%d:%d", 
		pieces[0], 
		pieces[1], 
		pieces[2], 
		pieces[3], 
		port);
}

stock void ForceAppendNewLine(char[] str, int size)
{
    int index = Format(str, size, "%s\n", str);

    --index;
    if (index > 0 && index < size)
        str[index] = '\n';
}

stock void RemoveLastNewLine(char[] str, int size)
{
    int len = strlen(str);
    if (len >= size)
        ThrowError("String is larger than size");
    
    --len;
    if (len >= 0 && str[len] == '\n')
    	str[len] = '\0';
}

bool ContainsBlockedCharacters(const char[] str, char separator, bool caseSensitive = true)
{
	int semicolons = CountExplodeSegments(g_ReportsData.blocked_chars, separator);

	char split[2];
	split[0] = separator;

	char[][] exploded = new char[semicolons][5]; // 4-byte chars (utf-8) + null
	ExplodeString(g_ReportsData.blocked_chars, split, exploded, semicolons, 5);

	for (int i = 0; i < semicolons; ++i)
	{
		if (StrContains(str, exploded[i], caseSensitive) != -1)
			return true;
	}

	return false;
}

int CountExplodeSegments(const char[] str, char separator)
{
	int len = strlen(str);
	int count = 0;
	for (int i = 0; i < len; ++i)
	{
		if (str[i] == separator)
			++count;
	}

	// If string ends in separator remove it from count
	if (str[len - 1] == separator)
		--count;
	return count;
}

stock bool QueryErrored(Database db, DBResultSet results, const char[] error)
{
	return (db == null || results == null || error[0] != '\0');
}

bool IsClientAdmin(int client)
{
	return CheckCommandAccess(client, "reports_admin", ADMFLAG_BAN);
}