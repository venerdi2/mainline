// misc lib

namespace l.misc {

	private static void set_locale() {
		Intl.setlocale(LocaleCategory.MESSAGES,BRANDING_SHORTNAME);
		Intl.textdomain(BRANDING_SHORTNAME);
		Intl.bind_textdomain_codeset(BRANDING_SHORTNAME,"utf-8");
		Intl.bindtextdomain(BRANDING_SHORTNAME,LOCALE_DIR);
	}

	public void vprint(string s,int v=1,FileStream f=stdout,bool n=true) {
		if (v>Main.VERBOSE) return;
		string o = s;
		if (Main.VERBOSE>3) o = "%d: ".printf(Posix.getpid()) + o;
		if (n) o += "\n";
		f.printf(o);
		f.flush();
	}

	public void uri_open(string s) {
		try { AppInfo.launch_default_for_uri(s,null); }
		catch (Error e) { warning("Unable to launch %s",s); }
	}

	private static void pbar(int64 part=0,int64 whole=100,string units="") {
		if (Main.VERBOSE<1) return;
		int l = 80; // bar length
		if (whole<1) { vprint("\r%*.s\r".printf(l,""),1,stdout,false); return; }
		int64 c = 0, plen = 0, wlen = l/2;
		string b = "", u = units;
		if (whole>0) { c=(part*100/whole); plen=(part*wlen/whole); }
		else { c=100; plen=wlen; }
		for (int i=0;i<wlen;i++) { if (i<plen) b+="▓"; else b+="░"; }
		if (u.length>0) u = " "+part.to_string()+"/"+whole.to_string()+" "+u;
		vprint("\r%*.s\r%s %d%% %s ".printf(l,"",b,(int)c,u),1,stdout,false);
	}

	public bool try_ppa() {
		vprint("try_ppa()",4);
		if (App.ppa_tried) return App.ppa_up;

		string std_err, std_out;

		string cmd = "aria2c"
		+ " --no-netrc"
		+ " --no-conf"
		+ " --max-file-not-found=3"
		+ " --retry-wait=2"
		+ " --max-tries=3"
		+ " --dry-run"
		+ " --quiet";
		if (App.connect_timeout_seconds>0) cmd += " --connect-timeout="+App.connect_timeout_seconds.to_string();
		if (App.all_proxy.length>0) cmd += " --all-proxy='"+App.all_proxy+"'";
		cmd += " '"+App.ppa_uri+"'";

		vprint(cmd,3);

		int status = exec_sync(cmd, out std_out, out std_err);
		if (std_err.length > 0) vprint(std_err,1,stderr);

		App.ppa_tried = true;
		App.ppa_up = false;
		if (status == 0) App.ppa_up = true;
		else vprint(_("Can not reach site")+": \""+App.ppa_uri+"\"",1,stderr);

		App.ppa_up = true;
		return App.ppa_up;
	}

	// returns waitpid() status not exit() value
	public int exec_sync(string cmd, out string? std_out = null, out string? std_err = null) {
		vprint("exec_sync("+cmd+")",2);
		int wait_status = -1;
		try { Process.spawn_command_line_sync(cmd, out std_out, out std_err, out wait_status); }
		catch (SpawnError e) { vprint(e.message,1,stderr); }
		return wait_status;
	}

	public void exec_async(string cmd) {
		vprint("exec_async("+cmd+")",2);
		try { Process.spawn_command_line_async(cmd); }
		catch (SpawnError e) { vprint(e.message,1,stderr); }
	}

	// delete file or directory, recursive, empty or not
	public bool rm(string path) {
		vprint("rm("+path+")",3);
		File p = File.new_for_path(path);
		if (!p.query_exists()) return true;
		if (p.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS) == FileType.DIRECTORY) try {
			FileEnumerator en = p.enumerate_children ("standard::*",FileQueryInfoFlags.NOFOLLOW_SYMLINKS,null);
			FileInfo i; File n; string s;
			while (((i = en.next_file(null)) != null)) {
				n = p.resolve_relative_path(i.get_name());
				s = n.get_path();
				if (i.get_file_type() == FileType.DIRECTORY) rm(s);
				else n.delete();
			}
		} catch (Error e) { print ("Error: %s\n", e.message); }
		try { p.delete(); } catch (Error e) { print ("Error: %s\n", e.message); }
		return !p.query_exists();
	}

	public string random_string(int len = 8, string set = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") {
		string o = ""; int l = set.length;
		for(int i=0;i<len;i++) o += set[Random.int_range(0,l)].to_string();
		return o;
	}
}
