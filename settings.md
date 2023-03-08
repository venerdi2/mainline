# Settings

## Notification
**\[ \] Notify if a major release is available**  
**\[ \] Notify if a point release is available**  
**Check every \[#\] \[units\]**  
Starts a background process that peridodically checks for new kernels and sends a desktop notification if a kernel is available that you don't have installed yet.  
The monitor is installed in your desktop autostart folder such that it is started in the background any time you log in.  
It is removed by unselecting both checkboxes.  

## Display
**\[ \] Hide unstable and RC releases**  
Excludes less stable more bleeding edge -rc kernels from the list.

**Show N previous major versions \[#\]**  
Defines a threshold value for the oldest major version to include in the display, as an offset from the whatever the current latest version is.  

The algorithm is essentially this (pseudocode):  
threshold_major = min( latest_available - N , oldest_installed )  

IE, the latest major version available minus N, or the oldest major version you have installed, whichever is lower.

Generally, you want this setting to just be 0.  
It's really only even a configurable option because in the past it was dumber, and you needed the option to set it to 1 or 2 in order to cover the times when each new major version gets it's first viable kernel, but you still need to see the more new point releases of the previous major version for a while, and you also just in general usually want to have access to all newer point releases for any (mainline) kernel that you have installed, whatever they are.  
Now, with this threshold_major rule, and N=0, you get the following behavior:  

Most of the time, you will have one or more kernels installed of the same major version as whatever is current at the time, and the list will only include the kernels from that one latest major version. It always includes all point releases for any given major version.  
So today, that means you have a 6.2.2 installed and the list shows all of the 6.x.x versions.  

Then 7.0.0 comes out.  

All else being equal, latest=7 and N=0 and 7-0=7 means on that day the list will only show 7.0.0 and nothing else except whatever ones you actually have installed.  

But there is also 6.3.0 available you might have wanted to use, but you never got a chance to see it, and never will get a chace to see 6.3.1 etc.  
So the above rule just adds another element to also consider whatever is the oldest mainline kernel you have installed, and set the threshold to that major version, or to latest-N, whichever is lower.  

On the other hand, if you explicitly *want* to see a bigger list including older kerneles, even if you don't have any of those installed, you can set N to 1 or greater, and you can get all the 6.x, all the 5.x, or more.  

## Other
**Internet connection timeout in \[##\] seconds**  
**Max concurrent downloads \[#\]**  
These correspond to options for aria2c used to download index.html and deb package files in the background.
