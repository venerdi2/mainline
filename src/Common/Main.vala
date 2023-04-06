/*
 * Main.vala
 *
 * Copyright 2012 Tony George <teejee2008@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

using GLib;
using Gee;
using Json;

using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;
using l.misc;

[CCode(cname="BRANDING_SHORTNAME")] extern const string BRANDING_SHORTNAME;
[CCode(cname="BRANDING_LONGNAME")] extern const string BRANDING_LONGNAME;
[CCode(cname="BRANDING_VERSION")] extern const string BRANDING_VERSION;
[CCode(cname="BRANDING_AUTHORNAME")] extern const string BRANDING_AUTHORNAME;
[CCode(cname="BRANDING_AUTHOREMAIL")] extern const string BRANDING_AUTHOREMAIL;
[CCode(cname="BRANDING_WEBSITE")] extern const string BRANDING_WEBSITE;
[CCode(cname="INSTALL_PREFIX")] extern const string INSTALL_PREFIX;

const string LOCALE_DIR = INSTALL_PREFIX + "/share/locale";
const string APP_LIB_DIR = INSTALL_PREFIX + "/lib/" + BRANDING_SHORTNAME;

//////////////////////////////////////////////////////////////////////////////
// CONFIG FILE DEFAULTS
// .h files are a pain in the ass in vala so dump these here

// network
const string	DEFAULT_PPA_URI					= "https://kernel.ubuntu.com/~kernel-ppa/mainline/";
const string	DEFAULT_ALL_PROXY				= ""		;
const int		DEFAULT_CONNECT_TIMEOUT_SECONDS	= 15		;
const int		DEFAULT_CONCURRENT_DOWNLOADS	= 1			;
// filters
const bool		DEFAULT_HIDE_UNSTABLE			= true		;
const int		DEFAULT_PREVIOUS_MAJORS			= 0			;
// notifications
const bool		DEFAULT_NOTIFY_MAJOR			= false		;
const bool		DEFAULT_NOTIFY_MINOR			= false		;
const int		DEFAULT_NOTIFY_INTERVAL_VALUE	= 4			;  // FIXME
const int		DEFAULT_NOTIFY_INTERVAL_UNIT	= 0			;  // use enum
// other
const bool		DEFAULT_VERIFY_CHECKSUMS		= false		;
// windows
const int		DEFAULT_WINDOW_WIDTH			= 800		;
const int		DEFAULT_WINDOW_HEIGHT			= 600		;
const int		DEFAULT_WINDOW_X				= -1		;
const int		DEFAULT_WINDOW_Y				= -1		;
const int		DEFAULT_TERM_WIDTH				= 1100		;
const int		DEFAULT_TERM_HEIGHT				= 600		;
//const int		DEFAULT_TERM_X					= -1		;
//const int		DEFAULT_TERM_Y					= -1		;

extern void exit(int exit_code);

public class Main : GLib.Object {

	// constants ----------

	public string TMP_PREFIX = "";
	public string APP_CONF_DIR = "";
	public string APP_CONFIG_FILE = "";
	public string STARTUP_SCRIPT_FILE = "";
	public string STARTUP_DESKTOP_FILE = "";
	public string OLD_STARTUP_SCRIPT_FILE = ""; // TRANSITION
	public string OLD_STARTUP_DESKTOP_FILE = ""; // TRANSITION
	public string NOTIFICATION_ID_FILE = "";
	public string MAJOR_SEEN_FILE = "";
	public string MINOR_SEEN_FILE = "";

	public string user_login = "";
	public string user_home = "";
	public string CACHE_DIR = "~/.cache/"+BRANDING_SHORTNAME ; // some hard-coded non-empty for rm -rf safety

	// global progress ----------------

	public string status_line = "";
	public int progress_total = 0;
	public int progress_count = 0;
	public bool cancelled = false;

	// state flags ----------

	public int VERBOSE = 1;
	public bool GUI_MODE = false;
	public string command = "list";
	public string requested_version = "";
	public bool ppa_tried = false;
	public bool ppa_up = true;
	public bool index_is_fresh = false;

	public string ppa_uri = DEFAULT_PPA_URI;
	public string all_proxy = DEFAULT_ALL_PROXY;
	public int connect_timeout_seconds = DEFAULT_CONNECT_TIMEOUT_SECONDS;
	public int concurrent_downloads = DEFAULT_CONCURRENT_DOWNLOADS;
	public bool hide_unstable = DEFAULT_HIDE_UNSTABLE;
	public int previous_majors = DEFAULT_PREVIOUS_MAJORS;
	public bool notify_major = DEFAULT_NOTIFY_MAJOR;
	public bool notify_minor = DEFAULT_NOTIFY_MINOR;
	public int notify_interval_unit = DEFAULT_NOTIFY_INTERVAL_UNIT;
	public int notify_interval_value = DEFAULT_NOTIFY_INTERVAL_VALUE;
	public bool verify_checksums = DEFAULT_VERIFY_CHECKSUMS;

	public int window_width = DEFAULT_WINDOW_WIDTH;
	public int window_height = DEFAULT_WINDOW_HEIGHT;
	public int _window_width = DEFAULT_WINDOW_WIDTH;
	public int _window_height = DEFAULT_WINDOW_HEIGHT;
	public int window_x = DEFAULT_WINDOW_X;
	public int window_y = DEFAULT_WINDOW_Y;
	public int _window_x = DEFAULT_WINDOW_X;
	public int _window_y = DEFAULT_WINDOW_Y;

	// *sizing* the terminal window is working
	public int term_width = DEFAULT_TERM_WIDTH;
	public int term_height = DEFAULT_TERM_HEIGHT;
	public int _term_width = DEFAULT_TERM_WIDTH;
	public int _term_height = DEFAULT_TERM_HEIGHT;
/* // *positioning* the terminal window is not working
	public int term_x = DEFAULT_TERM_X;
	public int term_y = DEFAULT_TERM_Y;
	public int _term_x = DEFAULT_TERM_X;
	public int _term_y = DEFAULT_TERM_Y;
*/

	public bool confirm = true;

	// constructors ------------

	public Main(string[] arg0, bool _gui_mode) {
		GUI_MODE = _gui_mode;
		get_env();
		vprint(BRANDING_SHORTNAME+" "+BRANDING_VERSION);
		init_paths();
		load_app_config();
		Package.initialize();
		LinuxKernel.initialize();
	}

	// helpers ------------

	public void get_env() {
		if (Environment.get_variable("VERBOSE")!=null) {
			string s = Environment.get_variable("VERBOSE").down();
			if (s=="false") s = "0";
			if (s=="true") s = "1";
			VERBOSE = int.parse(s);
			l.misc.VERBOSE = VERBOSE;
		}
	}

	public void init_paths() {

		// user info
		user_login = Environment.get_user_name();
		user_home = Environment.get_home_dir();

		APP_CONF_DIR = user_home + "/.config/" + BRANDING_SHORTNAME;
		APP_CONFIG_FILE = APP_CONF_DIR + "/config.json";
		STARTUP_SCRIPT_FILE = APP_CONF_DIR + "/" + BRANDING_SHORTNAME + "-notify.sh";
		STARTUP_DESKTOP_FILE = user_home + "/.config/autostart/" + BRANDING_SHORTNAME + "-notify.desktop";
		OLD_STARTUP_SCRIPT_FILE = APP_CONF_DIR + "/notify-loop.sh"; // TRANSITION
		OLD_STARTUP_DESKTOP_FILE = user_home + "/.config/autostart/" + BRANDING_SHORTNAME + ".desktop"; // TRANSITION
		NOTIFICATION_ID_FILE = APP_CONF_DIR + "/notification_id";
		MAJOR_SEEN_FILE = APP_CONF_DIR + "/notification_seen.major";
		MINOR_SEEN_FILE = APP_CONF_DIR + "/notification_seen.minor";
		CACHE_DIR = user_home + "/.cache/" + BRANDING_SHORTNAME;
		TMP_PREFIX = Environment.get_tmp_dir() + "/." + BRANDING_SHORTNAME;

		LinuxKernel.CACHE_DIR = CACHE_DIR;

	}

	public void save_app_config() {
		vprint("save_app_config()",2);

		var config = new Json.Object();
		config.set_string_member(	"ppa_uri",					ppa_uri					);
		config.set_string_member(	"all_proxy",				all_proxy				);
		config.set_int_member(		"connect_timeout_seconds",	connect_timeout_seconds	);
		config.set_int_member(		"concurrent_downloads",		concurrent_downloads	);
		config.set_boolean_member(	"hide_unstable",			hide_unstable			);
		config.set_int_member(		"previous_majors",			previous_majors			);
		config.set_boolean_member(	"notify_major",				notify_major			);
		config.set_boolean_member(	"notify_minor",				notify_minor			);
		config.set_int_member(		"notify_interval_unit",		notify_interval_unit	);
		config.set_int_member(		"notify_interval_value",	notify_interval_value	);
		config.set_boolean_member(	"verify_checksums",			verify_checksums		);
		config.set_int_member(		"window_width",				window_width			);
		config.set_int_member(		"window_height",			window_height			);
		config.set_int_member(		"window_x",					window_x				);
		config.set_int_member(		"window_y",					window_y				);
		config.set_int_member(		"term_width",				term_width				);
		config.set_int_member(		"term_height",				term_height				);
//		config.set_int_member(		"term_x",					term_x					);
//		config.set_int_member(		"term_y",					term_y					);

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		dir_create(APP_CONF_DIR);
		try { json.to_file(APP_CONFIG_FILE); }
		catch (Error e) { vprint(e.message,1,stderr); }

		vprint("Wrote config file: %s".printf(APP_CONFIG_FILE),2);

		update_notification_files();
	}

	public void update_notification_files() {
		update_startup_script();
		update_startup_desktop_file();
	}

	public void load_app_config() {
		vprint("load_app_config()",2);

		var parser = new Json.Parser();

		bool cf = true;
		try { parser.load_from_file(APP_CONFIG_FILE); }
		catch (Error e) { cf = false; vprint(e.message,2); }
		if (!cf) {
			vprint("detetcted no config file",2);
			save_app_config();
			try { parser.load_from_file(APP_CONFIG_FILE); }
			catch (Error e) { vprint(e.message,1,stderr); exit(1); }
		}

		var node = parser.get_root();
		var config = node.get_object();

		// TRANSITION PERIOD
		// detect old file format
		// hide_unstable, notify_major, notify minor
		// are all options that have existed since the oldest version of ukuu,
		// still exist today, and are not string type.
		// They should be present in all config files no matter how old,
		// and if they are stored as a string,
		// then the config file is in the old format
		bool resave = false;
		if (config.get_string_member("hide_unstable")==null) {
			vprint("detetcted new config file format",2);
			// new config file format - values stored in native format
			ppa_uri					=	config.get_string_member_with_default(		"ppa_uri",					DEFAULT_PPA_URI					);
			all_proxy				=	config.get_string_member_with_default(		"all_proxy",				DEFAULT_ALL_PROXY				);
			connect_timeout_seconds	=	(int)config.get_int_member_with_default(	"connect_timeout_seconds",	DEFAULT_CONNECT_TIMEOUT_SECONDS	);
			concurrent_downloads	=	(int)config.get_int_member_with_default(	"concurrent_downloads",		DEFAULT_CONCURRENT_DOWNLOADS	);
			hide_unstable			=	config.get_boolean_member_with_default(		"hide_unstable",			DEFAULT_HIDE_UNSTABLE			);
			previous_majors			=	(int)config.get_int_member_with_default(	"previous_majors",			DEFAULT_PREVIOUS_MAJORS			);
			notify_major			=	config.get_boolean_member_with_default(		"notify_major",				DEFAULT_NOTIFY_MAJOR			);
			notify_minor			=	config.get_boolean_member_with_default(		"notify_minor",				DEFAULT_NOTIFY_MINOR			);
			notify_interval_unit	=	(int)config.get_int_member_with_default(	"notify_interval_unit",		DEFAULT_NOTIFY_INTERVAL_UNIT	);
			notify_interval_value	=	(int)config.get_int_member_with_default(	"notify_interval_value",	DEFAULT_NOTIFY_INTERVAL_VALUE	);
			verify_checksums		=	config.get_boolean_member_with_default(		"verify_checksums",			DEFAULT_VERIFY_CHECKSUMS		);
			window_width			=	(int)config.get_int_member_with_default(	"window_width",				DEFAULT_WINDOW_WIDTH			);
			window_height			=	(int)config.get_int_member_with_default(	"window_height",			DEFAULT_WINDOW_HEIGHT			);
			window_x				=	(int)config.get_int_member_with_default(	"window_x",					DEFAULT_WINDOW_X				);
			window_y				=	(int)config.get_int_member_with_default(	"window_y",					DEFAULT_WINDOW_Y				);
			term_width				=	(int)config.get_int_member_with_default(	"term_width",				DEFAULT_TERM_WIDTH				);
			term_height				=	(int)config.get_int_member_with_default(	"term_height",				DEFAULT_TERM_HEIGHT				);
			//term_x				=	(int)config.get_int_member_with_default(	"term_x",					DEFAULT_TERM_X					);
			//term_y				=	(int)config.get_int_member_with_default(	"term_y",					DEFAULT_TERM_Y					);
		} else {
			vprint("detetcted old config file format",2);
			resave = true;
			// old config file format - all values stored as string
			ppa_uri					=				config.get_string_member_with_default(	"ppa_uri",					DEFAULT_PPA_URI									)	;
			all_proxy				=				config.get_string_member_with_default(	"all_proxy",				DEFAULT_ALL_PROXY								)	;
			connect_timeout_seconds	=	int.parse(	config.get_string_member_with_default(	"connect_timeout_seconds",	DEFAULT_CONNECT_TIMEOUT_SECONDS	.to_string()	)	);
			concurrent_downloads	=	int.parse(	config.get_string_member_with_default(	"concurrent_downloads",		DEFAULT_CONCURRENT_DOWNLOADS	.to_string()	)	);
			hide_unstable			=	bool.parse(	config.get_string_member_with_default(	"hide_unstable",			DEFAULT_HIDE_UNSTABLE			.to_string()	)	);
			previous_majors			=	int.parse(	config.get_string_member_with_default(	"previous_majors",			DEFAULT_PREVIOUS_MAJORS			.to_string()	)	);
			notify_major			=	bool.parse(	config.get_string_member_with_default(	"notify_major",				DEFAULT_NOTIFY_MAJOR			.to_string()	)	);
			notify_minor			=	bool.parse(	config.get_string_member_with_default(	"notify_minor",				DEFAULT_NOTIFY_MINOR			.to_string()	)	);
			notify_interval_unit	=	int.parse(	config.get_string_member_with_default(	"notify_interval_unit",		DEFAULT_NOTIFY_INTERVAL_UNIT	.to_string()	)	);
			notify_interval_value	=	int.parse(	config.get_string_member_with_default(	"notify_interval_value",	DEFAULT_NOTIFY_INTERVAL_VALUE	.to_string()	)	);
			window_width			=	int.parse(	config.get_string_member_with_default(	"window_width",				DEFAULT_WINDOW_WIDTH			.to_string()	)	);
			window_height			=	int.parse(	config.get_string_member_with_default(	"window_height",			DEFAULT_WINDOW_HEIGHT			.to_string()	)	);
			window_x				=	int.parse(	config.get_string_member_with_default(	"window_x",					DEFAULT_WINDOW_X				.to_string()	)	);
			window_y				=	int.parse(	config.get_string_member_with_default(	"window_y",					DEFAULT_WINDOW_Y				.to_string()	)	);
			term_width				=	int.parse(	config.get_string_member_with_default(	"term_width",				DEFAULT_TERM_WIDTH				.to_string()	)	);
			term_height				=	int.parse(	config.get_string_member_with_default(	"term_height",				DEFAULT_TERM_HEIGHT				.to_string()	)	);
			//term_x				=	int.parse(	config.get_string_member_with_default(	"term_x",					DEFAULT_TERM_X					.to_string()	)	);
			//term_y				=	int.parse(	config.get_string_member_with_default(	"term_y",					DEFAULT_TERM_Y					.to_string()	)	);
		}

		// fixups
		if (ppa_uri.length==0) { ppa_uri = DEFAULT_PPA_URI; resave = true; }
		if (!ppa_uri.has_suffix("/")) { ppa_uri += "/"; resave = true; }
		LinuxKernel.PPA_URI = ppa_uri;
		if (connect_timeout_seconds>600) connect_timeout_seconds = 600; // aria2c max allowed

		if (resave) save_app_config();

		vprint("Loaded config file: "+APP_CONFIG_FILE,2);
	}

	// begin ------------
	private void update_startup_script() {
		vprint("update_startup_script()",2);

		// construct the commandline argument for "sleep"
		int count = notify_interval_value;
		string suffix = "h";
		switch (notify_interval_unit) {
		case 0: // hour
			suffix = "h";
			break;
		case 1: // day
			suffix = "d";
			break;
		case 2: // week
			suffix = "d";
			count = notify_interval_value * 7;
			break;
		case 3: // second
			suffix = "";
			count = notify_interval_value;
			break;
		}

		file_delete(STARTUP_SCRIPT_FILE);
		file_delete(OLD_STARTUP_SCRIPT_FILE); // TRANSITION

		// TODO, ID file should not assume single DISPLAY
		//       ID and SEEN should probably be in /var/run ?
		string s = "#!/bin/bash\n"
			+ "# "+_("Called from")+" "+STARTUP_DESKTOP_FILE+" "+_("at logon")+".\n"
			+ "# "+_("This file is over-written and executed again whenever settings are saved in")+" "+BRANDING_SHORTNAME+"-gtk\n"
			+ "[[ $1 == --autostart ]] && rm -f \""+NOTIFICATION_ID_FILE+"\" \""+MAJOR_SEEN_FILE+"\" \""+MINOR_SEEN_FILE+"\"\n"
			+ "TMP=${XDG_RUNTIME_DIR:-/tmp}\n"
			+ "N=${0//\\//_}\n"
			+ "F=\"${TMP}/${N}.${$}.p\"\n"
			+ "trap '[[ -f ${F}_ ]] && read c < ${F}_ && kill $c ;rm -f ${F}{,_}' 0\n"
			+ "typeset -i p\n"
			+ "shopt -s extglob\n"
			+ "\n"
			+ "# clear previous state (kill previous instance)\n"
			+ "echo -n \"${DISPLAY} ${$}\" > $F\n"
			+ "for f in ${TMP}/${N}.+([0-9]).p ;do\n"
			+ "\t[[ -s $f ]] || continue\n"
			+ "\t[[ $f -ot $F ]] || continue\n"
			+ "\tread d p x < $f\n"
			+ "\t[[ $d == ${DISPLAY} ]] || continue\n"
			+ "\t((p>1)) || continue\n"
			+ "\trm -f $f\n"
			+ "\tkill $p\n"
			+ "done\n"
			+ "unset N f p d x\n"
			+ "\n"
			+ "# run whatever the new state should be\n";
		if (notify_minor || notify_major) {
			s += "while [[ -f $F ]] ;do\n"
			+ "\t"+BRANDING_SHORTNAME+" --notify 2>&- >&-\n"
			+ "\tsleep %d%s &\n".printf(count,suffix)
			+ "\tc=$!\n"
			+ "\techo $c >>${F}_\n"
			+ "\twait $c\n"	// respond to signals during sleep
			+ "done\n";
		} else {
			s += "# " + _("Notifications are disabled") + "\n"
			+ "exit 0\n";
		}

		if (GUI_MODE) {
			// save_app_config() gets run right at app startup if the config file
			// doesn't exist yet, so sometimes update_startup_script() might run
			// early in app start-up when we haven't done the cache update yet.
			// If we blindly launch the background notification process immediately
			// any time settings are updated, the --notify process and ourselves
			// will both try to update the same cache files at the same time and
			// step all over each other.
			// This is not really a fully correct answer, but mostly good enough:
			// * If all notifications are now OFF, then run the new startup script
			//   immediately so that it clears out the existing notification loop
			//   that might be running.
			// * Otherwise don't do anything right now, and run the new startup
			//   script at app exit instead.
			file_write(STARTUP_SCRIPT_FILE,s);
			if (!notify_major && !notify_minor) exec_async("bash "+STARTUP_SCRIPT_FILE+" 2>&- >&- <&-");
		}
	}

	private void update_startup_desktop_file() {
		vprint("update_startup_desktop_file()",2);

		if (notify_minor || notify_major) {
			string s = "[Desktop Entry]\n"
				+ "Exec=bash \""+STARTUP_SCRIPT_FILE+"\" --autostart\n"
				;
			file_write(STARTUP_DESKTOP_FILE,s);
		} else {
			file_delete(STARTUP_DESKTOP_FILE);
			file_delete(OLD_STARTUP_DESKTOP_FILE); // TRANSITION
		}
	}

}
