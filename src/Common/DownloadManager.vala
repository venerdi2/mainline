
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;
using l.misc;

public class DownloadTask : AsyncTask {

	// settings
	public int timeout_secs = 60;

	// download lists
	private Gee.ArrayList<DownloadItem> downloads;
	private Gee.HashMap<string, DownloadItem> map;
	private Gee.HashMap<string,Regex> regex = null;

	public DownloadTask() {

		base();

		downloads = new Gee.ArrayList<DownloadItem>();
		map = new Gee.HashMap<string, DownloadItem>();
		regex = new Gee.HashMap<string,Regex>();

		try {
			//Sample:
			//[#4df0c7 19283968B/45095814B(42%) CN:1 DL:105404B ETA:4m4s]
			regex["file-progress"] = new Regex("""^\[#([^ \t]+)[ \t]+([0-9]+)B\/([0-9]+)B\(([0-9]+)%\)[ \t]+[^ \t]+[ \t]+DL\:([0-9]+)B[ \t]+ETA\:([^ \]]+)\]""");

			//12/03 21:15:33 [NOTICE] Download complete: /home/teejee/.cache/ukuu/v4.7.8/CHANGES
			regex["file-complete"] = new Regex("""[0-9A-Z\/: ]*\[NOTICE\] Download complete\: (.*)""");

			//8ae3a3|OK  |    16KiB/s|/home/teejee/.cache/ukuu/v4.0.7-wily/index.html
			//bea740|OK  |        n/a|/home/teejee/.cache/ukuu/v4.0.9-wily/CHANGES
			regex["file-status"] = new Regex("""^([0-9A-Za-z]+)\|(OK|ERR)[ ]*\|[ ]*(n\/a|[0-9.]+[A-Za-z\/]+)\|(.*)""");
		}
		catch (Error e) {
			vprint(e.message,1,stderr);
		}
	}

	// execution ----------------------------

	public void add_to_queue(DownloadItem item) {
		item.task = this;
		downloads.add(item);

		do { item.gid = random_string(16,"0123456789abcdef"); }
		while (map.has_key(item.gid_key));

		map[item.gid_key] = item;
	}

	public void clear_queue() {
		downloads.clear();
		map.clear();
	}

	public void execute() {
		prepare();
		begin();
		if (status == AppStatus.RUNNING) {}
	}

	public void prepare() {
		string s = build_script();
		save_bash_script_temp(s, script_file);
	}

	private string build_script() {

		vprint("build_script():",2);
		vprint("working_dir: '"+working_dir+"'",2);
		string list = "";
		string list_file = working_dir+"/download.list";
		foreach (var item in downloads) {
			list += item.source_uri + "\n"
			+ "  gid=" + item.gid + "\n"
			+ "  dir=" + item.download_dir + "\n"
			+ "  out=" + item.file_name + "\n";
		}
		file_write(list_file, list);

		string cmd = "aria2c"
		+ " --no-netrc true"
		+ " -i '"+list_file.replace("'","'\\''")+"'"
		+ " --summary-interval=1"
		+ " --auto-save-interval=1"
		+ " --enable-color=false"
		+ " --allow-overwrite"
		+ " --connect-timeout=%d".printf(App.connect_timeout_seconds)
		+ " --timeout=600"
		+ " --max-concurrent-downloads=%d".printf(App.concurrent_downloads)
		+ " --max-file-not-found=3"
		+ " --retry-wait=2"
		+ " --show-console-readout=false"
		+ " --human-readable=false"
		;

		if (App.all_proxy.length>0) cmd += " --all-proxy='"+App.all_proxy+"'";

		vprint(cmd,2);

		return cmd;
	}

	public override void parse_stdout_line(string out_line) {
		if (is_terminated) return;
		update_progress_parse_console_output(out_line);
	}

	public override void parse_stderr_line(string err_line) {
		if (is_terminated) return;
		update_progress_parse_console_output(err_line);
	}

	public bool update_progress_parse_console_output (string line) {
		if ((line == null) || (line.length == 0)) return true;

		//vprint(line,2);

		MatchInfo match;

		if (regex["file-complete"].match(line, 0, out match)) {
			//vprint("match: file-complete: " + line,2);
			prg_count++;
		} else if (regex["file-status"].match(line, 0, out match)) {

			//8ae3a3|OK  |    16KiB/s|/home/teejee/.cache/ukuu/v4.0.7-wily/index.html

			string gid_key = match.fetch(1).strip();
			string status = match.fetch(2).strip();
			//int64 rate = int64.parse(match.fetch(3).strip());
			//string file = match.fetch(4).strip();

			if (map.has_key(gid_key)) map[gid_key].status = status;

		} else if (regex["file-progress"].match(line, 0, out match)) {

			var gid_key = match.fetch(1).strip();
			var received = int64.parse(match.fetch(2).strip());
			var total = int64.parse(match.fetch(3).strip());
			//var percent = double.parse(match.fetch(4).strip());
			//var rate = int64.parse(match.fetch(5).strip());
			//var eta = match.fetch(6).strip();

			if (map.has_key(gid_key)) {
				var item = map[gid_key];
				item.bytes_received = received;
				if (item.bytes_total == 0) item.bytes_total = total;
				item.status = "RUNNING";
			}

		} else {
			//vprint("unmatched: '%s'".printf(line),2);
		}

		return true;
	}

	protected override void finish_task() {
	}
}

public class DownloadItem : GLib.Object
{
	// File is saved as 'file_name' not the source file name.

	public string file_name = "";
	public string download_dir = "";
	public string source_uri = "";

	public string gid = ""; // ID
	public int64 bytes_total = 0;
	public int64 bytes_received = 0;
	public string status = "";

	public DownloadTask task = null;

	public string file_path {
		owned get {
			return download_dir+"/"+file_name;
		}
	}

	public string gid_key {
		owned get {
			return gid.substring(0,6);
		}
	}

	public DownloadItem(string _source_uri, string _download_dir, string _file_name) {
		file_name = _file_name;
		download_dir = _download_dir;
		source_uri = _source_uri;
	}
}
