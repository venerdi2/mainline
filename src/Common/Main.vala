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

using Json;

using l.misc;
using l.exec;
#if !VALA_0_50
using l.json;
#endif

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
const string   DEFAULT_PPA_URI                 = "https://kernel.ubuntu.com/~kernel-ppa/mainline/";
const string   DEFAULT_ALL_PROXY               = ""    ;
const int      DEFAULT_CONNECT_TIMEOUT_SECONDS = 15    ;
const int      DEFAULT_CONCURRENT_DOWNLOADS    = 4     ;
// filters
const bool     DEFAULT_HIDE_UNSTABLE           = true  ;
const bool     DEFAULT_HIDE_INVALID            = true  ;
const int      DEFAULT_PREVIOUS_MAJORS         = 0     ;
// notifications
const bool     DEFAULT_NOTIFY_MAJOR            = false ;
const bool     DEFAULT_NOTIFY_MINOR            = false ;
const int      DEFAULT_NOTIFY_INTERVAL_VALUE   = 4     ;
const int      DEFAULT_NOTIFY_INTERVAL_UNIT    = 0     ;
// other
const bool     DEFAULT_VERIFY_CHECKSUMS        = true  ;
const bool     DEFAULT_KEEP_DOWNLOADS          = false ;
const string[] DEFAULT_AUTH_CMDS = {
	//"pkexec env DISPLAY=${DISPLAY} XAUTHORITY=${XAUTHORITY}", // only needed for gui apps
	"pkexec",
	"sudo",
	"su -c \"%s\"",
	"doas",
	"lxsudo",
	"lxsu",
	"lxdoas",
	"gksudo",
	"gksu --su-mode",
	"pbrun"
	};

// Terminal command must stay foreground and block, not fork and return immediately.
// Most like xterm block naturally.
// Some like gnome-terminal have a special commandline option to make them block.
// Some like xfce4-terminal do not block no matter what you do, and can not be used.
// so not all terminals are usable
const string[] DEFAULT_TERM_CMDS = {
	"[internal-vte]",
	"gnome-terminal --wait --",
	"konsole --no-fork -e", // hoping --no-fork does what it says
	"mate-terminal -e \"%s\"",
	"lxterminal -e",
	"Eterm -e",
	"cool-retro-term -e",
	"urxvt -e",
	"sakura -e",
	"termit -e",
	"kitty",
	"qterminal -e",
	"mlterm -e",
	"pangoterm -e",
	"stterm -e",
	"pterm -e",
	"xterm -e"
	};
	// It's a shame, x-terminal-emulator would be the perfect thing to use,
	// automatic most-likely terminal for most users.
	// But since it might point to xfce terminal, we can't use it.
	//"x-terminal-emulator -e",             // might point to xfce
	//"xfce4-terminal -e \"%s\"",           // xfce4-terminal refuses to block
	//"exo-open --launch TerminalEmulator", // might point to xfce

// window sizes
const int      DEFAULT_WINDOW_WIDTH            = 800   ;
const int      DEFAULT_WINDOW_HEIGHT           = 600   ;
const int      DEFAULT_WINDOW_X                = -1    ;
const int      DEFAULT_WINDOW_Y                = -1    ;
const int      DEFAULT_TERM_WIDTH              = 1100  ;
const int      DEFAULT_TERM_HEIGHT             = 600   ;
const int      DEFAULT_TERM_X                  = -1    ;
const int      DEFAULT_TERM_Y                  = -1    ;
const double   DEFAULT_TERM_FONT_SCALE         = 1     ;

enum SIG {
#if VALA_0_40
	HUP = Posix.Signal.HUP,
	INT = Posix.Signal.INT,
	TERM = Posix.Signal.TERM
#else
	HUP = Posix.SIGHUP,
	INT = Posix.SIGINT,
	TERM = Posix.SIGTERM
#endif
}

extern void exit(int exit_code);

public class Main : GLib.Object {
//public class Main : Application {

	// constants ----------
	public string CONFIG_DIR = "";
	public string CACHE_DIR = "";
	public string DATA_DIR = "";
	public string APP_CONFIG_FILE = "";
	public string STARTUP_SCRIPT_FILE = "";
	public string STARTUP_DESKTOP_FILE = "";
	public string NOTIFICATION_ID_FILE = "";
	public string MAJOR_SEEN_FILE = "";
	public string MINOR_SEEN_FILE = "";

