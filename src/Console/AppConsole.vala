/*
 * AptikConsole.vala
 *
 * Copyright 2015 Tony George <teejee2008@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

using l.misc;
using l.exec;

public Main App;
public AppConsole CLI;

public class AppConsole : GLib.Object {

	string help = "\n"
		+ BRANDING_LONGNAME + " " + BRANDING_VERSION + " - " + _("install kernel packages from kernel.ubuntu.com") + "\n"
		+ "\n"
		+ _("Syntax") + ": " + BRANDING_SHORTNAME + " <command> [options]\n"
		+ "\n"
		+ _("Commands") + ":\n"
		+ "\n"
		+ "  --check             " + _("Check for kernel updates") + "\n"
		+ "  --notify            " + _("Check for kernel updates and send a desktop notification") + "\n"
		+ "  --list              " + _("List available kernels") + "\n"
		+ "  --list-installed    " + _("List installed kernels") + "\n"
		+ "  --install-latest    " + _("Install latest mainline kernel") + "\n"
		+ "  --install-minor     " + _("Install latest mainline kernel without going to a new major version") + "\n"
		+ "  --install <names>   " + _("Install specified kernels") + "(1)(2)\n"
		+ "  --uninstall <names> " + _("Uninstall specified kernels") + "(1)(2)\n"
		+ "  --uninstall-old     " + _("Uninstall all but the highest installed version") + "(2)\n"
		+ "  --download <names>  " + _("Download the specified kernels") + "(1)\n"
		+ "  --lock <names>      " + _("Lock the specified kernels") + "(1)\n"
		+ "  --unlock <names>    " + _("Unlock the specified kernels") + "(1)\n"
		+ "  --delete-cache      " + _("Delete cached info about available kernels") + "\n"
		+ "  -h|--help           " + _("This help") + "\n"
		+ "\n"
		+ _("Options") + ":\n"
		+ "\n"
		+ "  --include-rc        " + _("Include RC and unstable releases") + "\n"
		+ "  --exclude-rc        " + _("Exclude RC and unstable releases") + "\n"
		+ "  --include-flavors   " + _("Include flavors other than \"generic\"") + "\n"
		+ "  --exclude-flavors   " + _("Exclude flavors other than \"generic\"") + "\n"
		+ "  --include-invalid   " + _("Include failed/incomplete builds") + "\n"
		+ "  --exclude-invalid   " + _("Exclude failed/incomplete builds") + "\n"
		+ "  --previous-majors # " + _("Include # (or \"all\" or \"none\") previous major versions") +"\n"
		+ "  -y|--yes            " + _("Assume Yes for all prompts") + "\n"
		+ "  -n|--no|--dry-run   " + _("Assume No for all prompts - takes precedence over --yes") + "\n"
		+ "  -v|--verbose [#]    " + _("Verbosity - sets to level # if given, or increments by 1") + "\n"
		+ "  --pause             " + _("Pause and require keypress before exiting") + "\n"
		+ "\n"
		+ "Notes:\n"
		+ "(1) " +_("One or more version strings taken from the output of --list") + "\n"
		+ "    " +_("comma, pipe, colon, or space separated. (space requires quotes or backslashes)") + "\n"
		+ "(2) " +_("Locked kernels and the currently running kernel are ignored") + "\n"
		;

	static bool hold_on_exit = false;
	static bool help_shown = false;

	public static int main (string[] argv) {
		App = new Main();
		CLI = new AppConsole();
		var r = CLI.parse_arguments(argv);
		vprint(BRANDING_SHORTNAME+": "+_("done"));
		if (hold_on_exit) ask(_("(press Enter to close)"),false,true);
		return r;
	}

	void show_help() {
		if (help_shown) return;
		help_shown = true;
		vprint(help,0);
	}

	// misnomer, it's not just parsing but dispatching and doing everything
	public int parse_arguments(string[] args) {

		// check argument count -----------------

		if (args.length == 1) {
			vprint(help,0);
			return 1;
		}

		string cmd = "";
		string vlist = "";
		string a = "";

		// parse options first --------------

		for (int i = 1; i < args.length; i++) {
			a = args[i].down();
			switch (a) {

				case "-v":
				case "--debug":
				case "--verbose":
					if (App.set_verbose(args[i+1])) i++;
					break;

				case "-y":
				case "--yes":
					App.yes_mode = true;
					break;

				case "-n":
				case "--no":
				case "--dry-run":
					App.no_mode = true;
					break;

				// used by gui with external terminal
				case "--hold":
				case "--pause":
					hold_on_exit = true;
					break;

				// used by gui front-end
				case "--index-is-fresh":
					App.index_is_fresh = true;
					break;

				// config file overrides
				case "--show-unstable": // back compat
				case "--include-unstable":
				case "--include-rc":
					App.opt_hide_unstable = false;
					break;
				case "--hide-unstable": // back compat
				case "--exclude-unstable":
				case "--exclude-rc":
					App.opt_hide_unstable = true;
					break;
				case "--include-flavors":
					App.opt_hide_flavors = false;
					break;
				case "--exclude-flavors":
					App.opt_hide_flavors = true;
					break;
				case "--include-invalid":
					App.opt_hide_invalid = false;
					break;
				case "--exclude-invalid":
					App.opt_hide_invalid = true;
					break;
				case "--previous-majors":
					if (set_previous_majors(args[i+1])) i++;
					break;

				case "--list":
				case "--list-installed":
				case "--check":
				case "--notify":
				case "--install-latest":
				case "--install-point":
				case "--purge-old-kernels": // back compat
				case "--uninstall-old":
					cmd = a;
					break;

				case "--lock":
				case "--unlock":
				case "--download":
				case "--remove":
				case "--uninstall":
				case "--install":
					cmd = (a=="--remove") ? "--uninstall" : a ;
					if (++i < args.length) vlist = args[i];
					break;

				case "--clean-cache":
				case "--delete-cache":
					int r = 1;
					if (rm(Main.CACHE_DIR)) { r = 0; vprint(_("Deleted")+" "+Main.CACHE_DIR); }
					else vprint(_("Error deleting")+" "+Main.CACHE_DIR,1,stderr);
					return r;

				case "":
				case "-?":
				case "-h":
				case "--help":
				case "--version":
					show_help();
					return 0;

				default:
					show_help();
					vprint(_("Unknown option") + ": \"%s\"".printf(args[i]),1,stderr);
					return 1;
			}
		}

		if (App.no_mode) vprint(_("DRY-RUN MODE"),2);
		else if (App.yes_mode && !App.index_is_fresh) vprint(_("NO-CONFIRM MODE"),2);

		App.init2();

		// run command --------------------------------------

		switch (cmd) {
			case "--list":
				LinuxKernel.mk_kernel_list(true);
				LinuxKernel.print_list();
				break;

			case "--list-installed":
				// --- method a
				//Package.mk_dpkg_list();
				//LinuxKernel.check_installed(true);
				// --- method b
				//LinuxKernel.mk_kernel_list(true);
				//LinuxKernel.print_list(true);
				// --- method c
				Package.mk_dpkg_list();
				vprint(_("Installed Kernels")+":");
				foreach (var p in Package.dpkg_list) if (p.name.has_prefix("linux-image-")) vprint(p.name);
				break;

			case "--check":
				print_updates();
				break;

			case "--notify":
				return notify_user();

			case "--install-latest":
				return LinuxKernel.kinst_latest(false);

			case "--install-point":
				return LinuxKernel.kinst_latest(true);

			case "--purge-old-kernels":
			case "--uninstall-old":
				return LinuxKernel.kunin_old();

			case "--lock":
				return LinuxKernel.lock_klist(LinuxKernel.vlist_to_klist(vlist,true),true);

			case "--unlock":
				return LinuxKernel.lock_klist(LinuxKernel.vlist_to_klist(vlist,true),false);

			case "--download":
				return LinuxKernel.download_klist(LinuxKernel.vlist_to_klist(vlist,true));

			case "--uninstall":
				return LinuxKernel.uninstall_klist(LinuxKernel.vlist_to_klist(vlist,true));

			case "--install":
				return LinuxKernel.install_klist(LinuxKernel.vlist_to_klist(vlist,true));

			default:
				show_help();
				vprint(_("Unknown command") + ": \""+cmd+"\"",1,stderr);
				return 1;
		}

		return 0;
	}

	bool set_previous_majors(string? s) {
		string a = (s==null) ? "" : s.strip();
		if (a.length<1 || a.has_prefix("-")) return false;
		if (a=="none") a = "0";
		if (a=="all") a = "-1";
		App.opt_previous_majors = int.parse(a);
		return true;
	}

	void print_updates() {
		LinuxKernel.mk_kernel_list(true);
		var km = LinuxKernel.kernel_update_major;
		var kp = LinuxKernel.kernel_update_minor;
		if (km != null) vprint(_("Latest update")+": "+km.version_main);
		if (kp != null) vprint(_("Latest point update")+": "+kp.version_main);
		if ((km == null) && (kp == null)) vprint(_("No updates found"));
	}

	int notify_user() {
		vprint("notify_user()",3);

		if (!App.notify_major && !App.notify_minor) {
			vprint(_("Notifications disabled"),2);
			return 1;
		}

		if (Environment.get_variable("DISPLAY")==null) {
			vprint(_("No")+" $DISPLAY",2);
			return 1;
		}

		LinuxKernel.mk_kernel_list(true);

		string title = _("No updates found");
		string seen = "";
		string available = "";

		if (App.notify_minor) {
			var k = LinuxKernel.kernel_update_minor;
			if (k!=null && k.version_main!="") available = k.version_main;
			if (exists(App.MINOR_SEEN_FILE)) seen = fread(App.MINOR_SEEN_FILE).strip();
			if (seen!=available) fwrite(App.MINOR_SEEN_FILE,available);
		} else vprint(_("notify minor releases disabled"),2);

		// if notify_major enabled and there is one, simply overwrite available
		if (App.notify_major) {
			var k = LinuxKernel.kernel_update_major;
			if (k!=null && k.version_main!="") available = k.version_main;
			if (exists(App.MAJOR_SEEN_FILE)) seen = fread(App.MAJOR_SEEN_FILE).strip();
			if (seen!=available) fwrite(App.MAJOR_SEEN_FILE,available);
		} else vprint(_("notify major releases disabled"),2);

		if (seen==available) available = "";
		if (available!="") {
			title = _("Kernel %s Available").printf(available);
			string s = APP_LIB_DIR+"/notice.sh"
				+ " -i \"@"+App.NOTIFICATION_ID_FILE+"\""
				+ " -N \""+BRANDING_LONGNAME+"\""
				+ " -n "+BRANDING_SHORTNAME
				+ " -t0"
				+ " -a \""+_("Show")+":"+BRANDING_SHORTNAME+"-gtk\""
				+ " -a \""+_("Install")+":"+BRANDING_SHORTNAME+"-gtk --install "+available+"\""
				+ " -s \""+title+"\""
			;
			exec_async(s);
		} else {
			if (seen!="") title = _("Previously notified")+": \""+seen+"\"";
		}

		vprint(title,2);
		return 0;
	}

}
