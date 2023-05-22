
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;
using l.misc;

public class LinuxKernel : GLib.Object, Gee.Comparable<LinuxKernel> {

	public string kname = "";
	public string kver = "";
	public string version_main = "";
	public string version_package = "";
	public string page_uri = "";
	public string notes = "";

	public int version_major = -1;
	public int version_minor = -1;
	public int version_point = -1;
	public int version_rc = -1;

	public Gee.HashMap<string,string> deb_url_list = new Gee.HashMap<string,string>(); // assosciated .deb files K=filename,V=url
	public Gee.HashMap<string,string> deb_checksum_list = new Gee.HashMap<string,string>(); // assosciated .deb files K=filename,V=checksum
	public Gee.HashMap<string,string> pkg_list = new Gee.HashMap<string,string>(); // assosciated dpkg package names

	public static Gee.HashMap<string,Package> pkg_list_installed;

	public bool is_installed = false;
	public bool is_running = false;
	public bool is_mainline = false;
	public int ppa_dirs_ver = 0; // 0 = not set, 1 = old single dirs, 2 = new /<arch>/ subdirs
	public int64 ppa_datetime = -1; // timestamp from the main index

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
	public static string DATA_DIR;
	public static string MAIN_INDEX_HTML;

	public static LinuxKernel kernel_active;
	public static LinuxKernel kernel_update_major;
	public static LinuxKernel kernel_update_minor;
	public static LinuxKernel kernel_latest_available;
	public static LinuxKernel kernel_latest_installed;
	public static LinuxKernel kernel_oldest_installed;
	public static LinuxKernel kernel_last_stable_old_ppa_dirs;
	public static LinuxKernel kernel_last_unstable_old_ppa_dirs;

	public static Gee.ArrayList<LinuxKernel> kernel_list = new Gee.ArrayList<LinuxKernel>();

	public static Regex rex_header = null;
	public static Regex rex_header_all = null;
	public static Regex rex_image = null;
	public static Regex rex_image_extra = null;
	public static Regex rex_modules = null;

	// global progress  ------------
	public static string status_line = "";
	public static int progress_total = 0;
	public static int progress_count = 0;
	public static bool cancelled = false;
	public static int threshold_major = 0;

	// class initialize
	public static void initialize() {
		new LinuxKernel("", false); // instance must be created before setting static members

		LINUX_DISTRO = check_distribution();
		NATIVE_ARCH = check_package_architecture();
		RUNNING_KERNEL = check_running_kernel().replace("-generic","");
		MAIN_INDEX_HTML = CACHE_DIR+"/index.html";
		initialize_regex();

		// Special kernel versions where the mainline-ppa site changed their directory structure.
		// affects:
		// - ./foo.deb vs ./<arch>/foo.deb
		// - ./CHECKSUMS vs ./<arch>/CHECKSUMS
		// - ./BUILT vs ./<arch>/status
		kernel_last_stable_old_ppa_dirs = new LinuxKernel.from_version("5.6.17");
		kernel_last_unstable_old_ppa_dirs = new LinuxKernel.from_version("5.7-rc7");

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
		vprint(_("Running kernel") + ": %s".printf(ver));

		return ver;
	}

	public static void initialize_regex() {
		//log_debug("initialize_regex()");
		try {

			//linux-headers-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_header = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-[a-zA-Z0-9\.\-_]*-generic_[a-zA-Z0-9\.\-]*_""" + NATIVE_ARCH + ".deb");

			//linux-headers-3.4.75-030475_3.4.75-030475.201312201255_all.deb
			rex_header_all = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-[a-zA-Z0-9\.\-_]*_all.deb""");

			//linux-image-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_image = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-[a-zA-Z0-9\.\-_]*-generic_([a-zA-Z0-9\.\-]*)_""" + NATIVE_ARCH + ".deb");

			//linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_image_extra = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-extra-[a-zA-Z0-9\.\-_]*-generic_[a-zA-Z0-9\.\-]*_""" + NATIVE_ARCH + ".deb");

			//linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_modules = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-modules-[a-zA-Z0-9\.\-_]*-generic_[a-zA-Z0-9\.\-]*_""" + NATIVE_ARCH + ".deb");

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
		if (_name.has_suffix("/")) kname = _name[0: _name.length - 1];
		else kname = _name;

		// extract version numbers from the name
		kver = kname;
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

			// load the cached index before checking is_invalid
			// because we may discover that the cached invalid status is out of date
			if (k.cached_page_exists) {
				vprint(_("loading cached")+" "+k.version_main,3);
				if (k.load_cached_page()) continue;
			}

			if (k.is_invalid) continue;

			if (!k.is_installed) {
				if (k.version_major < threshold_major) continue;
				if (App.hide_unstable && k.is_unstable) continue;
			}

			// add index.html to download list
			vprint(_("queuing download")+" "+k.version_main,3);
			var item = new DownloadItem(k.cached_page_uri, file_parent(k.cached_page), file_basename(k.cached_page));
			downloads.add(item);

			// add kernel to update list
			kernels_to_update.add(k);

			if (notifier != null) notifier(timer, ref count);
		}