	// global progress ----------------
	public string status_line = "";
	public int progress_total = 0;
	public int progress_count = 0;
	public bool cancelled = false;

	// state flags ----------
	public static int VERBOSE = 1;
	public string command = "list";
	public string requested_versions = "";
	public bool ppa_tried = false;
	public bool ppa_up = true;
	public bool index_is_fresh = false;
	public bool RUN_NOTIFY_SCRIPT = false;
	public bool yes = false;

	// config
	public string ppa_uri              = DEFAULT_PPA_URI;
	public string all_proxy            = DEFAULT_ALL_PROXY;
	public int connect_timeout_seconds = DEFAULT_CONNECT_TIMEOUT_SECONDS;
	public int concurrent_downloads    = DEFAULT_CONCURRENT_DOWNLOADS;
	public bool hide_unstable          = DEFAULT_HIDE_UNSTABLE;
	public bool hide_invalid           = DEFAULT_HIDE_INVALID;
	public int previous_majors         = DEFAULT_PREVIOUS_MAJORS;
	public bool notify_major           = DEFAULT_NOTIFY_MAJOR;
	public bool notify_minor           = DEFAULT_NOTIFY_MINOR;
	public int notify_interval_unit    = DEFAULT_NOTIFY_INTERVAL_UNIT;
	public int notify_interval_value   = DEFAULT_NOTIFY_INTERVAL_VALUE;
	public bool verify_checksums       = DEFAULT_VERIFY_CHECKSUMS;
	public bool keep_downloads         = DEFAULT_KEEP_DOWNLOADS;
	public string auth_cmd             = DEFAULT_AUTH_CMDS[0];
	public string term_cmd             = DEFAULT_TERM_CMDS[0];
	// save & restore window size & position
	public int    window_width         = DEFAULT_WINDOW_WIDTH;
	public int    window_height        = DEFAULT_WINDOW_HEIGHT;
	public int    window_x             = DEFAULT_WINDOW_X;
	public int    window_y             = DEFAULT_WINDOW_Y;
	public int    term_width           = DEFAULT_TERM_WIDTH;
	public int    term_height          = DEFAULT_TERM_HEIGHT;
	public int    term_x               = DEFAULT_TERM_X;
	public int    term_y               = DEFAULT_TERM_Y;
	public double term_font_scale      = DEFAULT_TERM_FONT_SCALE;

	public static Rand rnd;

	public Main() {
		get_env();
		set_locale();
		vprint(BRANDING_SHORTNAME+" "+BRANDING_VERSION);
		if (!Thread.supported()) { vprint(_("Missing Thread support in Glib."),1,stderr); exit(1); }
		rnd = new Rand();
		init_paths();
		load_app_config();
		Package.initialize();
		LinuxKernel.initialize();
	}

	public void get_env() {
		var s = Environment.get_variable("VERBOSE");
		if (s != null) set_verbose(s.down().strip()); // don't do VERBOSE++

		s = Environment.get_variable("TERM");
		string[] tlist = { "xterm", "linux", "ansi", "vt" };
		foreach (var t in tlist) if (s.contains(t)) {
			vprint("\033]0;"+BRANDING_LONGNAME+"\007",1,stdout,false);
			break;
		}
	}

	public bool set_verbose(string? s) {
		string a = (s==null) ? "" : s.strip();
		switch (a) {
			case "n":
			case "no":
			case "off":
			case "false": a = "0"; break;
			case "y":
			case "yes":
			case "on":
			case "true": a = "1"; break;
		}
		int v = VERBOSE;
		bool r = true;
		if (a=="" || a.has_prefix("-")) { r = false; v++; }
		else v = int.parse(a);
		VERBOSE = v;
		Environment.set_variable("VERBOSE",v.to_string(),true);
		return r;
	}

