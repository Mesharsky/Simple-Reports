## Simple Reports Plugin

This simple plugin allows to report players on the server and store that data in MySQL.
Also there is built in Discord Integration that allows server admins to react faster for the reports.

------------

| SUPPORTED GAMES  |   | SUPPORTED SM VERSIONS |  |
| ------------ | ------------ | ------------ | ------------ |
|  CSGO |  ✅ | SM 1.10+ | ✅ |
|  CS:SOURCE |  ✅ | SM 1.10+ | ✅ |
|  TEAM FORTRESS 2 | ✅  | SM 1.10+ | ✅ |
|  LEFT 4 DEAD 2 |  ✅ | SM 1.10+ | ✅ |

**More games might work as well but their gametype will be marked as unknown in database**
**If you test other games and it will work properly. Let me know so i can add official support for it!**

------------
### FEATURES

- An extensive and eye-catching configuration file.
- MySQL support to store Reports with all the data.
- MultiLang support.
- Admin notification on the server + Sound.
- Reports cooldown in seconds (configurable).
- Full Discord Integration (Embed + Normal Messages). Fully configurable through configuration file + A lot options for discord messages.
------------
### COMMANDS
- !report - Main Report Menu.
- !reloadreports - Reload Configuration File (Reuries: Admin_Root permission).
------------
### HOW TO CONFIGURE

Please read the documentation in the config file

Link: [CLICK HERE](https://github.com/Mesharsky/Simple-Reports/blob/main/addons/sourcemod/configs/reports.cfg "CLICK HERE")

------------
### INSTALLATION

Download latest release from here: [CLICK HERE](https://github.com/Mesharsky/Simple-Reports/releases "CLICK HERE")
All the extensions and required plugins are in the zip file provided.

1. Upload all files to root directory of your server (Guide how to install plugins: [CLICK HERE](https://wiki.alliedmods.net/Managing_your_sourcemod_installation#Installing_Plugins "CLICK HERE")) Make sure discord_api plugin and smjansson extension are also uploaded (Otherwise plugin will not work)
2. This plugin **requires MySQL Database**. To se it up please navigate to: **addons/sourcemod/configs/databases.cfg** and create a database connection tree like below:

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
3. Configure plugin settings in the configuration file which is in: **addons/sourcemod/configs/reports.cfg** (Guide and comments are arleady in the configuration file).

#### How to get webhook for discord channel?
Please follow the official discord guide how to get your WebHook for discord channel: [CLICK HERE](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks "CLICK HERE")

------------
### WEB ADDONS

My friend made plugin integration with **Invision Community CMS Forum Software**. Plugin can be found in **web_addons** folder in the repository along with installation instructions.

------------
### EXTENSIONS AND CUSTOM PLUGINS/INCLUDES USED

SMJansson Extension: [CLICK HERE](https://forums.alliedmods.net/showthread.php?t=184604 "CLICK HERE")
Discord Api Plugin: [CLICK HERE](https://github.com/Deathknife/sourcemod-discord "CLICK HERE")
Multicolors Include: [CLICK HERE](https://forums.alliedmods.net/showthread.php?t=247770 "CLICK HERE")

------------
### CREDITS

Thrawn2 - Extension used in the plugin: [LINK TO PROFILE](https://forums.alliedmods.net/member.php?u=51683 "LINK TO PROFILE")
Deathknife - Discord Api Plugin: [LINK TO PROFILE](https://github.com/Deathknife "LINK TO PROFILE")
Bara - Multicolors Include: [LINK TO PROFILE](https://forums.alliedmods.net/member.php?u=178115 "PROFILE")
Digby - Huge help and tips how to write better code lol: [LINK TO PROFILE](https://github.com/sirdigbot/ "LINK TO PROFILE")




