
using l.misc;
using l.exec;

public class LinuxKernel : GLib.Object, Gee.Comparable<LinuxKernel> {

	public string kname = "";
	public string kver = "";
	public string version_main = "";
	public string page_uri = "";
	public string notes = "";
	public string flavor = ""; // generic, generic-64k, lowlatency, etc

	public int version_major = -1;
	public int version_minor = -1;
	public int version_micro = -1;
	public int version_rc = -1;
	public string version_extra = "";
	public string version_sort = "";

	public string deb_image = "";
	public Gee.HashMap<string,string> deb_url_list = new Gee.HashMap<string,string>(); // assosciated .deb files K=filename,V=url
	public Gee.HashMap<string,string> deb_checksum_list = new Gee.HashMap<string,string>(); // assosciated .deb files K=filename,V=checksum
	public string[] pkg_list = {}; // assosciated dpkg package names

	public int PPA_DIRS_VER = 0; // 0 = not set, 1 = old single dirs, 2 = new /<arch>/ subdirs
	public string CACHE_KDIR;
	public string CACHED_PAGE;
	public string CHECKSUMS_FILE;
	public string CHECKSUMS_URI;
	public string INVALID_FILE;

	public string DATA_KDIR;
	public string NOTES_FILE;
	public string LOCKED_FILE;

	public bool is_invalid = false;
	public bool is_locked = false;
	public bool is_installed = false;
	public bool is_running = false;
	public bool is_mainline = true;
	public bool is_unstable = false;
	public int64 ppa_datetime = -1; // timestamp from the main index
	public string status = ""; // Running, Installed, Invalid, for display only

	// static
	public static string NATIVE_ARCH;
	public static string LINUX_DISTRO;
	public static string RUNNING_KERNEL;
	public static int THRESHOLD_MAJOR = -1;

	public static string MAIN_INDEX_FILE;

	public static LinuxKernel kernel_active;
	public static LinuxKernel kernel_update_major;
	public static LinuxKernel kernel_update_minor;
	public static LinuxKernel kernel_latest_available;
	public static LinuxKernel kernel_latest_installed;
	public static LinuxKernel kernel_oldest_installed;
	public static LinuxKernel kernel_last_stable_ppa_dirs_v1;
	public static LinuxKernel kernel_last_unstable_ppa_dirs_v1;
	//public static LinuxKernel kernel_last_stable_ppa_dirs_v2; // if the site changes again
	//public static LinuxKernel kernel_last_unstable_ppa_dirs_v2;

	public static Gee.ArrayList<LinuxKernel> kernel_list = new Gee.ArrayList<LinuxKernel>();
	public static Gee.ArrayList<LinuxKernel> kall = new Gee.ArrayList<LinuxKernel>();

	public static Regex rex_pageuri = null;
	public static Regex rex_datetime = null;
	public static Regex rex_fileuri = null;
	public static Regex rex_header = null;
	public static Regex rex_header_all = null;
	public static Regex rex_image = null;
	public static Regex rex_image_extra = null;
	public static Regex rex_modules = null;

	// constructor
	public LinuxKernel(string s="") {
		vprint("LinuxKernel("+s+")",4);

		split_version_string(s);

		// for cache dir, strip off "_flavor"
		CACHE_KDIR = Main.CACHE_DIR+"/"+version_main.split("_")[0];
		CACHED_PAGE = CACHE_KDIR+"/index.html";
		CHECKSUMS_FILE = CACHE_KDIR+"/CHECKSUMS";
		INVALID_FILE = CACHE_KDIR+"/invalid";

		// for data dir, do not strip off "_flavor"
		DATA_KDIR = Main.DATA_DIR+"/"+version_main;
		NOTES_FILE = DATA_KDIR+"/notes";
		LOCKED_FILE = DATA_KDIR+"/locked";
	}

	// wrap kernel_list.add(k) to avoid doing some work unless we're actually going to use it
	public void kernel_list_add() {
		PPA_DIRS_VER = ppa_dirs_ver();
		CHECKSUMS_URI = checksums_uri();
		if (exists(NOTES_FILE)) notes = fread(NOTES_FILE).strip();
		is_invalid = exists(INVALID_FILE);
		is_locked = exists(LOCKED_FILE);
		set_status();

		kernel_list.add(this);
	}

	// class initialize
	public static void initialize() {
		new LinuxKernel(); // instance must be created before setting static members

		MAIN_INDEX_FILE = Main.CACHE_DIR+"/index.html";

		LINUX_DISTRO = check_distribution();
		NATIVE_ARCH = check_package_architecture();
		RUNNING_KERNEL = check_running_kernel();
		initialize_regex();

		kernel_active = new LinuxKernel(RUNNING_KERNEL);
		kernel_latest_installed = kernel_active;
		kernel_oldest_installed = kernel_active;
		kernel_latest_available = kernel_active;
		kernel_update_major = kernel_active;
		kernel_update_minor = kernel_active;

		// Special threshold kernel versions where the mainline-ppa site changed their directory structure.
		// ppa_dirs_ver=1       ppa_dirs_ver=2
		// ./foo.deb       vs   ./<arch>/foo.deb
		// ./CHECKSUMS     vs   ./<arch>/CHECKSUMS
		// ./BUILT         vs   ./<arch>/status
		kernel_last_stable_ppa_dirs_v1 = new LinuxKernel("5.6.17");
		kernel_last_unstable_ppa_dirs_v1 = new LinuxKernel("5.7-rc7");
		//kernel_last_stable_ppa_dirs_v2 = new LinuxKernel("x.y.z"); // if the site changes again
		//kernel_last_unstable_ppa_dirs_v2 = new LinuxKernel("x.y-rcZ");

	}

