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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public Main App;

public class AppGtk : GLib.Object {

	public static int main (string[] args) {
		
		set_locale();

		log_msg("%s %s".printf(BRANDING_SHORTNAME, BRANDING_VERSION));

		X.init_threads();

		Gtk.init(ref args);

		App = new Main(args, true);

		parse_arguments(args);

		// create main window --------------------------------------

		var window = new MainWindow ();

		window.configure_event.connect ((event) => {
			//log_debug("resize: %dx%d@%dx%d".printf(event.width,event.height,event.x,event.y));
			App.window_width = event.width;
			App.window_height = event.height;
			App.window_x = event.x;
			App.window_y = event.y;
			return false;
		});

		window.destroy.connect(() => {
			log_debug("MainWindow destroyed");
			Gtk.main_quit();
		});

		window.delete_event.connect((event) => {
			log_debug("MainWindow closed");
			Gtk.main_quit();
			return true;
		});

		window.show_all();

		// start event loop -------------------------------------

		Gtk.main();

		// save the window size if it changed
		if (
				App.window_width != App._window_width ||
				App.window_height != App._window_height ||
				App.window_x != App._window_x ||
				App.window_y != App._window_y
			) App.save_app_config();

		// possible future option - delete cache on every startup and exit
		// do not do this without rigging up a way to suppress it when the gui app runs the console app
		// like --index-is-fresh but maybe --keep-index or --batch
		//LinuxKernel.delete_cache();

		//log_debug("END AppGtk main()");
		return 0;
	}

	private static void set_locale() {
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, BRANDING_SHORTNAME);
		Intl.textdomain(BRANDING_SHORTNAME);
		Intl.bind_textdomain_codeset(BRANDING_SHORTNAME, "utf-8");
		Intl.bindtextdomain(BRANDING_SHORTNAME, LOCALE_DIR);
	}

	public static bool parse_arguments(string[] args) {

		// parse options
		for (int k = 1; k < args.length; k++)
		{
			switch (args[k].down()) {

			case "--debug":
				LOG_DEBUG = true;
				break;

			case "--help":
			case "--h":
			case "-h":
				log_msg(help_message());
				exit(0);
				break;

			default:
				log_error(_("Unknown option") + ": %s".printf(args[k]));
				log_msg(help_message());
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
