/*
 * AsyncTask.vala
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

using l.misc;

public abstract class AsyncTask : GLib.Object {

	protected Pid child_pid;
	int stdin_fd;
	int stdout_fd;
	DataInputStream stdout_s;

	public bool background_mode = false;

	// public
	public string[] spawn_args = {};
	public string stdin_data = "";
	public string status_line = "";
	public int prg_count = 0;
	public bool is_running = false;

	protected AsyncTask() {
	}

	public bool begin() {

		is_running = true;
		status_line = "";
		prg_count = 0;

		if (Main.VERBOSE>2) {
			vprint("AsyncTask.begin()");
			vprint("spawn_args: "+string.joinv(" ",spawn_args));
			vprint("stdin_data: ---begin---\n"+stdin_data+"\nstdin_data: ---end---");
		}

		try {
			Process.spawn_async_with_pipes(
				null, //working_dir, // working dir
				spawn_args,  // argv
				null,        // environment
				SpawnFlags.SEARCH_PATH,
				null,        // child_setup()
				out child_pid,
				out stdin_fd,
				out stdout_fd,
				null         //out stderr_fd
				);

			// read stdout
			stdout_s = new DataInputStream(new UnixInputStream(stdout_fd,true));
			stdout_s.newline_type = DataStreamNewlineType.ANY;
			new Thread<bool>(null,read_stdout);

			// write stdin
			FileStream stdin_pipe = FileStream.fdopen(stdin_fd,"w");
			stdin_pipe.puts(stdin_data);

			ChildWatch.add(child_pid, (pid, status) => {
				Process.close_pid(pid);
				is_running = false;
			});

		}
		catch (Error e) {
			is_running = false;
			vprint("AsyncTask.begin()",1,stderr);
			vprint(e.message,1,stderr);
		}

		return is_running;
	}

	bool read_stdout() {
		string? l = "";
		while (l!=null) {
			try { l = stdout_s.read_line(null); }
			catch (Error e) { vprint(e.message,1,stderr); }
			if (l==null) is_running = false;
			else process_line(l);
		}
		return true;
	}

	protected abstract void process_line(string? line);

}
