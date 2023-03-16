
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.Misc;
using l.misc;

public class LinuxKernel : GLib.Object, Gee.Comparable<LinuxKernel> {

	public string kname = "";
	public string kver = "";
	public string version_main = "";
	public string version_package = "";
	public string page_uri = "";

	public int version_maj = -1;
	public int version_min = -1;
	public int version_point = -1;
	public int version_rc = -1;

	public Gee.HashMap<string,string> deb_list = new Gee.HashMap<string,string>(); // assosciated .deb file names
	public Gee.HashMap<string,string> pkg_list = new Gee.HashMap<string,string>(); // assosciated dpkg package names

	public static Gee.HashMap<string,Package> pkg_list_installed;

	public bool is_installed = false;
	public bool is_running = false;
	public bool is_mainline = false;

	public string deb_header = "";
	public string deb_header_all = "";
	public string deb_image = "";
	public string deb_image_extra = "";
	public string deb_modules = "";

	// static
	public static string NATIVE_ARCH;
	public static string LINUX_DISTRO;
	public static string RUNNING_KERNEL;
	public static string PPA_URI;
	public static string CACHE_DIR;

	public static LinuxKernel kernel_active;
	public static LinuxKernel kernel_update_major;
	public static LinuxKernel kernel_update_minor;
	public static LinuxKernel kernel_latest_available;
	public static LinuxKernel kernel_latest_installed;
	public static LinuxKernel kernel_oldest_installed;

	public static Gee.ArrayList<LinuxKernel> kernel_list = new Gee.ArrayList<LinuxKernel>();

	public static Regex rex_header = null;
	public static Regex rex_header_all = null;
	public static Regex rex_image = null;
	public static Regex rex_image_extra = null;
	public static Regex rex_modules = null;

	// global progress  ------------
	public static string status_line;
	public static int progress_total;
	public static int progress_count;
	public static bool cancelled;
	public static int threshold_major = 0;

	// class initialize
	public static void initialize() {
		new LinuxKernel("", false); // instance must be created before setting static members

		LINUX_DISTRO = check_distribution();
		NATIVE_ARCH = check_package_architecture();
		RUNNING_KERNEL = check_running_kernel().replace("-generic","");
		initialize_regex();
		kernel_latest_installed = new LinuxKernel.from_version(RUNNING_KERNEL);
		kernel_oldest_installed = kernel_latest_installed;
		kernel_latest_available = kernel_latest_installed;
	}

	// dep: lsb_release
	public static string check_distribution() {
		vprint("check_distribution()",2);
		string dist = "";

		string std_out, std_err;
		int status = exec_sync("lsb_release -sd", out std_out, out std_err);
		if ((status == 0) && (std_out != null)) {
			dist = std_out.strip();
			vprint(_("Distribution") + ": %s".printf(dist));
		}

		return dist;
	}

	// dep: dpkg
	public static string check_package_architecture() {
		vprint("check_package_architecture()",2);
		string arch = "";

		string std_out, std_err;
		int status = exec_sync("dpkg --print-architecture", out std_out, out std_err);
		if ((status == 0) && (std_out != null)) {
			arch = std_out.strip();
			vprint(_("Architecture") + ": %s".printf(arch));
		}

		return arch;
	}

	// dep: uname
	public static string check_running_kernel() {
		vprint("check_running_kernel()",2);
		string ver = "";

		string std_out;
		exec_sync("uname -r", out std_out, null);

		ver = std_out.strip().replace("\n","");
		vprint("Running kernel" + ": %s".printf(ver));

		return ver;
	}

