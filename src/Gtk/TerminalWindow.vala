/*
 * TerminalWindow.vala
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
 */

using TeeJee.ProcessHelper;
using l.gtk;
using l.misc;

public class TerminalWindow : Gtk.Window {

	private Gtk.Box vbox_main;
	private Vte.Terminal term;
	private Gtk.Button btn_cancel;
	private Gtk.Button btn_close;
	private Gtk.ScrolledWindow scroll_win;

	private Pid child_pid;
	private Gtk.Window parent_win = null;

	public bool cancelled = false;
	public bool is_running = false;

	public signal void script_complete();

	// init

	public TerminalWindow.with_parent(Gtk.Window? parent, bool fullscreen = false, bool show_cancel_button = false) {
		if (parent != null) {
			set_transient_for(parent);
			parent_win = parent;
			window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
		}

		set_default_size(App.term_width,App.term_height);
		if (App.term_x>=0 && App.term_y>=0) move(App.term_x,App.term_y);

		delete_event.connect(cancel_window_close);

		set_modal(true);

		if (fullscreen) this.fullscreen();

		init_window();

		show_all();

		btn_cancel.visible = false;
		btn_close.visible = false;

		if (show_cancel_button) allow_cancel();
	}

	public bool cancel_window_close() {
		// do not allow window to close
		return true;
	}

	public void init_window () {

		App._term_width = App.term_width;
		App._term_height = App.term_height;
		App._term_x = App.term_x;
		App._term_y = App.term_y;

		title = BRANDING_LONGNAME;
		icon = get_app_icon(16);
		resizable = true;
		deletable = false;

		// vbox_main ---------------

		vbox_main = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		add(vbox_main);

		// terminal ----------------------

		term = new Vte.Terminal();

		term.expand = true;

		// sw_ppa
		scroll_win = new Gtk.ScrolledWindow(null, null);
		scroll_win.set_shadow_type (Gtk.ShadowType.ETCHED_IN);
		scroll_win.add (term);
		scroll_win.expand = true;
		scroll_win.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		scroll_win.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		vbox_main.add(scroll_win);

		term.input_enabled = true;
		term.backspace_binding = Vte.EraseBinding.AUTO;
		term.cursor_blink_mode = Vte.CursorBlinkMode.SYSTEM;
		term.cursor_shape = Vte.CursorShape.UNDERLINE;

		term.scroll_on_keystroke = true;
		term.scroll_on_output = true;
		term.scrollback_lines = 100000;

		// colors -----------------------------
		// why override the users desktop preference?
		//var color = Gdk.RGBA();
		//color.parse("#FFFFFF");
		//term.set_color_foreground(color);
		//color.parse("#404040");
		//term.set_color_background(color);

		// grab focus ----------------

		term.grab_focus();

		// add cancel button --------------

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		hbox.homogeneous = true;
		vbox_main.add (hbox);

		var label = new Gtk.Label("");
		hbox.pack_start (label, true, true, 0);
		
		label = new Gtk.Label("");
		hbox.pack_start (label, true, true, 0);
		
		// btn_cancel
		var button = new Gtk.Button.with_label (_("Cancel"));
		hbox.pack_start (button, true, true, 0);
		btn_cancel = button;
		
		btn_cancel.clicked.connect(()=>{
			cancelled = true;
			terminate_child();
		});

		// btn_close
		button = new Gtk.Button.with_label (_("Close"));
		hbox.pack_start (button, true, true, 0);
		btn_close = button;
		
		btn_close.clicked.connect(()=>{
			get_size(out App.term_width, out App.term_height);
			get_position(out App.term_x, out App.term_y);
			destroy();
		});

		label = new Gtk.Label("");
		hbox.pack_start (label, true, true, 0);

		label = new Gtk.Label("");
		hbox.pack_start (label, true, true, 0);

	}

	public void terminate_child() {
		btn_cancel.sensitive = false;
		process_quit(child_pid);
	}

	public void execute_script(string f, string d) {
		string[] argv = {"sh", f};

		string[] env = Environ.get();

		try {

			is_running = true;

			term.spawn_sync (
				Vte.PtyFlags.DEFAULT, //pty_flags
				d, //working_directory
				argv, //argv
				env, //env
				GLib.SpawnFlags.SEARCH_PATH, //spawn_flags
				null, //child_setup
				out child_pid,
				null
			);

			term.watch_child(child_pid);

			term.child_exited.connect(script_exit);
		}
		catch (Error e) {
			vprint(e.message,1,stderr);
		}
	}

	public void script_exit(int status) {
		is_running = false;
		btn_cancel.visible = false;
		btn_close.visible = true;
		script_complete();
	}

	public void allow_window_close(bool allow = true) {
		if (allow) {
			delete_event.disconnect(cancel_window_close);
			deletable = true;
		} else {
			delete_event.connect(cancel_window_close);
			deletable = false;
		}
	}

	public void allow_cancel(bool allow = true) {
		if (allow) {
			btn_cancel.visible = true;
			btn_cancel.sensitive = true;
			vbox_main.margin = 3;
		} else {
			btn_cancel.visible = false;
			btn_cancel.sensitive = false;
			vbox_main.margin = 3;
		}
	}
}
