# Zotero Backup Scripts

Automatically backup your Zotero library to Git, with hourly backups and cross-device synchronization.

## What This Does

- Creates hourly backups of your entire Zotero library
- Backs up all your PDFs, notes, and database
- Works across multiple computers
- Sends notifications if there are any issues
- Keeps a complete history of all your changes

## Quick Start Guide

### Step 1: Initial Setup (One-time)

1. Create a Git repository on GitHub/GitLab to store your backups
2. Open Terminal and go to your Zotero folder:
   ```bash
   cd ~/Zotero
   ```
3. Set up Git in your Zotero folder:
   ```bash
   git init
   git remote add origin your-repository-url
   ```
4. [Set up SSH keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh) for GitHub/GitLab if you haven't already

### Step 2: Install the Backup Scripts

1. Download this repository
2. Make the backup script executable:
   ```bash
   chmod +x backup.sh
   ```

### Step 3: Set Up Automatic Backups

#### On macOS:

1. Create the required files:
   ```bash
   mkdir -p ~/Library/LaunchAgents
   touch ~/Library/LaunchAgents/com.user.zoterobck.plist
   ```

2. Copy this content to `~/Library/LaunchAgents/com.user.zoterobck.plist` (replace YOUR_USERNAME with your username):
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

3. Set file permissions and start the backup service:
   ```bash
   chmod 644 ~/Library/LaunchAgents/com.user.zoterobck.plist
   launchctl load ~/Library/LaunchAgents/com.user.zoterobck.plist
   ```

#### On Linux:

1. Copy the service files:
   ```bash
   mkdir -p ~/.config/systemd/user
   cp zoterobck.service ~/.config/systemd/user/
   cp zoterobck.timer ~/.config/systemd/user/
   ```

2. Start the backup service:
   ```bash
   systemctl --user enable zoterobck.timer
   systemctl --user start zoterobck.timer
   ```

## Checking if It's Working

### On macOS:

```bash
# Check if service is running (should show a number)
launchctl list | grep zoterobck

# View backup logs
tail -f ~/Library/Logs/zoterobck.out
```

### On Linux:

```bash
# Check service status
systemctl --user status zoterobck.timer

# View backup logs
journalctl -u zoterobck.service --user -f
```

## Common Issues

### "Merge Conflict" Notification

If you get a merge conflict notification:

1. Open Terminal and go to your Zotero folder:
   ```bash
   cd ~/Zotero
   ```
2. Run `git status` to see which files have conflicts
3. Resolve the conflicts (usually keeping your local changes is safe)
4. Commit your changes:
   ```bash
   git add .
   git commit -m "Resolved conflicts"
   ```
5. Backups will automatically resume

### Service Won't Start

1. Check if paths in the plist/service file match your username
2. Make sure backup.sh is executable
3. Try unloading and reloading the service:
   ```bash
   # macOS
   launchctl unload ~/Library/LaunchAgents/com.user.zoterobck.plist
   launchctl load ~/Library/LaunchAgents/com.user.zoterobck.plist

   # Linux
   systemctl --user restart zoterobck.timer
   ```

## Restoring from Backup

The database file (zotero.sqlite) is stored in parts to handle its size. To restore:

1. Get the latest backup from your Git repository
2. In Terminal, go to your Zotero folder and run:
   ```bash
   cat zotero.sqlite.part* > zotero.sqlite
   ```

Need help? [Open an issue](https://github.com/paulpengtw/zotero-backup-scripts/issues) on GitHub.