	public void init_paths() {
		CONFIG_DIR = Environment.get_user_config_dir() + "/" + BRANDING_SHORTNAME;
		DATA_DIR = Environment.get_user_data_dir() + "/" + BRANDING_SHORTNAME;
		CACHE_DIR = Environment.get_user_cache_dir() + "/" + BRANDING_SHORTNAME;
		APP_CONFIG_FILE = CONFIG_DIR + "/config.json";
		STARTUP_SCRIPT_FILE = CONFIG_DIR + "/" + BRANDING_SHORTNAME + "-notify.sh";
		STARTUP_DESKTOP_FILE = CONFIG_DIR + "/autostart/" + BRANDING_SHORTNAME + "-notify.desktop";
		NOTIFICATION_ID_FILE = CONFIG_DIR + "/notification_id";
		MAJOR_SEEN_FILE = CONFIG_DIR + "/notification_seen.major";
		MINOR_SEEN_FILE = CONFIG_DIR + "/notification_seen.minor";
	}

	public void save_app_config() {
		vprint("save_app_config()",2);

		var config = new Json.Object();
		config.set_string_member(  "ppa_uri",                 ppa_uri                 );
		config.set_string_member(  "all_proxy",               all_proxy               );
		config.set_int_member(     "connect_timeout_seconds", connect_timeout_seconds );
		config.set_int_member(     "concurrent_downloads",    concurrent_downloads    );
		config.set_boolean_member( "hide_unstable",           hide_unstable           );
		config.set_boolean_member( "hide_invalid",            hide_invalid            );
		config.set_int_member(     "previous_majors",         previous_majors         );
		config.set_boolean_member( "notify_major",            notify_major            );
		config.set_boolean_member( "notify_minor",            notify_minor            );
		config.set_int_member(     "notify_interval_unit",    notify_interval_unit    );
		config.set_int_member(     "notify_interval_value",   notify_interval_value   );
		config.set_boolean_member( "verify_checksums",        verify_checksums        );
		config.set_boolean_member( "keep_downloads",          keep_downloads          );
		config.set_string_member(  "auth_cmd",                auth_cmd                );
		config.set_string_member(  "term_cmd",                term_cmd                );
		config.set_int_member(     "window_width",            window_width            );
		config.set_int_member(     "window_height",           window_height           );
		config.set_int_member(     "window_x",                window_x                );
		config.set_int_member(     "window_y",                window_y                );
		config.set_int_member(     "term_width",              term_width              );
		config.set_int_member(     "term_height",             term_height             );
		config.set_int_member(     "term_x",                  term_x                  );
		config.set_int_member(     "term_y",                  term_y                  );
		config.set_double_member(  "term_font_scale",         term_font_scale         );

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		mkdir(CONFIG_DIR);
		try { json.to_file(APP_CONFIG_FILE); }
		catch (Error e) { vprint(e.message,1,stderr); }

		vprint(_("Wrote config file")+": "+APP_CONFIG_FILE,2);

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
			vprint(_("No config file"),2);
			save_app_config();
			try { parser.load_from_file(APP_CONFIG_FILE); }
			catch (Error e) { vprint(e.message,1,stderr); exit(1); }
		}

