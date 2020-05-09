
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
	
	public static int notify_send (string title = "", string message = ""){ 

		/* Displays notification bubble on the desktop */

		int retVal = 0;

		long seconds = 9999;
		if (dt_last_notification != null){
			DateTime dt_end = new DateTime.now_local();
			TimeSpan elapsed = dt_end.difference(dt_last_notification);
			seconds = (long)(elapsed * 1.0 / TimeSpan.SECOND);
		}


		// Notification display timeout. Override the desktop default.
		
		// The action buttons in notify-send.sh only work
		// during the initial display life of a notification.
		// When a notification is generated, an associated notify-action.sh
		// process is started in the background which waits for a dbus
		// event. When you press the action button in the notification,
		// it generates a dbus event which the monitor process detects
		// and reacts to.
		// When the notification times out, the associated monitor
		// process goes away and never comes back.
		// When you view a past notification from the history,
		// the notification still has the button, and it's still clickable,
		// but nothing happens when you press it, because the associated
		// notify-action.sh process is no longer there to receive the event
		// and perform the action.
		
		// So as a work-around, override the default desktop timeout
		// and set a timeout that is slightly less than the update
		// interval, and use the --force-expire option so that when the
		// timeout does finally expire, it doesn't appear in the history.
		
		// So the notification appears and stays alive and fully functional
		// until the user dismisses it, or until just before the next
		// notification update is due to appear. If the user dismisses
		// the notification, there is no "broken" notification in the
		// the history. The force-expire option doesn't work 100%.
		// Sometimes an expired notification is still visible in the
		// notification daemon history, and sometimes you can view it,
		// and sometimes you can start to view it but then it goes away
		// by itself just after you pop it up, etc.
		
		// We may be able to do cool stuff with this later, with more
		// action buttons to install, dismiss, blacklist a certain version, etc.
		// And maybe we can use the notification ID option to update a
		// single notification rather then generate new ones.
		
		int timeout_ms = 604800000;
		switch (App.notify_interval_unit){
		case 0: // hour
			timeout_ms = 3600000;
			break;
		case 1: // day
			timeout_ms = 86400000;
			break;
		case 2: // week
			timeout_ms = 604800000;
			break;
		case 3: // second
			timeout_ms = 1000;
			break;
		}

		// notification timeout is kernel update interval minus one second
		timeout_ms = App.notify_interval_value * timeout_ms - 1000;

		if (seconds > MIN_NOTIFICATION_INTERVAL){

			string action = BRANDING_SHORTNAME+"-gtk";
			string body = message;
			if (LOG_DEBUG) {
				action = INSTALL_PREFIX+"/lib/"+BRANDING_SHORTNAME+"/notify-action-debug.sh";
				body = "debug: button runs %s".printf(action);
			}
			
			string s =
			INSTALL_PREFIX+"/lib/"+BRANDING_SHORTNAME+"/notify_send/notify-send.sh"
			+ " -u low"
			+ " -c info"
			+ " -f"
			+ " -a "+BRANDING_SHORTNAME
			+ " -i "+BRANDING_SHORTNAME
			+ " -o Install:%s".printf(action)
			+ " -t %d \"%s\" \"%s\"".printf(timeout_ms,title,body);

			retVal = exec_sync (s, null, null);

			dt_last_notification = new DateTime.now_local();

		}

		return retVal;
	}

}
