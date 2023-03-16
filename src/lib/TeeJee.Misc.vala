
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

	using TeeJee.FileSystem;
	using TeeJee.ProcessHelper;
	using l.misc;

	public string escape_html(string html, bool pango_markup = true) {
		string txt = html;

		if (pango_markup) {
			txt = txt
				.replace("\\u00", "")
				.replace("\\x"  , ""); 
		} else {
			txt = txt.replace(" ", "&nbsp;");  // pango markup throws an error with &nbsp;
		}

		txt = txt
				.replace("&" , "&amp;")
				.replace("\"", "&quot;")
				.replace("<" , "&lt;")
				.replace(">" , "&gt;")
				;

		return txt;
	}

	public string random_string(int length = 8, string charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890") {
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

		try { regex = new Regex(expression); }
		catch (Error e) { vprint(e.message,1,stderr); return null; }

		MatchInfo match;
		if (regex.match(line, 0, out match)) { return match; }
		else { return null; }
	}

}
