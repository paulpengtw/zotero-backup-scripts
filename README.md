# Zotero Backup Scripts

Automatically backup your Zotero library to Git, with hourly backups and cross-device synchronization.

## Files That Make Up This Backup System

This backup system consists of the following key files:

### Core Backup Files
- **`backup.sh`** - The main backup script that handles the entire backup process
- **`.gitignore`** - Specifies which files should be excluded from backup (styles, translators, etc.)
- **`README.md`** - This documentation file

### System Integration Files (User Created)
You'll need to create these files during setup:

#### macOS (using launchd):
- **`~/Library/LaunchAgents/com.user.zoterobck.plist`** - LaunchAgent configuration for automatic hourly backups

#### Linux (using systemd):
- **`~/.config/systemd/user/zoterobck.service`** - Systemd service definition
- **`~/.config/systemd/user/zoterobck.timer`** - Systemd timer for hourly execution

### What Gets Backed Up
The backup system automatically includes:
- **`zotero.sqlite`** - Your main Zotero database (split into parts for Git)
- **`better-bibtex.sqlite`** - Better BibTeX plugin database
- **`storage/`** - All your PDFs, notes, and attachments
- **`aria/`** - AI assistant messages and data
- Configuration files and other data files

### What Gets Excluded
The `.gitignore` file excludes:
- System files (`.DS_Store`)
- Zotero's built-in styles and translators (updated by Zotero itself)
- Temporary files and signatures
- Search engine icons

## What This Does

- Creates hourly backups of your entire Zotero library
- Backs up all your PDFs, notes, and database
- Works across multiple computers
- Smart process handling with notifications
- Keeps a complete history of all your changes
- Automatically manages conflicts and file locks

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

The backup system is already set up in this repository! The key files are:
- `backup.sh` - Already executable and ready to use
- `.gitignore` - Already configured to backup the right files
- `README.md` - This documentation

You don't need to download anything additional - just proceed to Step 3 to set up automatic backups.

### Step 3: Set Up Automatic Backups

#### On macOS:

1. Create the required files:
   ```bash
   mkdir -p ~/Library/LaunchAgents
   touch ~/Library/LaunchAgents/com.user.zoterobck.plist
   ```

2. Copy this content to `~/Library/LaunchAgents/com.user.zoterobck.plist` (replace YOUR_USERNAME with your actual username):
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
           <string>/Users/YOUR_USERNAME/Zotero/backup.sh</string>
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

   **Important:** Make sure the path `/Users/YOUR_USERNAME/Zotero/backup.sh` points to the actual location of the `backup.sh` file in this repository.

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

## Understanding the backup.sh Script

The `backup.sh` script is the heart of this backup system. Here's what it does:

### Smart Process Management
- **Zotero Detection**: Checks if Zotero is running before starting backup
- **Automatic Waiting**: Waits up to 3 attempts (20 seconds each) for you to close Zotero
- **Notifications**: Sends system notifications about backup status
- **Process Safety**: Waits 5 seconds after Zotero closes to ensure files are released

### File Handling
- **Large File Management**: Splits `zotero.sqlite` into 25MB parts for Git compatibility
- **Smart Cleanup**: Removes temporary `.part` files after successful backup
- **Lock File System**: Prevents multiple backup processes from running simultaneously
- **Automatic Recovery**: Removes stale lock files after 1 hour timeout

### Git Integration
- **Conflict Resolution**: Automatically handles merge conflicts with remote repository
- **Smart Commits**: Only commits when there are actual changes
- **Document Tracking**: Logs which PDFs and documents were added/modified
- **Push Safety**: Only removes temporary files after successful Git push

### Cross-Platform Support
- **macOS**: Uses `osascript` for native notifications and `pgrep` for process detection
- **Linux**: Uses `notify-send` for notifications and appropriate process management

## How the Backup Process Works

### Automatic Process Management

The backup script now includes smart process management:

1. When a backup starts, it checks if Zotero is running
2. If Zotero is running:
   - You'll receive a "Zotero Backup: Waiting" notification
   - The script will wait up to 3 times (with 20-second intervals)
   - After Zotero closes, it waits an additional 5 seconds for files to be released
3. If Zotero doesn't close after maximum attempts:
   - The backup is cancelled
   - You'll receive a "Backup cancelled" notification
   - The backup will try again in the next cycle

### Lock File Management

To prevent backup conflicts:

- A lock file is created during backup
- Lock files expire after 1 hour to prevent stuck backups
- All temporary files are automatically cleaned up
- Multiple backup attempts cannot run simultaneously

### File Handling

The script manages several types of files:

1. **zotero.sqlite**: The main database file
2. **zotero.sqlite.bak**: 
   - Created by Zotero for safety
   - Left untouched by the backup script
   - Managed by Zotero itself
3. **zotero.sqlite.part***:
   - Created temporarily during backup
   - Automatically cleaned up after successful backup
   - Used to handle large database files in Git

### Conflict Resolution

The script now handles conflicts more gracefully:

1. First attempts a fast-forward pull
2. If that fails, tries auto-merge favoring local changes
3. If conflicts still occur:
   - Notifies you to close Zotero
   - Preserves your local changes
   - Will retry in the next backup cycle

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

## Troubleshooting

### If You See "Zotero Backup: Waiting" Notification

1. Save your work in Zotero
2. Close Zotero completely
3. The backup will proceed automatically
4. You can reopen Zotero after seeing "Backup completed successfully"

### If You See "Backup Cancelled" Notification

1. Close Zotero
2. Run the backup manually:
   ```bash
   cd ~/Zotero
   ./backup.sh
   ```
3. Wait for completion before reopening Zotero

### Service Issues

1. **Check file paths**: Make sure paths in your `.plist` (macOS) or `.service` (Linux) files match your actual username and the location of `backup.sh`
2. **Verify backup.sh is executable**: Run `ls -la backup.sh` to confirm it has execute permissions
3. **Test the script manually**: Run `./backup.sh` from your Zotero directory to test
4. **Try restarting the service**:
   ```bash
   # macOS
   launchctl unload ~/Library/LaunchAgents/com.user.zoterobck.plist
   launchctl load ~/Library/LaunchAgents/com.user.zoterobck.plist

   # Linux
   systemctl --user restart zoterobck.timer
   ```

### File Structure Issues

If you're missing files or having permission issues:
```bash
# Check if backup.sh exists and is executable
ls -la ~/Zotero/backup.sh

# Make it executable if needed
chmod +x ~/Zotero/backup.sh

# Check if .gitignore exists
ls -la ~/Zotero/.gitignore

# Verify your plist file (macOS only)
ls -la ~/Library/LaunchAgents/com.user.zoterobck.plist
```

## Restoring from Backup

1. Get the latest backup from your Git repository
2. In Terminal, go to your Zotero folder and run:
   ```bash
   cd ~/Zotero
   cat zotero.sqlite.part* > zotero.sqlite
   ```

Need help? [Open an issue](https://github.com/paulpengtw/zotero-backup-scripts/issues) on GitHub.
