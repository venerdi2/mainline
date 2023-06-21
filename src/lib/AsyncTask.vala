using l.misc;

public abstract class AsyncTask : GLib.Object {

	protected Pid child_pid;
	int stdin_fd;
	int stdout_fd;
	DataInputStream stdout_s;

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
				null,        // working dir
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
			vprint(e.message,1,stderr);
		}

		return is_running;
	}

	bool read_stdout() {
		string? l = "";
		while (l!=null) {
			try { l = stdout_s.read_line(null); }
			catch (Error e) { vprint(e.message,1,stderr); }
			process_line(l);
		}
		is_running = false;
		return true;
	}

	protected abstract void process_line(string? line);

}
