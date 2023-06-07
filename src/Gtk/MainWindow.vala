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
using l.misc;

public class MainWindow : Window {

	private Box vbox_main;
	private Box hbox_list;

	private Button btn_install;
	private Button btn_uninstall;
	private Button btn_uninstall_old;
	private Button btn_reload;
	private Label lbl_info;
	private bool updating;

	private Gee.ArrayList<LinuxKernel> selected_kernels;
	private Gtk.ListStore tm;
	private TreeView tv;

	private Gdk.Pixbuf pix_ubuntu;
	private Gdk.Pixbuf pix_mainline;
	private Gdk.Pixbuf pix_mainline_rc;

	enum TM {
		INDEX,
		KERN,
		ICON,
		VERSION,
		LOCKED,
		STATUS,
		NOTES,
		TOOLTIP,
		N_COLS
	}

	public MainWindow() {
		set_default_size(App.window_width,App.window_height);
		if (App.window_x>=0 && App.window_y>=0) move(App.window_x,App.window_y);

		configure_event.connect ((event) => {
			App.window_width = event.width;
			App.window_height = event.height;
			App.window_x = event.x;
			App.window_y = event.y;
			return false;
		});

		title = BRANDING_LONGNAME;
		icon = get_app_icon(16);

		// vbox_main
		vbox_main = new Box(Orientation.VERTICAL, 6);
		vbox_main.margin = 6;

		add(vbox_main);

		selected_kernels = new Gee.ArrayList<LinuxKernel>();
		tm = new Gtk.ListStore(TM.N_COLS, typeof(int), typeof(LinuxKernel), typeof(Gdk.Pixbuf), typeof(string), typeof(bool), typeof(string), typeof(string), typeof(string));
		tv = new TreeView.with_model(tm);

		try {
			pix_ubuntu = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/ubuntu-logo.png");
			pix_mainline = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux.png");
			pix_mainline_rc = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux-red.png");
		} catch (Error e) { vprint(e.message,1,stderr); }

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
		vbox_main.add(hbox_list);

		// add treeview
		tv.get_selection().mode = SelectionMode.MULTIPLE;
		tv.headers_visible = true;
		tv.set_grid_lines(TreeViewGridLines.BOTH);
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
		col.set_sort_column_id(TM.INDEX);
		col.min_width = 180;
		tv.append_column(col);

		var k_version_icon = new CellRendererPixbuf();
		k_version_icon.xpad = 4;
		k_version_icon.ypad = 6;
		col.pack_start(k_version_icon, false);
		col.add_attribute(k_version_icon, "pixbuf", TM.ICON);

		var k_version_text = new CellRendererText();
		k_version_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start(k_version_text, true);
		col.add_attribute(k_version_text, "text", TM.VERSION);

		// locked
		var k_lock_toggle = new CellRendererToggle();
#if LOCK_TOGGLES_IN_KERNEL_COLUMN  // not sortable
		col.pack_end(k_lock_toggle, false);
#else  // sortable
		col = new TreeViewColumn();
		col.set_sort_column_id(TM.LOCKED);
		col.title = _("Lock");
		col.pack_start(k_lock_toggle, false);
		tv.append_column (col);
#endif
		col.add_attribute(k_lock_toggle,"active", TM.LOCKED);
		k_lock_toggle.toggled.connect((toggle,path) => {
			TreeIter iter;
			tm.get_iter_from_string(out iter, path);
			LinuxKernel k;
			tm.get(iter, TM.KERN, out k, -1);
			if (toggle.active) delete_r(k.locked_file);
			else file_write(k.locked_file, "");
			tm.set(iter, TM.LOCKED, k.is_locked);
		});

		// status
		col = new TreeViewColumn();
		col.title = _("Status");
		col.set_sort_column_id(TM.STATUS);
		col.resizable = true;
		col.min_width = 100;
		tv.append_column(col);
		var k_status_text = new CellRendererText();
		k_status_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start(k_status_text, true);
		col.add_attribute(k_status_text, "text", TM.STATUS); // text from column 4

		// notes
		col = new TreeViewColumn();
		col.title = _("Notes");
		col.set_sort_column_id(TM.NOTES);
		col.resizable = true;
		col.min_width = 100;
		tv.append_column(col);
		var k_notes_text = new CellRendererText();
		k_notes_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (k_notes_text, true);
		col.add_attribute(k_notes_text, "text", TM.NOTES); // text from column 5
		k_notes_text.editable = true;
		k_notes_text.edited.connect((path, data) => {
			TreeIter i;
			LinuxKernel k;
			tm.get_iter_from_string(out i, path);
			tm.get(i, TM.KERN, out k, -1);
			var t_old = k.notes.strip();
			var t_new = data.strip();
			if (t_old != t_new) {
				k.notes = t_new;
				if (t_new=="") delete_r(k.notes_file);
				else file_write(k.notes_file, t_new);
				tm.set(i, TM.NOTES, t_new, -1);
			}
		});

		// tooltip
		tv.set_tooltip_column(TM.TOOLTIP);

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

		int i = -1;
		Gdk.Pixbuf p;
		TreeIter iter;
		tm.clear();
		foreach (var k in LinuxKernel.kernel_list) {

			if (!k.is_installed) { // don't hide anything that's installed
				if (k.is_invalid) continue; // hide invalid
				if (k.version_rc>=0 && App.hide_unstable) continue; // hide unstable if settings say to
				if (k.version_major < LinuxKernel.THRESHOLD_MAJOR) continue; // hide versions older than settings threshold
			}

			tm.append(out iter); // add row

			tm.set(iter, TM.INDEX, ++i); // saves the special version number sorting built by compare_to()

			tm.set(iter, TM.KERN, k);

			p = pix_mainline;
			if (k.version_rc>=0) p = pix_mainline_rc;
			if (!k.is_mainline) p = pix_ubuntu;
			tm.set(iter, TM.ICON, p);

			tm.set(iter, TM.VERSION, k.version_main);

			tm.set(iter, TM.LOCKED, k.is_locked);

			tm.set(iter, TM.STATUS, k.status);

			tm.set(iter, TM.NOTES, k.notes);

			tm.set(iter, TM.TOOLTIP, k.tooltip_text());
		}

		selected_kernels.clear();
		updating = false;
		set_infobar();
		set_button_state();
	}

