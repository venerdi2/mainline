using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using TeeJee.Misc;

public class Package : GLib.Object {
	public string id = "";
	public string pname = "";
	public string arch = "";
	public string version = "";
	public string version_installed = "";

	public bool is_installed = false;

	public static string NATIVE_ARCH = "";

	public static void initialize() {
	}

	public Package(string _name) {
		pname = _name;
	}

	public static string get_id(string _name, string _arch) {
		log_debug("get_id("+_name+","+_arch+")");
		string str = "";
		str = "%s".printf(_name);
		if (check_if_foreign(_arch)){
			str = str + ":%s".printf(_arch); // make it unique
		}
		return str;
	}

	public static bool check_if_foreign(string architecture) {
		log_debug("check_if_foreign("+architecture+")");
		if ((architecture.length > 0) && (architecture != NATIVE_ARCH) && (architecture != "all") && (architecture != "any")) {
			return true;
		} else {
			return false;
		}
	}

	public static Gee.HashMap<string,Package> query_installed_packages() {
		log_debug("query_installed_packages()");

		var list = new Gee.HashMap<string,Package>();

		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir);

		// get installed packages from aptitude --------------

		string std_out, std_err;
		exec_sync("aptitude search --disable-columns -F '%p|%v' '?installed'", out std_out, out std_err);
		file_write(t_file, std_out);
/*
linux-headers-5.6.10-050610|5.6.10-050610.202005052153
linux-headers-5.6.10-050610-generic|5.6.10-050610.202005052153
linux-image-unsigned-5.3.0-51-generic|5.3.0-51.44
linux-image-unsigned-5.6.10-050610-generic|5.6.10-050610.202005052153
*/
		// parse ------------------------

		try {
			string line;
			var file = File.new_for_path (t_file);
			if (file.query_exists ()) {
				var dis = new DataInputStream (file.read());
				while ((line = dis.read_line (null)) != null) {
					string[] arr = line.split("|");
					if (arr.length != 2) continue;

					string pname = arr[0].strip();
					string arch = (pname.contains(":")) ? pname.split(":")[1].strip() : "";
					if (pname.contains(":")) { pname = pname.split(":")[0]; }
					string version = arr[1].strip();

					string id = Package.get_id(pname,arch);

					Package pkg = null;
					if (!list.has_key(id)) {
						pkg = new Package(pname);
						pkg.arch = arch;
						pkg.id = Package.get_id(pkg.pname,pkg.arch);
						list[pkg.id] = pkg;
					}

					if (pkg != null){
						pkg.is_installed = true;
						pkg.version_installed = version;
					}
				}
			}
			else {
				log_error (_("File not found: %s").printf(t_file));
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
		file_delete(t_file);
		dir_delete(t_dir);
		return list;
	}
}
