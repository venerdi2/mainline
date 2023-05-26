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

using GLib;
using Gee;
using Json;

using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;
using l.misc;

public Main App;

public class AppConsole : GLib.Object {

	public static int main (string[] args) {
		set_locale();
		App = new Main(args, false);
		var console = new AppConsole();
		bool is_success = console.parse_arguments(args);
		return (is_success) ? 0 : 1;
	}

	private static string help_message() {

		string msg = "\n" + BRANDING_SHORTNAME + " " + BRANDING_VERSION + " - " + BRANDING_LONGNAME + "\n"
		+ "\n"
		+ _("Syntax") + ": " + BRANDING_SHORTNAME + " <command> [options]\n"
		+ "\n"
		+ _("Commands") + ":\n"
		+ "\n"
		+ "  --check             " + _("Check for kernel updates") + "\n"
		+ "  --notify            " + _("Check for kernel updates and notify current user") + "\n"
		+ "  --list              " + _("List all available mainline kernels") + "\n"
		+ "  --list-installed    " + _("List installed kernels") + "\n"
		+ "  --install-latest    " + _("Install latest mainline kernel") + "\n"
		+ "  --install-point     " + _("Install latest point update for current series") + "\n"
		+ "  --install <name>    " + _("Install specified mainline kernel") + "(1)(3)\n"
		+ "  --uninstall <name>  " + _("Uninstall specified kernel") + "(1)(2)(3)\n"
		+ "  --uninstall-old     " + _("Uninstall all but the highest installed version") + "(3)\n"
		+ "  --download <name>   " + _("Download specified kernels") + "(2)\n"
		+ "  --delete-cache      " + _("Delete cached info about available kernels") + "\n"
		+ "\n"
		+ _("Options") + ":\n"
		+ "\n"
		+ "  --include-unstable  " + _("Include unstable and RC releases") + "\n"
		+ "  --exclude-unstable  " + _("Exclude unstable and RC releases") + "\n"
		+ "  --debug             " + _("Enable verbose debugging output") + "\n"
		+ "  --yes               " + _("Assume Yes for all prompts (non-interactive mode)") + "\n"
		+ "\n"
		+ "Notes:\n"
		+ "(1) " +_("A version string taken from the output of --list") + "\n"
		+ "(2) " +_("One or more, comma-seperated") + "\n"
		+ "(3) " +_("The currently running kernel will always be ignored") + "\n"
		;
		return msg;
	}

