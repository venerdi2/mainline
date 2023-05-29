/*
 * MainWindow.vala
 *
 * Copyright 2012 Tony George <teejee2008@gmail.com>
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

using Gtk;

using TeeJee.FileSystem;
using TeeJee.ProcessHelper;
using l.gtk;
using TeeJee.Misc;
using l.misc;

public class MainWindow : Window {

	private Box vbox_main;
	private Box hbox_list;

	private Button btn_install;
	private Button btn_uninstall;
	private Label lbl_info;

	private Gtk.ListStore tm;
	private TreeView tv;
	private Gee.ArrayList<LinuxKernel> selected_kernels;

	enum COL {
		INDEX,
		KERN,
		ICON,
		VERSION,
		LOCKED,
		STATUS,
		NOTES,
		TOOLTIP
	}

	public MainWindow() {

		title = BRANDING_LONGNAME;
		//window_position = WindowPosition.CENTER;
		window_position = WindowPosition.NONE;
		icon = get_app_icon(16);

		// vbox_main
		vbox_main = new Box(Orientation.VERTICAL, 6);
		vbox_main.margin = 6;
		vbox_main.set_size_request(App._window_width,App._window_height);
		App._window_width = App.window_width;
		App._window_height = App.window_height;
		add(vbox_main);

		selected_kernels = new Gee.ArrayList<LinuxKernel>();

		//                        0 index      1 kernel             2 kernel-icon       3 version       4 locked      5 status        6 notes         7 tooltip
		tm = new Gtk.ListStore(8, typeof(int), typeof(LinuxKernel), typeof(Gdk.Pixbuf), typeof(string), typeof(bool), typeof(string), typeof(string), typeof(string));
		tv = new TreeView.with_model(tm);

		init_ui();
		if (App.command == "install") do_install(LinuxKernel.vlist_to_klist(App.requested_versions));
		update_cache();
	}

	private void init_ui() {
		init_treeview();
		init_actions();
		init_infobar();

		this.resize(App.window_width,App.window_height);
		if (App.window_x >=0 && App.window_y >= 0) this.move(App.window_x,App.window_y);
		App._window_x = App.window_x;
		App._window_y = App.window_y;
	}

	private void init_treeview() {

		// hbox
		hbox_list = new Box(Orientation.HORIZONTAL, 6);
		// hbox.margin = 6;
		vbox_main.add(hbox_list);

		// add treeview
		tv.get_selection().mode = SelectionMode.MULTIPLE;
		tv.headers_visible = true;
		tv.set_grid_lines(BOTH);
		tv.expand = true;

		tv.row_activated.connect(tv_row_activated);

		tv.get_selection().changed.connect(tv_selection_changed);

		var scrollwin = new ScrolledWindow(((Scrollable) tv).get_hadjustment(), ((Scrollable) tv).get_vadjustment());
		scrollwin.set_shadow_type(ShadowType.ETCHED_IN);
		scrollwin.add (tv);
		hbox_list.add(scrollwin);

		// kernel icon & version
		// sort on the index column not on the version column
		// special version number sorting built by compare_to()
		var col = new TreeViewColumn();
		col.title = _("Kernel");
		col.resizable = true;
		col.set_sort_column_id(COL.INDEX);
		col.min_width = 180;
		tv.append_column(col);

		var k_version_icon = new CellRendererPixbuf();
		k_version_icon.xpad = 4;
		k_version_icon.ypad = 6;
		col.pack_start(k_version_icon, false);
		col.add_attribute(k_version_icon, "pixbuf", COL.ICON);

		var k_version_text = new CellRendererText();
		k_version_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start(k_version_text, true);
		col.add_attribute(k_version_text, "text", COL.VERSION);

		// locked
		var k_lock_toggle = new CellRendererToggle();
#if LOCK_TOGGLES_IN_KERNEL_COLUMN  // not sortable
		col.pack_end(k_lock_toggle, false);
#else  // sortable
		col = new TreeViewColumn();
		col.set_sort_column_id(COL.LOCKED);
		col.title = _("Lock");
		col.pack_start(k_lock_toggle, false);
		tv.append_column (col);
#endif
		col.add_attribute(k_lock_toggle,"active", COL.LOCKED);
		k_lock_toggle.toggled.connect((toggle,path) => {
			TreeIter iter;
			tm.get_iter_from_string(out iter, path);
			LinuxKernel k;
			tm.get(iter, COL.KERN, out k, -1);
			if (toggle.active) file_delete(k.locked_file);
			else file_write(k.locked_file, "");
			tm.set(iter, COL.LOCKED, k.is_locked);
		});

		// status
		col = new TreeViewColumn();
		col.title = _("Status");
		col.set_sort_column_id(COL.STATUS);
		col.resizable = true;
		col.min_width = 100;
		tv.append_column(col);
		var k_status_text = new CellRendererText();
		k_status_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start(k_status_text, true);
		col.add_attribute(k_status_text, "text", COL.STATUS); // text from column 4

		// notes
		col = new TreeViewColumn();
		col.title = _("Notes");
		col.set_sort_column_id(COL.NOTES);
		col.resizable = true;
		col.min_width = 100;
		tv.append_column(col);
		var k_notes_text = new CellRendererText();
		k_notes_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (k_notes_text, true);
		col.add_attribute(k_notes_text, "text", COL.NOTES); // text from column 5
		k_notes_text.editable = true;
		k_notes_text.edited.connect((path, data) => {
			TreeIter i;
			LinuxKernel k;
			tm.get_iter_from_string(out i, path);
			tm.get(i, COL.KERN, out k, -1);
			var t_old = k.notes.strip();
			var t_new = data.strip();
			if (t_old != t_new) {
				k.notes = t_new;
				if (t_new=="") file_delete(k.notes_file);
				else file_write(k.notes_file, t_new);
				tm.set(i, COL.NOTES, t_new, -1);
			}
		});

		// tooltip
		tv.set_tooltip_column(COL.TOOLTIP);

	}

	private void tv_row_activated(TreePath path, TreeViewColumn column) {
		set_button_state();
	}

	private void tv_selection_changed() {
		TreeModel model;
		TreeIter iter;
		var sel = tv.get_selection();
		var paths = sel.get_selected_rows (out model);

		selected_kernels.clear();
		foreach (var path in paths) {
			LinuxKernel k;
			model.get_iter(out iter, path);
			model.get(iter, 1, out k, -1);
			selected_kernels.add(k);
		}

		set_button_state();
	}

	private void tv_refresh() {
		vprint("tv_refresh()",2);

		Gdk.Pixbuf pix_ubuntu = null;
		Gdk.Pixbuf pix_mainline = null;
		Gdk.Pixbuf pix_mainline_rc = null;
		try {
			pix_ubuntu = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/ubuntu-logo.png");
			pix_mainline = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux.png");
			pix_mainline_rc = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux-red.png");
		}
		catch (Error e) {
			vprint(e.message,1,stderr);
		}

		int i = -1;
		Gdk.Pixbuf p;
		TreeIter iter;
		tm.clear();
		foreach (var k in LinuxKernel.kernel_list) {

			if (!k.is_installed) { // don't hide anything that's installed
				if (k.is_invalid) continue; // hide invalid
				if (k.version_rc>=0 && App.hide_unstable) continue; // hide unstable if settings say to
				if (k.version_major < LinuxKernel.threshold_major) continue; // hide versions older than settings threshold
			}

			tm.append(out iter); // add row

			tm.set(iter, COL.INDEX, ++i); // saves the special version number sorting built by compare_to()

			tm.set(iter, COL.KERN, k);

			p = pix_mainline;
			if (k.version_rc>=0) p = pix_mainline_rc;
			if (!k.is_mainline) p = pix_ubuntu;
			tm.set(iter, COL.ICON, p);

			tm.set(iter, COL.VERSION, k.version_main);
			//tm.set(iter, COL.VERSION, k.kver);
			//tm.set(iter, COL.VERSION, k.kname);
			//tm.set(iter, COL.VERSION, k.kname.replace("linux-image-",""));

			tm.set(iter, COL.LOCKED, k.is_locked);

			tm.set(iter, COL.STATUS, k.status);

			tm.set(iter, COL.NOTES, k.notes);

			tm.set(iter, COL.TOOLTIP, k.tooltip_text());
		}

		selected_kernels.clear();
		set_button_state();
		set_infobar();
	}

	private void set_button_state() {
		btn_install.sensitive = false;
		btn_uninstall.sensitive = false;

		if (selected_kernels.size > 0) {
			foreach (var k in selected_kernels) {
				if (k.is_locked || k.is_running) continue;
				if (k.is_installed) btn_uninstall.sensitive = true;
				else btn_install.sensitive = true;
			}
		}
	}

	private void init_actions() {

		var hbox = new Box(Orientation.VERTICAL, 6);
		hbox_list.add (hbox);

		// install
		var button = new Button.with_label (_("Install"));
		hbox.pack_start (button, true, true, 0);
		btn_install = button;
		button.clicked.connect(() => {
			do_install(selected_kernels);
		});

		// uninstall
		button = new Button.with_label (_("Uninstall"));
		hbox.pack_start (button, true, true, 0);
		btn_uninstall = button;
		button.clicked.connect(() => {
			do_uninstall(selected_kernels);
		});

		// ppa
		button = new Button.with_label ("PPA");
		button.set_tooltip_text(_("Changelog, build status, etc"));
		hbox.pack_start (button, true, true, 0);

		button.clicked.connect(() => {
			string uri = App.ppa_uri;
			if (selected_kernels.size==1 && selected_kernels[0].is_mainline) uri += selected_kernels[0].kname;
			uri_open(uri);
		});

		// uninstall-old
		button = new Button.with_label (_("Uninstall Old"));
		button.set_tooltip_text(_("Uninstall all but the highest installed version"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(uninstall_old);

		// reload
		button = new Button.with_label (_("Reload"));
		button.set_tooltip_text(_("Delete and reload all cached kernel info"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(reload_cache);

		// settings
		button = new Button.with_label (_("Settings"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_settings);

		// about
		button = new Button.with_label (_("About"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_about);

		// exit
		button = new Button.with_label (_("Exit"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_exit);

	}

	private void do_settings () {
			int _previous_majors = App.previous_majors;
			bool _hide_unstable = App.hide_unstable;

			var dlg = new SettingsDialog.with_parent(this);
			dlg.run();
			dlg.destroy();

			if (
					(_previous_majors != App.previous_majors) ||
					(_hide_unstable != App.hide_unstable)
				) update_cache();
	}

	private void do_exit () {
		main_quit();
	}

	private void do_about () {

		var dialog = new AboutWindow();
		dialog.set_transient_for (this);

		// FIXME - this should come from the AUTHORS file, or from git
		dialog.authors = {
			"Tony George <teejeetech@gmail.com>",
			BRANDING_AUTHORNAME+" <"+BRANDING_AUTHOREMAIL+">"
		};

		// FIXME - generate this list from the .po files
		/*
		dialog.translators = {
			"name",
			"name",
			"name"
		};
		*/
		// For now, run "make TRANSLATORS"
		// then cut & paste from generated TRANSLATORS file
		// and add the quotes & commas
		dialog.translators = {
			"de: Marvin Meysel <marvin@meysel.net>",
			"el: Vasilis Kosmidis <skyhirules@gmail.com>",
			"es: Adolfo Jayme Barrientos <fitojb@ubuntu.com>",
			"fr: Yolateng0 <yo@yo.nohost.me>",
			"hr: gogo <trebelnik2@gmail.com>",
			"it: Demetrio Mendozzi",
			"ko: Kevin Kim <root@hamonikr.org>",
			"nl: Heimen Stoffels <vistausss@outlook.com>",
			"pl: Matthaiks",
			"ru: Danik2343 <krutalevex@mail.ru>",
			"sv: Åke Engelbrektson <eson@svenskasprakfiler.se>",
			"tr: Sabri Ünal <libreajans@gmail.com>",
			"uk: Serhii Golovko <cappelikan@gmail.com>"
		};

		dialog.documenters = null;
		dialog.artists = null;

		dialog.program_name = BRANDING_LONGNAME;
		dialog.comments = _("Kernel upgrade utility for Ubuntu-based distributions");
		dialog.copyright = _("Original")+": \"ukuu\" © 2015-18 Tony George\n"+_("Forked")+": \""+BRANDING_SHORTNAME+"\" 2019 "+BRANDING_AUTHORNAME+" ("+BRANDING_AUTHOREMAIL+")";
		dialog.version = BRANDING_VERSION;
		dialog.logo = get_app_icon(128);

		dialog.license = "This program is free for personal and commercial use and comes with absolutely no warranty. You use this program entirely at your own risk. The author will not be liable for any damages arising from the use of this program.";
		dialog.website = BRANDING_WEBSITE;
		dialog.website_label = BRANDING_WEBSITE;

		dialog.third_party = {
			"Elementary project (various icons):github.com/elementary/icons",
			"Tango project (various icons):tango.freedesktop.org/Tango_Desktop_Project",
			"notify-send.sh:github.com/bkw777/notify-send.sh"
		};

		dialog.initialize();
		dialog.show_all();
	}

	// Full re-load. Delete cache and clear session state and start over.
	private void reload_cache() {
		vprint("reload_cache()",2);
		LinuxKernel.delete_cache();
		App.ppa_tried = false;
		update_cache();
	}

	// Update the cache as optimally as possible.
	private void update_cache() {
		vprint("update_cache()",2);

		if (!try_ppa()) return;

		if (!App.GUI_MODE) {
			LinuxKernel.mk_kernel_list(true);
			return;
		}

		string message = _("Updating kernels");
		var progress_window = new ProgressWindow.with_parent(this, message, true);
		progress_window.show_all();
		LinuxKernel.mk_kernel_list(false, (timer, ref count, last) => {
			update_progress_window(progress_window, message, timer, ref count, last);
		});
	}

	private void update_progress_window(ProgressWindow progress_window, string message, GLib.Timer timer, ref long count, bool last = false) {
		if (last) {
			progress_window.destroy();
			Gdk.threads_add_idle_full(0, () => {
				tv_refresh();
				return false;
			});
			timer_elapsed(timer, true);
		}

		App.status_line = LinuxKernel.status_line;
		App.progress_total = LinuxKernel.progress_total;
		App.progress_count = LinuxKernel.progress_count;

		Gdk.threads_add_idle_full(0, () => {
			if (App.progress_total > 0)
				progress_window.update_message("%s %s/%s".printf(message, App.progress_count.to_string(), App.progress_total.to_string()));

			progress_window.update_status_line(); 
			return false;
		});

		count++;
	}

	private void init_infobar() {

		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		//scrolled.margin = 6;
		scrolled.margin_top = 0;
		scrolled.hscrollbar_policy = PolicyType.NEVER;
		scrolled.vscrollbar_policy = PolicyType.NEVER;
		vbox_main.add(scrolled);

		// hbox
		var hbox = new Box(Orientation.HORIZONTAL, 6);
		//hbox.margin = 6;
		scrolled.add(hbox);

		lbl_info = new Label("");
		lbl_info.margin = 6;
		lbl_info.set_use_markup(true);
		hbox.add(lbl_info);
	}

	private void set_infobar() {

		if (LinuxKernel.kernel_active != null) {

			lbl_info.label = _("Running")+" <b>%s</b>".printf(LinuxKernel.kernel_active.version_main);

			if (LinuxKernel.kernel_active.is_mainline) {
				lbl_info.label += " (mainline)";
			} else {
				lbl_info.label += " (ubuntu)";
			}

			if (LinuxKernel.kernel_latest_available.compare_to(LinuxKernel.kernel_latest_installed) > 0) {
				lbl_info.label += " ~ <b>%s</b> ".printf(LinuxKernel.kernel_latest_available.version_main)+_("available");
			}
		}
		else{
			lbl_info.label = _("Running")+" <b>%s</b>".printf(LinuxKernel.RUNNING_KERNEL);
		}
	}

	public void do_install(Gee.ArrayList<LinuxKernel> klist = new Gee.ArrayList<LinuxKernel>()) {
		string vlist="";
		if (App.VERBOSE>2) {
			foreach (var k in klist) vlist += k.version_main+" ";
			vprint("do_install("+vlist.strip()+")");
		}

		// if we jumped directly here from a notification, switch to normal interactive mode after this
		if (App.command == "install") App.command = "list";

		vlist = "";
		foreach (var k in klist) {
			vprint(k.version_main);
			if (k.is_installed) { vprint(k.version_main+" is already installed"); continue; }
			if (k.is_locked) { vprint(k.version_main+" is locked"); continue; }
			vprint("adding "+k.version_main);
			vlist += k.version_main+" ";
		}
		if (vlist=="") { vprint("no installable kernels specified"); return; }
		vprint("vlist=\""+vlist+"\"",3);

		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.configure_event.connect ((event) => {
			//vprint("term resize: %dx%d@%dx%d".printf(event.width,event.height,event.x,event.y),2);
			App.term_width = event.width;
			App.term_height = event.height;
//			App.term_x = event.x;
//			App.term_y = event.y;
			return false;
		});

		term.script_complete.connect(()=>{
			term.allow_window_close();
			dir_delete(t_dir);
		});

		term.destroy.connect(()=>{
			this.present();
			update_cache();
		});

		string sh = "VERBOSE="+App.VERBOSE.to_string()+" "+BRANDING_SHORTNAME;
			if (App.index_is_fresh) sh += " --index-is-fresh";
			sh += " --install \"" + vlist + "\"\n"
			+ "echo '"+_("DONE")+"'\n"
			;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
	}

	public void do_uninstall(Gee.ArrayList<LinuxKernel> klist) {
		if (klist==null || klist.size<1) return;

		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.configure_event.connect ((event) => {
			App.term_width = event.width;
			App.term_height = event.height;
			return false;
		});


		term.script_complete.connect(()=>{
			term.allow_window_close();
			dir_delete(t_dir);
		});

		term.destroy.connect(() => {
			this.present();
			update_cache();
		});

		string cmd_klist = "";
		foreach(var k in klist) {
			cmd_klist += k.version_main+" ";
		}

		string sh = "VERBOSE="+App.VERBOSE.to_string()+" "+BRANDING_SHORTNAME;
			if (App.index_is_fresh) sh += " --index-is-fresh";
			sh += " --uninstall \"" + cmd_klist + "\"\n"
			+ "echo '"+_("DONE")+"'\n"
			;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
	}

	public void uninstall_old () {
		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.configure_event.connect ((event) => {
			App.term_width = event.width;
			App.term_height = event.height;
			return false;
		});


		term.script_complete.connect(()=>{
			term.allow_window_close();
			dir_delete(t_dir);
		});

		term.destroy.connect(()=>{
			this.present();
			update_cache();
		});

		string sh = "VERBOSE="+App.VERBOSE.to_string()+" "+BRANDING_SHORTNAME+" --uninstall-old";
			if (App.index_is_fresh) sh += " --index-is-fresh";
			sh += "\n"
			+ "echo '"+_("DONE")+"'\n"
			;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
	}

}
