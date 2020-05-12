
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

// FIXME - Stop creating temp dirs and files just to execute shell commands.
namespace TeeJee.ProcessHelper{
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.Misc;

	/* Convenience functions for executing commands and managing processes */

	// execute process ---------------------------------

	public string create_tmp_dir(){
		string d = App.TMP_PREFIX+"_%s".printf(random_string());
		dir_create(d);
		return d;
	}
	
	public int exec_sync (string cmd, out string? std_out = null, out string? std_err = null){

		/* Executes single command synchronously.
		 * Pipes and multiple commands are not supported.
		 * std_out, std_err can be null. Output will be written to terminal if null. */

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

	public string? save_bash_script_temp (string commands, string? script_path = null,
		bool force_locale = true, bool supress_errors = false){

		string sh_path = script_path;
		
		/* Creates a temporary bash script with given commands
		 * Returns the script file path */

		var script = new StringBuilder();
		script.append ("#!/bin/bash\n");
		script.append ("\n");
		if (force_locale){
			script.append ("LANG=C\n");
		}
		script.append ("\n");
		script.append ("%s\n".printf(commands));
		script.append ("\n\nexitCode=$?\n");
		// FIXME bad behavior just assuming you can create files in cwd any time
		script.append ("echo ${exitCode} > ${exitCode}\n");
		script.append ("echo ${exitCode} > status\n");

		// TODO - because of unwise things exactly like those echo > filename
		// commands above, and also just so that the caller always knows
		// how to clean up properly without risk of deleting something it shouldn't
		// this should be codified into a promise that if we generate a path,
		// then the final path element is *always* a new unique temp directory,
		// as well as the sh file itself. - bkw
		if ((sh_path == null) || (sh_path.length == 0)){
			string t_dir = create_tmp_dir();
			sh_path = get_temp_file_path(t_dir) + ".sh";
		}

		log_debug("save_bash_script_temp():sh_path:"+sh_path);

		try{
			//write script file
			var file = File.new_for_path (sh_path);
			if (file.query_exists ()) {
				file.delete ();
			}
			var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
			var data_stream = new DataOutputStream (file_stream);
			data_stream.put_string (script.str);
			data_stream.close();

			// set execute permission
			chmod (sh_path, "u+x");

			return sh_path;
		}
		catch (Error e) {
			if (!supress_errors){
				log_error (e.message);
			}
		}

		return null;
	}

	public string get_temp_file_path(string d){

		/* Generates temporary file path */

		return d + "/" + timestamp_numeric() + (new Rand()).next_int().to_string();
	}
	
	// find process -------------------------------
	
	// dep: which
	public string get_cmd_path (string cmd_tool){

		/* Returns the full path to a command */

		try {
			int exitCode;
			string stdout, stderr;
			Process.spawn_command_line_sync("which " + cmd_tool, out stdout, out stderr, out exitCode);
	        return stdout;
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

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
		Posix.kill (process_pid, Posix.Signal.TERM);

		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
				Posix.kill (childPid, Posix.Signal.TERM);
			}
		}
	}

}
