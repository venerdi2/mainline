/*
 * AppGtk.vala
 *
 * Copyright 2016 Tony George <teejee2008@gmail.com>
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
using X;

using TeeJee.ProcessHelper;
using l.misc;

public Main App;

public class AppGtk : GLib.Object {

	public static int main (string[] args) {

		X.init_threads();
		Gtk.init(ref args);
		App = new Main(args, true);
		parse_arguments(args);

		// create main window --------------------------------------
		var appwin = new MainWindow();

		appwin.destroy.connect(Gtk.main_quit);

		appwin.show_all();

		Gtk.main();

		// window size basically always changes slightly even if you don't touch anything,
		// so don't bother detecting changes, just always re-write the config file on exit
		var x = App.RUN_NOTIFY_SCRIPT; // save whether run_notify was already pending
		App.save_app_config();         // this sets run_notify blindly but we don't need that just for window size change
		App.RUN_NOTIFY_SCRIPT = x;     // restore the original pending/not-pending state
		App.run_notify_script();       // in case it was pending and somehow missed along the way

		return 0;
	}

	public static bool parse_arguments(string[] args) {

		string help = ""
		+ "\n" + BRANDING_SHORTNAME + " " + BRANDING_VERSION + " - " + BRANDING_LONGNAME + "\n"
		+ "\n"
		+ _("Syntax") + ": " + BRANDING_SHORTNAME + "-gtk ["+_("options")+"]\n"
		+ "\n"
		+ _("Options") + ":\n"
		+ "\n"
		+ "  --debug      " + _("Print debug information") + "\n"
		+ "  --help       " + _("Show all options") + "\n"
		+ "\n"
		;

		// parse options
		for (int i = 1; i < args.length; i++)
		{
			switch (args[i].down()) {

			case "-v":
			case "--debug":
			case "--verbose":
				if (App.set_verbose(args[i+1])) i++;
				break;

			// this is the notification action
			case "--install":
				App.command = "install";
				if (++i < args.length) App.requested_versions = args[i].down();
				break;

			case "-?":
			case "-h":
			case "--help":
				vprint(help,0);
				exit(0);
				break;

			default:
				vprint(_("Unknown option") + ": %s".printf(args[i]),1,stderr);
				vprint(help,0);
				exit(1);
				break;

			}
		}

		return true;
	}
}
