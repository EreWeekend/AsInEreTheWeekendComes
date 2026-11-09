## Download
[Download the Windows installer](https://github.com/EreWeekend/AsInEreTheWeekendComes/releases/latest)

Initial release — tested on my Windows 11 PC

This installer creates a PowerShell script and a scheduled task that runs every five minutes. The script removes shortcuts in the Windows shell:recent folder that match the locations you choose during installation. It removes the shortcuts, not the files they point to.

What it does not do: It does not selectively remove items from File Explorer Home. Windows’ Recent items and File Explorer Home are separate, and this program does not manage the latter.

The installer requires administrator permission to create the scheduled task. The task runs PowerShell hidden every five minutes. Review the included PowerShell and Inno Setup scripts if you want to inspect how the installer and task work.

I made this for myself after finding the shell:recent folder and wanting a way to automatically remove shortcuts to files. I haven’t found a way to selectively remove those items from Explorer Home, so this program only handles the shortcuts in shell:recent.

I haven’t seen evidence that anyone accessed my Recent items. I just prefer not to leave those shortcuts there, and made this tool to do something about it.

I have tested this only on my own Windows 11 system; I have not tested it on other Windows versions or configurations. It was built with help from AI and Inno Setup. Use it only if you understand and are comfortable with the changes it makes.

To view the shell:recent folder, press Win+R, type shell:recent, and press Enter.  You will probably want to delete them all.  It goes way back a month or more.  But this isn't setup to delete them all.  You may be able to modify the settings to make that happen.  Have at it.

SHA-256: C76B28C86FD386062C5285EAC84C62170FDADFBC0E3AD3BD08B6BF7287C669B2
