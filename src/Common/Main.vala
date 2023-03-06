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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;

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

public class Main : GLib.Object{

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

	// global progress ----------------
	
	public string status_line = "";
	public int64 progress_total = 0;
	public int64 progress_count = 0;
	public bool cancelled = false;

	// state flags ----------

	public bool GUI_MODE = false;
	public string command = "list";
	public string requested_version = "";
	public bool connection_checked = false;
	public bool connection_status = true;
	public bool index_is_fresh = false;
	public int window_width = 800;
	public int window_height = 600;
	public int _window_width = 800;
	public int _window_height = 600;
	public int window_x = -1;
	public int window_y = -1;
	public int _window_x = -1;
	public int _window_y = -1;

	public string ppa_uri = DEFAULT_PPA_URI;
	public bool notify_major = true;
	public bool notify_minor = true;
	public bool hide_unstable = true;
	public int show_prev_majors = 0;
	public int notify_interval_unit = 0;
	public int notify_interval_value = 2;
	public int connect_timeout_seconds = 15;
	public int concurrent_downloads = 4;
	public bool confirm = true;

	// constructors ------------

	public Main(string[] arg0, bool _gui_mode){
		//log_msg("Main()");

		GUI_MODE = _gui_mode;

		init_paths();

		load_app_config();

		Package.initialize();

		LinuxKernel.initialize();

	}

	// helpers ------------

	public void init_paths() {

		// user info
		user_login = GLib.Environment.get_user_name();

		user_home = GLib.Environment.get_home_dir();

		APP_CONF_DIR = user_home + "/.config/" + BRANDING_SHORTNAME;
		APP_CONFIG_FILE = APP_CONF_DIR + "/config.json";
		STARTUP_SCRIPT_FILE = APP_CONF_DIR + "/notify-loop.sh";
		STARTUP_DESKTOP_FILE = user_home + "/.config/autostart/" + BRANDING_SHORTNAME + ".desktop";
		NOTIFICATION_ID_FILE = APP_CONF_DIR + "/notification_id";
		MAJ_SEEN_FILE = APP_CONF_DIR + "/notification_seen.major";
		MIN_SEEN_FILE = APP_CONF_DIR + "/notification_seen.minor";

		LinuxKernel.CACHE_DIR = user_home + "/.cache/" + BRANDING_SHORTNAME;
		LinuxKernel.CURRENT_USER = user_login;
		LinuxKernel.CURRENT_USER_HOME = user_home;
		LinuxKernel.PPA_URI = ppa_uri;

		// todo: consider get_user_runtime_dir() or get_user_cache_dir()
		TMP_PREFIX = Environment.get_tmp_dir() + "/." + BRANDING_SHORTNAME;

		// possible future option - delete cache on every startup and exit
		// do not do this without rigging up a way to suppress it when the gui app runs the console app
		// like --index-is-fresh but maybe --keep-index or --batch
		//LinuxKernel.delete_cache();

	}
	
	public void save_app_config(){
		
		var config = new Json.Object();
		config.set_string_member("ppa_uri", ppa_uri);
		config.set_string_member("notify_major", notify_major.to_string());
		config.set_string_member("notify_minor", notify_minor.to_string());
		config.set_string_member("hide_unstable", hide_unstable.to_string());
		config.set_string_member("show_prev_majors", show_prev_majors.to_string());
		config.set_string_member("notify_interval_unit", notify_interval_unit.to_string());
		config.set_string_member("notify_interval_value", notify_interval_value.to_string());
		config.set_string_member("connect_timeout_seconds", connect_timeout_seconds.to_string());
		config.set_string_member("concurrent_downloads", concurrent_downloads.to_string());
		config.set_string_member("window_width", window_width.to_string());
		config.set_string_member("window_height", window_height.to_string());
		config.set_string_member("window_x", window_x.to_string());
		config.set_string_member("window_y", window_y.to_string());

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		try{
			json.to_file(APP_CONFIG_FILE);
		} catch (Error e) {
	        log_error (e.message);
	    }

	    log_debug("Saved config file: %s".printf(APP_CONFIG_FILE));

		update_notification_files();
	}

