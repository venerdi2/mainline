
/*
 * TeeJee.ProcessHelper.vala
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

namespace TeeJee.ProcessHelper {
	using TeeJee.FileSystem;
	using TeeJee.Misc;
	using l.misc;

	// temp files -------------------------------------

	// create a unique temp dir rooted at App.TMP_PREFIX
	// return full path to created dir
	public string create_tmp_dir() {
		string d = App.TMP_PREFIX+"."+random_string();
		dir_create(d);
		return d;
	}

	// TODO replace with mkstemp
	public string get_temp_file_path(string d) {
		return d + "/" + "%ld".printf((long) time_t()) + (new Rand()).next_int().to_string();
	}

	// create a temporary bash script
	// return the script file path
	public string? save_bash_script_temp (string cmds, string? file = null) {

		string f = file;
		if ((file == null) || (file.length == 0)) {
			string t_dir = create_tmp_dir();
			f = get_temp_file_path(t_dir) + ".sh";
		}

		vprint("save_bash_script_temp("+file+"):"+f,3);

		string s = "#!/bin/bash\n"
		+ cmds + "\n";

		if (file_write(f,s)) {
			GLib.FileUtils.chmod (f, 0755);
			return f;
		}
		return null;
	}

}
