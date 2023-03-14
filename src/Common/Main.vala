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
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.Misc;
using l.time;
using l.misc;

[CCode(cname="BRANDING_SHORTNAME")] extern const string BRANDING_SHORTNAME;
[CCode(cname="BRANDING_LONGNAME")] extern const string BRANDING_LONGNAME;
[CCode(cname="BRANDING_VERSION")] extern const string BRANDING_VERSION;
[CCode(cname="BRANDING_AUTHORNAME")] extern const string BRANDING_AUTHORNAME;
[CCode(cname="BRANDING_AUTHOREMAIL")] extern const string BRANDING_AUTHOREMAIL;
[CCode(cname="BRANDING_WEBSITE")] extern const string BRANDING_WEBSITE;
[CCode(cname="INSTALL_PREFIX")] extern const string INSTALL_PREFIX;
[CCode(cname="DEFAULT_PPA_URI")] extern const string DEFAULT_PPA_URI;

private const string LOCALE_DIR = INSTALL_PREFIX + "/share/locale";
private const string APP_LIB_DIR = INSTALL_PREFIX + "/lib/" + BRANDING_SHORTNAME;

extern void exit(int exit_code);

public class Main : GLib.Object {

	// constants ----------

	public string TMP_PREFIX = "";
	public string APP_CONF_DIR = "";
	public string APP_CONFIG_FILE = "";
	public string STARTUP_SCRIPT_FILE = "";
	public string STARTUP_DESKTOP_FILE = "";
	public string NOTIFICATION_ID_FILE = "";
	public string MAJ_SEEN_FILE = "";
	public string MIN_SEEN_FILE = "";

	public string user_login = "";
	public string user_home = "";
	public string CACHE_DIR = "~/.cache/"+BRANDING_SHORTNAME ; // non-empty for safety

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

	public int window_width = 800;
	public int window_height = 600;
	public int _window_width = 800;
	public int _window_height = 600;
	public int window_x = -1;
	public int window_y = -1;
	public int _window_x = -1;
	public int _window_y = -1;

	public int term_width = 1100;
	public int term_height = 600;
	public int _term_width = 1100;
	public int _term_height = 600;
/*
	public int term_x = -1;
	public int term_y = -1;
	public int _term_x = -1;
	public int _term_y = -1;
*/
	public string ppa_uri = DEFAULT_PPA_URI;
	public string all_proxy = "";
	public bool notify_major = false;
	public bool notify_minor = false;
	public bool hide_unstable = true;
	public int previous_majors = 0;
	public int notify_interval_unit = 0;
	public int notify_interval_value = 4;
	public int connect_timeout_seconds = 15;
	public int concurrent_downloads = 1;
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
		STARTUP_SCRIPT_FILE = APP_CONF_DIR + "/notify-loop.sh";
		STARTUP_DESKTOP_FILE = user_home + "/.config/autostart/" + BRANDING_SHORTNAME + ".desktop";
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
		config.set_string_member("notify_major", notify_major.to_string());
		config.set_string_member("notify_minor", notify_minor.to_string());
		config.set_string_member("hide_unstable", hide_unstable.to_string());
		config.set_string_member("previous_majors", previous_majors.to_string());
		config.set_string_member("notify_interval_unit", notify_interval_unit.to_string());
		config.set_string_member("notify_interval_value", notify_interval_value.to_string());
		config.set_string_member("connect_timeout_seconds", connect_timeout_seconds.to_string());
		config.set_string_member("concurrent_downloads", concurrent_downloads.to_string());
		config.set_string_member("window_width", window_width.to_string());
		config.set_string_member("window_height", window_height.to_string());
		config.set_string_member("window_x", window_x.to_string());
		config.set_string_member("window_y", window_y.to_string());
		config.set_string_member("term_width", term_width.to_string());
		config.set_string_member("term_height", term_height.to_string());
//		config.set_string_member("term_x", term_x.to_string());
//		config.set_string_member("term_y", term_y.to_string());

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

		if (!file_exists(APP_CONFIG_FILE)) save_app_config();

		try { parser.load_from_file(APP_CONFIG_FILE); }
		catch (Error e) { vprint(e.message,1,stderr); }

		var node = parser.get_root();
		var config = node.get_object();