	public static void initialize_regex() {
		//log_debug("initialize_regex()");
		try {
			//linux-headers-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_header = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-[a-zA-Z0-9.\-_]*-generic_[a-zA-Z0-9.\-]*_""" + NATIVE_ARCH + ".deb");

			//linux-headers-3.4.75-030475_3.4.75-030475.201312201255_all.deb
			rex_header_all = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-[a-zA-Z0-9.\-_]*_all.deb""");

			//linux-image-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_image = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-[a-zA-Z0-9.\-_]*-generic_([a-zA-Z0-9.\-]*)_""" + NATIVE_ARCH + ".deb");

			//linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_image_extra = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-extra-[a-zA-Z0-9.\-_]*-generic_[a-zA-Z0-9.\-]*_""" + NATIVE_ARCH + ".deb");

			//linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_modules = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-modules-[a-zA-Z0-9.\-_]*-generic_[a-zA-Z0-9.\-]*_""" + NATIVE_ARCH + ".deb");
		} catch (Error e) {
			vprint(e.message,1,stderr);
		}
	}

	public static bool check_if_initialized() {
		bool ok = (NATIVE_ARCH.length > 0);
		if (!ok){
			vprint("LinuxKernel: Class should be initialized before use!",1,stderr);
			exit(1);
		}
		return ok;
	}

	public static void delete_cache() {
		vprint("delete_cache()",2);
		kernel_list.clear();
		dir_delete(CACHE_DIR);
	}

	// constructor
	public LinuxKernel(string _name, bool _is_mainline) {
		vprint("LinuxKernel("+_name+","+_is_mainline.to_string()+")",4);
		// _name, kname includes the leading "v" and everything after the version number
		// same as what's in the urls on the kernel ppa index.html

		// strip off the trailing "/"
		if (_name.has_suffix("/")) this.kname = _name[0: _name.length - 1];
		else this.kname = _name;

		// extract version numbers from the name
		kver = this.kname;
		split_version_string(kver, out version_main);

		// build url
		page_uri = PPA_URI + _name;

		// override is_mainline from split_version_string()
		is_mainline = _is_mainline;
	}

	public LinuxKernel.from_version(string _version) {
		kver = _version;
		split_version_string(kver, out version_main);
		page_uri = "";
	}

	// static

	public delegate void Notifier(GLib.Timer timer, ref long count, bool last = false);

	public static void query(bool wait, owned Notifier? notifier = null) {
		vprint("LinuxKernel.query()",2);

		check_if_initialized();
		kernel_list.clear();

		try {
			cancelled = false;
			var worker = new Thread<bool>.try(null, () => query_thread((owned) notifier) );
			if (wait) worker.join();
		} catch (Error e) {
			vprint(e.message,1,stderr);
		}
	}

	private static bool query_thread(owned Notifier? notifier) {
		vprint("query_thread()",2);
		App.progress_total = 1;
		App.progress_count = 0;

		var timer = timer_start();
		long count = 0;
		status_line = "";
		progress_total = 0;
		progress_count = 0;

		// ===== download the main index.html listing all kernels =====
		download_index();
		load_index();

		// find the oldest major version to include
		Package.update_dpkg_list();
		update_threshold_major();

		// ===== download the per-kernel index.html and CHANGES =====

		// list of kernels - 1 LinuxKernel object per kernel to update
		var kernels_to_update = new Gee.ArrayList<LinuxKernel>();
		// list of files - 1 DownloadItem object per individual file to download
		var downloads = new Gee.ArrayList<DownloadItem>();

		// add files to download list, and add kernels to kernel list
		foreach (var k in kernel_list) {
			if (cancelled) break;

			// skip some kernels for various reasons
			if (k.cached_page_exists) {
				//log_debug(k.version_main+" "+_("cached"));
				// load the index.html files we already had in cache
				k.load_cached_page();
				continue;
			}

			if (!k.is_valid) continue;

			if (!k.is_installed) {
				if (k.version_maj < threshold_major) continue;
				if (App.hide_unstable && k.is_unstable) continue;
			}

			//log_debug(k.version_main+" "+_("GET"));

			// add index.html to download list
			var item = new DownloadItem(k.cached_page_uri, file_parent(k.cached_page), file_basename(k.cached_page));
			downloads.add(item);

			// add CHANGES to download list
			item = new DownloadItem(k.changes_file_uri, file_parent(k.changes_file), file_basename(k.changes_file));
			downloads.add(item);

			// add kernel to update list
			kernels_to_update.add(k);

			if (notifier != null) notifier(timer, ref count);
		}

		// process the download list
		if ((downloads.size > 0) && App.ppa_up) {
			progress_total = downloads.size;
			var mgr = new DownloadTask();

			// add download list to queue
			foreach (var item in downloads) mgr.add_to_queue(item);

			// start downloading
			mgr.execute();

			vprint(_("Fetching individual kernel indexes")+"...");

			// while downloading
			while (mgr.is_running()) {
				progress_count = mgr.prg_count;
				//pbar(progress_count,progress_total,"files");
				pbar(progress_count,progress_total);
				sleep(250);
				if (notifier != null) notifier(timer, ref count);
			}

			// done downloading
			pbar(0,0);

			// load the index.html files we just added to cache
			foreach (var k in kernels_to_update) k.load_cached_page();

			if (notifier != null) notifier(timer, ref count);
		}

		check_installed();
		check_updates();

		timer_elapsed(timer, true);
		if (notifier != null) notifier(timer, ref count, true);

		return true;
	}

	// download the main index.html listing all mainline kernels
	private static bool download_index() {
		vprint("download_index()",2);
		check_if_initialized();

		if (!try_ppa()) return false;
		if (!file_exists(index_page)) App.index_is_fresh=false;
		if (App.index_is_fresh) return true;

		dir_create(file_parent(index_page));
		file_delete(index_page+"_");

		// preserve the old index in case the dl fails
		string tbn = random_string();
		string tfn = CACHE_DIR+"/"+tbn;
		vprint("+ DownloadItem("+PPA_URI+","+CACHE_DIR+","+tbn+")",4);
		var item = new DownloadItem(PPA_URI, CACHE_DIR, tbn);
		var mgr = new DownloadTask();
		mgr.add_to_queue(item);

		vprint(_("Updating from")+": '"+PPA_URI+"'");
		mgr.execute();

		while (mgr.is_running()) sleep(500);

		vprint("waiting for '"+tfn+"'",4);
		// brute force until I can figure out the right way to deal with AsyncTask
		int i = 0;
		while (!file_exists(tfn) && i++ < 100) {
			vprint("not yet",4);
			sleep(500);
		}

		if (file_exists(tfn)) {
			vprint("got it",4);
			file_move(tfn,index_page);
			App.index_is_fresh=true;
			vprint(_("OK"));
			return true;
		} else {
			vprint(_("FAILED"),1,stderr);
			return false;
		}
	}

	// read the main index.html listing all kernels
	private static void load_index() {
		vprint("load_index()",2);

		if (!file_exists(index_page)) return;
		string txt = file_read(index_page);
		kernel_list.clear();

		try {
			var rex = new Regex("""<a href="(v[a-zA-Z0-9\-._\/]+)">v([a-zA-Z0-9\-._]+)[\/]*<\/a>""");
			// <a href="v3.1.8-precise/">v3.1.8-precise/</a>
			//          ###fetch(1)####   ##fetch(2)###

			MatchInfo match;

			foreach (string line in txt.split("\n")) {
				if (!rex.match(line, 0, out match)) continue;
				var k = new LinuxKernel(match.fetch(1), true);
				if (!k.is_valid) continue;
				if (k.is_unstable && App.hide_unstable) continue;
				kernel_list.add(k);
				vprint("kernel_list.add("+k.kname+")",3);
			}

			kernel_list.sort((a,b) => { return a.compare_to(b) * -1; });

			kernel_latest_available = kernel_list[0];
			vprint("latest_available: "+kernel_latest_available.version_main,2);
		}
		catch (Error e) {
			vprint(e.message,1,stderr);
		}

	}

	public static void check_installed() {
		vprint("check_installed()",2);

		var pkg_versions = new Gee.ArrayList<string>();

		foreach (var pkg in Package.dpkg_list) {
			if (!pkg.pname.has_prefix("linux-image-")) continue;
			vprint("Found installed : "+pkg.version);
			pkg_versions.add(pkg.version);

			// temp kernel object for current pkg
			string pkern_name = pkg.version;
			var pkern = new LinuxKernel(pkern_name, false);
			pkern.is_installed = true; // dpkg_list[] only contains installed packages
			pkern.set_pkg_list(); // find assosciated packages and fill pkern.pkg_list[]

			// search the mainline list for matching package name
			// fill k.pkg_list list of assosciated pkgs
			bool found = false;
			foreach (var k in kernel_list) {
				if (!k.is_valid) continue;
				if (k.version_maj<threshold_major) continue;
				if (k.version_package == pkern.kname) {
					found = true;
					k.pkg_list = pkern.pkg_list;
					break;
				}
			}

			// current package was not found in the mainline list
			// so it's a distro kernel, add a kernel_list entry
			if (!found) {
				//vprint("kernel_list.add("+pkern.kname+") (distro kernel)",3); // not always true, --uninstall-old thinks all are
				vprint("kernel_list.add("+pkern.kname+")",3);
				kernel_list.add(pkern);
			}
		}

		// mark the installed mainline kernels
		foreach (string pkg_version in pkg_versions) {
			foreach (var k in kernel_list) {
				if (!k.is_valid) continue;
				if (k.version_maj<threshold_major) continue;
				if (k.version_package == "") continue;
				if (pkg_version == k.version_package) {
					k.is_installed = true;
					break;
				}
			}
		}

		// Find and tag the running kernel in list ------------------
		
		// Running: 4.2.7-040207-generic
		// Package: 4.2.7-040207.201512091533

		// Running: 4.4.0-28-generic
		// Package: 4.4.0-28.47

		var kern_running = new LinuxKernel.from_version(RUNNING_KERNEL);
		kernel_active = null;

		// https://github.com/bkw777/mainline/issues/91

		// scan mainline kernels
		foreach (var k in kernel_list) {
			if (!k.is_valid) continue;
			if (!k.is_mainline) continue;
			if (k.version_package.length > 0) {
				// (k.version_main.contains(kern_running.version_main) || kern_running.version_main.contains(k.version_main))
				if (k.version_package[0 : k.version_package.last_index_of(".")] == RUNNING_KERNEL) {
					k.is_running = true;
					k.is_installed = true;
					kernel_active = k;
					break;
				}
			}
		}

		// scan ubuntu kernels
		if (kernel_active == null) {
			foreach (var k in kernel_list) {
				if (!k.is_valid) continue;
				if (k.is_mainline) continue;
				//if (kern_running.version_main == k.version_main) {  // strict
				//if (k.version_main.contains(kern_running.version_main) || kern_running.version_main.contains(k.version_main)) { // forgiving
				if (k.version_main.has_prefix(kern_running.version_main) || kern_running.version_main.has_prefix(k.version_main)) { // forgiving
					k.is_running = true;
					k.is_installed = true;
					kernel_active = k;
					break;
				}
			}
		}

		kernel_list.sort((a,b) => {
			return a.compare_to(b) * -1;
		});

		// find the highest & lowest installed versions ----------------------
		kernel_latest_installed = new LinuxKernel.from_version("0");
		kernel_oldest_installed = kernel_latest_installed;
		foreach(var k in kernel_list) {
			if (k.is_installed) {
				if (kernel_latest_installed.version_maj==0) kernel_latest_installed = k;
				kernel_oldest_installed = k;
			}
		}

//		log_debug("latest_available: "+kernel_latest_available.version_main);
		vprint("latest_installed: "+kernel_latest_installed.version_main,2);
		vprint("oldest_installed: "+kernel_oldest_installed.version_main,2);
	}

	// scan kernel_list for versions newer than latest installed
	public static void check_updates() {
		vprint("check_updates()",2);
		kernel_update_major = null;
		kernel_update_minor = null;

		foreach(var k in LinuxKernel.kernel_list) {
			if (!k.is_valid) continue;
			if (k.is_installed) continue;
			if (k.is_unstable && App.hide_unstable) continue;

			bool major_available = false;
			bool minor_available = false;

			if (k.version_maj > kernel_latest_installed.version_maj) major_available = true;
			else if (k.version_maj == kernel_latest_installed.version_maj) {
				if (k.version_min > kernel_latest_installed.version_min) major_available = true;
				else if (k.version_min == kernel_latest_installed.version_min) {
					if (k.version_point > kernel_latest_installed.version_point) minor_available = true;
					else if (k.version_point == kernel_latest_installed.version_point) {
						if (k.version_rc > kernel_latest_installed.version_rc) minor_available = true;
					}
				}
			}

			if (major_available && (kernel_update_major == null)) kernel_update_major = k;

			if (minor_available && (kernel_update_minor == null)) kernel_update_minor = k;

			// stop if we have everything possible
			if ((kernel_update_major != null) && (kernel_update_minor != null) && (kernel_latest_available != null)) break;
		}
	}

	// helpers

	public static void update_threshold_major() {
		vprint("update_threshold_major()",2);

		//Package.update_dpkg_list();

		// start from the running kernel and work down
		kernel_oldest_installed = new LinuxKernel.from_version(RUNNING_KERNEL);

		foreach (var pkg in Package.dpkg_list) {
			if (!pkg.pname.has_prefix("linux-image-")) continue;
			var candidate = new LinuxKernel(pkg.version, false);
			if (candidate.version_maj < kernel_oldest_installed.version_maj) kernel_oldest_installed = candidate;
		}

		threshold_major = kernel_latest_available.version_maj - App.previous_majors;
		if (kernel_oldest_installed.version_maj < threshold_major) threshold_major = kernel_oldest_installed.version_maj;
		vprint("threshold_major %d".printf(threshold_major),2);
	}

	public void split_version_string(string _version_string, out string ver_main) {
		ver_main = "";
		version_maj = 0;
		version_min = 0;
		version_point = 0;
		version_rc = -1;

		if (_version_string.length == 0) return;

		var version_string = _version_string.split("~")[0];
		var match = regex_match("""[v]*([0-9]+|r+c+)""", version_string);
		int index = -1;
		string version_extra = "";
		bool saw_rc = false;

		while (match != null){
			string? num = match.fetch(1);

			if (num != null){
				index++;

				if (saw_rc) {
					saw_rc = false;
					version_rc = int.parse(num);
				} else if (num == "rc") {
					saw_rc = true;
				} else {
					switch (index) {
					case 0:
						version_maj = int.parse(num);
						break;
					case 1:
						version_min = int.parse(num);
						break;
					case 2:
						version_point = int.parse(num);
						break;
					case 3:
						if ((version_rc<0) && (num.length<3)) version_extra += "."+num;
						break;
					case 4:
						if ((version_rc<0) && (num.length<3)) version_extra += "."+num;
						break;
					}
					if (num.length >= 12) is_mainline = true;
				}
			}

			if (version_rc>-1) version_extra = "-rc%d".printf(version_rc);
			ver_main = "%d.%d.%d%s".printf(version_maj,version_min,version_point,version_extra);

			try{
				if (!match.next()) break;
			}
			catch(Error e) {
				break;
			}
		}

	}

	public int compare_to(LinuxKernel b) {
		LinuxKernel a = this;
		//vprint("compare_to()",5);
		string[] arr_a = a.version_main.split_set(".-_");
		string[] arr_b = b.version_main.split_set(".-_");
		//vprint("a "+a.version_main,5);
		//vprint("b "+b.version_main,5);

		int i = 0;
		int x, y;

		// while both arrays have an element
		while ((i < arr_a.length) && (i < arr_b.length)) {

			// continue if equal
			//vprint("("+arr_a[i]+" == "+arr_b[i]+")",5);
			if (arr_a[i] == arr_b[i]) {
				i++;
				continue;
			}

			// check if number
			x = int.parse(arr_a[i]);
			y = int.parse(arr_b[i]);
			if ((x > 0) && (y > 0)) {
				// both are numbers
				//vprint(arr_a[i]+" - "+arr_b[i]+" = return "+(x-y).to_string(),5);
				return (x - y);
			} else if ((x == 0) && (y == 0)) {
				// BKW - this is one place where "-rc3" gets compared to "-rc4"
				// both are strings
				//vprint("strcmp("+arr_a[i]+","+arr_b[i]+") = return "+strcmp(arr_a[i], arr_b[i]).to_string(),5);
				return strcmp(arr_a[i], arr_b[i]);
			} else {
				//vprint("("+arr_a[i]+">0)",5);
				if (x > 0) {
					//vprint("return 1",5);
					return 1;
				}
				//vprint("return -1",5);
				return -1;
			}
		}

		// if we got here
		// one array has less parts than the other, and all corresponding parts are equal

		if (i < arr_a.length) {
			//vprint("a ("+arr_a[i]+">0)",5);
			x = int.parse(arr_a[i]);
			if (x > 0) return 1;
			return -1;
		}

		if (i < arr_b.length) {
			//vprint("b ("+arr_b[i]+">0)",5);
			y = int.parse(arr_b[i]);
			if (y > 0) return -1;
			return 1;
		}

		return (arr_a.length - arr_b.length) * -1; // smaller array is larger version
	}

	public void mark_invalid() {
		string f = cache_subdir+"/invalid";
		if (!file_exists(f)) file_write(f, "");
	}

	public void set_pkg_list() {
		vprint("set_pkg_list()",2);
		vprint("kname:"+kname+" kver:"+kver+" version_main:"+version_main,3);
		foreach(var pkg in Package.dpkg_list) {
			if (!pkg.pname.has_prefix("linux-")) continue;
			if (pkg.version == kver) {
				pkg_list[pkg.pname] = pkg.pname;
				vprint("Package: "+pkg.pname,2);
			}
		}
	}

	// properties

	public bool is_unstable {
		get {
			return kver.contains("-rc") || kver.contains("-unstable");
		}
	}

	public bool is_valid {
		get {
			return !file_exists(cache_subdir+"/invalid");
		}
	}

	public static string index_page {
		owned get {
			return CACHE_DIR+"/index.html";
		}
	}

	public string cache_subdir {
		owned get {
			return CACHE_DIR+"/"+version_main;
		}
	}

	public string cached_page {
		owned get {
			return cache_subdir+"/index.html";
		}
	}

	public string cached_page_uri {
		owned get {
			return page_uri;
		}
	}

	public string changes_file {
		owned get {
			return cache_subdir+"/CHANGES";
		}
	}

	public string changes_file_uri {
		owned get {
			return page_uri+"CHANGES";
		}

	}

	public bool cached_page_exists {
		get {
			return file_exists(cached_page);
		}
	}

	public string tooltip_text() {
		string txt = "";

		string list = "";
		foreach (string deb in deb_list.keys) list += "\n"+deb;

		if (list.length > 0) txt += "<b>"+_("Packages Available")+"</b>\n"+list;

		list = "";
		foreach (string deb in pkg_list.keys) list += "\n"+deb;

		if (list.length > 0) txt += "\n\n<b>"+_("Packages Installed")+"</b>\n"+list;

		return txt;
	}

	// load

	private void load_cached_page() {
		vprint("load_cached_page(): '"+cached_page+"'",4);

		var list = new Gee.HashMap<string,string>();

		if (!file_exists(cached_page)) {
			vprint("load_cached_page(): " + _("File not found") + ": %s".printf(cached_page),1,stderr);
			return;
		}

		string txt = file_read(cached_page);

		// parse index.html --------------------------

		try {
			//<a href="linux-headers-4.6.0-040600rc1-generic_4.6.0-040600rc1.201603261930_amd64.deb">//same deb name//</a>
			var rex = new Regex("""<a href="([a-zA-Z0-9\-._/]+)">([a-zA-Z0-9\-._/]+)<\/a>""");
			MatchInfo match;

			foreach(string line in txt.split("\n")) {
				if (rex.match(line, 0, out match)) {

					string file_name = Path.get_basename (match.fetch(2));
					string file_uri = "%s%s".printf(page_uri, match.fetch(1));
					bool add = false;

					if (rex_header.match(file_name, 0, out match)) {
						deb_header = file_name;
						add = true;
					}

					if (rex_header_all.match(file_name, 0, out match)) {
						deb_header_all = file_name;
						add = true;
					}

					if (rex_image.match(file_name, 0, out match)) {
						deb_image = file_name;
						version_package = match.fetch(1);
						add = true;
					}

					if (rex_image_extra.match(file_name, 0, out match)) {
						deb_image_extra = file_name;
						add = true;
					}

					if (rex_modules.match(file_name, 0, out match)) {
						deb_modules = file_name;
						add = true;
					}

					if (add) list[file_name] = file_uri;
				}
			}

			// if ((deb_header.length == 0) || (deb_header_all.length == 0) || (deb_image.length == 0))
			if (deb_image.length == 0) mark_invalid();

		} catch (Error e) {
			vprint(e.message,1,stderr);
		}

		deb_list = list;
	}

	// actions

	public static void print_list() {
		vprint("----------------------------------------------------------------");
		vprint(_("Available Kernels"));
		vprint("----------------------------------------------------------------");

		foreach(var k in kernel_list) {
			if (!k.is_valid) continue;

			// check running/installed state before checking for hidden
			var desc = k.is_running ? _("Running") : (k.is_installed ? _("Installed") : "");

			// hide hidden, but don't hide any installed
			if (!k.is_installed) {
				if (App.hide_unstable && k.is_unstable) continue;
				if (k.version_maj < threshold_major) continue;
			}

			// kern.kname "v5.6.11" -> cache download dir names, needed for --install, --remove
			// kern.kver or kern.version_main "5.6.11" -> most displays & references
			//log_msg("%-32s %-32s %s".printf(kern.kname, kern.version_main, desc));
			vprint("%-32s %s".printf(k.version_main, desc));
		}
	}

	public static bool download_kernels(Gee.ArrayList<LinuxKernel> selected_kernels) {
		foreach (var k in selected_kernels) k.download_packages();
		return true;
	}

	// dep: aria2c
	public bool download_packages() {
		bool ok = true;

		check_if_initialized();

		foreach (string file_name in deb_list.keys) {

			string dl_dir = cache_subdir;
			string file_path = "%s/%s".printf(dl_dir, file_name);

			if (file_exists(file_path) && !file_exists(file_path + ".aria2c")) continue;

			dir_create(dl_dir);

			vprint(_("Downloading")+": "+file_name);

			var item = new DownloadItem(deb_list[file_name], file_parent(file_path), file_basename(file_path));
			var mgr = new DownloadTask();
			mgr.add_to_queue(item);
			mgr.execute();

			while (mgr.is_running()) {
				pbar(item.bytes_received,item.bytes_total);
				sleep(200);
			}

			string r = _("OK");
			if (!file_exists(file_path)) {
				ok = false;
				r = _("FAILED");
			}
			pbar(0,0);
		}

		return ok;
	}

	// dep: dpkg
	public bool kinst() {

		// check if installed
		if (is_installed) {
			vprint(version_main+" "+_("is already installed."),1,stderr);
			return false;
		}

		if (!try_ppa()) return false;

		bool ok = download_packages();
		int status = -1;

		if (ok) {

			// full paths instead of env -C
			// https://github.com/bkw777/mainline/issues/128
			var flist = "";
			foreach (string file_name in deb_list.keys) flist += " '"+cache_subdir+"/"+file_name+"'";
			string cmd = "pkexec env DISPLAY=${DISPLAY} XAUTHORITY=${XAUTHORITY} dpkg --install "+flist;
			status = Posix.system(cmd);
			ok = (status == 0);
			foreach (string file_name in deb_list.keys) file_delete(cache_subdir+"/"+file_name);

		}

		return ok;
	}

	// dep: dpkg
	public static bool kunin_list(Gee.ArrayList<LinuxKernel> selected_kernels) {
		bool ok = false;
		int status = -1;

		vprint(_("Uninstalling selected kernels")+":");

		string cmd = "pkexec env DISPLAY=${DISPLAY} XAUTHORITY=${XAUTHORITY} dpkg --purge";
		string found = "";

		foreach (var k in selected_kernels) {
			vprint(_("requested")+" "+k.version_main);

			if (k.is_running) {
				vprint("! "+_("not uninstalling the currently running kernel")+" "+k.version_main);
				continue;
			}

			found = "";
			foreach (var pkg_name in k.pkg_list.values) {
				//vprint(pkg_name,5);
				if (
					!pkg_name.has_prefix("linux-tools") &&
					!pkg_name.has_prefix("linux-libc")
				) {
					cmd += " '%s'".printf(pkg_name);
					found += " "+pkg_name;
					ok = true;
				}
			}
			vprint(_("found")+" : "+found,2);

			if (!ok) {
				vprint(_("No packages to un-install!"),1,stderr);
				return false;
			}

		}

		vprint(cmd,2);
		status = Posix.system(cmd);
		ok = (status == 0);

		return ok;
	}

	public static void kunin_old(bool confirm) {
		vprint("kunin_old()",2);

		download_index();
		load_index();
		Package.update_dpkg_list();
		update_threshold_major();
		check_installed();

		var list = new Gee.ArrayList<LinuxKernel>();

		var kern_running = new LinuxKernel.from_version(RUNNING_KERNEL);

		bool found_running_kernel = false;

		//vprint("latest_installed: "+kernel_latest_installed.version_main,4);
		//vprint("running_kernel: "+kern_running.version_main,4);

		foreach(var k in LinuxKernel.kernel_list) {
			if (!k.is_valid) continue;
			if (!k.is_installed) continue;
			if (k.version_main == kern_running.version_main) {
				found_running_kernel = true;
				//vprint(k.version_main+" == running_kernel -> skip",4);
				continue;
			}
			if (k.compare_to(kernel_latest_installed) >= 0) {
				//vprint(k.version_main+" >= "+kernel_latest_installed.version_main+" -> skip ",4);
				continue;
			}
			//vprint(k.version_main+" < "+kernel_latest_installed.version_main+" -> delete",4);
			list.add(k);
		}

		if (!found_running_kernel) {
			vprint(_("Could not find running kernel in list"),1,stderr);
			return;
		}

		if (list.size == 0){
			vprint(_("Could not find any kernels to uninstall"),2);
			return;
		}

		// confirm -------------------------------

		if (confirm) {

			var message = "\n"+_("The following kernels will be uninstalled")+"\n";

			foreach (var k in list) message += " ▰ %s\n".printf(k.version_main);

			message += "\n%s (y/n): ".printf(_("Continue ?"));

			vprint(message,0);

			int ch = stdin.getc();

			if (ch != 'y') return;
		}

		// uninstall --------------------------------
		kunin_list(list);
	}

	public static void kinst_latest(bool point_update, bool confirm) {
		vprint("kinst_latest()",2);

		query(true);

		var kern_major = LinuxKernel.kernel_update_major;

		if ((kern_major != null) && !point_update) {

			var message = "%s: %s".printf(_("Latest update"), kern_major.version_main);
			vprint(message);

			kinst_update(kern_major, confirm);
			return;
		}

		var kern_minor = LinuxKernel.kernel_update_minor;

		if (kern_minor != null) {

			var message = "%s: %s".printf(_("Latest point update"), kern_minor.version_main);
			vprint(message);

			kinst_update(kern_minor, confirm);
			return;
		}

		if ((kern_major == null) && (kern_minor == null)) {
			vprint(_("No updates found"));
		}

	}

	public static void kinst_update(LinuxKernel k, bool confirm) {

		if (confirm) {

			var message = "\n" + _("Install Kernel Version %s ? (y/n): ").printf(k.version_main);
			vprint(message,0);

			int ch = stdin.getc();
			if (ch != 'y') return;
		}

		k.kinst();
	}

}
