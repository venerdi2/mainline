
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

	public string create_tmp_dir(string p=""){
		string d = App.TMP_PREFIX+"_%s".printf(random_string());
		log_debug("create_tmp_dir:"+p+":"+d);
		dir_create(d);
		return d;
	}
	
	public int exec_sync (string cmd, out string? std_out = null, out string? std_err = null){

		/* Executes single command synchronously.
		 * Pipes and multiple commands are not supported.
		 * std_out, std_err can be null. Output will be written to terminal if null. */

		try {
			int status;
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out status);
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

	public int exec_script_sync (string script,
		out string? std_out = null, out string? std_err = null,
		bool supress_errors = false, bool run_as_admin = false,
		bool cleanup_tmp = true, bool print_to_terminal = false){

		/* Executes commands synchronously.
		 * Pipes and multiple commands are fully supported.
		 * Commands are written to a temporary bash script and executed.
		 * std_out, std_err can be null. Output will be written to terminal if null.
		 * */

		string t_dir = create_tmp_dir("exec_script_sync()");
		string t_f = get_temp_file_path(t_dir);
		string sh_file = t_f+".sh";
		save_bash_script_temp(script,sh_file, true, supress_errors);
		string su_file = t_f+"_su.sh";

		if (run_as_admin){
			string s = "#!/bin/bash\n"
				+ "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY"
				+ " '%s'".printf(escape_single_quote(sh_file));

			save_bash_script_temp(s, su_file, true, supress_errors);
		}
		
		try {
			string[] argv = new string[1];
			if (run_as_admin){
				argv[0] = su_file;
			}
			else{
				argv[0] = sh_file;
			}

			string[] env = Environ.get();

			int exit_code;

			if (print_to_terminal){
				
				Process.spawn_sync (
					t_dir, //working dir
					argv, //argv
					env, //environment
					SpawnFlags.SEARCH_PATH,
					null,   // child_setup
					null,
					null,
					out exit_code
					);
			}
			else{
		
				Process.spawn_sync (
					t_dir, //working dir
					argv, //argv
					env, //environment
					SpawnFlags.SEARCH_PATH,
					null,   // child_setup
					out std_out,
					out std_err,
					out exit_code
					);
			}

			string d = "exec_script_sync():";
			if (cleanup_tmp){
				d += "file_delete("+sh_file+")";
				file_delete(sh_file);
				if (run_as_admin){
					d += ":file_delete("+su_file+")";
					file_delete(su_file);
				}
				d += ":dir_delete("+t_dir+")";
				dir_delete(t_dir);
			}
			log_debug(d);
			return exit_code;
		}
		catch (Error e){
			if (!supress_errors){
				log_error (e.message);
			}
			return -1;
		}
	}

	public int exec_script_async (string s){

		/* Executes commands synchronously.
		 * Pipes and multiple commands are fully supported.
		 * Commands are written to a temporary bash script and executed.
		 * Return value indicates if script was started successfully.
		 *  */

		try {

			string t_dir = create_tmp_dir("exec_script_async()");
			string t_file = get_temp_file_path(t_dir);
			save_bash_script_temp(s,t_file);

			string[] argv = new string[1];
			argv[0] = t_file;

			string[] env = Environ.get();
			
			Pid child_pid;
			Process.spawn_async_with_pipes(
			    t_dir, //working dir
			    argv, //argv
			    env, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,
			    out child_pid);

			return 0;
		}
		catch (Error e){
	        log_error (e.message);
	        return 1;
	    }
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
		script.append ("echo ${exitCode} > ${exitCode}\n");
		script.append ("echo ${exitCode} > status\n");

		if ((sh_path == null) || (sh_path.length == 0)){
			string t_dir = create_tmp_dir("**** save_bash_script_temp() ****");
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

	public void exec_process_new_session(string command){
		exec_script_async("setsid %s &".printf(command));
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

	public bool cmd_exists(string cmd_tool){
		string path = get_cmd_path (cmd_tool);
		if ((path == null) || (path.length == 0)){
			return false;
		}
		else{
			return true;
		}
	}

	// dep: pidof, TODO: Rewrite using /proc
	public int get_pid_by_name (string name){

		/* Get the process ID for a process with given name */

		string std_out, std_err;
		exec_sync("pidof \"%s\"".printf(name), out std_out, out std_err);
		
		if (std_out != null){
			string[] arr = std_out.split ("\n");
			if (arr.length > 0){
				return int.parse (arr[0]);
			}
		}

		return -1;
	}

	public int get_pid_by_command(string cmdline){

		/* Searches for process using the command line used to start the process.
		 * Returns the process id if found.
		 * */
		 
		try {
			FileEnumerator enumerator;
			FileInfo info;
			File file = File.parse_name ("/proc");

			enumerator = file.enumerate_children ("standard::name", 0);
			while ((info = enumerator.next_file()) != null) {
				try {
					string io_stat_file_path = "/proc/%s/cmdline".printf(info.get_name());
					var io_stat_file = File.new_for_path(io_stat_file_path);
					if (file.query_exists()){
						var dis = new DataInputStream (io_stat_file.read());

						string line;
						string text = "";
						size_t length;
						while((line = dis.read_until ("\0", out length)) != null){
							text += " " + line;
						}

						if ((text != null) && text.contains(cmdline)){
							return int.parse(info.get_name());
						}
					} //stream closed
				}
				catch(Error e){
					// do not log
					// some processes cannot be accessed by non-admin user
				}
			}
		}
		catch(Error e){
		  log_error (e.message);
		}

		return -1;
	}

	public void get_proc_io_stats(int pid, out int64 read_bytes, out int64 write_bytes){

		/* Returns the number of bytes read and written by a process to disk */
		
		string io_stat_file_path = "/proc/%d/io".printf(pid);
		var file = File.new_for_path(io_stat_file_path);

		read_bytes = 0;
		write_bytes = 0;

		try {
			if (file.query_exists()){
				var dis = new DataInputStream (file.read());
				string line;
				while ((line = dis.read_line (null)) != null) {
					if(line.has_prefix("rchar:")){
						read_bytes = int64.parse(line.replace("rchar:","").strip());
					}
					else if(line.has_prefix("wchar:")){
						write_bytes = int64.parse(line.replace("wchar:","").strip());
					}
				}
			} //stream closed
		}
		catch(Error e){
			log_error (e.message);
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

	// dep: pgrep TODO: Rewrite using /proc
	public bool process_is_running_by_name(string proc_name){

		/* Checks if given process is running */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "pgrep -f '%s'".printf(proc_name);
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
	
	public void process_kill(Pid process_pid, bool killChildren = true){

		/* Kills specified process and its children (optional).
		 * Sends signal SIGKILL to the process to kill it forcefully.
		 * It is recommended to use the function process_quit() instead.
		 * */
		
		int[] child_pids = get_process_children (process_pid);
		Posix.kill (process_pid, Posix.Signal.KILL);

		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
				Posix.kill (childPid, Posix.Signal.KILL);
			}
		}
	}

	// dep: kill
	public int process_pause (Pid procID){

		/* Pause/Freeze a process */

		return exec_sync ("kill -STOP %d".printf(procID), null, null);
	}

	// dep: kill
	public int process_resume (Pid procID){

		/* Resume/Un-freeze a process*/

		return exec_sync ("kill -CONT %d".printf(procID), null, null);
	}

	// dep: ps TODO: Rewrite using /proc
	public void process_quit_by_name(string cmd_name, string cmd_to_match, bool exact_match){

		/* Kills a specific command */
		
		string std_out, std_err;
		exec_sync ("ps w -C '%s'".printf(cmd_name), out std_out, out std_err);
		//use 'ps ew -C conky' for all users

		string pid = "";
		foreach(string line in std_out.split("\n")){
			if ((exact_match && line.has_suffix(" " + cmd_to_match))
			|| (!exact_match && (line.index_of(cmd_to_match) != -1))){
				pid = line.strip().split(" ")[0];
				Posix.kill ((Pid) int.parse(pid), 15);
				log_debug(_("Stopped") + ": [PID=" + pid + "] ");
			}
		}
	}

}
