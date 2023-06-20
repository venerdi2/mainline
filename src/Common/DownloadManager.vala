
using l.misc;

public class DownloadTask : AsyncTask {

	// settings
	public int timeout_secs = 60;

	// item lists
	Gee.ArrayList<DownloadItem> downloads;
	Gee.HashMap<string, DownloadItem> map;
	Gee.HashMap<string,Regex> regex = null;

	public DownloadTask() {

		base();

		downloads = new Gee.ArrayList<DownloadItem>();
		map = new Gee.HashMap<string, DownloadItem>();
		regex = new Gee.HashMap<string,Regex>();

		try {
			//[#4df0c7 19283968B/45095814B(42%) CN:1 DL:105404B ETA:4m4s]
			regex["file-progress"] = new Regex("""^\[#(.+) (.+)B\/(.+)B""");

			//12/03 21:15:33 [NOTICE] Download complete: /home/teejee/.cache/ukuu/v4.7.8/CHANGES
			regex["file-complete"] = new Regex("""^.+\[NOTICE\] Download complete\: (.+)""");

			//8ae3a3|OK  |    16KiB/s|/home/teejee/.cache/ukuu/v4.0.7-wily/index.html
			//bea740|OK  |        n/a|/home/teejee/.cache/ukuu/v4.0.9-wily/CHANGES
			regex["file-result"] = new Regex("""^(.+)\|(OK|ERR) +\|.+\|(.+)""");
		}
		catch (Error e) {
			vprint(e.message,1,stderr);
		}
	}

	// execution ----------------------------

	public void add_to_queue(DownloadItem item) {
		item.task = this;
		item.gid = "%06x".printf(Main.rnd.int_range(0,0xffffff));
		map[item.gid] = item;
		downloads.add(item);
	}

	public void execute() {
		prepare();
		begin();
	}

	public void prepare() {
		vprint("prepare():",2);
		stdin_data = "";

		foreach (var item in downloads) {
			stdin_data += item.source_uri + "\n"
				+ " gid="+item.gid+"0000000000\n"
				+ " dir="+item.download_dir+"\n"
				+ " out="+item.file_name+"\n"
				;
			if (item.checksum.length>0) stdin_data += ""
				+ " checksum="+item.checksum+"\n"
				+ " check-integrity=true\n"
				;
		}

		string[] cmd = {
			"aria2c",
			//"--max-download-limit=256K",  // force slow download for debugging
			"--input-file=-",
			"--no-netrc=true",
			"--no-conf=true",
			"--summary-interval=1",
			"--auto-save-interval=1",
			"--enable-color=false",
			"--allow-overwrite",
			"--timeout=600",
			"--max-file-not-found=3",
			"--retry-wait=2",
			"--show-console-readout=false",
			"--download-result=full",
			"--human-readable=false"
		};

		if (App.connect_timeout_seconds>0) cmd += "--connect-timeout="+App.connect_timeout_seconds.to_string();

		if (App.concurrent_downloads>0) {
			cmd += "--max-concurrent-downloads="+App.concurrent_downloads.to_string();
			cmd += "--max-connection-per-server="+App.concurrent_downloads.to_string();
		}

		if (App.all_proxy.length>0) cmd += "--all-proxy='"+App.all_proxy+"'";

		spawn_args = cmd;
	}

	public override void process_line(string? line) {
		if (line==null) return;
		var l = line.strip();
		if (l.length<1) return;

		//vprint(l,2);

		MatchInfo match;

		if (regex["file-progress"].match(l, 0, out match)) {
			//vprint("match file-progress",2);
			var gid = match.fetch(1).strip();
			if (map.has_key(gid)) {
				var item = map[gid];
				item.bytes_received = int64.parse(match.fetch(2).strip());
				if (item.bytes_total == 0) item.bytes_total = int64.parse(match.fetch(3).strip());
				status_line = item.file_name+" "+item.bytes_received.to_string()+"/"+item.bytes_total.to_string();
			}
		} else if (regex["file-complete"].match(l, 0, out match)) {
			//vprint("match file-complete",2);
			prg_count++;
		} else if (regex["file-result"].match(l, 0, out match)) {
			//vprint("match file-result",2);
			var gid = match.fetch(1).strip();
			//string fname = match.fetch(3).strip();
			if (map.has_key(gid)) {
				var item = map[gid];
				if (match.fetch(2)=="OK") {
					item.bytes_received = item.bytes_total;
					status_line = item.file_name+" "+item.bytes_received.to_string()+"/"+item.bytes_total.to_string();
				}
			}
		}

		return;
	}
}

public class DownloadItem : GLib.Object {
	// File is saved as 'file_name' in 'download_dir', not the source file name.

	public string source_uri = "";		// "https://kernel.ubuntu.com/~kernel-ppa/mainline/v6.2.7/amd64/linux-headers-6.2.7-060207-generic_6.2.7-060207.202303170542_amd64.deb"
	public string download_dir = "";	// "/home/bkw/.cache/mainline/6.2.7/amd64"
	public string file_name = "";		// "linux-headers-6.2.7-060207-generic_6.2.7-060207.202303170542_amd64.deb"
	public string checksum = "";		// "sha-256=4a90d708984d6a8fab68411710be09aa2614fe1be5b5e054a872b155d15faab6"

	public string gid = ""; // first 6 bytes of gid
	public int64 bytes_total = 0;
	public int64 bytes_received = 0;

	public DownloadTask task = null;

	public DownloadItem(string uri = "", string destdir = "", string fname = "", string? cksum = "") {
		if (cksum==null) cksum = "";
		vprint("DownloadItem("+uri+","+destdir+","+fname+","+cksum+")",3);
		source_uri = uri;
		file_name = fname;
		download_dir = destdir;
		checksum = cksum;
	}
}
