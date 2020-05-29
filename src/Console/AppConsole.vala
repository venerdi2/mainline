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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;

public Main App;

public class AppConsole : GLib.Object {

	public static int main (string[] args) {
		
		set_locale();

		log_msg(BRANDING_SHORTNAME+" "+BRANDING_VERSION);

		App = new Main(args, false);
		
		var console =  new AppConsole();
		bool is_success = console.parse_arguments(args);

		return (is_success) ? 0 : 1;
	}

	private static void set_locale() {
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, "%s".printf(BRANDING_SHORTNAME));
		Intl.textdomain(BRANDING_SHORTNAME);
		Intl.bind_textdomain_codeset(BRANDING_SHORTNAME, "utf-8");
		Intl.bindtextdomain(BRANDING_SHORTNAME, LOCALE_DIR);
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
		+ "  --install <name>    " + _("Install specified mainline kernel") + "(1)\n"
		+ "  --remove <name>     " + _("Uninstall specified kernels") + "(2)\n"
		+ "  --purge-old-kernels " + _("Remove installed kernels older than running kernel") + "\n"
		+ "  --download <name>   " + _("Download specified kernels") + "(2)\n"
		+ "  --clean-cache       " + _("Remove files from application cache") + "\n"
		+ "  --show-unstable     " + _("Show unstable and RC releases") + "\n"
		+ "\n"
		+ _("Options") + ":\n"
		+ "\n"
		+ "  --debug           " + _("Enable verbose debugging output") + "\n"
		+ "  --yes             " + _("Assume Yes for all prompts (non-interactive mode)") + "\n"
		+ "  --user            " + _("Override user") + "\n"
		+ "\n"
		+ "Notes:\n"
		+ "(1) " +_("A version string taken from the output of --list") + "\n"
		+ "(2) " +_("One or more version strings (comma-separated) taken from the output of --list") + "\n";
		return msg;
	}

	public bool parse_arguments(string[] args) {

		string txt = BRANDING_SHORTNAME + " ";
		for (int k = 1; k < args.length; k++) {
			txt += "'%s' ".printf(args[k]);
		}

		// check argument count -----------------

		if (args.length == 1) {
			log_msg(help_message());
			return false;
		}

		string cmd = "";
		string cmd_versions = "";
			
		// parse options first --------------
		
		for (int k = 1; k < args.length; k++)
		{
			switch (args[k].down()) {
			case "--debug":
				LOG_DEBUG = true;
				break;

			case "--yes":
				App.confirm = false;
				break;

			case "--user":
				if (++k < args.length){
					string custom_user_login = args[k];
					App.init_paths(custom_user_login);
					App.load_app_config();
				}
				break;

			case "--list":
			case "--list-installed":
			case "--check":
			case "--notify":
			case "--install-latest":
			case "--install-point":
			case "--purge-old-kernels":
			case "--clean-cache":
				cmd = args[k].down();
				break;
			
			case "--show-unstable":
				App.hide_unstable = false;
				break;

			case "--download":
			case "--install":
			case "--remove":
				cmd = args[k].down();
				
				if (++k < args.length){
					cmd_versions = args[k];
				}
				break;

			case "--help":
			case "--h":
			case "-h":
				log_msg(help_message());
				return true;
				
			default:
				// unknown option
				log_error(_("Unknown option") + ": %s".printf(args[k]));
				// FIXME use argv[0] instead of hardcoded app name
				log_error(_("Run")+" '"+BRANDING_SHORTNAME+" --help' "+_("to list all options"));
				return false;
			}
		}

		// run command --------------------------------------

		switch (cmd) {
		case "--list":

			check_if_internet_is_active(false);
			
			LinuxKernel.query(true);
			
			LinuxKernel.print_list();

			break;

		case "--list-installed":
		
			LinuxKernel.check_installed();
			
			break;

		case "--check":

			print_updates();

			break;

		case "--notify":

			notify_user();
			
			break;

		case "--install-latest":
		case "--install-point":

			check_if_internet_is_active(true);

			LinuxKernel.install_latest(false, App.confirm);
			
			break;

		case "--purge-old-kernels":

			LinuxKernel.purge_old_kernels(App.confirm);

			break;
			
		case "--clean-cache":

			LinuxKernel.clean_cache();
			
			break;

		case "--download":
		case "--install":
		case "--remove":
			if (cmd=="--download") check_if_internet_is_active();

			LinuxKernel.query(true);

			if (cmd_versions.length==0){
				log_error(_("No kernels specified"));
				exit(1);
			}

			string[] requested_versions = cmd_versions.split(",");
			if ((requested_versions.length > 1) && (cmd == "--install")){
				log_error(_("Multiple kernels selected for installation. Select only one."));
				exit(1);
			}

			var list = new Gee.ArrayList<LinuxKernel>();

			foreach(string requested_version in requested_versions){
				LinuxKernel kern_requested = null;
				foreach(var kern in LinuxKernel.kernel_list){
					// match --list output
					if (kern.version_main == requested_version){
						kern_requested = kern;
						break;
					}
				}

				if (kern_requested == null){
					
					var msg = _("Could not find requested version");
					msg += ": %s".printf(requested_version);
					log_error(msg);
					log_error(_("Run")+" '"+BRANDING_SHORTNAME+" --list' "+_("and use a version string listed in first column"));
					exit(1);
				}

				list.add(kern_requested);
			}

			if (list.size == 0){
				log_error(_("No kernels specified"));
				exit(1);
			}

			switch(cmd){
			case "--download":
				return LinuxKernel.download_kernels(list);
	
			case "--remove":
				return LinuxKernel.remove_kernels(list);
				
			case "--install":
				return list[0].install();
			}

			break;
			
		default:
			// unknown option
			log_error(_("Command not specified"));
			log_error(_("Run")+" '"+BRANDING_SHORTNAME+" --help' "+_("to list all commands"));
			break;
		}

		return true;
	}

	private void print_updates(){

		check_if_internet_is_active(false);
				
		LinuxKernel.query(true);

		// already done in query() -> query_thread() ?
		//LinuxKernel.check_updates("print_updates()");
		//LinuxKernel.check_updates();

		var kern_major = LinuxKernel.kernel_update_major;
		
		if (kern_major != null){
			var message = "%s: %s".printf(_("Latest update"), kern_major.version_main);
			log_msg(message);
		}

		var kern_minor = LinuxKernel.kernel_update_minor;

		if (kern_minor != null){
			var message = "%s: %s".printf(_("Latest point update"), kern_minor.version_main);
			log_msg(message);
		}

		if ((kern_major == null) && (kern_minor == null)){
			log_msg(_("No updates found"));
		}

		log_msg(string.nfill(70, '-'));
	}

	private void notify_user(){

		check_if_internet_is_active(false);

		LinuxKernel.query(true);

		// already done in query() -> query_thread() ?
		//LinuxKernel.check_updates("notify_user()");
		//LinuxKernel.check_updates();

		string seen_maj = "";
		string seen_min = "";
		if (file_exists(App.MAJ_SEEN_FILE)) seen_maj = file_read(App.MAJ_SEEN_FILE).strip();
		if (file_exists(App.MIN_SEEN_FILE)) seen_min = file_read(App.MIN_SEEN_FILE).strip();
		log_msg("seen_maj:\""+seen_maj+"\"");
		log_msg("seen_min:\""+seen_min+"\"");

		string debug_action = "";
		string close_action = "";  // command to run when user closes notification instead of pressing any action button
		string body = "";
		var alist = new Gee.ArrayList<string> (); // notification action buttons:  "buttonlabel:command line to run"

		if (App.notify_major || App.notify_minor) {
			if (LOG_DEBUG) {
				debug_action = APP_LIB_DIR+"/notify-action-debug.sh";
				body = debug_action;
				debug_action += " ";
			}
			alist.add(_("Show")+":"+debug_action+BRANDING_SHORTNAME+"-gtk");
		}

		var kern = LinuxKernel.kernel_update_major;
		if (App.notify_major && (kern!=null) && (seen_maj!=kern.version_main)){
			var title = _("Kernel %s Available").printf(kern.version_main);
			if (App.notify_major || App.notify_minor){
				alist.add(_("Install")+":"+debug_action+BRANDING_SHORTNAME+"-gtk --install "+kern.version_main);
				file_write(App.MAJ_SEEN_FILE,kern.version_main);
				OSDNotify.notify_send(title,body,alist,close_action);
			}
			log_msg(title);
			return;
		}

		kern = LinuxKernel.kernel_update_minor;
		if (App.notify_minor && (kern!=null) && (seen_min!=kern.version_main)){
			var title = _("Kernel %s Available").printf(kern.version_main);
			if (App.notify_major || App.notify_minor) {
				alist.add(_("Install")+":"+debug_action+BRANDING_SHORTNAME+"-gtk --install "+kern.version_main);
				file_write(App.MIN_SEEN_FILE,kern.version_main);
				OSDNotify.notify_send(title,body,alist,close_action);
			}
			log_msg(title);
			return;
		}

		log_msg(_("No updates found"));
	}

	public void check_if_internet_is_active(bool exit_app = true){
		if (!check_internet_connectivity()){
			if (exit_app){
				exit(1);
			}
		}
	}
}
