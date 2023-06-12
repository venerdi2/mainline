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

using TeeJee.FileSystem;
using l.misc;

public Main App;

public class AppConsole : GLib.Object {

	public static int main (string[] args) {
		App = new Main(args, false);
		var console = new AppConsole();
		return console.parse_arguments(args);
	}

	public int parse_arguments(string[] args) {

		string help = "\n" + BRANDING_SHORTNAME + " " + BRANDING_VERSION + " - " + BRANDING_LONGNAME + "\n"
		+ "\n"
		+ _("Syntax") + ": " + BRANDING_SHORTNAME + " <command> [options]\n"
		+ "\n"
		+ _("Commands") + ":\n"
		+ "\n"
		+ "  --check             " + _("Check for kernel updates") + "\n"
		+ "  --notify            " + _("Check for kernel updates and notify current user") + "\n"
		+ "  --list              " + _("List available mainline kernels") + "\n"
		+ "  --list-installed    " + _("List installed kernels") + "\n"
		+ "  --install-latest    " + _("Install latest mainline kernel") + "\n"
		+ "  --install-point     " + _("Install latest point update in the current major version") + "\n"
		+ "  --install <names>   " + _("Install specified kernels") + "(1)(2)\n"
		+ "  --uninstall <names> " + _("Uninstall specified kernels") + "(1)(2)\n"
		+ "  --uninstall-old     " + _("Uninstall all but the highest installed version") + "(2)\n"
		+ "  --download <names>  " + _("Download specified kernels") + "(1)\n"
		+ "  --delete-cache      " + _("Delete cached info about available kernels") + "\n"
		+ "\n"
		+ _("Options") + ":\n"
		+ "\n"
		+ "  --include-unstable  " + _("Include unstable and RC releases") + "\n"
		+ "  --exclude-unstable  " + _("Exclude unstable and RC releases") + "\n"
		+ "  -v|--verbose [n]    " + _("Verbosity. Set to n if given, or increment.") + "\n"
		+ "  -y|--yes            " + _("Assume Yes for all prompts (non-interactive mode)") + "\n"
		+ "\n"
		+ "Notes:\n"
		+ "(1) " +_("One or more version strings taken from the output of --list") + "\n"
		+ "    " +_("comma, pipe, or colon-seperated, or quoted space seperated") + "\n"
		+ "(2) " +_("Locked kernels and the currently running kernel are ignored") + "\n"
		;

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
					App.confirm = false;
					break;

				// used by gui front-end
				case "--index-is-fresh":
					App.index_is_fresh = true;
					break;

				case "--show-unstable":		// back compat
				case "--include-unstable":
					App.hide_unstable = false;
					break;
				case "--hide-unstable":		// back compat
				case "--exclude-unstable":
					App.hide_unstable = true;
					break;

				case "--list":
				case "--list-installed":
				case "--check":
				case "--notify":
				case "--install-latest":
				case "--install-point":
				case "--purge-old-kernels":	// back compat
				case "--uninstall-old":
				case "--clean-cache":	// back compat
				case "--delete-cache":
					cmd = a;
					break;

				case "--download":
				case "--remove":
				case "--uninstall":
				case "--install":
					cmd = (a=="--remove") ? "--uninstall" : a ;
					if (++i < args.length) vlist = args[i];
					break;

				case "":
				case "-?":
				case "-h":
				case "--help":
					vprint(help,0);
					return 0;

				default:
					vprint(_("Unknown option") + ": \"%s\"".printf(args[i]),1,stderr);
					vprint(help,0);
					return 1;
			}
		}

		// run command --------------------------------------

		switch (cmd) {
			case "--list":
				LinuxKernel.mk_kernel_list(true);
				LinuxKernel.print_list();
				break;

			case "--list-installed":
				Package.mk_dpkg_list();
				LinuxKernel.check_installed();
				break;

			case "--check":
				print_updates();
				break;

			case "--notify":
				return notify_user();

			case "--install-latest":
				return LinuxKernel.kinst_latest(false, App.confirm);

			case "--install-point":
				return LinuxKernel.kinst_latest(true, App.confirm);

			case "--purge-old-kernels":	// back compat
			case "--uninstall-old":
				return LinuxKernel.kunin_old(App.confirm);

			case "--clean-cache": // back compat
			case "--delete-cache":
				LinuxKernel.delete_cache();
				break;

			case "--download":
				return LinuxKernel.download_klist(LinuxKernel.vlist_to_klist(vlist,true));

			case "--uninstall":
				return LinuxKernel.uninstall_klist(LinuxKernel.vlist_to_klist(vlist,true));

			case "--install":
				return LinuxKernel.install_klist(LinuxKernel.vlist_to_klist(vlist,true));

			default:
				vprint(_("Unknown option") + ": \""+cmd+"\"",1,stderr);
				vprint(help,0);
				return 1;
		}

		return 0;
	}

	private void print_updates() {
		LinuxKernel.mk_kernel_list(true);
		var km = LinuxKernel.kernel_update_major;
		var kp = LinuxKernel.kernel_update_minor;
		if (km != null) vprint(_("Latest update")+": "+km.version_main);
		if (kp != null) vprint(_("Latest point update")+": "+kp.version_main);
		if ((km == null) && (kp == null)) vprint(_("No updates found"));
	}

	private int notify_user() {
		vprint("notify_user()",2);

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
			if (file_exists(App.MINOR_SEEN_FILE)) seen = file_read(App.MINOR_SEEN_FILE).strip();
			if (seen!=available) file_write(App.MINOR_SEEN_FILE,available);
		} else vprint(_("notify point releases disabled"),2);

		// if notify_major enabled and there is one, simply overwrite available
		if (App.notify_major) {
			var k = LinuxKernel.kernel_update_major;
			if (k!=null && k.version_main!="") available = k.version_main;
			if (file_exists(App.MAJOR_SEEN_FILE)) seen = file_read(App.MAJOR_SEEN_FILE).strip();
			if (seen!=available) file_write(App.MAJOR_SEEN_FILE,available);
		} else vprint(_("notify major releases disabled"),2);

		if (seen==available) available = "";

		if (available!="") {
			title = _("Kernel %s Available").printf(available);
			string close_action = ""; // command to run when user closes notification without pressing any action button
			string body = ""; // notification message body
			var alist = new Gee.ArrayList<string> (); // notification action buttons:  "buttonlabel:command line to run"
			alist.add(_("Show")+":"+BRANDING_SHORTNAME+"-gtk");
			alist.add(_("Install")+":"+BRANDING_SHORTNAME+"-gtk --install "+available);
			OSDNotify.notify_send(title,body,alist,close_action);
		} else {
			if (seen!="") title = _("Previously notified")+": \""+seen+"\"";
		}

		vprint(title,2);
		return 0;
	}

}
