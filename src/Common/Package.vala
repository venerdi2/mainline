
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;
using l.misc;

public class Package : GLib.Object {
	public string pname = "";
	public string version = "";
	public string arch = "";
	public bool is_installed = false;
	public static Gee.ArrayList<Package> dpkg_list = new Gee.ArrayList<Package>();

	public static void initialize() {
		new Package("");
	}

	public Package(string _name) {
		pname = _name;
	}

	public static void mk_dpkg_list() {
		vprint("mk_dpkg_list()",2);
		// get installed packages from dpkg --------------

		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir);
		string std_out, std_err;
		exec_sync("dpkg-query -f '${Package}|${Version}|${Architecture}|${db:Status-Abbrev}\n' -W 'linux-image-*' 'linux-modules-*' 'linux-headers-*'", out std_out, out std_err);
		file_write(t_file, std_out);

		// parse ------------------------

		try {
			string line;
			var file = File.new_for_path(t_file);
			if (file.query_exists()) {
				var dis = new DataInputStream(file.read());
				dpkg_list.clear();
				while ((line = dis.read_line(null)) != null) {
					string[] arr = line.split("|");
					if (arr.length != 4) continue;
					if (arr[3].substring(1,1) != "i" ) continue;

					string name = arr[0].strip();
					string vers = arr[1].strip();
					string arch = arr[2].strip();

					if (arch != LinuxKernel.NATIVE_ARCH && arch != "all" && arch != "any") continue;

					var p = new Package(name);
					p.version = vers;
					p.arch = arch;
					dpkg_list.add(p);
					vprint("dpkg_list.add("+p.pname+")  version:"+p.version+"  arch:"+p.arch,2);
				}
			} else {
				vprint(_("File not found: %s").printf(t_file),1,stderr);
			}
		}
		catch (Error e) {
			vprint(e.message,1,stderr);
		}
		dir_delete(t_dir);
	}
}
