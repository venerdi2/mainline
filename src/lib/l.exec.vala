using l.misc;

namespace l.exec {
	public void uri_open(string s) {
		try { AppInfo.launch_default_for_uri(s,null); }
		catch (Error e) { warning("Unable to launch %s",s); }
	}

	// blocking exec - returns waitpid() status not exit() value
	public int exec_sync(string cmd, out string? std_out = null, out string? std_err = null) {
		vprint("exec_sync("+cmd+")",2);
		int wait_status = -1;
		try { Process.spawn_command_line_sync(cmd, out std_out, out std_err, out wait_status); }
		catch (SpawnError e) { vprint(e.message,1,stderr); }
		return wait_status;
	}

	// non-blocking exec
	public void exec_async(string cmd) {
		vprint("exec_async("+cmd+")",2);
		try { Process.spawn_command_line_async(cmd); }
		catch (SpawnError e) { vprint(e.message,1,stderr); }
	}
}
