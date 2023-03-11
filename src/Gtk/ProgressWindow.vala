/*
 * ProgressWindow.vala
 *
 * Copyright 2015 Tony George <teejee2008@gmail.com>
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
using l.gtk;
using TeeJee.Misc;
using l.time;

public class ProgressWindow : Gtk.Window {

	private Gtk.Box vbox_main;
	private Gtk.Spinner spinner;
	private Gtk.Label lbl_msg;
	private Gtk.Label lbl_status;
	private Gtk.Button btn_cancel;

	private int def_width = 400;
	private int def_height = 50;

	private string status_message;
	private bool allow_cancel = false;
	private bool allow_close = false;

	// init

	public ProgressWindow.with_parent(Window parent, string message, bool allow_cancel = false) {

		set_transient_for(parent);
		set_modal(true);
		set_decorated(false);
		set_type_hint(Gdk.WindowTypeHint.DIALOG);
		//window_position = WindowPosition.CENTER;
		window_position = WindowPosition.CENTER_ON_PARENT;

		set_default_size(def_width, def_height);

		icon = get_app_icon(16);

		App.status_line = "";
		App.progress_count = 0;
		App.progress_total = 0;

		this.status_message = message;
		this.allow_cancel = allow_cancel;

		App.cancelled = false;

		this.delete_event.connect(close_window);

		init_window();
	}

	private bool close_window() {
		if (allow_close) return false;
		else return true;
	}

	public void init_window () {

		title = "";
		icon = get_app_icon(16);
		resizable = false;
		set_deletable(false);

		//vbox_main
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_main.margin = 12;
		add (vbox_main);

		var hbox_status = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add (hbox_status);

		spinner = new Gtk.Spinner();
		spinner.active = true;
		hbox_status.add(spinner);

		//lbl_msg
		lbl_msg = new Gtk.Label (status_message);
		lbl_msg.halign = Align.START;
		lbl_msg.ellipsize = Pango.EllipsizeMode.END;
		lbl_msg.max_width_chars = 40;
		hbox_status.add (lbl_msg);

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);

		//lbl_status
		lbl_status = new Gtk.Label ("");
		lbl_status.halign = Align.START;
		lbl_status.ellipsize = Pango.EllipsizeMode.END;
		lbl_status.max_width_chars = 40;
		vbox_main.add (lbl_status);

		//box
		var box = new Gtk.Box(Orientation.HORIZONTAL, 6);
		box.set_homogeneous(true);
		vbox_main.add (box);

		//btn
		var button = new Gtk.Button.with_label (_("Cancel"));
		button.margin_top = 6;
		box.pack_start (button, false, false, 0);
		btn_cancel = button;

		button.clicked.connect(()=>{
			App.cancelled = true;
			btn_cancel.sensitive = false;
		});

		show_all();

		btn_cancel.visible = allow_cancel;
		//btn_cancel.sensitive = allow_cancel;
	}

	// common

	public void update_message(string msg) {
		if (msg.length > 0) lbl_msg.label = msg;
	}

	public void update_status_line(bool clear = false) {

		if (clear) {
			lbl_status.label = "";
		} else {
			lbl_status.label = App.status_line;
		}

		//title = "Threads: %d".printf(DownloadManager.download_count);
	}

}
