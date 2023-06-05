
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;
using l.misc;

public class LinuxKernel : GLib.Object, Gee.Comparable<LinuxKernel> {

	public string kname = "";
	public string kver = "";
	public string version_main = "";
	public string page_uri = "";
	public string notes = "";

	public int version_major = -1;
	public int version_minor = -1;
	public int version_point = -1;
	public int version_rc = -1;
	public string version_extra = "";
	public string version_sort = "";

	public Gee.HashMap<string,string> deb_url_list = new Gee.HashMap<string,string>(); // assosciated .deb files K=filename,V=url
	public Gee.HashMap<string,string> deb_checksum_list = new Gee.HashMap<string,string>(); // assosciated .deb files K=filename,V=checksum
	public Gee.HashMap<string,string> pkg_list = new Gee.HashMap<string,string>(); // assosciated dpkg package names

	public static Gee.HashMap<string,Package> pkg_list_installed;

	public bool is_installed = false;
	public bool is_running = false;
	public bool is_mainline = true;
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
	public static int THRESHOLD_MAJOR = -1;

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

	// class initialize
	public static void initialize() {
		new LinuxKernel(); // instance must be created before setting static members

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

		// Special kernel versions where the mainline-ppa site changed their directory structure.
		// affects:
		// - ./foo.deb vs ./<arch>/foo.deb
		// - ./CHECKSUMS vs ./<arch>/CHECKSUMS
		// - ./BUILT vs ./<arch>/status
		kernel_last_stable_old_ppa_dirs = new LinuxKernel("5.6.17");
		kernel_last_unstable_old_ppa_dirs = new LinuxKernel("5.7-rc7");

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
			rex_header = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-[a-zA-Z0-9\.\-_]+-generic_[a-zA-Z0-9\.\-]+_""" + NATIVE_ARCH + ".deb");

			//linux-headers-3.4.75-030475_3.4.75-030475.201312201255_all.deb
			rex_header_all = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-[a-zA-Z0-9\.\-_]+_all.deb""");

			//linux-image-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_image = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-[a-zA-Z0-9\.\-_]+-generic_([a-zA-Z0-9\.\-]+)_""" + NATIVE_ARCH + ".deb");

			//linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_image_extra = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-extra-[a-zA-Z0-9\.\-_]+-generic_[a-zA-Z0-9\.\-]+_""" + NATIVE_ARCH + ".deb");