		var node = parser.get_root();
		var config = node.get_object();

#if VALA_0_50 // glib-json 1.6
		ppa_uri                 =       config.get_string_member_with_default(  "ppa_uri",                 DEFAULT_PPA_URI                 );
		all_proxy               =       config.get_string_member_with_default(  "all_proxy",               DEFAULT_ALL_PROXY               );
		connect_timeout_seconds = (int) config.get_int_member_with_default(     "connect_timeout_seconds", DEFAULT_CONNECT_TIMEOUT_SECONDS );
		concurrent_downloads    = (int) config.get_int_member_with_default(     "concurrent_downloads",    DEFAULT_CONCURRENT_DOWNLOADS    );
		hide_unstable           =       config.get_boolean_member_with_default( "hide_unstable",           DEFAULT_HIDE_UNSTABLE           );
		hide_invalid            =       config.get_boolean_member_with_default( "hide_invalid",            DEFAULT_HIDE_INVALID            );
		previous_majors         = (int) config.get_int_member_with_default(     "previous_majors",         DEFAULT_PREVIOUS_MAJORS         );
		notify_major            =       config.get_boolean_member_with_default( "notify_major",            DEFAULT_NOTIFY_MAJOR            );
		notify_minor            =       config.get_boolean_member_with_default( "notify_minor",            DEFAULT_NOTIFY_MINOR            );
		notify_interval_unit    = (int) config.get_int_member_with_default(     "notify_interval_unit",    DEFAULT_NOTIFY_INTERVAL_UNIT    );
		notify_interval_value   = (int) config.get_int_member_with_default(     "notify_interval_value",   DEFAULT_NOTIFY_INTERVAL_VALUE   );
		verify_checksums        =       config.get_boolean_member_with_default( "verify_checksums",        DEFAULT_VERIFY_CHECKSUMS        );
		keep_downloads          =       config.get_boolean_member_with_default( "keep_downloads",          DEFAULT_KEEP_DOWNLOADS          );
		auth_cmd                =       config.get_string_member_with_default(  "auth_cmd",                DEFAULT_AUTH_CMDS[0]            );
		term_cmd                =       config.get_string_member_with_default(  "term_cmd",                DEFAULT_TERM_CMDS[0]            );
		window_width            = (int) config.get_int_member_with_default(     "window_width",            DEFAULT_WINDOW_WIDTH            );
		window_height           = (int) config.get_int_member_with_default(     "window_height",           DEFAULT_WINDOW_HEIGHT           );
		window_x                = (int) config.get_int_member_with_default(     "window_x",                DEFAULT_WINDOW_X                );
		window_y                = (int) config.get_int_member_with_default(     "window_y",                DEFAULT_WINDOW_Y                );
		term_width              = (int) config.get_int_member_with_default(     "term_width",              DEFAULT_TERM_WIDTH              );
		term_height             = (int) config.get_int_member_with_default(     "term_height",             DEFAULT_TERM_HEIGHT             );
		term_x                  = (int) config.get_int_member_with_default(     "term_x",                  DEFAULT_TERM_X                  );
		term_y                  = (int) config.get_int_member_with_default(     "term_y",                  DEFAULT_TERM_Y                  );
		term_font_scale         =       config.get_double_member_with_default(  "term_font_scale",         DEFAULT_TERM_FONT_SCALE         );
#else
		ppa_uri                 = json_get_string( config, "ppa_uri",                 DEFAULT_PPA_URI                 );
		all_proxy               = json_get_string( config, "all_proxy",               DEFAULT_ALL_PROXY               );
		connect_timeout_seconds = json_get_int(    config, "connect_timeout_seconds", DEFAULT_CONNECT_TIMEOUT_SECONDS );
		concurrent_downloads    = json_get_int(    config, "concurrent_downloads",    DEFAULT_CONCURRENT_DOWNLOADS    );
		hide_unstable           = json_get_bool(   config, "hide_unstable",           DEFAULT_HIDE_UNSTABLE           );
		hide_invalid            = json_get_bool(   config, "hide_invalid",            DEFAULT_HIDE_INVALID            );
		previous_majors         = json_get_int(    config, "previous_majors",         DEFAULT_PREVIOUS_MAJORS         );
		notify_major            = json_get_bool(   config, "notify_major",            DEFAULT_NOTIFY_MAJOR            );
		notify_minor            = json_get_bool(   config, "notify_minor",            DEFAULT_NOTIFY_MINOR            );
		notify_interval_unit    = json_get_int(    config, "notify_interval_unit",    DEFAULT_NOTIFY_INTERVAL_UNIT    );
		notify_interval_value   = json_get_int(    config, "notify_interval_value",   DEFAULT_NOTIFY_INTERVAL_VALUE   );
		verify_checksums        = json_get_bool(   config, "verify_checksums",        DEFAULT_VERIFY_CHECKSUMS        );
		keep_downloads          = json_get_bool(   config, "keep_downloads",          DEFAULT_KEEP_DOWNLOADS          );
		auth_cmd                = json_get_string( config, "auth_cmd",                DEFAULT_AUTH_CMDS[0]            );
		term_cmd                = json_get_string( config, "term_cmd",                DEFAULT_TERM_CMDS[0]            );
		window_width            = json_get_int(    config, "window_width",            DEFAULT_WINDOW_WIDTH            );
		window_height           = json_get_int(    config, "window_height",           DEFAULT_WINDOW_HEIGHT           );
		window_x                = json_get_int(    config, "window_x",                DEFAULT_WINDOW_X                );
		window_y                = json_get_int(    config, "window_y",                DEFAULT_WINDOW_Y                );
		term_width              = json_get_int(    config, "term_width",              DEFAULT_TERM_WIDTH              );
		term_height             = json_get_int(    config, "term_height",             DEFAULT_TERM_HEIGHT             );
		term_x                  = json_get_int(    config, "term_x",                  DEFAULT_TERM_X                  );
		term_y                  = json_get_int(    config, "term_y",                  DEFAULT_TERM_Y                  );
		term_font_scale         = json_get_double( config, "term_font_scale",         DEFAULT_TERM_FONT_SCALE         );
#endif