	public void update_notification_files(){
		update_startup_script();
	    update_startup_desktop_file();
	}

	public void load_app_config(){

		var f = File.new_for_path(APP_CONFIG_FILE);

		if (!f.query_exists()) {
			// initialize static
			hide_unstable = true;
			show_prev_majors = 0;
			return;
		}

		var parser = new Json.Parser();

		try {
			parser.load_from_file(APP_CONFIG_FILE);
		} catch (Error e) {
			log_error (e.message);
		}

		var node = parser.get_root();
		var config = node.get_object();

		ppa_uri = json_get_string(config, "ppa_uri", DEFAULT_PPA_URI); LinuxKernel.PPA_URI = ppa_uri;
		notify_major = json_get_bool(config, "notify_major", true);
		notify_minor = json_get_bool(config, "notify_minor", true);
		notify_interval_unit = json_get_int(config, "notify_interval_unit", 0);
		notify_interval_value = json_get_int(config, "notify_interval_value", 2);
		connect_timeout_seconds = json_get_int(config, "connect_timeout_seconds", 15);
		concurrent_downloads = json_get_int(config, "concurrent_downloads", 4);

		hide_unstable = json_get_bool(config, "hide_unstable", true);
		show_prev_majors = json_get_int(config, "show_prev_majors", 0);

		window_width = json_get_int(config, "window_width", window_width);
		window_height = json_get_int(config, "window_height", window_height);
		window_x = json_get_int(config, "window_x", window_x);
		window_y = json_get_int(config, "window_y", window_y);

		log_debug("Load config file: %s".printf(APP_CONFIG_FILE));
	}

	// begin ------------

	private void update_startup_script() {

		// construct the commandline argument for "sleep"
		int count = App.notify_interval_value;
		string suffix = "h";
		switch (App.notify_interval_unit){
		case 0: // hour
			suffix = "h";
			break;
		case 1: // day
			suffix = "d";
			break;
		case 2: // week
			suffix = "d";
			count = App.notify_interval_value * 7;
			break;
		case 3: // second
			suffix = "";
			count = App.notify_interval_value;
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
			s += "while gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.GetId 2>&- >&- ;do\n"
			+ "\t"+BRANDING_SHORTNAME+" --notify";
			if (LOG_DEBUG) s += " --debug";
			s += "\n"
			+ "\tsleep %d%s &\n".printf(count,suffix)
			+ "\twait ${!}\n"	// respond to signals during sleep
			+ "done\n";
		} else {
			s += "# " + _("Notifications are disabled") + "\n"
			+ "exit 0\n";
		}

		file_write(STARTUP_SCRIPT_FILE,s);
		exec_async("bash "+STARTUP_SCRIPT_FILE);
	}

	private void update_startup_desktop_file() {
		if (notify_minor || notify_major){

			string txt = "[Desktop Entry]\n"
				+ "Type=Application\n"
				+ "Exec=bash \""+STARTUP_SCRIPT_FILE+"\" --autostart\n"
				+ "Hidden=false\n"
				+ "NoDisplay=false\n"
				+ "X-GNOME-Autostart-enabled=true\n"
				+ "Name="+BRANDING_SHORTNAME+" notification\n"
				+ "Comment="+BRANDING_SHORTNAME+" notification\n";

			file_write(STARTUP_DESKTOP_FILE, txt);

		}
		else{
			file_delete(STARTUP_DESKTOP_FILE);
		}
	}

	public bool check_internet_connectivity() {
		if (connection_checked) return connection_status;

		string std_err, std_out;
		string cmd = "aria2c --no-netrc --no-conf --connect-timeout="+connect_timeout_seconds.to_string()+" --max-file-not-found=3 --retry-wait=2 --max-tries=3 --dry-run --quiet '"+ppa_uri+"'";

		int status = exec_sync(cmd, out std_out, out std_err);
		if (std_err.length > 0) log_error(std_err);

		connection_status = false;
		if (status == 0) connection_status = true;
		else log_error(_("Can not reach")+" "+ppa_uri);

		connection_checked = true;
		return connection_status;
	}

}
