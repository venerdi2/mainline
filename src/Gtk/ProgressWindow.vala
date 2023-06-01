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

using l.gtk;
using l.misc;

public class ProgressWindow : Window {

	private Box vbox_main;
	private Spinner spinner;
	private Label lbl_msg;

	private string body_message = "";

	public ProgressWindow.with_parent(Window parent, string message) {

		set_modal(true);
		set_decorated(false);
		set_transient_for(parent);
		set_type_hint(Gdk.WindowTypeHint.DIALOG);
		//window_position = WindowPosition.CENTER_ON_PARENT;

		icon = get_app_icon(16);

		App.progress_count = 0;
		App.progress_total = 0;

		body_message = message.strip();

		init_window();
	}

	public void init_window () {

		title = "";
		icon = get_app_icon(16);
		resizable = false;
		deletable = false;
		//set_deletable(false);

		vbox_main = new Box(Orientation.VERTICAL, 6);
		vbox_main.margin = 12;
		add(vbox_main);

		var hbox_status = new Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox_status);

		spinner = new Spinner();
		spinner.active = true;
		hbox_status.add(spinner);

		lbl_msg = new Label(body_message);
		hbox_status.add(lbl_msg);

		var hbox = new Box(Orientation.HORIZONTAL, 6);
		vbox_main.add(hbox);

		show_all();
	}

	public void update_message(string s) {
		if (s.length > 0) lbl_msg.label = s;
	}

}