		// process the download list
		if (downloads.size>0 && App.ppa_up) {
			progress_total = downloads.size;
			var mgr = new DownloadTask();

			// add download list to queue
			foreach (var item in downloads) mgr.add_to_queue(item);

			// start downloading
			mgr.execute();

			vprint(_("Fetching individual kernel indexes")+"...");

			// while downloading
			while (mgr.is_running()) {
				progress_count = mgr.prg_count; // also used by the progress window in MainWindow.vala
				//pbar(mgr.prg_count,progress_total,"files");
				pbar(progress_count,progress_total);
				sleep(250);
				if (notifier != null) notifier(timer, ref count);
			}

			// done downloading
			pbar(0,0);

			// load the index.html files we just added to cache
			foreach (var k in kernels_to_update) {
				vprint(_("loading downloaded")+" "+k.version_main,3);
				k.load_cached_page();
			}

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
		if (!file_exists(MAIN_INDEX_HTML)) App.index_is_fresh=false;
		if (App.index_is_fresh) return true;

		dir_create(CACHE_DIR);

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

		if (file_exists(tfn)) {
			file_move(tfn,MAIN_INDEX_HTML);
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

		if (!file_exists(MAIN_INDEX_HTML)) return;
		string txt = file_read(MAIN_INDEX_HTML);
		kernel_list.clear();

		try {
// <tr><td valign="top"><img src="/icons/folder.gif" alt="[DIR]"></td><td><a href="v2.6.27.61/">v2.6.27.61/</a></td><td align="right">2018-05-13 20:40  </td><td align="right">  - </td><td>&nbsp;</td></tr>
			var rex = new Regex("""<a href="(v[a-zA-Z0-9\-._\/]+)">v([a-zA-Z0-9\-._]+)[\/]*<\/a>.*>([0-9]{4})-([0-9]{2})-([0-9]{2}) ([0-9]{2}):([0-9]{2}) *<""");
			// <a href="v3.1.8-precise/">v3.1.8-precise/</a>
			//          ###fetch(1)####   ##fetch(2)###

			MatchInfo match;

			foreach (string line in txt.split("\n")) {
				if (!rex.match(line, 0, out match)) continue;
				var k = new LinuxKernel(match.fetch(1), true);
				kernel_list.add(k);

				// "...<td align="right">2018-05-13 20:40  </td>..." -> 201805132040
				// kernel date/time from main index converted to int
				// used to detect kernel that changed after we cached it
				k.ppa_datetime = int64.parse(match.fetch(3)+match.fetch(4)+match.fetch(5)+match.fetch(6)+match.fetch(7));

				vprint("kernel_list.add("+k.kname+")",3);
			}

			kernel_list.sort((a,b) => { return a.compare_to(b) * -1; });

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
			vprint(_("Found installed")+" : "+pkg.version);
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
				if (k.is_invalid) continue;
				if (k.version_major<threshold_major) continue;
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
				pkern.is_mainline = false;
				if (file_exists(pkern.notes_file)) pkern.notes = file_read(pkern.notes_file);
				kernel_list.add(pkern);
			}
		}

		// mark the installed mainline kernels
		foreach (string pkg_version in pkg_versions) {
			foreach (var k in kernel_list) {
				if (k.is_invalid) continue;
				if (k.version_major<threshold_major) continue;
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
			if (k.is_invalid) continue;
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
				if (k.is_invalid) continue;
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
				if (kernel_latest_installed.version_major==0) kernel_latest_installed = k;
				kernel_oldest_installed = k;
			}
		}

//		vprint("latest_available: "+kernel_latest_available.version_main,2);
		vprint("latest_installed: "+kernel_latest_installed.version_main,2);
		vprint("oldest_installed: "+kernel_oldest_installed.version_main,2);
	}

