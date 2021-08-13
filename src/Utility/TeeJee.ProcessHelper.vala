
/*
 * TeeJee.ProcessHelper.vala
 *
 * Copyright 2016 Tony George <teejeetech@gmail.com>
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

namespace TeeJee.ProcessHelper{
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.Misc;

	/* Convenience functions for executing commands and managing processes */

	// execute process ---------------------------------

	// execute command synchronously
	public int exec_sync (string cmd, out string? std_out = null, out string? std_err = null){
		try {
			int status;
			Process.spawn_command_line_sync (cmd, out std_out, out std_err, out status);
	        return status;
		}
		catch (Error e){
	        log_error (e.message);
	        return -1;
	    }
	}

	// 20200510 bkw - execute command without waiting
	public void exec_async (string cmd){
		try {Process.spawn_command_line_async (cmd);}
		catch (SpawnError e) {log_error (e.message);}
	}

	// temp files -------------------------------------

	// create a unique temp dir rooted at App.TMP_PREFIX
	// return full path to created dir
	public string create_tmp_dir(){
		string d = App.TMP_PREFIX+"_%s".printf(random_string());
		dir_create(d);
		return d;
	}

	// TODO replace with mkstemp
	public string get_temp_file_path(string d){
		return d + "/" + timestamp_numeric() + (new Rand()).next_int().to_string();
	}

	// create a temporary bash script
	// return the script file path
	public string? save_bash_script_temp (string cmds, string? file = null){

		string f = file;
		if ((file == null) || (file.length == 0)){
			string t_dir = create_tmp_dir();
			f = get_temp_file_path(t_dir) + ".sh";
		}

		string s = "#!/bin/bash\n"
		+ cmds + "\n";

		log_debug("save_bash_script_temp("+file+"):"+f);

		if(file_write(f,s)){
			GLib.FileUtils.chmod (f, 0755);
			return f;
		}
		return null;
	}

	// find process -------------------------------

	// dep: ps TODO: Rewrite using /proc
	public bool process_is_running(long pid){

		/* Checks if given process is running */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "ps --pid %ld".printf(pid);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}

		return (ret_val == 0);
	}

	// dep: ps TODO: Rewrite using /proc
	public int[] get_process_children (Pid parent_pid){

		/* Returns the list of child processes spawned by given process */

		string std_out, std_err;
		exec_sync("ps --ppid %d".printf(parent_pid), out std_out, out std_err);

		int pid;
		int[] procList = {};
		string[] arr;

		foreach (string line in std_out.split ("\n")){
			arr = line.strip().split (" ");
			if (arr.length < 1) { continue; }

			pid = 0;
			pid = int.parse (arr[0]);

			if (pid != 0){
				procList += pid;
			}
		}
		return procList;
	}

	// manage process ---------------------------------

	public void process_quit(Pid process_pid, bool killChildren = true){

		/* Kills specified process and its children (optional).
		 * Sends signal SIGTERM to the process to allow it to quit gracefully.
		 * */

		int[] child_pids = get_process_children (process_pid);

#if VALA_0_40
		Posix.kill (process_pid, Posix.Signal.TERM);
#else
		Posix.kill (process_pid, Posix.SIGTERM);
#endif

		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
#if VALA_0_40
				Posix.kill (childPid, Posix.Signal.TERM);
#else
				Posix.kill (childPid, Posix.SIGTERM);
#endif
			}
		}
	}

}
