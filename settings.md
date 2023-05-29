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

**\[ \] Verify Checksums**  
When downloading .deb packages, first download the CHECKSUMS file and extract the sha-256 hashes from it, and use them to verify the .deb file downloads.

**Proxy
\[                               \]**  
proxy support via aria2c's [all-proxy](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-all-proxy) setting