	// scan kernel_list for versions newer than latest installed
	public static void check_updates() {
		vprint("check_updates()",2);
		kernel_update_major = null;
		kernel_update_minor = null;
		kernel_latest_available = kernel_latest_installed;

		bool major_available = false;
		bool minor_available = false;

		foreach(var k in LinuxKernel.kernel_list) {
			vprint(k.version_main,3);
			if (k.is_invalid) continue;
			if (k.is_installed) continue;
			if (k.is_unstable && App.hide_unstable) continue;
			if (k.version_major < threshold_major) break;
			if (k.compare_to(kernel_latest_installed)<=0) break;

			// kernel_list is sorted so first match is highest match
			if (k.version_major > kernel_latest_installed.version_major) major_available = true;
			else if (k.version_major == kernel_latest_installed.version_major) {
				if (k.version_minor > kernel_latest_installed.version_minor) major_available = true;
				else if (k.version_minor == kernel_latest_installed.version_minor) {
					if (k.version_point > kernel_latest_installed.version_point) minor_available = true;
					else if (k.version_point == kernel_latest_installed.version_point) {
						if (k.version_rc > kernel_latest_installed.version_rc) minor_available = true;
					}
				}
			}

			if (major_available && (kernel_update_major == null)) kernel_update_major = k;
			if (minor_available && (kernel_update_minor == null)) kernel_update_minor = k;

			// if we have everything possible, skip the rest
			if (kernel_update_major != null && kernel_update_minor != null) break;
		}

		if (kernel_update_minor != null) kernel_latest_available = kernel_update_minor;
		if (kernel_update_major != null) kernel_latest_available = kernel_update_major;

		if (kernel_update_minor != null) vprint("minor available: "+kernel_update_minor.version_main,2);
		if (kernel_update_major != null) vprint("major available: "+kernel_update_major.version_main,2);
		if (kernel_latest_available != kernel_latest_installed) vprint("latest available: "+kernel_latest_available.version_main,2);

	}

	// helpers

	public static void update_threshold_major() {
		vprint("update_threshold_major()",2);

		//Package.update_dpkg_list();

		if (App.previous_majors<0 || App.previous_majors>=kernel_latest_available.version_major) { threshold_major=0; return; }

		// start from the running kernel and work down
		kernel_oldest_installed = new LinuxKernel.from_version(RUNNING_KERNEL);

		foreach (var pkg in Package.dpkg_list) {
			if (!pkg.pname.has_prefix("linux-image-")) continue;
			var candidate = new LinuxKernel(pkg.version, false);
			if (candidate.version_major < kernel_oldest_installed.version_major) kernel_oldest_installed = candidate;
		}

		threshold_major = kernel_latest_available.version_major - App.previous_majors;
		if (kernel_oldest_installed.version_major < threshold_major) threshold_major = kernel_oldest_installed.version_major;
		vprint("threshold_major %d".printf(threshold_major),2);
	}