	private void set_button_state() {
		btn_install.sensitive = false;
		btn_uninstall.sensitive = false;

		if (updating) {
			btn_uninstall_old.sensitive = false;
			btn_reload.sensitive = false;
			return;
		}

		btn_uninstall_old.sensitive = true;
		btn_reload.sensitive = true;

		if (selected_kernels.size > 0) {
			foreach (var k in selected_kernels) {
				if (k.is_locked || k.is_running) continue;
				if (k.is_installed) btn_uninstall.sensitive = true;
				else btn_install.sensitive = true;
			}
		}
	}

	private void init_actions() {

		Button button;

		var hbox = new Box(Orientation.VERTICAL, 6);
		hbox_list.add (hbox);

		// install
		btn_install = new Button.with_label (_("Install"));
		hbox.pack_start (btn_install, true, true, 0);
		btn_install.clicked.connect(() => { do_install(selected_kernels); });

		// uninstall
		btn_uninstall = new Button.with_label (_("Uninstall"));
		hbox.pack_start (btn_uninstall, true, true, 0);
		btn_uninstall.clicked.connect(() => { do_uninstall(selected_kernels); });

		// ppa
		button = new Button.with_label ("PPA");
		button.set_tooltip_text(_("Changelog, build status, etc"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(() => {
			string uri = App.ppa_uri;
			if (selected_kernels.size==1 && selected_kernels[0].is_mainline) uri=selected_kernels[0].page_uri;
			uri_open(uri);
		});

		// uninstall-old
		btn_uninstall_old = new Button.with_label (_("Uninstall Old"));
		btn_uninstall_old.set_tooltip_text(_("Uninstall all but the highest installed version"));
		hbox.pack_start (btn_uninstall_old, true, true, 0);
		btn_uninstall_old.clicked.connect(uninstall_old);

		// reload
		btn_reload = new Button.with_label (_("Reload"));
		btn_reload.set_tooltip_text(_("Delete and reload all cached kernel info"));
		hbox.pack_start (btn_reload, true, true, 0);
		btn_reload.clicked.connect(reload_cache);

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
		button.clicked.connect(Gtk.main_quit);

	}

	private void do_settings () {
		// settings that change the selection set -> trigger cache update
		var old_previous_majors = App.previous_majors;
		var old_hide_unstable = App.hide_unstable;
		// settings that change the notification behavior -> trigger notify script update
		var old_notify_interval_unit = App.notify_interval_unit;
		var old_notify_interval_value = App.notify_interval_value;
		var old_notify_major = App.notify_major;
		var old_notify_minor = App.notify_minor;

		var dlg = new SettingsDialog.with_parent(this);
		dlg.run();
		dlg.destroy();

		App.save_app_config();

		// By default the notify script will be flagged to (re)run itself
		// simply because settings were saved at all. It is not run immediately,
		// only flagged to be run at the end of cache update.

		// If no notifications settings changed, un-flag the notify script update.
		if (App.notify_interval_unit == old_notify_interval_unit &&
			App.notify_interval_value == old_notify_interval_value &&
			App.notify_major == old_notify_major &&
			App.notify_minor == old_notify_minor) App.RUN_NOTIFY_SCRIPT = false;

		// If the selection set didn't change, then don't update cache.
		// If we don't update cache, then we have to do the notify script now.
		if (App.previous_majors == old_previous_majors &&
			App.hide_unstable == old_hide_unstable) App.run_notify_script();
		else update_cache();
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
		string msg = _("Updating kernels");
		vprint(msg);

		if (!try_ppa()) return;

		updating = true;
		set_button_state();
		set_infobar(msg);
		LinuxKernel.mk_kernel_list(false, (timer, ref count, last) => {
			update_status_line(msg, timer, ref count, last);
		});
	}

	private void update_status_line(string message, GLib.Timer timer, ref int count, bool last = false) {
		count++;
		if (last) {
			Gdk.threads_add_idle_full(Priority.DEFAULT_IDLE, () => {
				tv_refresh();
				return false;
			});
			timer_elapsed(timer, true);
		}

		Gdk.threads_add_idle_full(Priority.DEFAULT_IDLE, () => {
			if (updating) set_infobar("%s %d/%d".printf(message, App.progress_count, App.progress_total));
			return false;
		});
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
		lbl_info.set_single_line_mode(true);
		lbl_info.selectable = false;
		hbox.add(lbl_info);
	}

	private void set_infobar(string s="") {
		if (s!="") { lbl_info.set_label(s); return; }

		string l = _("Running")+" <b>%s</b>".printf(LinuxKernel.kernel_active.version_main);
		if (LinuxKernel.kernel_active.is_mainline) l += " (mainline)";
		else l += " (ubuntu)";
		if (LinuxKernel.kernel_latest_available.compare_to(LinuxKernel.kernel_latest_installed) > 0)
			l += " ~ <b>%s</b> ".printf(LinuxKernel.kernel_latest_available.version_main)+_("available");

		lbl_info.set_label(l);
	}

	public void do_install(Gee.ArrayList<LinuxKernel> klist) {
		string vlist="";
		if (Main.VERBOSE>2) {
			foreach (var k in klist) vlist += k.version_main+" ";
			vprint("do_install("+vlist.strip()+")");
		}

		// if we jumped directly here from a notification, switch to normal interactive mode after this
		if (App.command == "install") App.command = "list";

		vlist = "";
		foreach (var k in klist) {
			if (k.is_installed) { vprint(k.version_main+" "+_("is already installed")); continue; }
			if (k.is_locked) { vprint(k.version_main+" "+_("is locked")); continue; }
			vprint(_("adding")+" "+k.version_main);
			vlist += " "+k.version_main;
		}
		vlist = vlist.strip();
		if (vlist=="") { vprint(_("Install: no installable kernels specified")); return; }

		bool did_update_cache = false;
		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.script_complete.connect(()=>{
			term.present();
			term.allow_window_close();
			did_update_cache = true;
			update_cache();
		});

		term.destroy.connect(()=>{
			delete_r(t_dir);
			if (!did_update_cache) update_cache();
		});

		string sh = "VERBOSE="+Main.VERBOSE.to_string()+" "+BRANDING_SHORTNAME;
			if (App.index_is_fresh) sh += " --index-is-fresh";
			sh += " --install \""+vlist+"\"\n"
			+ "echo '"+_("DONE")+"'\n"
			;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
	}

	public void do_uninstall(Gee.ArrayList<LinuxKernel> klist) {
		if (klist==null || klist.size<1) return;

		bool did_update_cache = false;
		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.script_complete.connect(()=>{
			term.present();
			term.allow_window_close();
			did_update_cache = true;
			update_cache();
		});

		term.destroy.connect(() => {
			delete_r(t_dir);
			if (!did_update_cache) update_cache();
		});

		string vlist = "";
		foreach(var k in klist) vlist += " "+k.version_main;
		vlist = vlist.strip();

		string sh = "VERBOSE="+Main.VERBOSE.to_string()+" "+BRANDING_SHORTNAME;
			if (App.index_is_fresh) sh += " --index-is-fresh";
			sh += " --uninstall \""+vlist+"\"\n"
			+ "echo '"+_("DONE")+"'\n"
			;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
	}

	public void uninstall_old () {
		bool did_update_cache = false;
		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.script_complete.connect(()=>{
			term.present();
			term.allow_window_close();
			did_update_cache = true;
			update_cache();
		});

		term.destroy.connect(()=>{
			delete_r(t_dir);
			if (!did_update_cache) update_cache();
		});

		string sh = "VERBOSE="+Main.VERBOSE.to_string()+" "+BRANDING_SHORTNAME+" --uninstall-old";
			if (App.index_is_fresh) sh += " --index-is-fresh";
			sh += "\n"
			+ "echo '"+_("DONE")+"'\n"
			;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
	}

}
