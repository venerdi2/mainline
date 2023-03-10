
/*
 * TeeJee.Misc.vala
 *
 * Copyright 2016 Tony George <teejeetech@gmail.com>
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
 *
 *
 */
 
namespace TeeJee.Misc {

	/* Various utility functions */

	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.ProcessHelper;

	// timestamp ----------------

	public string timestamp (bool show_millis = false) {

		DateTime now = new GLib.DateTime.now_local();

		if (show_millis) {
			var msec = now.get_microsecond() / 1000;
			return "%s.%03d".printf(now.format("%H:%M:%S"), msec);
		} else {
			return now.format ("%H:%M:%S");
		}
	}

	public string timestamp_numeric() {
		return "%ld".printf((long) time_t ());
	}

	// string formatting -------------------------------------------------

	public string format_time_left(int64 millis) {
		double mins = (millis * 1.0) / 60000;
		double secs = ((millis * 1.0) % 60000) / 1000;
		string txt = "";
		if (mins >= 1) txt += "%.0fm ".printf(mins);
		txt += "%.0fs".printf(secs);
		return txt;
	}

	public string escape_html(string html, bool pango_markup = true) {
		string txt = html;

		if (pango_markup) {
			txt = txt
				.replace("\\u00", "")
				.replace("\\x"  , ""); 
		} else {
			txt = txt
				.replace(" ", "&nbsp;");  // pango markup throws an error with &nbsp;
		}

		txt = txt
				.replace("&" , "&amp;")
				.replace("\"", "&quot;")
				.replace("<" , "&lt;")
				.replace(">" , "&gt;")
				;

		return txt;
	}

	public string uri_decode(string path) {
		return Uri.unescape_string(path);
	}

	public string random_string(int length = 8, string charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"){
		string random = "";

		for(int i=0;i<length;i++) {
			int random_index = Random.int_range(0,charset.length);
			string ch = charset.get_char(charset.index_of_nth_char(random_index)).to_string();
			random += ch;
		}

		return random;
	}

	public MatchInfo? regex_match(string expression, string line) {

		Regex regex = null;

		try {
			regex = new Regex(expression);
		}
		catch (Error e) {
			log_error (e.message);
			return null;
		}

		MatchInfo match;
		if (regex.match(line, 0, out match)) {
			return match;
		} else {
			return null;
		}
	}

	private static void print_progress_bar_start(string message) {
		log_msg("\n%s\n".printf(message));
	}

	private static void print_progress_bar(double fraction) {

		string txt = "";

		double length = 30.0;

		double length_complete = fraction * length;

		double length_remaining = length - length_complete;

		if (length_complete > 0) {
			for(int i = 0; i < length_complete; i++) {
				txt += "▓";
			}
		}

		if (length_remaining > 0) {
			for(int i = 0; i < length_remaining; i++) {
				txt += "░";
			}
		}

		txt += " %0.0f %% ".printf(fraction * 100.0);

		stdout.printf("\r%s".printf(txt));
		stdout.flush();
	}

	private static void print_progress_bar_finish() {
		print_progress_bar(1.0);
		stdout.printf("\n\n");
		stdout.flush();
	}

}