	public void split_version_string(string _version_string, out string ver_main) {
		ver_main = "";
		version_major = 0;
		version_minor = 0;
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
						version_major = int.parse(num);
						break;
					case 1:
						version_minor = int.parse(num);
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
			ver_main = "%d.%d.%d%s".printf(version_major,version_minor,version_point,version_extra);

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

		// the larger array is the lower version,
		// because 1.2.3-rcN comes before 1.2.3
		return (arr_a.length - arr_b.length) * -1;
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

	public void mark_invalid() {
			file_write(cached_status_file,"");
	}

	// properties

	public bool is_unstable {
		get {
			return kver.contains("-rc") || kver.contains("-unstable");
		}
	}

	public bool is_invalid {
		get {
			return file_exists(cached_status_file);
		}
	}

	public string status {
		get {
				return
					is_running ? _("Running") :
					is_installed ? _("Installed") :
					is_invalid ? _("Invalid") :
					"";
		}
	}

	public bool new_ppa_dirs {
		get {
			//    if stable   and newer than kernel_last_stable_old_ppa_dirs
			// or if unstable and newer than kernel_last_unstable_old_ppa_dirs
			if (ppa_dirs_ver==2) return true;
			if (ppa_dirs_ver==1) return false;
			int r = 0;
			if (is_unstable) r = compare_to(kernel_last_unstable_old_ppa_dirs);
			else r = compare_to(kernel_last_stable_old_ppa_dirs);
			if (r>0) { ppa_dirs_ver = 2; return true; }
			else { ppa_dirs_ver = 1; return false; }
		}
	}

	public string cache_subdir {
		owned get {
			return CACHE_DIR+"/"+version_main;
		}
	}

	public string data_subdir {
		owned get {
			return DATA_DIR+"/"+version_main;
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

	public string notes_file {
		owned get {
			return data_subdir+"/notes";
		}
	}

	public string cached_status_file {
		owned get {
			return cache_subdir+"/invalid";
		}
	}

	public string cached_checksums_file {
		owned get {
			return cache_subdir+"/CHECKSUMS";
		}
	}

	public string checksums_file_uri {
		owned get {
			if (new_ppa_dirs) return page_uri+NATIVE_ARCH+"/CHECKSUMS";
			return page_uri+"CHECKSUMS";
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
		foreach (string deb in deb_url_list.keys) list += "\n"+deb;

		if (list.length > 0) txt += "<b>"+_("Packages Available")+"</b>\n"+list;

		list = "";
		foreach (string deb in pkg_list.keys) list += "\n"+deb;

		if (txt.length > 0 && list.length > 0) txt += "\n\n";
		if (list.length > 0) txt += "<b>"+_("Packages Installed")+"</b>\n"+list;

		return txt;
	}

	// load

	// return false if we don't have the cached page or if it's out of date
	// return true if we have a valid cached page, whether the kernel itself is a valid build or not
	private bool load_cached_page() {
		vprint("load_cached_page(): '"+cached_page+"'",4);

		string txt = "";
		int64 d_this = 0;
		int64 d_max = 0;
		deb_image = "";
		deb_header = "";
		deb_header_all = "";
		deb_image_extra = "";
		deb_modules = "";
		version_package = "";
		deb_url_list.clear();
		notes = "";

		// load locally generated data regardless of the state of the cached index
		if (file_exists(notes_file)) notes = file_read(notes_file).strip();

		if (!file_exists(cached_page)) {
			vprint("load_cached_page(): " + _("File not found") + ": "+cached_page,1,stderr);
			return false;
		}

		// parse index.html --------------------------
		txt = file_read(cached_page);

		// find the highest datetime anywhere in the cached index
		//<tr><td valign="top"><img src="/icons/text.gif" alt="[TXT]"></td><td><a href="HEADER.html">HEADER.html</a></td><td align="right">2023-05-11 23:21  </td><td align="right">5.6K</td><td>&nbsp;</td></tr>
		//<tr><td valign="top"><img src="/icons/folder.gif" alt="[DIR]"></td><td><a href="amd64/">amd64/</a></td><td align="right">2023-05-11 22:30  </td><td align="right">  - </td><td>&nbsp;</td></tr>
		try {
			var rex = new Regex(""">([0-9]{4})-([0-9]{2})-([0-9]{2}) ([0-9]{2}):([0-9]{2}) *<""");
			MatchInfo match;
			foreach (string line in txt.split("\n")) {
				if (rex.match(line, 0, out match)) {
					d_this = int64.parse(match.fetch(1)+match.fetch(2)+match.fetch(3)+match.fetch(4)+match.fetch(5));
					if (d_this>d_max) d_max = d_this;
				}
			}
		} catch (Error e) {
			vprint(e.message,1,stderr);
		}

		// if datetime from main index is newer than the latest cached datetime,
		// delete the cached index and status, keep the notes, return false
		if (ppa_datetime>d_max) {
			file_delete(cached_page);
			file_delete(cached_status_file);
			file_delete(cached_checksums_file);
			return false;
		}

		// skip the rest of the work if we already know it's a failed build
		if (is_invalid) return true;

		// scan for urls to .deb files
		try {
			//<a href="linux-headers-4.6.0-040600rc1-generic_4.6.0-040600rc1.201603261930_amd64.deb">//same deb name//</a>
			var rex = new Regex("""<a href="([a-zA-Z0-9\-\._/]+\.deb)">([a-zA-Z0-9\-\._/]+\.deb)<\/a>""");
			MatchInfo match;

			foreach (string line in txt.split("\n")) {
				if (rex.match(line, 0, out match)) {

					string file_name = Path.get_basename (match.fetch(2));
					string file_uri = "%s%s".printf(page_uri, match.fetch(1));
					if (deb_url_list.has_key(file_name)) continue;

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

					if (add) deb_url_list[file_name] = file_uri;
				}
			}
		} catch (Error e) {
			vprint(e.message,1,stderr);
		}
		if (deb_image.length<1 || deb_url_list.size<1) mark_invalid();
		return true;
	}

	// actions

	public static void print_list() {
		vprint("----------------------------------------------------------------");
		vprint(_("Available Kernels"));
		vprint("----------------------------------------------------------------");

		int nl = 16; // name length
		foreach(var k in kernel_list) {
			if (k.is_invalid) continue;

			// hide hidden, but don't hide any installed
			if (!k.is_installed) {
				if (App.hide_unstable && k.is_unstable) continue;
				if (k.version_major < threshold_major) continue;
			}

			if (k.version_main.length>nl) nl = k.version_main.length;
			vprint("%-*s %-10s %s".printf(nl, k.version_main, k.status, k.notes));
		}
	}

	public static bool download_kernels(Gee.ArrayList<LinuxKernel> selected_kernels) {
		foreach (var k in selected_kernels) k.download_packages();
		return true;
	}

	// dep: aria2c
	public bool download_packages() {
		bool ok = true;
		int MB = 1024 * 1024;

		check_if_initialized();

		var mgr = new DownloadTask();

		// CHECKSUMS
		//fetch CHECKSUMS or <arch>/CHECKSUMS depending on version
		deb_checksum_list.clear();
		foreach (string f in deb_url_list.keys) deb_checksum_list[f] = "";
		if (App.verify_checksums) {
			vprint("CHECKSUMS "+_("enabled"),2);

			if (!file_exists(cached_checksums_file)) {
				mgr.add_to_queue(new DownloadItem(checksums_file_uri,cache_subdir,"CHECKSUMS"));
				mgr.execute();
				while (mgr.is_running()) sleep(250);
			}

			// extract the sha256 hashes and save in aria2c format
			// 52e8d02b2975920e7cc9a9d57843fcb8049addf53f1894073afce02d0e7351b2  linux-image-unsigned-6.2.9-060209-generic_6.2.9-060209.202303301133_amd64.deb
			// deb_checksum_list[filename]="sha-256=...hash..."
			// deb_checksum_list["linux-image-unsigned-6.2.9-060209-generic_6.2.9-060209.202303301133_amd64.deb"]="sha-256=52e8d02b2975920e7cc9a9d57843fcb8049addf53f1894073afce02d0e7351b2"
			// aria2c -h#checksum  ;aria2c -v |grep "^Hash Algorithms:"
			// FIXME assumption: if 1st word is 64 bytes then it is a sha256 hash
			// FIXME assumption: there will always be exactly 2 spaces between hash & filename
			foreach (string l in file_read(cached_checksums_file).split("\n")) {
				var w = l.split(" ");
				if (w.length==3 && w[0].length==64) deb_checksum_list[w[2]] = "sha-256="+w[0];
			}
		}

		mgr = new DownloadTask();
		foreach (string file_name in deb_url_list.keys) mgr.add_to_queue(new DownloadItem(deb_url_list[file_name],cache_subdir,file_name,deb_checksum_list[file_name]));

		vprint(_("Downloading")+" "+version_main);
		mgr.execute();

		string[] stat = {"","",""};
		while (mgr.is_running()) {
			stat = mgr.status_line.split_set(" /");
			if (stat[1]!=null && stat[2]!=null) pbar(int64.parse(stat[1])/MB,int64.parse(stat[2])/MB,"MB - file "+(mgr.prg_count+1).to_string()+"/"+deb_url_list.size.to_string());
			sleep(250);
		}
		pbar(0,0);

		foreach (string f in deb_url_list.keys) if (!file_exists(cache_subdir+"/"+f)) ok = false;

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
			foreach (string file_name in deb_url_list.keys) flist += " '"+cache_subdir+"/"+file_name+"'";
			string cmd = "pkexec env DISPLAY=${DISPLAY} XAUTHORITY=${XAUTHORITY} dpkg --install "+flist;
			status = Posix.system(cmd);
			ok = (status == 0);
			foreach (string file_name in deb_url_list.keys) file_delete(cache_subdir+"/"+file_name);

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
			if (k.is_invalid) continue;
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
