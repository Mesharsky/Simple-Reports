## Simple Reports Plugin

A simple player reporting plugin that stores reports in a MySQL database, with Discord integration to help server admins to react faster to the reports.  

------------

| Supported Games | Minimum SourceMod Version |
| ------------ | ------------ |
|  CS:GO | SM 1.10+ |
|  CS:Source | SM 1.10+ |
|  Team Fortress 2  | SM 1.10+ |
|  Left 4 Dead 2 | SM 1.10+ |

*Other games should still work, but their gametype will be marked as unknown in the database.*  
*If you test other games and they work properly, let me know so I can add official support for it!*  

------------
### FEATURES

- An extensive and eye-catching configuration file.
- MySQL database support to store reports.
- SourceMod translations support (currently only *Polish* and *English* have translations).
- In-game admin notification (with optional sound).
- Full Discord Integration (Embed + Normal Messages). Fully configurable through configuration file, with completely customiseable message text.
------------
### COMMANDS
| Command | Description |
| ------------ | ------------ |
| **!report** | Main Report Menu. |
| **!reloadreports** | Reload Configuration File *(requires root flag)*. |  

------------
### HOW TO CONFIGURE

Read the documentation inside [the config file.](https://github.com/Mesharsky/Simple-Reports/blob/main/addons/sourcemod/configs/reports.cfg "Config File")

------------
### INSTALLATION

Download the latest release [from here.](https://github.com/Mesharsky/Simple-Reports/releases "Latest Release")  

All the extensions and required plugins are in the zip file provided.  

1. Upload all files to root directory of your server ([How to install plugins](https://wiki.alliedmods.net/Managing_your_sourcemod_installation#Installing_Plugins "Installing Plugins"))  
Make sure `discord_api` plugin and `smjansson` extension are also uploaded (both are required).  

2. This plugin **requires a MySQL Database**. You will need to add the connection into  
`addons/sourcemod/configs/databases.cfg` like below:

```
	"reports"
	{
		"driver"			"default"
		"host"				"database host (example: 152.325.654.245)"
		"database"			"database name"
		"user"				"database username"
		"pass"				"database password"
	}
```
3. Configure plugin settings in the configuration file: `addons/sourcemod/configs/reports.cfg`

#### "How do I get the discord channel webhook?"
Please follow the official discord guide on [how to get your WebHook for discord channel.](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks "Intro to WebHooks")

------------
### WEB ADDONS

My friend made plugin integration with **Invision Community CMS Forum Software**.  
The plugin can be found in the `web_addons` folder in the repository along with installation instructions.

------------
### EXTENSIONS/LIBRARIES/INCLUDES USED

[SMJansson](https://forums.alliedmods.net/showthread.php?t=184604 "SMJansson")  
[Discord API](https://github.com/Deathknife/sourcemod-discord "Discord API")  
[MultiColors](https://forums.alliedmods.net/showthread.php?t=247770 "MultiColors")  *(included in the repository)*

------------
### LANGUAGE SUPPORT
Currently only Polish and English have translations, if you make one for another language let me know so I can add it to the plugin.

------------
### CREDITS

[Thrawn2](https://forums.alliedmods.net/member.php?u=51683 "Thrawn2") - Extension used in the plugin.  
[Deathknife](https://github.com/Deathknife "Deathknife") - Discord Api Plugin.  
[Bara](https://forums.alliedmods.net/member.php?u=178115 "Bara") - Multicolors Include.  
[Digby](https://github.com/sirdigbot/ "dude who makes plugins in 3 hours") - Huge help and tips how to write better code lol.
