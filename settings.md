# Settings

## Notification
**\[ \] Notify if a major release is available**  
**\[ \] Notify if a point release is available**  
**Check every \[#\] \[units\]**  
Starts a background process that periodically checks for new kernels and sends a desktop notification if a kernel is available that you don't have installed yet.  
The monitor is installed in your desktop autostart folder such that it is started in the background any time you log in.  
It is removed by unselecting both checkboxes.  

## Filters
**\[ \] Hide unstable and RC releases**  
Excludes less stable more bleeding edge -rc kernels from the list.

**Show N previous major versions \[#\]**  
Defines a threshold value for the oldest major version to include in the display, as an offset from the whatever the current latest version is.  

The threshold is whichever is lower:  
 - the oldest mainline kernel you have installed
 - the highest mainline version available minus N

The special value "-1" is also allowed, and means to show all possible kernel versions. With this setting the initial cache update or Reload takes a long time, but it's actually usable after that.

Any installed non-mainline kernels are ignored for this.  
This allows to have a prior-generation distribution kernel installed without causing the list to include the entire prior generation of mainline kernels for no reason.  

Generally, you want this setting to just be 0.  

## Network
**Internet connection timeout in \[##\] seconds**  
**Max concurrent downloads \[#\]**  

**\[ \] Verify Downloads with the CHECKSUMS files**  
When downloading .deb packages, first download the CHECKSUMS file and extract the sha-256 hashes from it, and use them to verify the .deb file downloads.

**\[ \] Keep Downloads**  
Don't delete the .deb files after installing them. This allows to uninstall & reinstall kernels without having to re-download them.  
The cache is still kept trimmed even with this option enabled. The cache for any kernels that are older than the "Show N previous major versions" setting are still deleted as normal, so the cache grows but does not grow forever. And the datestamp comparison that detects when already-cached kernels have been changed on the mainline-ppa site, still deletes any out-of-date cached kernels as normal, so the setting does not result in retaining out-of-date kernel packages either. The "Reload" button still deletes everything too.

**Proxy  
\[_________________________________________________\]**  
proxy support via aria2c's [all-proxy](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-all-proxy) setting

**mainline-ppa url  
\[https://kernel.ubuntu.com/~kernel-ppa/mainline/  \]**  

## Auth Command
**\[pkexec env DISPLAY=${DISPLAY} XAUTHORITY=${XAUTHORITY}  \]**  
This is the sudo-equivalent used internally to run `dpkg` as root.  

pkexec can be problematic though, so if you need to, you can select from a few other common options like "sudo" etc, or write a custom command with anything you want.  
The other examples will only work if the relevant program is actually installed, and if your user login is configured in that utility. The default pkexec is assured to be installed by the dependency declared in the .deb package. For anything else, you may need to install the program, and you may need to do other configuration to allow your user to use that facility. For instance, probably you do already have both "sudo" and "su" installed, so you won't need to install them. But "sudo" won't actually work until you configure your user in "sudoers", and "su" won't actually work until you set a valid password for the root account. These days ubuntu systems don't set any password for the root account by default, and it's probably best NOT to give root a working password. The "su -c" option and others exist simply to allow for unusual situations.

This is probably most useful when accessing a remote system by ssh where there is no desktop session or gdbus daemon running, and sudo is more convenient than pkexec.  
Or when you have some custom commercial/enterprise/in-house command you need to run in work or vps environments.

There are several "sudo-alike" commands built-in to select from, or you can edit your own custom command.  
The syntax is mostly simple/literal, or you may optionally include a single "%s".  
If the auth command doesn't contain a %s, then the dpkg command is simply appended to the end after a space.  
If there is a %s, then the dpkg command is embedded within the auth command in place of the %s. One of the built-in default options shows an example of this: `su -c "%s"`  
Only the first "%s" encountered is active, if any. Any other % are treated as plain literal % chars.  
To write a custom command, you can select the blank line or select any of the built-in examples and edit it. The edited version is saved as a new custom entry, the built-in is not actually modified.

If you are opertaing entirely from the commandline, and so can not access the Settings screen in the gui, you can manually edit auth_cmd in ~/.config/mainline/config.json
