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

	string out_line = "";
	DataInputStream dis_out;
	protected bool is_terminated = false;

	bool stdout_is_open = false;

	protected Pid child_pid;
	int stdin_fd;
	int stdout_fd;
	bool finish_called = false;

	public bool background_mode = false;

	// public
	public AppStatus status;
	public string[] spawn_args = {};
	public string stdin_data = "";
	public string status_line = "";
	public double progress = 0.0;
	public double percent = 0.0;
	public int prg_count = 0;

	// signals
	public signal void stdout_line_read(string line);
	public signal void task_complete();

	protected AsyncTask() {
	}

	public bool begin() {

		status = AppStatus.RUNNING;

		bool has_started = true;
		is_terminated = false;
		finish_called = false;

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
			UnixInputStream uis_out = new UnixInputStream(stdout_fd, false);
			dis_out = new DataInputStream(uis_out);
			dis_out.newline_type = DataStreamNewlineType.ANY;
			new Thread<bool> (null,read_stdout);

			// write stdin
			FileStream stdin_pipe = FileStream.fdopen(stdin_fd,"w");
			stdin_pipe.puts(stdin_data);

		}
		catch (Error e) {
			vprint("AsyncTask.begin()",1,stderr);
			vprint(e.message,1,stderr);
			has_started = false;
		}

		return has_started;
	}

	private bool read_stdout() {
		try {
			stdout_is_open = true;
			out_line = dis_out.read_line (null);
			while (out_line != null) {
				//log_msg("O: " + out_line);
				if (!is_terminated && (out_line.length > 0)) {
					parse_stdout_line(out_line);
					stdout_line_read(out_line); // signal
				}
				out_line = dis_out.read_line(null); // read next
			}

			stdout_is_open = false;

			// dispose stdout
			if ((dis_out != null) && !dis_out.is_closed()) dis_out.close();

			// dis_out.close();
			dis_out = null;
			FileUtils.close(stdout_fd);

			// check if complete
			if (!stdout_is_open) finish();

		}
		catch (Error e) {
			vprint("AsyncTask.read_stdout()",1,stderr);
			vprint(e.message,1,stderr);
			return false;
		}
		return true;
	}

	protected abstract void parse_stdout_line(string out_line);

	private void finish() {
		if (stdout_is_open) return;
		if (finish_called) return;
		finish_called = true;

		out_line = "";

		if (status != AppStatus.CANCELLED) status = AppStatus.FINISHED;

		task_complete(); //signal

	}

	public bool is_running() {
		return (status == AppStatus.RUNNING);
	}
}

public enum AppStatus {
	RUNNING,
	FINISHED,
	CANCELLED
}