	public bool parse_arguments(string[] args) {

		string txt = BRANDING_SHORTNAME + " ";
		for (int i = 1; i < args.length; i++) txt += "'%s' ".printf(args[i]);

		// check argument count -----------------

		if (args.length == 1) {
			vprint(help_message(),0);
			return false;
		}

		string cmd = "";
		string cmd_versions = "";
		string a = "";

		// parse options first --------------

		for (int i = 1; i < args.length; i++)
		{
			a = args[i].down();
			switch (a) {
			case "--debug":
				App.VERBOSE = 2;
				l.misc.VERBOSE = 2;
				Environment.set_variable("VERBOSE","2",true);
				break;

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

			case "--remove":	// back compat
				cmd = "--uninstall";
				if (++i < args.length) cmd_versions = args[i];
				break;

			case "--uninstall":
			case "--download":
			case "--install":
				cmd = a;
				if (++i < args.length) cmd_versions = args[i];
				break;

			// which is better for no args ?
			case "":	// no args -> --list
				cmd = "--list";
				break;

			//case "":	// no args -> --help
			case "--help":
			case "-h":
			case "-?":
				vprint(help_message(),0);
				return true;

			default:
				// unknown option
				vprint(_("Unknown option") + ": %s".printf(args[i]),1,stderr);
				vprint(_("Run")+" '"+args[0]+" --help' "+_("to list all options"),1,stderr);
				return false;
			}
		}

		// run command --------------------------------------

		switch (cmd) {
		case "--list":
			LinuxKernel.query(true);
			LinuxKernel.print_list();
			break;

		case "--list-installed":
			Package.update_dpkg_list();
			LinuxKernel.check_installed();
			break;

		case "--check":
			print_updates();
			break;

		case "--notify":
			// silence VERBOSE only if it's 1
			if (App.VERBOSE==1) App.VERBOSE=0;
			l.misc.VERBOSE = App.VERBOSE;
			notify_user();
			break;

		case "--install-latest":
			LinuxKernel.kinst_latest(false, App.confirm);
			break;

		case "--install-point":
			LinuxKernel.kinst_latest(true, App.confirm);
			break;

		case "--purge-old-kernels":	// back compat
		case "--uninstall-old":
			LinuxKernel.kunin_old(App.confirm);
			break;

		case "--clean-cache": // back compat
		case "--delete-cache":
			LinuxKernel.delete_cache();
			break;

		case "--download":
		case "--install":
		case "--uninstall":

			// FIXME move this list-builder out of the switch

			if (cmd_versions.length==0) {
				vprint(_("No kernels specified"),1,stderr);
				exit(1);
			}

			string[] requested_versions = cmd_versions.split_set(",;:| ");
			if ((requested_versions.length > 1) && (cmd == "--install")) {
				vprint(_("Multiple kernels selected for installation. Select only one."),1,stderr);
				exit(1);
			}

			LinuxKernel.query(true);

			var list = new Gee.ArrayList<LinuxKernel>();

			foreach(string requested_version in requested_versions) {
				LinuxKernel kern_requested = null;
				foreach(var k in LinuxKernel.kernel_list) {
					// match --list output
					// FIXME version_main can dupe with mainline & distro pkgs of the same version
					// if cmd is uninstall, must also match k.is_installed
					// but if cmd is download or install, must IGNORE k.is_installed
					// extra FUGLY because this whole cmdline parser is redundant multi-pass junk
					if (k.version_main == requested_version && (cmd != "--uninstall" || k.is_installed)) {
						kern_requested = k;
						break;
					}
				}

				if (kern_requested == null) {
					var msg = _("Could not find requested version");
					msg += ": "+requested_version;
					vprint(msg,1,stderr);
					vprint(_("Run")+" '"+args[0]+" --list' "+_("and use a version string listed in first column"),1,stderr);
					exit(1);
				}

				list.add(kern_requested);
			}

			if (list.size == 0) {
				vprint(_("No kernels specified"),1,stderr);
				exit(1);
			}

			switch (cmd) {
			case "--download":
				return LinuxKernel.download_kernels(list);

			case "--uninstall":
				return LinuxKernel.kunin_list(list);

			case "--install":
				return list[0].kinst();
			}

			break;

		default:
			// unknown command
			vprint(_("Command not specified"),1,stderr);
			vprint(_("Run")+" '"+args[0]+" --help' "+_("to list all commands"),1,stderr);
			break;
		}

		return true;
	}

	private void print_updates() {

		LinuxKernel.query(true);

		var kern_major = LinuxKernel.kernel_update_major;
		
		if (kern_major != null) {
			var message = "%s: %s".printf(_("Latest update"), kern_major.version_main);
			vprint(message);
		}

		var kern_minor = LinuxKernel.kernel_update_minor;

		if (kern_minor != null) {
			var message = "%s: %s".printf(_("Latest point update"), kern_minor.version_main);
			vprint(message);
		}

		if ((kern_major == null) && (kern_minor == null)) {
			vprint(_("No updates found"));
		}

		vprint(line);
	}

	private void notify_user() {
		vprint("notify_user()",2);

		if (!App.notify_major && !App.notify_minor) {
			vprint(_("Notifications disabled in settings"),2);
			return;
		}

		LinuxKernel.query(true);

		string title = _("No updates found");
		string seen = "";
		string available = "";

		if (App.notify_minor) {
			var k = LinuxKernel.kernel_update_minor;
			if (k!=null && k.version_main!="") available = k.version_main;
			if (file_exists(App.MINOR_SEEN_FILE)) seen = file_read(App.MINOR_SEEN_FILE).strip();
			if (seen!=available) file_write(App.MINOR_SEEN_FILE,available);
		} else vprint("notify point releases disabled",2);

		// if notify_major enabled and there is one, simply overwrite available
		if (App.notify_major) {
			var k = LinuxKernel.kernel_update_major;
			if (k!=null && k.version_main!="") available = k.version_main;
			if (file_exists(App.MAJOR_SEEN_FILE)) seen = file_read(App.MAJOR_SEEN_FILE).strip();
			if (seen!=available) file_write(App.MAJOR_SEEN_FILE,available);
		} else vprint("notify major releases disabled",2);

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
	}

}
