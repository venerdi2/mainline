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
using Gtk;
using Gee;
using Json;
using X;

using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using l.gtk;
using TeeJee.Misc;
using l.misc;

public Main App;

public class AppGtk : GLib.Object {

	public static int main (string[] args) {
		set_locale();
		X.init_threads();
		Gtk.init(ref args);
		App = new Main(args, true);
		parse_arguments(args);

		// create main window --------------------------------------
		var window = new MainWindow ();
		window.configure_event.connect ((event) => {
			App.window_width = event.width;
			App.window_height = event.height;
			App.window_x = event.x;
			App.window_y = event.y;
			return false;
		});

		window.destroy.connect(() => {
			vprint("MainWindow destroyed",4);
			Gtk.main_quit();
		});

		window.delete_event.connect((event) => {
			vprint("MainWindow closed",4);
			Gtk.main_quit();
			return true;
		});

		window.show_all();

		// start event loop -------------------------------------

		Gtk.main();

		// save the window size if it changed
		if (
				App.window_width != App._window_width
				|| App.window_height != App._window_height
				|| App.window_x != App._window_x
				|| App.window_y != App._window_y
				|| App.term_width != App._term_width
				|| App.term_height != App._term_height
				//|| App.term_x != App._term_x
				//|| App.term_y != App._term_y
			) App.save_app_config();

		// start the notification background process if any notifcations are enabled
		if (App.notify_major || App.notify_minor) exec_async("bash "+App.STARTUP_SCRIPT_FILE+" 2>&- >&- <&-");

		return 0;
	}

	public static bool parse_arguments(string[] args) {

		// parse options
		for (int i = 1; i < args.length; i++)
		{
			switch (args[i].down()) {

			case "-v":
			case "--debug":
			case "--verbose":
				int v = App.VERBOSE;
				if (args[i+1]==null || args[i+1].has_prefix("-")) v++;
				else if (++i < args.length) v = int.parse(args[i]);
				App.VERBOSE = v;
				l.misc.VERBOSE = v;
				Environment.set_variable("VERBOSE",v.to_string(),true);
				//vprint("verbose="+App.VERBOSE.to_string());
				break;

			// this is the notification action
			case "--install":
				App.command = "install";
				if (++i < args.length) App.requested_versions = args[i].down();
				break;

			case "--help":
			case "--h":
			case "-h":
				vprint(help_message(),0);
				exit(0);
				break;

			default:
				vprint(_("Unknown option") + ": %s".printf(args[i]),1,stderr);
				vprint(help_message(),0);
				exit(1);
				break;

			}
		}

		return true;
	}

	public static string help_message() {
		string msg = "\n" + BRANDING_SHORTNAME + " " + BRANDING_VERSION + " - " + BRANDING_LONGNAME + "\n";
		msg += "\n";
		msg += _("Syntax") + ": " + BRANDING_SHORTNAME + "-gtk ["+_("options")+"]\n";
		msg += "\n";
		msg += _("Options") + ":\n";
		msg += "\n";
		msg += "  --debug      " + _("Print debug information") + "\n";
		msg += "  --help       " + _("Show all options") + "\n";
		msg += "\n";
		return msg;
	}
}