			//linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_modules = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-modules-[a-zA-Z0-9\.\-_]+-generic_[a-zA-Z0-9\.\-]+_""" + NATIVE_ARCH + ".deb");

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
		delete_r(App.CACHE_DIR);
	}

	// constructor
	public LinuxKernel(string s="") {
		vprint("LinuxKernel("+s+")",4);
		split_version_string(s);
	}

	// static

	public delegate void Notifier(GLib.Timer timer, ref int count, bool last = false);

	public static void mk_kernel_list(bool wait = true, owned Notifier? notifier = null) {
		vprint("mk_kernel_list()",2);
		check_if_initialized();

		kernel_list.clear();

		try {
			App.cancelled = false;
			var worker = new Thread<bool>.try(null, () => query_thread((owned) notifier) );
			if (wait) worker.join();
		} catch (Error e) {
			vprint(e.message,1,stderr);
		}
	}

	private static bool query_thread(owned Notifier? notifier) {
		vprint("query_thread()",2);
		App.progress_total = 0;
		App.progress_count = 0;

		var timer = timer_start();
		int count = 0;

		// find the oldest major version to include
		find_thresholds(true);

		// ===== download the main index.html listing all kernels =====
		download_index();
		load_index();

		// ===== download the per-kernel index.html and CHANGES =====

		// list of kernels - 1 LinuxKernel object per kernel to update
		var kernels_to_update = new Gee.ArrayList<LinuxKernel>();
		// list of files - 1 DownloadItem object per individual file to download
		var downloads = new Gee.ArrayList<DownloadItem>();

		// add files to download list, and add kernels to kernel list
		foreach (var k in kernel_list) {
			if (App.cancelled) break;

			// skip some kernels for various reasons

			// load the cached index before checking is_invalid
			// because we may discover that the cached invalid status is out of date
			if (k.cached_page_exists) {
				vprint(_("loading cached")+" "+k.version_main,3);
				if (k.load_cached_page()) continue;
			}

			if (k.is_invalid) continue;

			if (!k.is_installed) {
				if (k.version_major < THRESHOLD_MAJOR) continue;
				if (App.hide_unstable && k.version_rc>=0) continue;
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
			App.progress_total = downloads.size;
			var mgr = new DownloadTask();

			// add download list to queue
			foreach (var item in downloads) mgr.add_to_queue(item);

			// start downloading
			mgr.execute();

			vprint(_("Fetching individual kernel indexes")+"...");

			// while downloading
			while (mgr.is_running()) {
				App.progress_count = mgr.prg_count; // also used by the progress indicator in MainWindow.vala
				pbar(App.progress_count,App.progress_total,"(files)");
				//pbar(App.progress_count,App.progress_total);
				sleep(250);
				if (notifier != null) notifier(timer, ref count);
			}
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

		// This is here because it had to be delayed from whenever settings
		// changed until now, so that the notify script instance of ourself
		// doesn't do mk_kernel_list() at the same time while we still are.
		App.run_notify_script();

		timer_elapsed(timer, true);
		if (notifier != null) notifier(timer, ref count, true);

		return true;
	}

	// download the main index.html listing all mainline kernels
	private static bool download_index() {
		vprint("download_index()",2);
		check_if_initialized();

		string cif = main_index_file();
		if (!file_exists(cif)) App.index_is_fresh=false;
		if (App.index_is_fresh) return true;
		if (!try_ppa()) return false;

		dir_create(App.CACHE_DIR);

		// preserve the old index in case the dl fails
		string tbn = random_string();
		string tfn = App.CACHE_DIR+"/"+tbn;
		vprint("+ DownloadItem("+App.ppa_uri+","+App.CACHE_DIR+","+tbn+")",4);
		var item = new DownloadItem(App.ppa_uri, App.CACHE_DIR, tbn);
		var mgr = new DownloadTask();
		mgr.add_to_queue(item);

		vprint(_("Updating from")+": '"+App.ppa_uri+"'");
		mgr.execute();

		while (mgr.is_running()) sleep(500);

		if (file_exists(tfn)) {
			file_move(tfn,cif);
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
		if (THRESHOLD_MAJOR<0) find_thresholds(true);
		if (THRESHOLD_MAJOR<0) { vprint("load_index(): THRESHOLD_MAJOR not initialized"); exit(1); }

		string cif = main_index_file();
		if (!file_exists(cif)) return;
		string txt = file_read(cif);
		kernel_list.clear();

		try {
			var rex = new Regex("""href="(v[0-9][a-zA-Z0-9\-._\/]+)".+>[\t ]*([0-9]{4})-([0-9]{2})-([0-9]{2})[\t ]+([0-9]{2}):([0-9]{2})[\t ]*<""");
			// <tr><td valign="top"><img src="/icons/folder.gif" alt="[DIR]"></td><td><a href="v2.6.27.61/">v2.6.27.61/</a></td><td align="right">2018-05-13 20:40  </td><td align="right">  - </td><td>&nbsp;</td></tr>
			//                                                                                 ###########                                        #### ## ## ## ##
			//                                                                                 fetch(1)                                           2    3  4  5  6

			MatchInfo mi;
			string v;
			foreach (string l in txt.split("\n")) {
				if (!rex.match(l, 0, out mi)) continue;
				v = mi.fetch(1);
				var k = new LinuxKernel(v);

				if (k.version_major<THRESHOLD_MAJOR ||
					(k.version_rc>=0 && App.hide_unstable)) { delete_r(k.cache_subdir); continue; }

				k.page_uri = App.ppa_uri + v;
				k.is_mainline = true;
				k.ppa_datetime = int64.parse(mi.fetch(2)+mi.fetch(3)+mi.fetch(4)+mi.fetch(5)+mi.fetch(6));
				vprint("kernel_list.add("+k.version_main+") "+k.ppa_datetime.to_string(),2);
				kernel_list.add(k);
			}

			// sort the list, highest first
			kernel_list.sort((a,b) => { return b.compare_to(a); });

		}
		catch (Error e) {
			vprint(e.message,1,stderr);
		}
	}

	public static void check_installed() {
		vprint("check_installed()",2);

		string msg = "";

		if (Package.dpkg_list.size<1) { vprint("dpkg_list empty!"); exit(1); }
		if (kernel_list.size<1) { vprint("kernel_list empty!"); exit(1); }

		foreach (var p in Package.dpkg_list) {
			if (!p.pname.has_prefix("linux-image-")) continue;

			// temp kernel object for current pkg
			var pk = new LinuxKernel(p.version);
			pk.set_pkg_list(); // find assosciated packages

			msg = _("Found installed")+": "+p.pname;
			if (pk.is_locked) msg += " (" + _("locked") +")";
			vprint(msg);

			// search the mainline list for matching package name
			// fill k.pkg_list list of assosciated pkgs
			bool found = false;
			foreach (var k in kernel_list) {
				if (k.is_invalid) continue;
				if (k.version_major<THRESHOLD_MAJOR) continue;
				if (k.kver == pk.kver) {
					found = true;
					k.pkg_list = pk.pkg_list;
					k.is_installed = true;
					break;
				}
			}

			// installed package was not found in the mainline list
			// so it's a distro kernel, add to kernel_list
			if (!found) {
				pk.kname = p.pname;
				pk.is_mainline = false;
				pk.is_installed = true;
				if (file_exists(pk.notes_file)) pk.notes = file_read(pk.notes_file);
				vprint("kernel_list.add("+pk.version_main+" "+pk.kname+" "+pk.kver+")",2);
				kernel_list.add(pk);
			}
		}

		// finding the running kernel reliably is hard, because uname
		// output does not relaibly match any of the other available
		// strings: pkg name, pkg version, ppa site version string
		// https://github.com/bkw777/mainline/issues/91
		// uname 6.3.4-060304-generic
		// version_main sometimes 6.3.4-060304.202305241735
		// version_main othertimes 6.3.4
		// kname linux-image-unsigned-6.3.4-060304-generic
		// kver 6.3.4-060304.202305241735
		//t = k.kver[0:k.kver.last_index_of(".")]; // 6.3.4-060304

		// kernel_list should contain both mainline and distro kernels now
		foreach (var k in kernel_list) {
			if (!k.kname.has_suffix(RUNNING_KERNEL)) continue;
			k.is_running = true;
			k.is_installed = true;
			kernel_active = k;
			break;
		}

		// sort, reverse
		kernel_list.sort((a,b) => { return b.compare_to(a); });

		// find the highest & lowest installed versions
		kernel_latest_installed = new LinuxKernel();
		kernel_oldest_installed = kernel_latest_installed;
		foreach(var k in kernel_list) {
			//if (k.is_installed && k.is_mainline) {
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

		foreach(var k in kernel_list) {
			vprint(k.version_main,3);
			if (k.is_invalid) continue;
			if (k.is_installed) continue;
			if (k.is_locked) { vprint(k.version_main+" "+_("is locked."),2); continue; }
			if (k.version_rc>=0 && App.hide_unstable) continue;
			if (k.version_major < THRESHOLD_MAJOR) break;
			if (k.compare_to(kernel_latest_installed)<1) break;

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

	// There is a circular dependency here.
	// (1) Ideally we want to know THRESHOLD_MAJOR before running mk_kernel_list(),
	//     so mk_kernel_list() can use it to set bounds on the size of it's job,
	//     instead of processing all kernels since the beginning of time, every time.
	// (2) Ideally we want is_mainline while finding THRESHOLD_MAJOR, to ignore non-mainline kernels
	//     so that an installed distro kernel doesn't pull THRESHOLD_MAJOR down a whole generation.
	// (3) The only way to find out is_mainline for real is to scan kernel_list[],
	//     and see if a given installed package matches one of those.
	// (4) But we don't have kernel_list[] yet, and we can't get it yet, because GOTO (1)
	// 
	// So for this early task, we rely on a weak is_mainline that was made
	// from an unsafe assumption in split_version_string(), when mk_dpkg_list()
	// generates some kernel objects from the installed package info from dpkg.
	//
	// TODO maybe... get a full kernel_list from a preliminary pass with load_index()
	// before runing mk_dpkg_list(). have mk_dpkg_list() use that
	// to fill in a real actual is_mainline for each item in dpkg_list[]
	// use that here and along the way delete the unwanted items from kernel_list[]
	// then mk_kernel_list() can just process that kernel_list[]
	// 
	public static void find_thresholds(bool up=false) {
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

		THRESHOLD_MAJOR = kernel_latest_available.version_major - App.previous_majors;
		if (kernel_oldest_installed.is_mainline && kernel_oldest_installed.version_major < THRESHOLD_MAJOR) THRESHOLD_MAJOR = kernel_oldest_installed.version_major;
	}

	public void split_version_string(string s="") {
		version_main = "";
		version_major = 0;
		version_minor = 0;
		version_point = 0;
		version_rc = -1;
		version_extra = "";
		is_mainline = true; // FIXME bad assumption

		string t = s.strip();
		if (t.has_prefix("v")) t = t[1: t.length - 1];
		if (t.has_suffix("/")) t = t[0: t.length - 1];
		version_main = t;

		t = t.split("~")[0];
		if (t==null || t=="") t = "0";
		kver = t;
		//vprint("\""+t+"\"");

		// Unsafe. "rc" could be part of intel-arc or something some day.
		var mi = regex_match("""([0-9]+|rc)""",t);
		int i = -1;
		bool rc = false;

		while (mi != null) {
			string? v = mi.fetch(1);

			if (v != null) {
				i++;

				if (rc) {
					rc = false;
					version_rc = int.parse(v);
					//vprint ("%s: i=%d v.length=%d mainline=%s".printf(t,i,v.length,is_mainline.to_string()));
				} else if (v == "rc") {
					rc = true;
					//vprint ("%s: i=%d v.length=%d mainline=%s".printf(t,i,v.length,is_mainline.to_string()));
				} else {
					switch (i) {
						case 0: version_major = int.parse(v); break;
						case 1: version_minor = int.parse(v); break;
						case 2: version_point = int.parse(v); break;
						case 3: if (version_rc<0 && v.length<6) version_extra += "."+v; break;  // not great
						case 4:
							if (version_rc<0 && v.length<6) version_extra += "."+v; // not great
							if (v.length<12) is_mainline = false; // FIXME bad assumption
							break;
					}
					//vprint ("%s: i=%d v.length=%d mainline=%s".printf(t,i,v.length,is_mainline.to_string()));
				}
			}

			if (version_rc>=0) version_extra = "-rc%d".printf(version_rc);
			version_sort = "%d.%d.%d%s".printf(version_major,version_minor,version_point,version_extra);

			try { if (!mi.next()) break; }
			catch (Error e) { break; }
		}
	}

// complicated comparison logic for kernel version strings
// like strcmp(), but l & r are LinuxKernel objects
//  l<r  return -1
//  l==r return 0
//  l>r  return 1
	public int compare_to(LinuxKernel t) {
		vprint(version_main+" compare_to() "+t.version_main,4);
		// TODO version_sort is a transitional hack to keep doing the old way of parsing version_main
		// since version_main has a different format now.
		// The better way will be to just examine the individual variables we already have for free,
		// version_major, version_minor, etc...
		var a = version_sort.split_set(".-_");
		var b = t.version_sort.split_set(".-_");
		int x, y, i = -1;
		while (++i<a.length && i<b.length) {
			if (a[i] == b[i]) continue;
			x = int.parse(a[i]);
			y = int.parse(b[i]);
			if (x>0 && y>0) return (x - y);
			if (x==0 && y==0) return strcmp(a[i],b[i]);
			if (x>0) return 1;
			return -1;
		}
		if (i<a.length) { if (int.parse(a[i])>0) return 1; return -1; }
		if (i<b.length) { if (int.parse(b[i])>0) return -1; return 1; }
		return 0;
	}

	public void set_pkg_list() {
		vprint("set_pkg_list()",2);
		vprint("kname:"+kname+" kver:"+kver+" version_main:"+version_main,3);
		foreach(var p in Package.dpkg_list) {
			if (!p.pname.has_prefix("linux-")) continue;
			if (p.version == kver) {
				pkg_list[p.pname] = p.pname;
				vprint("Package: "+p.pname,2);
			}
		}
	}

	public void mark_invalid() {
			file_write(cached_status_file,"");
	}

	// properties

	public bool is_invalid {
		get {
			return file_exists(cached_status_file);
		}
	}

	public bool is_locked {
		get {
			return file_exists(locked_file);
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
			var k = kernel_last_stable_old_ppa_dirs;
			if (version_rc>=0) k = kernel_last_unstable_old_ppa_dirs;
			if (compare_to(k)>0) { ppa_dirs_ver = 2; return true; }
			else { ppa_dirs_ver = 1; return false; }
		}
	}


	public static string main_index_file () {
		return App.CACHE_DIR+"/index.html";
	}

	public string cache_subdir {
		owned get {
			return App.CACHE_DIR+"/"+version_main;
		}
	}

	public string data_subdir {
		owned get {
			return App.DATA_DIR+"/"+version_main;
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

	public string locked_file {
		owned get {
			return data_subdir+"/locked";
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

	// return false if we don't have the cached page or if it's out of date
	// return true if we have a valid cached page, whether the kernel itself is a valid build or not
	private bool load_cached_page() {
		vprint("load_cached_page("+cached_page+")",2);

		string txt = "";
		int64 d_this = 0;
		int64 d_max = 0;
		deb_image = "";
		deb_header = "";
		deb_header_all = "";
		deb_image_extra = "";
		deb_modules = "";
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
			var rex = new Regex(""">[\t ]*([0-9]{4})-([0-9]{2})-([0-9]{2})[\t ]+([0-9]{2}):([0-9]{2})[\t ]*<""");
			MatchInfo mi;
			foreach (string l in txt.split("\n")) {
				if (rex.match(l, 0, out mi)) {
					d_this = int64.parse(mi.fetch(1)+mi.fetch(2)+mi.fetch(3)+mi.fetch(4)+mi.fetch(5));
					if (d_this>d_max) d_max = d_this;
					//vprint(d_this.to_string()+"  "+d_max.to_string());
				}
			}
		} catch (Error e) {
			vprint(e.message,1,stderr);
		}

		// if datetime from main index is later than the latest cached datetime,
		// delete the cached index and status, return false
		if (ppa_datetime>d_max) {
			vprint(version_main+": ppa:"+ppa_datetime.to_string()+" > cache:"+d_max.to_string()+" : needs update");
			delete_r(cache_subdir);
			return false;
		}

		// skip the rest of the work if we already know it's a failed build
		if (is_invalid) return true;

		// scan for urls to .deb files
		try {
			//<a href="linux-headers-4.6.0-040600rc1-generic_4.6.0-040600rc1.201603261930_amd64.deb">//same deb name//</a>
			var rex = new Regex("""href="([a-zA-Z0-9\-\._/]+\.deb)"""");
			MatchInfo mi;
			foreach (string l in txt.split("\n")) {
				if (rex.match(l, 0, out mi)) {

					string file_uri = page_uri + mi.fetch(1);
					//vprint("file_uri:"+file_uri);
					string file_name = Path.get_basename(file_uri);
					//vprint("file_name:"+file_name);
					if (deb_url_list.has_key(file_name)) continue;

					bool add = false;

					if (rex_header.match(file_name, 0, out mi)) {
						deb_header = file_name;
						add = true;
					}

					if (rex_header_all.match(file_name, 0, out mi)) {
						deb_header_all = file_name;
						add = true;
					}

					if (rex_image.match(file_name, 0, out mi)) {
						deb_image = file_name;
						add = true;
						// linux-headers-4.6.0-040600rc1-generic_4.6.0-040600rc1.201603261930_amd64.deb
						var p = file_name.split("_");
						if (p[0]!="") kname = p[0];
						if (p[1]!="") kver = p[1];
					}

					if (rex_image_extra.match(file_name, 0, out mi)) {
						deb_image_extra = file_name;
						add = true;
					}

					if (rex_modules.match(file_name, 0, out mi)) {
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
				if (App.hide_unstable && k.version_rc>=0) continue;
				if (k.version_major < THRESHOLD_MAJOR) continue;
			}

			string lck = "  ";
			if (k.is_locked) lck = "🔒";

			if (k.version_main.length>nl) nl = k.version_main.length;
			vprint("%-*s %s %-10s %s".printf(nl, k.version_main, lck, k.status, k.notes));
		}
	}

	public static Gee.ArrayList<LinuxKernel> vlist_to_klist(string list="",bool uk=false) {
		vprint("vlist_to_klist("+list+")",3);
		check_if_initialized();
		var klist = new Gee.ArrayList<LinuxKernel>();
		var vlist = list.split_set(",;:| ");
		int i=vlist.length;
		foreach (var v in vlist) if (v.strip()=="") i-- ;
		if (i<1) return klist;
		if (uk || kernel_list.size<1) mk_kernel_list(true);
		bool e = false;
		foreach (var v in vlist) {
			e = false;
			if (v.strip()=="") continue;
			foreach (var k in kernel_list) if (k.version_main==v) { e = true; klist.add(k); break; }
			if (!e) vprint(_("Kernel")+" \""+v+"\" "+_("not found"));
		}
		return klist;
	}

	public static int download_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint("download_klist()",2);
		if (klist.size<1) vprint(_("Download: no downloadable kernels specified")); 
		int r = 0;
		foreach (var k in klist) if (!k.download_packages()) r++;
		return r;
	}

	// dep: aria2c
	public bool download_packages() {
		vprint("download_packages("+version_main+")",2);
		check_if_initialized();
		bool ok = true;
		int MB = 1024 * 1024;

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
	public static int install_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint(_("Installing selected kernels")+":");

		if (!try_ppa()) return 1;

		string[] flist = {};
		foreach (var k in klist) {
			vprint(_("Requested")+" "+k.version_main);

			if (k.is_installed) {
				vprint(k.version_main+"! "+_("is already installed."),1,stderr);
				continue;
			}

			if (k.is_locked) {
				vprint(k.version_main+"! "+_("is locked."),1,stderr);
				continue;
			}

			if (!k.download_packages()) {
				vprint(k.version_main+"! "+_("download failed."),1,stderr);
				continue;
			}

			foreach (string f in k.deb_url_list.keys) flist += k.cache_subdir+"/"+f;
		}

		if (flist.length==0) { vprint(_("Install: no installable kernels specified")); return 1; }

		// full paths instead of env -C
		// https://github.com/bkw777/mainline/issues/128
		string cmd = "";
		foreach (string f in flist) { cmd += " '"+f+"'"; }
		cmd = sanitize_auth_cmd(App.auth_cmd).printf("dpkg --install "+cmd);
		vprint(cmd,2);
		int r = Posix.system(cmd);
		foreach (string f in flist) delete_r(f);
		return r;
	}

	// dep: dpkg
	public static int uninstall_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint(_("Uninstalling selected kernels")+":");

		string pnames = "";
		foreach (var k in klist) {
			vprint(_("Requested")+" "+k.version_main);

			if (k.is_running) {
				vprint("! "+_("Not uninstalling the currently running kernel")+" "+k.version_main);
				continue;
			}

			if (k.is_locked) {
				vprint("! "+k.version_main+" "+_("is locked"));
				continue;
			}

			foreach (var p in k.pkg_list.values) {
				if (p.has_prefix("linux-tools")) continue;
				if (p.has_prefix("linux-libc")) continue;
				pnames += " '"+p+"'";
				vprint(_("found")+" : "+p,2);
			}
		}
		pnames = pnames.strip();
		if (pnames=="") { vprint(_("Uninstall: no uninstallable packages found"),1,stderr); return 1; }

		string cmd = sanitize_auth_cmd(App.auth_cmd).printf("dpkg --purge "+pnames);
		vprint(cmd,2);
		return Posix.system(cmd);
	}

	public static void kunin_old(bool confirm) {
		vprint("kunin_old()",2);

		find_thresholds(true);
		download_index();
		load_index();
		check_installed();

		//vprint("kernel_oldest_installed: "+kernel_oldest_installed.version_main,2);
		//vprint("kernel_latest_installed: "+kernel_latest_installed.version_main,2);
		//vprint("kernel_latest_available: "+kernel_latest_available.version_main,2);

		var klist = new Gee.ArrayList<LinuxKernel>();

		bool found_running_kernel = false;

		//vprint("latest_installed: "+kernel_latest_installed.version_main,4);
		//vprint("running_kernel: "+kern_running.version_main,4);

		foreach(var k in kernel_list) {
			if (k.is_invalid) continue;
			if (!k.is_installed) continue;

			if (k.is_running) {
				found_running_kernel = true;
				vprint(k.version_main+" "+"is running.",2);
				continue;
			}
			if (k.compare_to(kernel_latest_installed) >= 0) {
				vprint(k.version_main+" "+_("is the highest installed version."),2);
				continue;
			}
			if (k.is_locked) {
				vprint(k.version_main+" "+_("is locked."),2);
				continue;
			}

			//vprint(k.version_main+" < "+kernel_latest_installed.version_main+" -> delete",4);
			klist.add(k);
		}

		if (!found_running_kernel) {
			vprint(_("Could not find running kernel in list"),1,stderr);
			return;
		}

		if (klist.size == 0){
			vprint(_("Could not find any kernels to uninstall"),2);
			return;
		}

		// confirm -------------------------------

		if (confirm) {

			var message = "\n"+_("The following kernels will be uninstalled")+"\n";

			foreach (var k in klist) message += " ▰ %s\n".printf(k.version_main);

			message += "\n%s (y/n): ".printf(_("Continue ?"));

			vprint(message,0);

			int ch = stdin.getc();

			if (ch != 'y') return;
		}

		// uninstall --------------------------------
		uninstall_klist(klist);
	}

	public static void kinst_latest(bool point_update, bool confirm) {
		vprint("kinst_latest()",2);

		mk_kernel_list(true);

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

		var klist = new Gee.ArrayList<LinuxKernel>();
		klist.add(k);
		install_klist(klist);
	}

}
