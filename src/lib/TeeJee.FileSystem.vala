
/*
 * TeeJee.FileSystem.vala
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

namespace TeeJee.FileSystem {

	using l.misc;

	public string file_parent(string f) {
		//vprint("file_parent("+f+")",4);
		return File.new_for_path(f).get_parent().get_path();
	}

	public string file_basename(string f) {
		//vprint("file_basename("+f+")",4);
		return File.new_for_path(f).get_basename();
	}

	public bool file_exists(string file_path) {
		//vprint("file_exists("+file_path+")",4);
		return (FileUtils.test(file_path, GLib.FileTest.EXISTS)
			&& !FileUtils.test(file_path, GLib.FileTest.IS_DIR));
	}

	public string? file_read(string file_path) {
		vprint("file_read("+file_path+")",3);

		string txt = "";
		size_t size;

		try { GLib.FileUtils.get_contents(file_path, out txt, out size); }
		catch (Error e) { vprint(e.message,1,stderr); }

		return txt;
	}

	public bool file_write(string path, string data) {
		vprint("file_write("+path+")",3);

		try {
			dir_create(file_parent(path));
			var file = File.new_for_path(path);
			var file_stream = file.replace(null, false, FileCreateFlags.REPLACE_DESTINATION);
			var data_stream = new DataOutputStream(file_stream);
			data_stream.put_string(data);
			data_stream.close();
			return true;
		} catch (Error e) {
			vprint(e.message,1,stderr);
			return false;
		}
	}

	public bool file_copy(string src_file, string dest_file) {
		vprint("file_copy('"+src_file+"','"+dest_file+"')",3);

		try {
			var file_src = File.new_for_path(src_file);
			if (file_src.query_exists()) {
				var file_dest = File.new_for_path(dest_file);
				file_src.copy(file_dest,FileCopyFlags.OVERWRITE,null,null);
				return true;
			}
		}
		catch (Error e) { vprint(e.message,1,stderr); }

		return false;
	}

	public void file_move(string src_file, string dest_file) {
		vprint("file_move('"+src_file+"','"+dest_file+"')",3);
		try {
			if (!file_exists(src_file)) {
				vprint(_("File not found") + ": '%s'".printf(src_file),1,stderr);
				return;
			}

			dir_create(file_parent(dest_file));

			var file_src = File.new_for_path(src_file);
			var file_dest = File.new_for_path(dest_file);
			if (file_exists(dest_file)) file_dest.delete();
			file_src.move(file_dest,FileCopyFlags.OVERWRITE,null,null);

		}
		catch (Error e) { vprint(e.message,1,stderr); }
	}

	public bool dir_create(string d) {
		vprint("dir_create("+d+")",3);
		try {
			var dir = File.parse_name(d);
			if (!dir.query_exists()) dir.make_directory_with_parents();
			return true;
		} catch (Error e) {
			vprint(e.message,1,stderr);
			return false;
		}
	}

}
