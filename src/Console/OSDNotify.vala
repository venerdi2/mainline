
/*
 * OSDNotify.vala
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;

public class OSDNotify : GLib.Object {

	private static DateTime dt_last_notification = null;
	public const int MIN_NOTIFICATION_INTERVAL = 3;

	public static int notify_send (string summary = "", string _body = "", string extra_action = ""){ 

		/* Displays notification bubble on the desktop */

		int retVal = 0;

		long seconds = 9999;
		if (dt_last_notification != null){
			DateTime dt_end = new DateTime.now_local();
			TimeSpan elapsed = dt_end.difference(dt_last_notification);
			seconds = (long)(elapsed * 1.0 / TimeSpan.SECOND);
		}

		if (seconds > MIN_NOTIFICATION_INTERVAL){

			string action = BRANDING_SHORTNAME+"-gtk";
			string body = _body;

			if (LOG_DEBUG) {
				action = APP_LIB_DIR+"/notify-action-debug.sh";
				if (body!="") body += "\\n\\n";
				body += "("+action+")";
			}

			string s =
				APP_LIB_DIR+"/notify_send/notify-send.sh"
				+ " -u low"
				+ " -c info"
				+ " -a "+BRANDING_SHORTNAME
				+ " -i "+BRANDING_SHORTNAME
				+ " -t 0"
				+ " -R "+App.NOTIFICATION_ID_FILE
				+ " -o \""+_("Show")+":"+action+"\"";
				if (extra_action!="") s += " -o \""+extra_action+"\"";
				s += " \""+summary+"\""
				+ " \""+body+"\"";

			log_debug(s);

			exec_async (s);

			dt_last_notification = new DateTime.now_local();

		}

		return retVal;
	}

}
