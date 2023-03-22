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

private const string LOCALE_DIR = INSTALL_PREFIX + "/share/locale";
private const string APP_LIB_DIR = INSTALL_PREFIX + "/lib/" + BRANDING_SHORTNAME;

// .h files are a pain in the ass in vala so dump these "defines" here
const string DEFAULT_PPA_URI = "https://kernel.ubuntu.com/~kernel-ppa/mainline/";
const string DEFAULT_ALL_PROXY = "";
const bool DEFAULT_NOTIFY_MAJOR = false;
const bool DEFAULT_NOTIFY_MINOR = false;
const bool DEFAULT_HIDE_UNSTABLE = true;
const int DEFAULT_PREVIOUS_MAJORS = 0;
const int DEFAULT_NOTIFY_INTERVAL_VALUE = 4;      // 
const int DEFAULT_NOTIFY_INTERVAL_UNIT = 0;       // FIXME should really be an enum or string 0=hours, 1=days, 2=weeks, 3=seconds
const int DEFAULT_CONNECT_TIMEOUT_SECONDS = 15;
const int DEFAULT_CONCURRENT_DOWNLOADS = 1;
const int DEFAULT_WINDOW_WIDTH = 800;
const int DEFAULT_WINDOW_HEIGHT = 600;
const int DEFAULT_WINDOW_X = -1;
const int DEFAULT_WINDOW_Y = -1;
const int DEFAULT_TERM_WIDTH = 1100;
const int DEFAULT_TERM_HEIGHT = 600;
//const int DEFAULT_TERM_X = -1;
//const int DEFAULT_TERM_Y = -1;

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
	public string MAJ_SEEN_FILE = "";
	public string MIN_SEEN_FILE = "";

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

	public int window_width = DEFAULT_WINDOW_WIDTH;
	public int window_height = DEFAULT_WINDOW_HEIGHT;
	public int _window_width = DEFAULT_WINDOW_WIDTH;
	public int _window_height = DEFAULT_WINDOW_HEIGHT;
	public int window_x = DEFAULT_WINDOW_X;
	public int window_y = DEFAULT_WINDOW_Y;
	public int _window_x = DEFAULT_WINDOW_X;
	public int _window_y = DEFAULT_WINDOW_Y;

	public int term_width = DEFAULT_TERM_WIDTH;
	public int term_height = DEFAULT_TERM_HEIGHT;
	public int _term_width = DEFAULT_TERM_WIDTH;
	public int _term_height = DEFAULT_TERM_HEIGHT;
