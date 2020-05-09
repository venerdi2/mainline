
/*
 * TeeJee.System.vala
 *
 * Copyright 2017 Tony George <teejeetech@gmail.com>
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

namespace TeeJee.System{

	using TeeJee.ProcessHelper;
	using TeeJee.Logging;
	using TeeJee.Misc;
	using TeeJee.FileSystem;
	
	// user ---------------------------------------------------

	public bool user_is_admin(){
		return (get_user_id_effective() == 0);
	}
	
	public int get_user_id(){

		// returns actual user id of current user (even for applications executed with sudo and pkexec)
		
		string pkexec_uid = GLib.Environment.get_variable("PKEXEC_UID");

		if (pkexec_uid != null){
			return int.parse(pkexec_uid);
		}

		string sudo_user = GLib.Environment.get_variable("SUDO_USER");

		if (sudo_user != null){
			return get_user_id_from_username(sudo_user);
		}

		return get_user_id_effective(); // normal user
	}

	public int get_user_id_effective(){
		
		// returns effective user id (0 for applications executed with sudo and pkexec)

		int uid = -1;
		string cmd = "id -u";
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);
		if ((std_out != null) && (std_out.length > 0)){
			uid = int.parse(std_out);
		}

		return uid;
	}
	
	public string get_username(){

		// returns actual username of current user (even for applications executed with sudo and pkexec)
		
		return get_username_from_uid(get_user_id());
	}

	public int get_user_id_from_username(string username){
		
		int user_id = -1;

		foreach(var line in file_read("/etc/passwd").split("\n")){
			var arr = line.split(":");
			if (arr.length < 3) { continue; }
			if (arr[0] == username){
				user_id = int.parse(arr[2]);
				break;
			}
		}

		return user_id;
	}

	public string get_username_from_uid(int user_id){
		
		string username = "";

		foreach(var line in file_read("/etc/passwd").split("\n")){
			var arr = line.split(":");
			if (arr.length < 3) { continue; }
			if (int.parse(arr[2]) == user_id){
				username = arr[0];
				break;
			}
		}

		return username;
	}

	public string get_user_home(string username = get_username()){
		
		string userhome = "";

		foreach(var line in file_read("/etc/passwd").split("\n")){
			var arr = line.split(":");
			if (arr.length < 6) { continue; }
			if (arr[0] == username){
				userhome = arr[5];
				break;
			}
		}

		return userhome;
	}

	// internet helpers ----------------------
	public bool check_internet_connectivity(){
		//log_msg("check_internet_connectivity()");

	    if (App.skip_connection_check) {
	        return true;
	    }

		string std_err, std_out;

		string cmd = "aria2c --no-netrc --no-conf --connect-timeout="+App.connection_timeout_seconds.to_string()+" --max-file-not-found=3 --retry-wait=2 --max-tries=3 --dry-run --quiet https://www.google.com/";

		int status = exec_script_sync(cmd, out std_out, out std_err, false);

		if (std_err.length > 0){
			log_error(std_err);
		}

		if (status != 0){
			log_error(_("Internet connection is not active"));
		}

	    return (status == 0);
	}

	// open -----------------------------

	public bool xdg_open (string file, string user = ""){
		
		string path = get_cmd_path ("xdg-open");
		
		if ((path != null) && (path != "")){
			
			string cmd = "xdg-open '%s'".printf(escape_single_quote(file));
			
			if (user.length > 0){
				cmd = "pkexec --user %s env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY ".printf(user) + cmd;
			}
			
			log_debug(cmd);
			
			int status = exec_script_async(cmd);
			
			return (status == 0);
		}
		
		return false;
	}
	
	// timers --------------------------------------------------
	
	public GLib.Timer timer_start(){
		var timer = new GLib.Timer();
		timer.start();
		return timer;
	}

	public void timer_restart(GLib.Timer timer){
		timer.reset();
		timer.start();
	}

	public ulong timer_elapsed(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		return (ulong)((seconds * 1000 ) + (microseconds / 1000));
	}

	public void sleep(int milliseconds){
		Thread.usleep ((ulong) milliseconds * 1000);
	}

	public void set_numeric_locale(string type){
		Intl.setlocale(GLib.LocaleCategory.NUMERIC, type);
	    Intl.setlocale(GLib.LocaleCategory.COLLATE, type);
	    Intl.setlocale(GLib.LocaleCategory.TIME, type);
	}
}
