using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;

public class Package : GLib.Object {
	public string pname = "";
	public string arch = "";
	public string version = "";

	public bool is_installed = false;

	public static void initialize() {
	}

	public Package(string _name) {
		pname = _name;
	}

	public static Gee.HashMap<string,Package> query_installed_packages() {
		log_debug("query_installed_packages()");

		// get installed packages from dpkg --------------

		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir);
		string std_out, std_err;
		exec_sync("dpkg-query -f '${Package}|${Version}|${Architecture}|${db:Status-Abbrev}\n' -W 'linux-image-*' 'linux-modules-*' 'linux-headers-*'", out std_out, out std_err);
		file_write(t_file, std_out);

		// parse ------------------------

		var list = new Gee.HashMap<string,Package>();
		try {
			string line;
			var file = File.new_for_path (t_file);
			if (file.query_exists ()) {
				var dis = new DataInputStream (file.read());
				while ((line = dis.read_line (null)) != null) {
					string[] arr = line.split("|");
					if (arr.length != 4) continue;
					if (arr[3].substring(1,1) != "i" ) continue;

					string name = arr[0].strip();
					string vers = arr[1].strip();
					string arch = arr[2].strip();

					if (arch != LinuxKernel.NATIVE_ARCH && arch != "all" && arch != "any") continue;

					var pkg = new Package(name);
					pkg.version = vers;
					pkg.arch = arch;
					list[name] = pkg;

					//log_debug("pkg: "+pkg.pname+"|"+pkg.version+"|"+pkg.arch);

				}
			}
			else {
				log_error (_("File not found: %s").printf(t_file));
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
		dir_delete(t_dir);
		return list;
	}
}