/* // positioning terminal window is not working
	public int term_x = DEFAULT_TERM_X;
	public int term_y = DEFAULT_TERM_Y;
	public int _term_x = DEFAULT_TERM_X;
	public int _term_y = DEFAULT_TERM_Y;
*/

	public string ppa_uri = DEFAULT_PPA_URI;
	public string all_proxy = DEFAULT_ALL_PROXY;
	public bool notify_major = DEFAULT_NOTIFY_MAJOR;
	public bool notify_minor = DEFAULT_NOTIFY_MINOR;
	public bool hide_unstable = DEFAULT_HIDE_UNSTABLE;
	public int previous_majors = DEFAULT_PREVIOUS_MAJORS;
	public int notify_interval_unit = DEFAULT_NOTIFY_INTERVAL_UNIT;
	public int notify_interval_value = DEFAULT_NOTIFY_INTERVAL_VALUE;
	public int connect_timeout_seconds = DEFAULT_CONNECT_TIMEOUT_SECONDS;
	public int concurrent_downloads = DEFAULT_CONCURRENT_DOWNLOADS;
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
		MAJ_SEEN_FILE = APP_CONF_DIR + "/notification_seen.major";
		MIN_SEEN_FILE = APP_CONF_DIR + "/notification_seen.minor";
		CACHE_DIR = user_home + "/.cache/" + BRANDING_SHORTNAME;
		TMP_PREFIX = Environment.get_tmp_dir() + "/." + BRANDING_SHORTNAME;

		LinuxKernel.CACHE_DIR = CACHE_DIR;

	}

	public void save_app_config() {
		vprint("save_app_config()",2);

		var config = new Json.Object();
		config.set_string_member("ppa_uri", ppa_uri);
		config.set_string_member("all_proxy", all_proxy);
		config.set_boolean_member("notify_major", notify_major);
		config.set_boolean_member("notify_minor", notify_minor);
		config.set_boolean_member("hide_unstable", hide_unstable);
		config.set_int_member("previous_majors", previous_majors);
		config.set_int_member("notify_interval_unit", notify_interval_unit);
		config.set_int_member("notify_interval_value", notify_interval_value);
		config.set_int_member("connect_timeout_seconds", connect_timeout_seconds);
		config.set_int_member("concurrent_downloads", concurrent_downloads);
		config.set_int_member("window_width", window_width);
		config.set_int_member("window_height", window_height);
		config.set_int_member("window_x", window_x);
		config.set_int_member("window_y", window_y);
		config.set_int_member("term_width", term_width);
		config.set_int_member("term_height", term_height);
//		config.set_int_member("term_x", term_x);
//		config.set_int_member("term_y", term_y);

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
			save_app_config();
			try { parser.load_from_file(APP_CONFIG_FILE); }
			catch (Error e) { vprint(e.message,1,stderr); exit(1); }
		}

		var node = parser.get_root();
		var config = node.get_object();

		ppa_uri = config.get_string_member_with_default("ppa_uri",DEFAULT_PPA_URI);
		if (ppa_uri.length==0) ppa_uri = DEFAULT_PPA_URI;
		if (!ppa_uri.has_suffix("/")) ppa_uri += "/";
		LinuxKernel.PPA_URI = ppa_uri;

		all_proxy = config.get_string_member_with_default("all_proxy",DEFAULT_ALL_PROXY);
		notify_major = config.get_boolean_member_with_default("notify_major",DEFAULT_NOTIFY_MAJOR);
		notify_minor = config.get_boolean_member_with_default("notify_minor",DEFAULT_NOTIFY_MINOR);
		notify_interval_unit = (int)config.get_int_member_with_default("notify_interval_unit",DEFAULT_NOTIFY_INTERVAL_UNIT);
		notify_interval_value = (int)config.get_int_member_with_default("notify_interval_value",DEFAULT_NOTIFY_INTERVAL_VALUE);
		connect_timeout_seconds = (int)config.get_int_member_with_default("connect_timeout_seconds",DEFAULT_CONNECT_TIMEOUT_SECONDS);
		concurrent_downloads = (int)config.get_int_member_with_default("concurrent_downloads",DEFAULT_CONCURRENT_DOWNLOADS);
		hide_unstable = config.get_boolean_member_with_default("hide_unstable",DEFAULT_HIDE_UNSTABLE);
		previous_majors = (int)config.get_int_member_with_default("previous_majors",DEFAULT_PREVIOUS_MAJORS);

		window_width = (int)config.get_int_member_with_default("window_width",DEFAULT_WINDOW_WIDTH);
		window_height = (int)config.get_int_member_with_default("window_height",DEFAULT_WINDOW_HEIGHT);
		window_x = (int)config.get_int_member_with_default("window_x",DEFAULT_WINDOW_X);
		window_y = (int)config.get_int_member_with_default("window_y",DEFAULT_WINDOW_Y);
		term_width = (int)config.get_int_member_with_default("term_width",DEFAULT_TERM_WIDTH);
		term_height = (int)config.get_int_member_with_default("term_height",DEFAULT_TERM_HEIGHT);
		//term_x = (int)config.get_int_member_with_default("term_x",DEFAULT_TERM_X);
		//term_y = (int)config.get_int_member_with_default("term_y",DEFAULT_TERM_Y);


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
			+ "# "+_("Called from")+" "+STARTUP_DESKTOP_FILE+" at logon.\n"
			+ "# "+_("This file is over-written and executed again whenever settings are saved in")+" "+BRANDING_SHORTNAME+"-gtk\n"
			+ "[[ $1 == --autostart ]] && rm -f \""+NOTIFICATION_ID_FILE+"\" \""+MAJ_SEEN_FILE+"\" \""+MIN_SEEN_FILE+"\"\n"
			+ "TMP=${XDG_RUNTIME_DIR:-/tmp}\n"
			+ "N=${0//\\//_}\n"
			+ "F=\"${TMP}/${N}.${$}.p\"\n"
			+ "trap 'read c<\\\"${F}_\\\" ;kill $c ;rm -f \\\"$F{,_}\\\"' 0\n"
			+ "echo -n \"${DISPLAY} ${$}\" > \"${F}\"\n"
			+ "typeset -i p\n"
			+ "shopt -s extglob\n"
			+ "\n"
			+ "# clear previous state (kill previous instance)\n"
			+ "for f in ${TMP}/${N}.+([0-9]).p ;do\n"
			+ "\t[[ -s ${f} ]] || continue\n"
			+ "\t[[ $f -ot $F ]] || continue\n"
			+ "\tread d p x < \"$f\"\n"
			+ "\t[[ $d == ${DISPLAY} ]] || continue\n"
			+ "\t((p>1)) || continue\n"
			+ "\trm -f \"$f\"\n"
			+ "\tkill $p\n"
			+ "done\n"
			+ "unset N f p d x\n"
			+ "\n"
			+ "# run whatever the new state should be\n";
		if (notify_minor || notify_major) {
			s += "while [[ -f \"$F\" ]] ;do\n"
			+ "\t"+BRANDING_SHORTNAME+" --notify 2>&- >&-\n"
			+ "\tsleep %d%s &\n".printf(count,suffix)
			+ "\tc=$!\n"
			+ "\techo $c >>\"${F}_\"\n"
			+ "\twait $c\n"	// respond to signals during sleep
			+ "done\n";
		} else {
			s += "# " + _("Notifications are disabled") + "\n"
			+ "exit 0\n";
		}

		file_write(STARTUP_SCRIPT_FILE,s);
		// settings get saved on startup if the file doesn't exist yet,
		// so we don't always want to launch the background process immediately on save,
		// because when notifications are enabled,
		// the background process runs another instance of ourself while we are still starting up ourselves,
		// and the two instances' cache operations step all over each other.
		// This is not really a fully correct answer, but mostly good enough:
		// if notifications are now off, then run immediately so it clears out the existing watcher possibly already running
		// if notifications are now on, then wait and run later on exit.
		if (!notify_major && !notify_minor) exec_async("bash "+STARTUP_SCRIPT_FILE+" 2>&- >&- <&-");
	}

	private void update_startup_desktop_file() {
		vprint("update_startup_desktop_file()",2);

		if (notify_minor || notify_major) {
			string txt = "[Desktop Entry]\n"
				+ "Exec=bash \""+STARTUP_SCRIPT_FILE+"\" --autostart\n"
				;
			file_write(STARTUP_DESKTOP_FILE, txt);
		} else {
			file_delete(STARTUP_DESKTOP_FILE);
			file_delete(OLD_STARTUP_DESKTOP_FILE); // TRANSITION
		}
	}

}
