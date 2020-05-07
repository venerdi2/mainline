
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
	public const int NOTIFICATION_INTERVAL = 3;

	public static int notify_send (string title, string message){ 

		/* Displays notification bubble on the desktop */

		int retVal = 0;

		long seconds = 9999;
		if (dt_last_notification != null){
			DateTime dt_end = new DateTime.now_local();
			TimeSpan elapsed = dt_end.difference(dt_last_notification);
			seconds = (long)(elapsed * 1.0 / TimeSpan.SECOND);
		}

		if (seconds > NOTIFICATION_INTERVAL){
			//string s = "notify-send -t %d -u %s -i %s \"%s\" \"%s\"".printf(durationMillis, urgency, icon, title, message);
			// notify-send.sh -u low -a mainline -i mainline -c info -o "Show:mainline-gtk" "mainline" "New kernel is available"
			string s = INSTALL_PREFIX+"/lib/"+BRANDING_SHORTNAME+"/notify-send.sh/notify-send.sh -u low -c info -a "+BRANDING_SHORTNAME+" -i "+BRANDING_SHORTNAME+" -o \"Show:"+BRANDING_SHORTNAME+"-gtk\" \"%s\" \"%s\"".printf(title,message);
			//log_msg(s);
			retVal = exec_sync (s, null, null);
			dt_last_notification = new DateTime.now_local();
		}

		return retVal;
	}

}