	// dep: lsb_release
	public static string check_distribution() {
		vprint("check_distribution()",2);
		string dist = "";

		string std_out, std_err;
		int e = exec_sync("lsb_release -sd", out std_out, out std_err);
		if ((e == 0) && (std_out != null)) {
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
		int e = exec_sync("dpkg --print-architecture", out std_out, out std_err);
		if ((e == 0) && (std_out != null)) {
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
		try {

			// uri to a kernel page and it's datetime, in the main index.html
			// <tr><td valign="top"><img src="/icons/folder.gif" alt="[DIR]"></td><td><a href="v2.6.27.61/">v2.6.27.61/</a></td><td align="right">2018-05-13 20:40  </td><td align="right">  - </td><td>&nbsp;</td></tr>
			//                                                                                 ###########                                        #### ## ## ## ##
			//                                                                                 fetch(1)                                           2    3  4  5  6
			rex_pageuri     = new Regex("""href="(v.+/)".+>[\t ]*([0-9]{4})-([0-9]{2})-([0-9]{2})[\t ]+([0-9]{2}):([0-9]{2})[\t ]*<""");

			// date & time for any uri in a per-kernel page
			// <tr><td valign="top"><img src="/icons/text.gif" alt="[TXT]"></td><td><a href="HEADER.html">HEADER.html</a></td><td align="right">2023-05-11 23:21  </td><td align="right">5.6K</td><td>&nbsp;</td></tr>
			// <tr><td valign="top"><img src="/icons/folder.gif" alt="[DIR]"></td><td><a href="amd64/">amd64/</a></td><td align="right">2023-05-11 22:30  </td><td align="right">  - </td><td>&nbsp;</td></tr>
			//                                                                                                                          #### ## ## ## ##
			//                                                                                                                          1    2  3  4  5
			rex_datetime    = new Regex(""">[\t ]*([0-9]{4})-([0-9]{2})-([0-9]{2})[\t ]+([0-9]{2}):([0-9]{2})[\t ]*<""");

			// uri to any .deb file in a per-kernel page
			// <a href="linux-headers-4.6.0-040600rc1-generic_4.6.0-040600rc1.201603261930_amd64.deb">//same deb name//</a>
			//          ############################################################################
			rex_fileuri     = new Regex("""href="(.+\.deb)"""");

			// linux-image-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			//                           ###1###
			rex_image       = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-.+-(.+)_.+_"""       + NATIVE_ARCH + ".deb");

			// linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			//                                 ###1###
			rex_image_extra = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-extra-.+-(.+)_.+_""" + NATIVE_ARCH + ".deb");

			// linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			//                                 ###1###
			rex_modules     = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-modules-.+-(.+)_.+_"""     + NATIVE_ARCH + ".deb");

			// linux-headers-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			//                             ###1###
			rex_header      = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-.+-(.+)_.+_"""     + NATIVE_ARCH + ".deb");

			// linux-headers-3.4.75-030475_3.4.75-030475.201312201255_all.deb
			rex_header_all  = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-.+_all.deb""");

		} catch (Error e) {
			vprint(e.message,1,stderr);
		}
	}

	static void trim_cache() {
		foreach (var k in kall) {
			if (k.is_installed) continue;
			// don't remove anything >= threshold_major even if hidden
			if (k.version_major<THRESHOLD_MAJOR && File.parse_name(k.CACHE_KDIR).query_exists()) rm(k.CACHE_KDIR);
		}
	}

	public static void delete_cache() {
		vprint("delete_cache()",2);
		kernel_list.clear();
		kall.clear();
		rm(Main.CACHE_DIR);
	}

	public void set_invalid(bool b) {
		if (b) fwrite(INVALID_FILE,"");
		else rm(INVALID_FILE);
		is_invalid = b;
	}

	public void set_locked(bool b) {
		if (b) fwrite(LOCKED_FILE,"");
		else rm(LOCKED_FILE);
		is_locked = b;
	}

	public void set_notes(string s="") {
		if (s.length>0) fwrite(NOTES_FILE,s);
		else rm(NOTES_FILE);
		notes = s;
	}

	public void set_status() {
		status =
			is_running ? _("Running") :
			is_installed ? _("Installed") :
			is_invalid ? _("Invalid") :
			"";
	}

	public delegate void Notifier(bool last = false);

	public static void mk_kernel_list(bool wait = true, owned Notifier? notifier = null) {
		vprint("mk_kernel_list()",2);
		try {
			var worker = new Thread<bool>.try(null, () => mk_kernel_list_worker((owned)notifier) );
			if (wait) worker.join();
		} catch (Error e) { vprint(e.message,1,stderr); }
	}

	static bool mk_kernel_list_worker(owned Notifier? notifier) {
		vprint("mk_kernel_list_worker()",2);

		kernel_list.clear();
		App.progress_total = 0;
		App.progress_count = 0;
		App.cancelled = false;

		// find the oldest major version to include
		find_thresholds(true);

		// ===== download the main index.html listing all kernels =====
		download_main_index(); // download the main index.html
		load_main_index();  // scrape the main index.html to make the initial kernel_list

		// ===== download the per-kernel index.html and CHANGES =====

		// list of kernels - one LinuxKernel object per kernel to update
		var kernels_to_update = new Gee.ArrayList<LinuxKernel>();
		// list of files - one DownloadItem object per individual file to download
		var downloads = new Gee.ArrayList<DownloadItem>();

		// add files to download list
		foreach (var k in kernel_list) {
			if (App.cancelled) break;

			// skip some kernels for various reasons

			// don't try to skip this kernel by looking at is_invalid yet.
			// is_invalid is cached and might be obsolete

			// try to load cached info for this kernel
			if (k.load_cached_page()) continue;

			// now we can consider is_invalid
			// an invalid kernel might be installed, but that would have to
			// be a distro kernel or self-compiled, not a mainline-ppa one,
			// so it's ok to filter out an invalid mainline-ppa one here
			if (k.is_invalid && App.hide_invalid) continue;

			// there may be installed rc kernels even if rc are currently disabled
			// so don't try to filter out rc kernels yet

			// we have either not found a cached page,
			// or found it to be out of date and deleted it,
			// and have not skipped this kernel due to is_invalid

			// add index.html to download list
			vprint(_("queuing download")+" "+k.version_main,3);
			downloads.add(new DownloadItem(k.page_uri,Path.get_dirname(k.CACHED_PAGE),Path.get_basename(k.CACHED_PAGE)));

			// add kernel to update list
			kernels_to_update.add(k);

			if (notifier != null) notifier();
		}

		// process the download list
		if (downloads.size>0 && App.ppa_up) {

			// download the indexes
			vprint(_("Fetching individual kernel indexes")+"...");
			App.progress_total = downloads.size;
			var mgr = new DownloadTask();
			foreach (var item in downloads) mgr.add_to_queue(item);
			mgr.execute();
			while (mgr.is_running) {
				App.progress_count = mgr.prg_count;
				pbar(App.progress_count,App.progress_total);
				Thread.usleep(250000);
				if (notifier != null) notifier();
			}
			pbar(0,0);

			// load the indexes
			foreach (var k in kernels_to_update) {
				k.load_cached_page();
				k.set_status();
			}
			if (notifier != null) notifier();

		}

		check_installed();
		trim_cache();
		check_updates();

		// This is here because it had to be delayed from whenever settings
		// changed until now, so that the notify script instance of ourself
		// doesn't do it's own mk_kernel_list() at the same time while we still are.
		App.run_notify_script_if_due();

		if (notifier != null) notifier(true);
		return true;
	}

	// download the main index.html listing all mainline kernels
	static bool download_main_index() {
		vprint("download_main_index()",2);

		if (!exists(MAIN_INDEX_FILE)) App.index_is_fresh=false;
		if (App.index_is_fresh) return true;
		if (!App.try_ppa()) return false;

		mkdir(Main.CACHE_DIR);

		// preserve the old index in case the dl fails
		string tbn = "%8.8X".printf(Main.rnd.next_int());
		string tfn = Main.CACHE_DIR+"/"+tbn;
		vprint("+ DownloadItem("+App.ppa_uri+","+Main.CACHE_DIR+","+tbn+")",4);
		var item = new DownloadItem(App.ppa_uri, Main.CACHE_DIR, tbn);
		var mgr = new DownloadTask();
		mgr.add_to_queue(item);

		vprint(_("Updating from")+": '"+App.ppa_uri+"'");
		mgr.execute();
		while (mgr.is_running) Thread.usleep(250000);

		if (exists(tfn)) {
			FileUtils.rename(tfn,MAIN_INDEX_FILE);
			App.index_is_fresh=true;
			vprint(_("OK"),2);
			return true;
		} else {
			vprint(_("FAILED"),1,stderr);
			return false;
		}
	}

	// read the main index.html listing all kernels
	static void load_main_index() {
		vprint("load_main_index()",2);
		if (THRESHOLD_MAJOR<0) find_thresholds(true);
		if (THRESHOLD_MAJOR<0) { vprint("load_index(): THRESHOLD_MAJOR not initialized"); exit(1); }

		if (!exists(MAIN_INDEX_FILE)) return;
		string txt = fread(MAIN_INDEX_FILE);
		kernel_list.clear();
		kall.clear();

		MatchInfo mi;
		foreach (string l in txt.split("\n")) {
			if (!rex_pageuri.match(l, 0, out mi)) continue;
			var v = mi.fetch(1);
			var k = new LinuxKernel(v);

			// Don't try to exclude unstable here, just k.version_major<THRESHOLD_MAJOR.
			// They all need to exist in kernel_list at least long enough for check_installed()
			// to recognize any already-installed even if they would otherwise be hidden.

			k.page_uri = App.ppa_uri + v;
			k.is_mainline = true;
			if (k.version_major>=THRESHOLD_MAJOR) {
				k.ppa_datetime = int64.parse(mi.fetch(2)+mi.fetch(3)+mi.fetch(4)+mi.fetch(5)+mi.fetch(6));
				vprint("kernel_list.add("+k.version_main+") "+k.ppa_datetime.to_string(),2);
				k.kernel_list_add(); // the active list
			}
			kall.add(k); // a seperate list with nothing removed, used in trim_cache()
		}

		// sort the list, highest first
		kernel_list.sort((a,b) => { return b.compare_to(a); });

	}

	public static void check_installed() {
		vprint("check_installed()",2);

		string msg = "";

		if (Package.dpkg_list.size<1) vprint("!!! dpkg_list empty!");
		if (kernel_list.size<1) vprint("!!! kernel_list empty!");

		foreach (var p in Package.dpkg_list) {
			if (!p.pname.has_prefix("linux-image-")) continue;

			// temp kernel object for current pkg
			var pk = new LinuxKernel(p.version);
			pk.kname = p.pname;
			pk.is_installed = true;
			pk.set_pkg_list(); // find assosciated packages

			// search the mainline list for matching package name
			// fill k.pkg_list list of associated pkgs
			bool found = false;
			foreach (var k in kernel_list) {
				if (k.is_invalid) continue;
				if (k.kname==pk.kname) {
					if (!pk.kname.has_suffix("-"+k.flavor)) continue;
					found = true;
					k.pkg_list = pk.pkg_list;
					k.is_installed = true;
					break;
				}
			}

			// installed package was not found in the mainline list
			// add to kernel_list as a distro kernel
			if (!found) {
				pk.is_mainline = false;
				vprint("kernel_list.add("+pk.version_main+" "+pk.kname+" "+pk.kver+")",2);
				pk.kernel_list_add();
			}
		}

		// finding the running kernel reliably is hard
		// https://github.com/bkw777/mainline/issues/91
		// RUNNING_KERNEL = uname -r      =                      6.3.4-060304-generic
		// kname          = dpkg pkg name = linux-image-unsigned-6.3.4-060304-generic

		// kernel_list contains both mainline and installed distro kernels now
		// find the running kernel
		foreach (var k in kernel_list) {
			if (k.kname.has_suffix(RUNNING_KERNEL)) {
				k.is_running = true;
				kernel_active = k;
				break;
			}
		}

		// sort, reverse
		kernel_list.sort((a,b) => { return b.compare_to(a); });

		// find the highest & lowest installed versions
		kernel_latest_installed = new LinuxKernel();
		kernel_oldest_installed = kernel_latest_installed;
		foreach(var k in kernel_list) {
			if (k.is_installed) {
				k.set_status();
				if (kernel_latest_installed.version_major==0) kernel_latest_installed = k;
				kernel_oldest_installed = k;
				msg = _("Found installed")+": "+k.kname;
				if (k.is_locked) msg += " (" + _("locked") +")";
				if (k.is_running) msg += " (" + _("running") +")";
				vprint(msg);
			}
		}

		vprint("oldest_installed: "+kernel_oldest_installed.version_main,2);
		vprint("latest_installed: "+kernel_latest_installed.version_main,2);
//		vprint("latest_available: "+kernel_latest_available.version_main,2);
	}

	// scan kernel_list for versions newer than latest installed
	public static void check_updates() {
		vprint("check_updates()",2);
		kernel_update_major = null;
		kernel_update_minor = null;
		kernel_latest_available = kernel_latest_installed;

		bool major_available = false;
		bool minor_available = false;

		foreach(var k in kernel_list) {
			vprint(k.version_main,3);
			if (k.is_invalid) continue;
			if (k.is_installed) continue;
			if (k.is_locked) { vprint(k.version_main+" "+_("is locked."),2); continue; }
			if (k.is_unstable && App.hide_unstable) continue;
			if (k.version_major < THRESHOLD_MAJOR) break;
			if (k.compare_to(kernel_latest_installed)<1) break;

			// kernel_list is sorted so first match is highest match
			if (k.version_major > kernel_latest_installed.version_major) major_available = true;
			else if (k.version_major == kernel_latest_installed.version_major) {
				if (k.version_minor > kernel_latest_installed.version_minor) major_available = true;
				else if (k.version_minor == kernel_latest_installed.version_minor) {
					if (k.version_micro > kernel_latest_installed.version_micro) minor_available = true;
					else if (k.version_micro == kernel_latest_installed.version_micro) {
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

		if (kernel_update_minor != null) vprint(_("minor available")+": "+kernel_update_minor.version_main,2);
		if (kernel_update_major != null) vprint(_("major available")+": "+kernel_update_major.version_main,2);
		if (kernel_latest_available != kernel_latest_installed) vprint(_("latest available")+": "+kernel_latest_available.version_main,2);

	}

	// There is a circular dependency here.
	// (1) Ideally we want to know THRESHOLD_MAJOR before running mk_kernel_list(),
	//     so mk_kernel_list() can use it to set bounds on the size of it's job,
	//     instead of processing all kernels since the beginning of time, every time.
	// (2) Ideally we want to use is_mainline while finding THRESHOLD_MAJOR,
	//     to prevent non-mainline kernels from pulling THRESHOLD_MAJOR down.
	// (3) The only way to find out is_mainline for real is to scan kernel_list[],
	//     and see if a given installed package matches one of those.
	// (4) But we don't have kernel_list[] yet, and we can't get it yet, because GOTO (1)
	// 
	// So for this early task, we rely on a weak is_mainline assertion that was made
	// from an unsafe assumption in split_version_string(), when mk_dpkg_list()
	// generates some kernel objects from the installed package info from dpkg.
	// The version field from dpkg for mainline kernels includes a 12-byte
	// date/time stamp that distro packages don't have.
	//
	// TODO maybe...
	// Get a full kernel_list from a preliminary pass with load_index() before runing mk_dpkg_list().
	// Have mk_dpkg_list() use that to fill in a real actual is_mainline for each item in dpkg_list[].
	// Use that here, and along the way delete the unwanted items from kernel_list[].
	// Then mk_kernel_list() can just process that kernel_list[].
	// 
	static void find_thresholds(bool up=false) {
		vprint("find_thresholds()",2);

		if (up || Package.dpkg_list.size<1) Package.mk_dpkg_list();

		if (App.previous_majors<0 || App.previous_majors>=kernel_latest_available.version_major) { THRESHOLD_MAJOR = 0; return; }

		// start from the latest available and work down, ignore distro kernels
		kernel_oldest_installed = kernel_latest_installed;
		foreach (var p in Package.dpkg_list) {
			if (!p.pname.has_prefix("linux-image-")) continue;
			var k = new LinuxKernel(p.version);
			if (k.version_major < kernel_oldest_installed.version_major && k.is_mainline) kernel_oldest_installed = k;
		}

		// threshold is whichever is lower: latest_available - show_N_previous_majors, or oldest installed mainline.
		THRESHOLD_MAJOR = kernel_latest_available.version_major - App.previous_majors;
		if (kernel_oldest_installed.is_mainline && kernel_oldest_installed.version_major < THRESHOLD_MAJOR) THRESHOLD_MAJOR = kernel_oldest_installed.version_major;
	}

	// two main forms of input string:
	//
	// directory name & display version from the mainline-ppa web site
	// with or without leading "v" and/or trailing "/"
	//    v4.4-rc2+cod1/
	//    v4.2-rc1-unstable/
	//    v4.4.10-xenial/
	//    v4.6-rc2-wily/
	//    v4.2.8-ckt7-wily/
	//    v2.6.27.62/
	//    v4.19.285/
	//    v5.12-rc1-dontuse/
	//    v6.0/         trailing .0 but only one (not "6", nor "6.0.0")
	//    v6.0-rc5/
	//    v6.1/         no trailing .0 (not 6.1.0)
	//    v6.1-rc8/
	//    v6.1.9/
	//
	// version field from dpkg from installed packages
	//    5.19.0-42.43                  distro package
	//    6.3.6-060306.202306050836     mainline package
	//    4.6.0-040600rc1.201603261930  sigh, rc without a delimiter...

	void split_version_string(string s="") {
		//vprint("\n-new-: "+s);
		version_major = 0;
		version_minor = 0;
		version_micro = 0;
		version_rc = 0;
		version_extra = "";
		is_mainline = true;
		is_unstable = false;

		string t = s.strip();
		if (t.has_prefix("v")) t = t[1: t.length - 1];
		if (t.has_suffix("/")) t = t[0: t.length - 1];

		if (t==null || t=="") t = "0";
		version_main = t;
		kver = t;

		//vprint("\n"+t);

		var chunks = t.split_set(".-+_~ ");
		int i = 0, n = 0;
		foreach (string chunk in chunks) {
			++i;
			if (chunk.length<1) continue;
			if (chunk.has_prefix("rc")) { version_rc = int.parse(chunk.substring(2)); continue; }
			n = int.parse(chunk);
			if (n>0 || chunk=="0") switch (i) {  // weakness, would still fail on "00"  or "000" etc
				case 1: version_major = n; continue;
				case 2: version_minor = n; continue;
				case 3: version_micro = n; continue;
			}
			if (i>=chunks.length) {
				if (chunk.length==12) continue;
				is_mainline = false;
			} else if (i==chunks.length-1) {
				if (chunk.contains("rc")) { var x = chunk.split("c"); version_rc = int.parse(x[x.length-1]); continue; }
				if (version_micro<100 && chunk.has_prefix("%02d%02d%02d".printf(version_major,version_minor,version_micro))) continue;
				else if (chunk.has_prefix("%02d%02d%d".printf(version_major,version_minor,version_micro))) continue;
			}
			version_extra += "."+chunk;
		}
		version_sort = "%d.%d.%d".printf(version_major,version_minor,version_micro);
		if (version_rc>0) version_sort += ".rc"+version_rc.to_string();
		version_sort += version_extra;

		if (version_rc>0 || version_extra.contains("unstable")) is_unstable = true;
		//vprint("major: %d\nminor: %d\nmicro: %d\nrc   : %d\nextra: %s\nunstable: %s\nsort :%s".printf(version_major,version_minor,version_micro,version_rc,version_extra,is_unstable.to_string(),version_sort));
		//vprint(version_sort);
	}

// complicated comparison logic for kernel version strings
// * individual fields tested numerically if possible
//   so that 1.12.0 is higher than 1.2.0
// * 1.2.3-rc5 is higher than 1.2.3-rc4    normal
//   1.2.3 is higher than 1.2.3-rc5        special
// like strcmp(l,r), but l & r are LinuxKernel objects
// l.compare_to(r)   name & interface to please Gee.Comparable
//  l<r  return -1
//  l==r return 0
//  l>r  return 1
	public int compare_to(LinuxKernel t) {
		vprint(version_main+" compare_to() "+t.version_main,4);
		// TODO version_sort is a transitional hack to keep doing the old way of
		// parsing version_main, since version_main has a different format now.
		// The better way will be to just examine the individual variables
		// which we already did the work of parsing in split_version_string()
		var a = version_sort.split(".");
		var b = t.version_sort.split(".");
		int x, y, i = -1;
		while (++i<a.length && i<b.length) {            // while both strings have chunks
			if (a[i] == b[i]) continue;                 // both the same, next chunk
			x = int.parse(a[i]); y = int.parse(b[i]);   // parse strings to ints
			if (x>0 && y>0) return (x - y);             // both numerical >0, numerical compare
			if (x==0 && y==0) return strcmp(a[i],b[i]); // neither numerical >0 (alpha or maybe 0), lexical compare
			if (x>0) return 1;                          // only left is numerical>0, left is greater
			return -1;                                  // only right is numerical>0, right is greater
		}
		if (i<a.length) { if (int.parse(a[i])>0) return 1; return -1; } // only if left is longer: if left is numerical>0, left is greater else right is greater
		if (i<b.length) { if (int.parse(b[i])>0) return -1; return 1; } // only if right is longer: if right is numerical>0, right is greater else left is greater
		return 0;                                       // left & right identical the whole way
	}

	void set_pkg_list() {
		vprint("set_pkg_list("+kver+")",2);
		foreach(var p in Package.dpkg_list) {
			if (p.version == kver) {
				var l = pkg_list;
				l += p.pname;
				pkg_list = l;
				vprint("  p: "+p.pname,2);
			}
		}
	}

	int ppa_dirs_ver() {
		int v = 1;
		var k = kernel_last_stable_ppa_dirs_v1;                // Which threshold,
		if (is_unstable) k = kernel_last_unstable_ppa_dirs_v1; // stable or unstable?
		if (compare_to(k)>0) v = 2;                 // Do we exceed it?
		// in the future if the ppa site changes again,
		// add more copies of these 3 lines
		//k = kernel_last_stable_ppa_dirs_v2;
		//if (is_unstable) k = kernel_last_unstable_ppa_dirs_v2;
		//if (compare_to(k)>0) v = 3;
		return v;
	}

	string checksums_uri() {
		switch (PPA_DIRS_VER) {
			case 1: return page_uri+"CHECKSUMS";
			//case 2: return page_uri+NATIVE_ARCH+"/CHECKSUMS";
			default: return page_uri+NATIVE_ARCH+"/CHECKSUMS";
		}
	}

	public string tooltip_text() {
		string txt = "";

		// available packages
		string list = "";
		foreach (var x in deb_url_list.keys) list += "\n"+x;
		if (list.length > 0) txt += "<b>"+_("Packages Available")+"</b>"+list;

		// installed packages
		list = "";
		foreach (var x in pkg_list) list += "\n"+x;
		if (list.length > 0) {
			if (txt.length > 0) txt += "\n\n";
			txt += "<b>"+_("Packages Installed")+"</b>"+list;
		}

		// user notes
		if (notes.length > 0) {
			if (txt.length > 0) txt += "\n\n";
			txt += "<b>"+_("Notes")+"</b>\n"+notes;
		}

		// other
		if (is_locked) {
			if (txt.length > 0) txt += "\n\n";
			txt += "<b>"+_("Locked")+"</b>\n";
			if (is_installed) txt += _("removal"); else txt += _("installation");
			txt += " " + _("prevented");
		}

		return txt;
	}

	// return false if we don't have the cached page
	//   or if it's older than its timestamp in the main index.html
	// return true if we have a valid cached page,
	//   whether the kernel itself is a valid build or not
	bool load_cached_page() {
		vprint("load_cached_page("+CACHED_PAGE+")",2);
		if (!exists(CACHED_PAGE)) { vprint(_("not found"),3); return false; }

		string txt = "";
		int64 d_this = 0;
		int64 d_max = 0;
		MatchInfo mi;
		deb_image = "";
		deb_url_list.clear();
		var _url_list = new Gee.HashMap<string,string>(); // local temp deb_url_list
		var _flavors = new Gee.HashMap<string,string>(); // flavors[flavor]=kname
		string? _flavor;
		string? _kname;
		string? _kver;

		// read cached page
		txt = fread(CACHED_PAGE);

		// detect and delete out-of-date cache

		// find the latest timestamp anywhere in the cached page
		foreach (string l in txt.split("\n")) {
			if (rex_datetime.match(l, 0, out mi)) {
				d_this = int64.parse(mi.fetch(1)+mi.fetch(2)+mi.fetch(3)+mi.fetch(4)+mi.fetch(5));
				if (d_this>d_max) d_max = d_this;
			}
		}

		// if this kernel's timestamp from the main index is later than the latest in this
		// kernel's cached page, then delete the cache for this kernel and return false.
		if (ppa_datetime>d_max) {
			vprint(version_main+": ppa:"+ppa_datetime.to_string()+" > cache:"+d_max.to_string()+" : "+_("needs update"),2);
			rm(CACHE_KDIR);
			return false;
		}

		// skip the rest of the work if we already know it's a failed build
		if (is_invalid) return true;

		// scan for urls to .deb files
		foreach (string l in txt.split("\n")) {
			if (!rex_fileuri.match(l, 0, out mi)) continue;
			string file_uri = page_uri + mi.fetch(1);
			string file_name = Path.get_basename(file_uri);
			if (_url_list.has_key(file_name)) continue;

			_kname = null;
			_kver = null;
			_flavor = null;
			if (rex_image.match(file_name, 0, out mi)) {
				// use linux-image-*.deb to define valid kernels and flavors
				// besides just the file itself

				// TODO FIXME
				// some kernels have multiple builds
				// amd64/linux-image-unsigned-5.16.0-051600-generic_5.16.0-051600.202201091830_amd64.deb
				// amd64/linux-image-unsigned-5.16.0-051600-generic_5.16.0-051600.202201092355_amd64.deb
				// We are not handling that at all. We end up creating a single LinuxKernel
				// for "5.16" whith a deb_url_list that has two full sets of files

				//  linux-image-4.6.0-040600rc1-generic_4.6.0-040600rc1.201603261930_amd64.deb
				// |                           |flavor-|                            |
				// |---------------kname---------------|------------kver------------|
				//
				//  linux-image-unsigned-6.4.3-060403-generic-64k_6.4.3-060403.202307110536_arm64.deb
				// |                                 |--flavor---|                         |
				// |--------------------kname--------------------|----------kver-----------|
				var x = file_name.split("_");
				_kname = x[0];
				_kver = x[1];
				_flavor = mi.fetch(1);
				if (_flavor=="generic") {
					deb_image = file_name;
					kname = _kname;
					kver = _kver;
				}
				if (_flavor!=null) _flavors[_flavor] = _kname;

			} else if (rex_image_extra.match(file_name, 0, out mi)) {
			} else if (rex_modules.match(file_name, 0, out mi)) {
			} else if (rex_header.match(file_name, 0, out mi)) {
			} else if (rex_header_all.match(file_name, 0, out mi)) {
			} else file_name = "";

			// if we matched a file of any kind, add it to the url list
			if (file_name.length>0) _url_list[file_name] = file_uri;

		}

		// minimum requirement is linux-image*.deb
		if (deb_image.length<1) set_invalid(true);

		// create a new LinuxKernel for each detected flavor
		if (_flavors.size<1) _flavors[""] = kname; // non-mainline
		foreach (var flv in _flavors.keys) {
			LinuxKernel k;
			if (flv.length>0 && flv!="generic") {
				k = new LinuxKernel(version_main+"_"+flv);
				k.is_mainline = is_mainline;
				k.page_uri = page_uri;
				k.kname = _flavors[flv];
			} else {
				k = this;
			}
			k.flavor = flv;
			k.deb_url_list.clear();
			foreach (var f in _url_list.keys) {
				var da = f.split("_");
				if (da[0].has_suffix("-"+flv) || f.has_suffix("_all.deb")) k.deb_url_list[f] = _url_list[f];
			}
			if (k != this) k.kernel_list_add();
		}

		return true;
	}

	// actions

	public static void print_list() {
		vprint("----------------------------------------------------------------");
		vprint(_("Available Kernels"));
		vprint("----------------------------------------------------------------");

		int nl = 16; // name length
		foreach(var k in kernel_list) {
			if (k.is_invalid && App.hide_invalid) continue;

			// hide hidden, but don't hide any installed
			if (!k.is_installed) {
				if (App.hide_unstable && k.is_unstable) continue;
				if (App.hide_flavors && k.flavor!="generic") continue;
				if (k.version_major < THRESHOLD_MAJOR) continue;
			}

			string lck = "  ";
			if (k.is_locked) lck = "🔒";

			if (k.version_main.length>nl) nl = k.version_main.length;
			vprint("%-*s %s %-10s %s".printf(nl, k.version_main, lck, k.status, k.notes));
		}
	}

	public static Gee.ArrayList<LinuxKernel> vlist_to_klist(string list="",bool update_kernel_list=false) {
		vprint("vlist_to_klist("+list+")",3);
		var klist = new Gee.ArrayList<LinuxKernel>();
		var vlist = list.split_set(",;:| ");
		int i=vlist.length;
		foreach (var v in vlist) if (v.strip()=="") i-- ;
		if (i<1) return klist;
		if (update_kernel_list || kernel_list.size<1) mk_kernel_list(true);
		bool e = false;
		foreach (var v in vlist) {
			e = false;
			if (v.strip()=="") continue;
			foreach (var k in kernel_list) if (k.version_main==v) { e = true; klist.add(k); break; }
			if (!e) vprint(_("Kernel")+" \""+v+"\" "+_("not found"));
		}
		return klist;
	}

	// dep: aria2c
	public bool download_packages() {
		vprint("download_packages("+version_main+")",2);
		bool r = true;
		int MB = 1024 * 1024;
		string[] flist = {};

		foreach (var f in deb_url_list.keys) if (!App.keep_downloads || !exists(CACHE_KDIR+"/"+f)) flist += f;

		// CHECKSUMS
		if (flist.length>0) {
			deb_checksum_list.clear();
			if (App.verify_checksums) {
				vprint(_("checksums enabled"),2);

				// download the CHECKSUMS file
				if (!exists(CHECKSUMS_FILE)) {
					var dt = new DownloadTask();
					dt.add_to_queue(new DownloadItem(CHECKSUMS_URI,Path.get_dirname(CHECKSUMS_FILE),Path.get_basename(CHECKSUMS_FILE)));
					dt.execute();
					while (dt.is_running) Thread.usleep(100000);
				}
				if (!exists(CHECKSUMS_FILE)) return false;

				// parse the CHECKSUMS file
				// extract the sha256 hashes and save in aria2c format
				// 52e8d02b2975920e7cc9a9d57843fcb8049addf53f1894073afce02d0e7351b2  linux-image-unsigned-6.2.9-060209-generic_6.2.9-060209.202303301133_amd64.deb
				// deb_checksum_list[filename]="sha-256=hash"
				// deb_checksum_list["linux-image-unsigned-6.2.9-060209-generic_6.2.9-060209.202303301133_amd64.deb"]="sha-256=52e8d02b2975920e7cc9a9d57843fcb8049addf53f1894073afce02d0e7351b2"
				// aria2c -h#checksum  ;aria2c -v |grep "^Hash Algorithms:"
				// FIXME assumption: if 1st word is 64 bytes then it is a sha256 hash
				// FIXME assumption: there will always be exactly 2 spaces between hash & filename
				foreach (string l in fread(CHECKSUMS_FILE).split("\n")) {
					var w = l.split(" ");
					if (w.length==3 && w[0].length==64) deb_checksum_list[w[2]] = "sha-256="+w[0];
				}
			}

			var dt = new DownloadTask();
			foreach (var f in flist) dt.add_to_queue(new DownloadItem(deb_url_list[f],CACHE_KDIR,f,deb_checksum_list[f]));
			vprint(_("Downloading %s").printf(version_main));
			dt.execute();
			string[] stat = {"","",""};
			var t = deb_url_list.size.to_string();
			while (dt.is_running) {
				stat = dt.status_line.split_set(" /");
				if (stat[1]!=null && stat[2]!=null) pbar(int64.parse(stat[1])/MB,int64.parse(stat[2])/MB,"MB - file "+(dt.prg_count+1).to_string()+"/"+t);
				Thread.usleep(250000);
			}
			pbar(0,0);
		}

		foreach (string f in deb_url_list.keys) if (!exists(CACHE_KDIR+"/"+f)) r = false;
		return r;
	}

// ---------------------------------------------------------------------
// download_klist()
// install_klist()
// uninstall_klist()

	public static int download_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint("download_klist()",2);
		if (klist.size<1) vprint(_("Download: no downloadable kernels specified")); 
		int r = 0;
		foreach (var k in klist) if (!k.download_packages()) r++;
		return r;
	}

	// dep: dpkg
	public static int install_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint("install_klist()",2);

		if (!App.try_ppa()) return 1;

		string[] flist = {};
		foreach (var k in klist) {
			var v = k.version_main;

			if (k.is_installed) {
				vprint(_("%s is already installed").printf(v),1,stderr);
				continue;
			}

			if (k.is_locked) {
				vprint(_("%s is locked").printf(v),1,stderr);
				continue;
			}

			if (k.is_invalid) {
				vprint(_("%s is invalid").printf(v),1,stderr);
				continue;
			}

			if (!k.download_packages()) {
				vprint(_("%s download failed").printf(v),1,stderr);
				continue;
			}

			vprint(_("Installing %s").printf(v));
			foreach (var f in k.deb_url_list.keys) flist += k.CACHE_KDIR+"/"+f;
		}

		if (flist.length==0) { vprint(_("Install: no installable kernels specified")); return 1; }

		string cmd = "";
		foreach (var f in flist) { cmd += " '"+f+"'"; }
		cmd = sanitize_cmd(App.auth_cmd).printf("dpkg --install "+cmd);
		vprint(cmd,2);
		if (!ask()) return 1;
		var r = Posix.system(cmd);
		if (!App.keep_downloads) foreach (var f in flist) rm(f);
		return r;
	}

	// dep: dpkg
	public static int uninstall_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint("uninstall_klist()",2);

		string pnames = "";
		foreach (var k in klist) {
			var v = k.version_main;

			if (k.is_running) {
				vprint(_("%s is running").printf(v));
				continue;
			}

			if (k.is_locked) {
				vprint(_("%s is locked").printf(v));
				continue;
			}

			vprint(_("Uninstalling %s").printf(v));
			foreach (var p in k.pkg_list) {
				pnames += " '"+p+"'";
				vprint(_("found")+" : "+p,2);
			}
		}
		pnames = pnames.strip();
		if (pnames.length<1) { vprint(_("Uninstall: no uninstallable packages found"),1,stderr); return 1; }

		var cmd = sanitize_cmd(App.auth_cmd).printf("dpkg --purge "+pnames);
		vprint(cmd,2);
		if (!ask()) return 1;
		return Posix.system(cmd);
	}

// ---------------------------------------------------------------------
// kunin_old()
// kinst_latest()

	public static int kunin_old() {
		vprint("kunin_old()",2);

		find_thresholds(true);
		download_main_index();
		load_main_index();
		check_installed();

		var klist = new Gee.ArrayList<LinuxKernel>();
		//string vl = "";
		bool found_running_kernel = false;

		foreach(var k in kernel_list) {
			if (!k.is_installed) continue;

			var v = k.version_main;

			if (k.is_running) {
				found_running_kernel = true;
				vprint(_("%s is running").printf(v),2);
				continue;
			}
			if (k.compare_to(kernel_latest_installed) >= 0) {
				vprint(_("%s is the highest installed version").printf(v),2);
				continue;
			}
			if (k.is_locked) {
				vprint(_("%s is locked").printf(v),2);
				continue;
			}

			klist.add(k);
			//vl += "\n ▰ "+v;
		}

		if (!found_running_kernel) {
			vprint(_("Could not find running kernel in list"),1,stderr);
			return 2;
		}

		if (klist.size == 0){
			vprint(_("No old kernels to uninstall"));
			return 0;
		}

		//vprint("\n"+_("Uninstalling")+"\n"+vl);

		return uninstall_klist(klist);
	}

	public static int kinst_latest(bool point_only = false) {
		vprint("kinst_latest()",2);

		mk_kernel_list(true);

		var k = kernel_update_minor;
		if (!point_only && kernel_update_major!=null) k = kernel_update_major;

		if (k==null) { vprint(_("No updates")); return 1; }

		//vprint(_("Installing %s").printf(k.version_main));

		var klist = new Gee.ArrayList<LinuxKernel>();
		klist.add(k);
		return install_klist(klist);
	}

}