		bool resave = false;
		if (ppa_uri.length==0) { ppa_uri = DEFAULT_PPA_URI; resave = true; }
		if (!ppa_uri.has_suffix("/")) { ppa_uri += "/"; resave = true; }
		if (connect_timeout_seconds>600) connect_timeout_seconds = 600; // aria2c max allowed
		if (resave) save_app_config();

		vprint(_("Loaded config file")+": "+APP_CONFIG_FILE,2);
	}

	private void update_startup_script() {
		vprint("update_startup_script()",2);

		// construct the commandline argument for "sleep"
		int n = notify_interval_value; string u = "";
		switch (notify_interval_unit) {
			case 0: u = "h"; break;
			case 1: u = "d"; break;
			case 2: n = n*7; u = "d"; break;
			case 3: break;
		}

		// TODO, ID file should not assume single DISPLAY
		//       ID and SEEN should probably be in /var/run ?
		//       Sleep for days or weeks makes no sense.
		//       Really needs to compare target with current date/time.
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
			+ "\tVERBOSE=0 "+BRANDING_SHORTNAME+" --notify 2>&- >&- || exit\n"
			+ "\tsleep %d%s &\n".printf(n,u)
			+ "\tc=$!\n"
			+ "\techo $c >>${F}_\n"
			+ "\twait $c\n"	// respond to signals during sleep
			+ "done\n";
		} else {
			s += "# " + _("Notifications are disabled") + "\n"
			+ "exit 0\n";
		}

		fwrite(STARTUP_SCRIPT_FILE,s);
		RUN_NOTIFY_SCRIPT = true;
	}

	private void update_startup_desktop_file() {
		vprint("update_startup_desktop_file()",2);

		if (notify_minor || notify_major) {
			string s = "[Desktop Entry]\n"
				+ "Exec=bash \""+STARTUP_SCRIPT_FILE+"\" --autostart\n"
				;
			fwrite(STARTUP_DESKTOP_FILE,s);
		} else {
			rm(STARTUP_DESKTOP_FILE);
		}
	}

	public void run_notify_script_if_due() {
		if (!RUN_NOTIFY_SCRIPT) return;
		RUN_NOTIFY_SCRIPT = false;
		exec_async("bash "+STARTUP_SCRIPT_FILE);
	}

	public bool try_ppa() {
		vprint("try_ppa()",4);
		if (ppa_tried) return ppa_up;

		string std_err, std_out;

		string cmd = "aria2c"
		+ " --no-netrc"
		+ " --no-conf"
		+ " --max-file-not-found=3"
		+ " --retry-wait=2"
		+ " --max-tries=3"
		+ " --dry-run"
		+ " --quiet";
		if (connect_timeout_seconds>0) cmd += " --connect-timeout="+connect_timeout_seconds.to_string();
		if (all_proxy.length>0) cmd += " --all-proxy='"+all_proxy+"'";
		cmd += " '"+ppa_uri+"'";

		vprint(cmd,3);

		int status = exec_sync(cmd, out std_out, out std_err);
		if (std_err.length > 0) vprint(std_err,1,stderr);

		ppa_tried = true;
		ppa_up = false;
		if (status == 0) ppa_up = true;
		else vprint(_("Can not reach site")+": \""+ppa_uri+"\"",1,stderr);

		ppa_up = true;
		return ppa_up;
	}

}