		ppa_uri = json_get_string(config, "ppa_uri", DEFAULT_PPA_URI);
		all_proxy = json_get_string(config, "all_proxy", all_proxy);
		notify_major = json_get_bool(config, "notify_major", notify_major);
		notify_minor = json_get_bool(config, "notify_minor", notify_minor);
		notify_interval_unit = json_get_int(config, "notify_interval_unit", notify_interval_unit);
		notify_interval_value = json_get_int(config, "notify_interval_value", notify_interval_value);
		connect_timeout_seconds = json_get_int(config, "connect_timeout_seconds", connect_timeout_seconds);
		concurrent_downloads = json_get_int(config, "concurrent_downloads", concurrent_downloads);
		hide_unstable = json_get_bool(config, "hide_unstable", hide_unstable);
		previous_majors = json_get_int(config, "previous_majors", previous_majors);
		window_width = json_get_int(config, "window_width", window_width);
		window_height = json_get_int(config, "window_height", window_height);
		window_x = json_get_int(config, "window_x", window_x);
		window_y = json_get_int(config, "window_y", window_y);
		term_width = json_get_int(config, "term_width", term_width);
		term_height = json_get_int(config, "term_height", term_height);
//		term_x = json_get_int(config, "term_x", term_x);
//		term_y = json_get_int(config, "term_y", term_y);

		// fixups
		//if (ppa_uri.length==0) ppa_uri = DEFAULT_PPA_URI;
		if (!ppa_uri.has_suffix("/")) ppa_uri += "/";
		LinuxKernel.PPA_URI = ppa_uri;

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

		// TODO, ID file should not assume single DISPLAY
		//       ID and SEEN should probably be in /var/run ?
		string s = "#!/bin/bash\n"
			+ "# " +_("Called from")+" "+STARTUP_DESKTOP_FILE+" at logon.\n"
			+ "# This file is over-written and executed again whenever settings are saved in "+BRANDING_SHORTNAME+"-gtk\n"
			+ "[[ \"${1}\" = \"--autostart\" ]] && rm -f "+NOTIFICATION_ID_FILE+" "+MAJ_SEEN_FILE+" "+MIN_SEEN_FILE+"\n"
			+ "TMP=${XDG_RUNTIME_DIR:-/tmp}\n"
			+ "F=\"${TMP}/"+BRANDING_SHORTNAME+"-notify-loop.${$}.p\"\n"
			+ "trap \"rm -f \\\"${F}\\\"\" 0\n"
			+ "echo -n \"${DISPLAY} ${$}\" > \"${F}\"\n"
			+ "typeset -i p\n"
			+ "shopt -s extglob\n"
			+ "\n"
			+ "# clear previous state (kill previous instance)\n"
			+ "for f in ${TMP}/"+BRANDING_SHORTNAME+"-notify-loop.+([0-9]).p ;do\n"
			+ "\t[[ -s ${f} ]] || continue\n"
			+ "\t[[ ${f} -ot ${F} ]] || continue\n"
			+ "\tread d p x < \"${f}\"\n"
			+ "\t[[ \"${d}\" == \"${DISPLAY}\" ]] || continue\n"
			+ "\t((${p}>1)) || continue\n"
			+ "\trm -f \"${f}\"\n"
			+ "\tkill ${p}\n"
			+ "done\n"
			+ "unset F f p d x\n"
			+ "\n"
			+ "# run current state\n";
		if (notify_minor || notify_major) {
			// This gdbus check doesn't do what I'd hoped.
			// Still succeeds while logged out but sitting at a display manager login screen.
			s += ""
			//+ "export VERBOSE=0\n"
			+ "while gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.GetId 2>&- >&- ;do\n"
			+ "\t"+BRANDING_SHORTNAME+" --notify 2>&- >&-";
			//if (LOG_DEBUG) s += " --debug";
			s += "\n"
			+ "\tsleep %d%s &\n".printf(count,suffix)
			+ "\twait ${!}\n"	// respond to signals during sleep
			+ "done\n";
		} else {
			s += "# " + _("Notifications are disabled") + "\n"
			+ "exit 0\n";
		}

		file_write(STARTUP_SCRIPT_FILE,s);
		// settings get saved on startup if the file doesn't exist yet,
		// so we don't always want to launch the bg process
		// on every save, because when notifications are enabled,
		// the bg process runs another instance of ourself while we are still starting up ourselves,
		// and the two instances' cache operations step all over each other.
		// slightly better:
		// if notifications are now off, then run immediately so it clears out the existing bg possibly already running
		// if notifications are now on, then run on exit.
		if (!notify_major && !notify_minor) exec_async("bash "+STARTUP_SCRIPT_FILE+" 2>&- >&-");
	}

	private void update_startup_desktop_file() {
		vprint("update_startup_desktop_file()",2);

		if (notify_minor || notify_major) {
			string txt = "[Desktop Entry]\n"
				+ "Type=Application\n"
				+ "Exec=bash \""+STARTUP_SCRIPT_FILE+"\" --autostart\n"
				+ "Hidden=false\n"
				+ "NoDisplay=false\n"
				+ "X-GNOME-Autostart-enabled=true\n"
				+ "Name="+BRANDING_SHORTNAME+" notification\n"
				+ "Comment="+BRANDING_SHORTNAME+" notification\n";
			file_write(STARTUP_DESKTOP_FILE, txt);
		} else {
			file_delete(STARTUP_DESKTOP_FILE);
		}
	}

}
