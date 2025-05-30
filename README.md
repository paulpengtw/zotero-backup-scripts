# Zotero Backup Script

This script provides automated backups of your Zotero folder using git. It runs hourly to ensure your research data is safely versioned and can be restored if needed. Before each backup, it attempts to sync with the remote repository using the following strategy:

1. Attempts a fast-forward pull to get the latest changes
2. If fast-forward fails, tries auto-merge favoring local changes
3. If conflicts still occur, sends a system notification and pauses backups until conflicts are resolved manually

This approach ensures safe synchronization across multiple machines while preserving local changes.

---

# Prerequisites

1. Initialize git in your Zotero folder: `git init`
2. Add your remote repository: `git remote add origin your-repo-url`
3. Set up SSH keys for passwordless git operations
4. Make the backup script executable: `chmod +x backup.sh`

# Setup Instructions

## For macOS Users

1. Place `backup.sh` in the `zotero-backup-scripts` folder
2. Create a LaunchAgent file:
```bash
mkdir -p ~/Library/LaunchAgents
touch ~/Library/LaunchAgents/com.user.zoterobck.plist
```

3. Add this content to the plist file (adjust paths as needed):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.zoterobck</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>/Users/YOUR_USERNAME/zotero-backup-scripts/backup.sh</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/YOUR_USERNAME/Zotero</string>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/zoterobck.err</string>
    <key>StandardOutPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/zoterobck.out</string>
</dict>
</plist>
```

4. Set proper permissions:
```bash
chmod 644 ~/Library/LaunchAgents/com.user.zoterobck.plist
```

5. Load the service:
```bash
launchctl load ~/Library/LaunchAgents/com.user.zoterobck.plist
```

To manage the service:
- Stop: `launchctl unload ~/Library/LaunchAgents/com.user.zoterobck.plist`
- Start: `launchctl load ~/Library/LaunchAgents/com.user.zoterobck.plist`
- Check status: `launchctl list | grep zoterobck`
- View logs in: `~/Library/Logs/zoterobck.out` and `~/Library/Logs/zoterobck.err`

Note: If you receive a notification about a merge conflict or see "MERGE CONFLICT DETECTED!" in the logs, you'll need to:
1. Navigate to your Zotero folder
2. Resolve the conflicts manually (`git status` will show conflicting files)
3. Commit your changes
The backup service will automatically resume in the next cycle.

## For Linux Users (systemd)

1. Place `backup.sh` in the `zotero-backup-scripts` folder
2. Link the service files (note: symlinks don't work with `systemd`):
```bash
ln ./zoterobck.service ~/.config/systemd/user/zoterobck.service
ln ./zoterobck.timer ~/.config/systemd/user/zoterobck.timer
```

3. Manage the service:
```bash
# Check status
systemctl --user status zoterobck.timer

# Enable and start
systemctl --user enable zoterobck.timer
systemctl --user start zoterobck.timer
```

To view logs:
```bash
journalctl -u zoterobck.service --user
```

Note: If you receive a notification about a merge conflict or see "MERGE CONFLICT DETECTED!" in the logs, you'll need to:
1. Navigate to your Zotero folder
2. Resolve the conflicts manually (`git status` will show conflicting files)
3. Commit your changes
The backup service will automatically resume in the next cycle.

# How to Restore

The `zotero.sqlite` database is stored in split files to avoid using git's large file storage. To restore:

```bash
cat zotero.sqlite.part* > zotero.sqlite
```

This will recreate the original `zotero.sqlite` file from the split parts.
