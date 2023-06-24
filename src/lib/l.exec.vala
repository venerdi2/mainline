using l.misc;

namespace l.exec {
	public void uri_open(string s) {
		try { AppInfo.launch_default_for_uri(s,null); }
		catch (Error e) { warning("Unable to launch %s",s); }
	}

	// blocking exec
	public int exec_sync(string cmd, out string? std_out = null, out string? std_err = null) {
		vprint("exec_sync("+cmd+")",2);
		int r = 0;
		try { Process.spawn_command_line_sync(cmd, out std_out, out std_err); }
		catch (SpawnError e) { r = 1; vprint(e.message,1,stderr); }
		return r;
	}

	// non-blocking exec
	public void exec_async(string cmd) {
		vprint("exec_async("+cmd+")",2);
		try { Process.spawn_command_line_async(cmd); }
		catch (SpawnError e) { vprint(e.message,1,stderr); }
	}
}
