// new not TeeJee

namespace l.misc {

	public static int VERBOSE = 1;
	const int64 KB = 1024;
	const int64 MB = 1024 * KB;

	private static void set_locale() {
		Intl.setlocale(LocaleCategory.MESSAGES,BRANDING_SHORTNAME);
		Intl.textdomain(BRANDING_SHORTNAME);
		Intl.bind_textdomain_codeset(BRANDING_SHORTNAME,"utf-8");
		Intl.bindtextdomain(BRANDING_SHORTNAME,LOCALE_DIR);
	}

	public void vprint(string s,int v=1,FileStream f=stdout,bool n=true) {
		if (v>VERBOSE) return;
		string o = s;
		if (VERBOSE>3) o = "%d: ".printf(Posix.getpid()) + o;
		if (n) o += "\n";
		f.printf(o);
		f.flush();
	}

	public void uri_open(string s) {
		try { AppInfo.launch_default_for_uri(s,null); }
		catch (Error e) { warning("Unable to launch %s",s); }
	}

	private static void pbar(int64 part=0,int64 whole=100,string units="") {
		if (VERBOSE<1) return;
		if (whole==0) { vprint("\r%79s\r".printf(""),1,stdout,false); return; }

		int i = 0;
		int64 c = 0;
		int64 plen = 0;
		int64 wlen = 40;
		string b = "";
		string u = units;

		if (whole>0) { c=(part*100/whole); plen=(part*wlen/whole); }
		else { c=100; plen=wlen; }

		for (i=0;i<wlen;i++) { if (i<plen) b+="▓"; else b+="░"; }
		if (u.length>0) u = " "+part.to_string()+"/"+whole.to_string()+" "+u;
		vprint("\r%79s\r%s %d%% %s ".printf("",b,(int)c,u),1,stdout,false);
	}

	public string b2h(int64 b) {
		if (b>MB) return (b/MB).to_string()+"M";
		else      return (b/KB).to_string()+"K";
	}

}
