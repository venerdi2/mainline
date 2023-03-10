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
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class MainWindow : Gtk.Window {

	private Gtk.Box vbox_main;
	private Gtk.Box hbox_list;

	private Gtk.TreeView tv;
	private Gtk.Button btn_install;
	private Gtk.Button btn_uninstall;
	private Gtk.Button btn_changes;
	private Gtk.Button btn_ppa;
	private Gtk.Label lbl_info;

	// helper members

	private Gee.ArrayList<LinuxKernel> selected_kernels;

	public MainWindow() {

		title = BRANDING_LONGNAME;
		window_position = WindowPosition.CENTER;
		icon = get_app_icon(16);

		// vbox_main
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_main.margin = 6;

		vbox_main.set_size_request(App._window_width,App._window_height);
		App._window_width = App.window_width;
		App._window_height = App.window_height;

		add (vbox_main);

		selected_kernels = new Gee.ArrayList<LinuxKernel>();

		init_ui();

		update_cache();

		if (App.command == "install") {
			var k = new LinuxKernel.from_version(App.requested_version);
			do_install(k);
		}

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
		hbox_list = new Gtk.Box(Orientation.HORIZONTAL, 6);
		//hbox.margin = 6;
		vbox_main.add(hbox_list);

		//add treeview
		tv = new TreeView();
		tv.get_selection().mode = SelectionMode.MULTIPLE;
		tv.headers_visible = true;
		tv.expand = true;

		tv.row_activated.connect(tv_row_activated);

		tv.get_selection().changed.connect(tv_selection_changed);

		var scrollwin = new ScrolledWindow(((Gtk.Scrollable) tv).get_hadjustment(), ((Gtk.Scrollable) tv).get_vadjustment());
		scrollwin.set_shadow_type (ShadowType.ETCHED_IN);
		scrollwin.add (tv);
		hbox_list.add(scrollwin);

		//column
		var col = new TreeViewColumn();
		col.title = _("Kernel");
		col.resizable = true;
		col.min_width = 200;
		tv.append_column(col);

		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf ();
		cell_pix.xpad = 4;
		cell_pix.ypad = 6;
		col.pack_start (cell_pix, false);
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter)=>{
			Gdk.Pixbuf pix;
			model.get (iter, 1, out pix, -1);
			return_if_fail(cell as Gtk.CellRendererPixbuf != null);
			((Gtk.CellRendererPixbuf) cell).pixbuf = pix;
		});

		//cell text
		var cellText = new CellRendererText();
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cellText, false);
		col.set_cell_data_func (cellText, (cell_layout, cell, model, iter)=>{
			LinuxKernel kern;
			model.get (iter, 0, out kern, -1);
			return_if_fail(cell as Gtk.CellRendererText != null);
			((Gtk.CellRendererText) cell).text = kern.version_main;
		});

		//column
		col = new TreeViewColumn();
		col.title = _("Status");
		col.resizable = true;
		col.min_width = 200;
		tv.append_column(col);

		//cell text
		cellText = new CellRendererText();
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cellText, false);
		col.set_cell_data_func (cellText, (cell_layout, cell, model, iter)=>{
			LinuxKernel kern;
			model.get (iter, 0, out kern, -1);
			return_if_fail(cell as Gtk.CellRendererText != null);
			((Gtk.CellRendererText) cell).text = kern.is_running ? _("Running") : (kern.is_installed ? _("Installed") : "");
		});

		tv.set_tooltip_column(3);

	}

	private void tv_row_activated(TreePath path, TreeViewColumn column) {
		TreeIter iter;
		tv.model.get_iter_from_string(out iter, path.to_string());
		LinuxKernel kern;
		tv.model.get (iter, 0, out kern, -1);

		set_button_state();
	}

	private void tv_selection_changed() {
		var sel = tv.get_selection();

		TreeModel model;
		TreeIter iter;
		var paths = sel.get_selected_rows (out model);

		selected_kernels.clear();
		foreach (var path in paths) {
			LinuxKernel kern;
			model.get_iter(out iter, path);
			model.get (iter, 0, out kern, -1);
			selected_kernels.add(kern);
			//log_msg("size=%d".printf(selected_kernels.size));
		}

		set_button_state();
	}

	private void tv_refresh() {
		log_debug("tv_refresh()");

		var model = new Gtk.ListStore(4, typeof(LinuxKernel), typeof(Gdk.Pixbuf), typeof(bool), typeof(string));

		Gdk.Pixbuf pix_ubuntu = null;
		Gdk.Pixbuf pix_mainline = null;
		Gdk.Pixbuf pix_mainline_rc = null;

		try {
			pix_ubuntu = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/ubuntu-logo.png");
			pix_mainline = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux.png");
			pix_mainline_rc = new Gdk.Pixbuf.from_file (INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux-red.png");
		}
		catch (Error e) {
			log_error (e.message);
		}

		TreeIter iter;
		bool odd_row = false;
		foreach (var kern in LinuxKernel.kernel_list) {
			if (!kern.is_valid) continue;
			if (!kern.is_installed) {
				if (kern.is_unstable && App.hide_unstable) continue;
				if (kern.version_maj < LinuxKernel.threshold_major) continue;
			}

			odd_row = !odd_row;

			// add row
			model.append(out iter);
			model.set (iter, 0, kern);

			if (kern.is_mainline) {
				if (kern.is_unstable) model.set (iter, 1, pix_mainline_rc);
				else model.set (iter, 1, pix_mainline);
			}
			else model.set (iter, 1, pix_ubuntu);

			model.set (iter, 2, odd_row);
			model.set (iter, 3, kern.tooltip_text());
		}

		tv.set_model(model);
		tv.columns_autosize();

		selected_kernels.clear();
		set_button_state();

		set_infobar();
	}

	private void set_button_state() {
		if (selected_kernels.size == 0) {
			btn_install.sensitive = false;
			btn_uninstall.sensitive = false;
			btn_changes.sensitive = false;
			btn_ppa.sensitive = true;
		} else {
			// only allow selecting a single kernel for install/uninstall, examine the installed state
			btn_install.sensitive = (selected_kernels.size == 1) && !selected_kernels[0].is_installed;
			btn_uninstall.sensitive = selected_kernels[0].is_installed && !selected_kernels[0].is_running;
			btn_changes.sensitive = (selected_kernels.size == 1) && file_exists(selected_kernels[0].changes_file);
			btn_ppa.sensitive = (selected_kernels.size == 1) && selected_kernels[0].is_mainline;
			// allow selecting multiple kernels for install/uninstall, but IF only a single selected, examine the installed state
			// (the rest of the app does not have loops to process a list yet)
			//btn_install.sensitive = selected_kernels.size == 1 ? !selected_kernels[0].is_installed : true;
			//btn_uninstall.sensitive = selected_kernels.size == 1 ? selected_kernels[0].is_installed && !selected_kernels[0].is_running : true;
		}
	}

	private void init_actions() {

		var hbox = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_list.add (hbox);

		// install
		var button = new Gtk.Button.with_label (_("Install"));
		hbox.pack_start (button, true, true, 0);
		btn_install = button;

		button.clicked.connect(() => {
			return_if_fail(selected_kernels.size == 1);
			do_install(selected_kernels[0]);
		});

		// uninstall
		button = new Gtk.Button.with_label (_("Uninstall"));
		hbox.pack_start (button, true, true, 0);
		btn_uninstall = button;

		button.clicked.connect(() => {
			return_if_fail(selected_kernels.size > 0);
			do_uninstall(selected_kernels);
		});

		// changes
		button = new Gtk.Button.with_label (_("Changes"));
		hbox.pack_start (button, true, true, 0);
		btn_changes = button;

		button.clicked.connect(() => {
			if ((selected_kernels.size == 1) && file_exists(selected_kernels[0].changes_file)) {
				uri_open("file://"+selected_kernels[0].changes_file);
			}
		});

		// ppa
		button = new Gtk.Button.with_label ("PPA");
		hbox.pack_start (button, true, true, 0);
		btn_ppa = button;

		button.clicked.connect(() => {
			string uri = App.ppa_uri;
			if (selected_kernels.size == 1) uri += selected_kernels[0].kname;
			uri_open(uri);
		});

		// uninstall-old
		button = new Gtk.Button.with_label (_("Uninstall Old"));
		button.set_tooltip_text(_("Uninstall kernels older than running kernel"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_purge);

		// reload
		button = new Gtk.Button.with_label (_("Reload"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(reload_cache);

		// settings
		button = new Gtk.Button.with_label (_("Settings"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_settings);

		// about
		button = new Gtk.Button.with_label (_("About"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_about);

		// exit
		button = new Gtk.Button.with_label (_("Exit"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_exit);

	}

	private void do_settings () {
			int _show_prev_majors = App.show_prev_majors;
			bool _hide_unstable = App.hide_unstable;

			var dlg = new SettingsDialog.with_parent(this);
			dlg.run();
			dlg.destroy();

			if (
					(_show_prev_majors != App.show_prev_majors) ||
					(_hide_unstable != App.hide_unstable)
				) {
				reload_cache();
			}
	}

	private void do_exit () {
		Gtk.main_quit();
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
			"it: Albano Battistella <albano_battistella@hotmail.com>",
			"ko: Kevin Kim <root@hamonikr.org>",
			"nl: Heimen Stoffels <vistausss@outlook.com>",
			"pl: Viktor Sokyrko <victor_sokyrko@windowslive.com>",
			"ru: Danik2343 <krutalevex@mail.ru>",
			"sv: Åke Engelbrektson <eson@svenskasprakfiler.se>",
			"tr: Sabri Ünal <libreajans@gmail.com>",
			"uk: Serhii Golovko <cappelikan@gmail.com>",
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
		log_debug("reload_cache()");
		LinuxKernel.delete_cache();
		App.connection_checked=false;
		update_cache();
	}

	// Update the cache as optimally as possible.
	private void update_cache() {
		log_debug("update_cache()");

		test_net();

		if (!App.GUI_MODE) {
			// refresh without GUI
			LinuxKernel.query(false);
			return;
		}

		string message = _("Updating kernels");
		var progress_window = new ProgressWindow.with_parent(this, message, true);
		progress_window.show_all();

		LinuxKernel.query(false, (timer, ref count, last) => {
			update_progress_window(progress_window, message, timer, ref count, last);
		});

		tv_refresh();
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

		int64 remaining_count = App.progress_total - App.progress_count;

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
		scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.vscrollbar_policy = Gtk.PolicyType.NEVER;
		vbox_main.add(scrolled);

		// hbox
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		//hbox.margin = 6;
		scrolled.add(hbox);

		lbl_info = new Gtk.Label("");
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

	public void do_install(LinuxKernel kern) {
		return_if_fail(!kern.is_installed);
		// let it try even if we think the net is down
		// just so the button responds instead of looking broken
		//if (!test_net()) return;

		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.script_complete.connect(()=>{
			term.allow_window_close();
			dir_delete(t_dir);
		});

		term.destroy.connect(()=>{
			this.present();
			update_cache();
		});

		string sh = BRANDING_SHORTNAME;
		if (App.index_is_fresh) sh += " --index-is-fresh";
		if (LOG_DEBUG) sh += " --debug";
		sh += " --install %s\n".printf(kern.version_main)
		+ "echo \n"
		+ "echo '"+_("DONE")+"'\n"
		;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
	}

	public void do_uninstall(Gee.ArrayList<LinuxKernel> klist) {
		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.script_complete.connect(()=>{
			term.allow_window_close();
			dir_delete(t_dir);
		});

		term.destroy.connect(()=>{
			this.present();
			update_cache();
		});

		string names = "";
		foreach(var k in klist) {
			if (names.length > 0) names += ",";
			names += "%s".printf(k.version_main);
		}

		string sh = BRANDING_SHORTNAME;
		if (App.index_is_fresh) sh += " --index-is-fresh";
		if (LOG_DEBUG) sh += " --debug";
			sh += " --uninstall %s\n".printf(names)
			+ "echo \n"
			+ "echo '"+_("DONE")+"'\n"
			;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
	}

	public void do_purge () {
		var term = new TerminalWindow.with_parent(this, false, true);
		string t_dir = create_tmp_dir();
		string t_file = get_temp_file_path(t_dir)+".sh";

		term.script_complete.connect(()=>{
			term.allow_window_close();
			dir_delete(t_dir);
		});

		term.destroy.connect(()=>{
			this.present();
			update_cache();
		});

		string sh = BRANDING_SHORTNAME+" --uninstall-old";
		if (App.index_is_fresh) sh += " --index-is-fresh";
		if (LOG_DEBUG) sh += " --debug";
			sh += "\n"
			+ "echo \n"
			+ "echo '"+_("DONE")+"'\n"
			;

		save_bash_script_temp(sh,t_file);
		term.execute_script(t_file,t_dir);
	}

	public bool test_net() {
		if (App.connection_checked) return App.connection_status;
		if (!App.check_internet_connectivity()) errbox(this,_("Can not reach")+" "+App.ppa_uri);
		return App.connection_status;
	}

}
