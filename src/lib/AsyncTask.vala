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

using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using l.misc;

public abstract class AsyncTask : GLib.Object {

	private string err_line = "";
	private string out_line = "";
	private DataInputStream dis_out;
	private DataInputStream dis_err;
	protected bool is_terminated = false;

	private bool stdout_is_open = false;
	private bool stderr_is_open = false;

	protected Pid child_pid;
	private int output_fd;
	private int error_fd;
	private bool finish_called = false;

	protected string script_file = "";
	protected string working_dir = "";

	public bool background_mode = false;

	// public
	public AppStatus status;
	public string status_line = "";
	public int exit_code = 0;
	public string error_msg = "";
	public double progress = 0.0;
	public double percent = 0.0;
	public int prg_count = 0;
	public string eta = "";

	// signals
	public signal void stdout_line_read(string line);
	public signal void stderr_line_read(string line);
	public signal void task_complete();

	protected AsyncTask() {
		working_dir = create_tmp_dir();
		script_file = working_dir+"script.sh";
	}

	public bool begin() {

		status = AppStatus.RUNNING;

		bool has_started = true;
		is_terminated = false;
		finish_called = false;

		status_line = "";
		prg_count = 0;
		error_msg = "";

		string[] spawn_args = {"bash",script_file};

		vprint("AsyncTask begin()",2);
		vprint("working_dir: '"+working_dir+"'",2);

		try {
			// execute script file
			Process.spawn_async_with_pipes(
				working_dir, // working dir
				spawn_args,  // argv
				null,        // environment
				SpawnFlags.SEARCH_PATH,
				null,        // child_setup()
				out child_pid,
				null,        //out input_fd,
				out output_fd,
				out error_fd);

			// create stream readers
			UnixInputStream uis_out = new UnixInputStream(output_fd, false);
			UnixInputStream uis_err = new UnixInputStream(error_fd, false);
			dis_out = new DataInputStream(uis_out);
			dis_err = new DataInputStream(uis_err);
			dis_out.newline_type = DataStreamNewlineType.ANY;
			dis_err.newline_type = DataStreamNewlineType.ANY;

			// read stdout & stderr
			new Thread<bool> (null,read_stdout);
			new Thread<bool> (null,read_stderr);

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
			GLib.FileUtils.close(output_fd);

			// check if complete
			if (!stdout_is_open && !stderr_is_open) finish();

		}
		catch (Error e) {
			vprint("AsyncTask.read_stdout()",1,stderr);
			vprint(e.message,1,stderr);
			return false;
		}
		return true;
	}

	private bool read_stderr() {
		try {
			stderr_is_open = true;
			err_line = dis_err.read_line (null);
			while (err_line != null) {
				if (!is_terminated && (err_line.length > 0)) {
				//	error_msg += "%s\n".printf(err_line);
					parse_stderr_line(err_line);
					stderr_line_read(err_line); //signal
				}
				err_line = dis_err.read_line (null); //read next
			}

			stderr_is_open = false;

			// dispose stderr
			if ((dis_err != null) && !dis_err.is_closed()) dis_err.close();

			// dis_err.close();
			dis_err = null;
			GLib.FileUtils.close(error_fd);

			// check if complete
			if (!stdout_is_open && !stderr_is_open) finish();

		}
		catch (Error e) {
			vprint("AsyncTask.read_stderr()",1,stderr);
			vprint(e.message,1,stderr);
			return false;
		}
		return true;
	}

	protected abstract void parse_stdout_line(string out_line);

	protected abstract void parse_stderr_line(string err_line);

	private void finish() {
		// finish() gets called by 2 threads but should be executed only once
		if (finish_called) return;
		finish_called = true;

		err_line = "";
		out_line = "";

		rm(working_dir);
		if ((status != AppStatus.CANCELLED) && (status != AppStatus.PASSWORD_REQUIRED)) status = AppStatus.FINISHED;

		task_complete(); //signal

	}

	public bool is_running() {
		return (status == AppStatus.RUNNING);
	}
}

public enum AppStatus {
	NOT_STARTED,
	RUNNING,
	PAUSED,
	FINISHED,
	CANCELLED,
	PASSWORD_REQUIRED
}
