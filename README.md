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
- **`zotero.sqlite.bak` / `zotero.sqlite.1.bak`** - Zotero's own rolling backups. Since
  `zotero.sqlite` is versioned directly, these are redundant copies of a file Git already
  keeps full history of, and they roughly triple the repository growth rate. See
  [High Memory Usage from Git Maintenance](#high-memory-usage-from-git-maintenance).
- **`zotero.sqlite.part*`** - Transient chunks from the `split` step, deleted after each run

## What This Does

- Creates hourly backups of your entire Zotero library
- Backs up all your PDFs, notes, and database
- Works across multiple computers
- Smart process handling with notifications
- Keeps a complete history of all your changes
- Detects conflicts between machines and manages file locks

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
- **Backs Up While Zotero Is Open**: Commits Zotero's own database backup (`zotero.sqlite.bak`) instead of the live database, which can't be copied safely while Zotero runs
- **Notifications**: Sends a system notification if another machine's backup conflicts with this one
- **Process Safety**: Waits 5 seconds before a backup with Zotero closed, in case it only just closed

### File Handling
- **Large File Management**: Splits `zotero.sqlite` into 25MB parts for Git compatibility
- **Smart Cleanup**: Removes temporary `.part` files after successful backup
- **Lock File System**: Prevents multiple backup processes from running simultaneously
- **Automatic Recovery**: Removes stale lock files after 1 hour timeout

### Git Integration
- **Conflict Detection**: Only fast-forwards to other machines' backups. If both sides changed the library, it stops and notifies you instead of merging
- **Smart Commits**: Only commits when there are actual changes
- **Document Tracking**: Logs which PDFs and documents were added/modified
- **Push Safety**: Only removes temporary files after successful Git push

### Cross-Platform Support
- **macOS**: Uses `osascript` for native notifications and `pgrep` for process detection
- **Linux**: Uses `notify-send` for notifications and appropriate process management

## How the Backup Process Works

### Automatic Process Management

Backups run whether or not Zotero is open:

1. **Zotero closed**: everything is backed up, including the live `zotero.sqlite`.
2. **Zotero open**: Zotero locks `zotero.sqlite` and keeps recent changes in `zotero.sqlite-wal`, so copying those files while it runs can capture a database that won't open. Instead:
   - Attachments and other files are backed up as usual
   - `zotero.sqlite.bak`, the backup Zotero makes of its own database about once a day, is committed as `zotero.sqlite`. The live file on disk is not touched
   - The `.bak` is only used if it is newer than the database already committed and passes `sqlite3`'s `PRAGMA quick_check`
   - Other `*.sqlite` files (such as `fulltext.sqlite`) wait for the next backup with Zotero closed
   - If another machine has pushed a newer database, nothing is merged until Zotero is closed, so the database is never rewritten under a running Zotero

While Zotero stays open, the backed-up database can be up to a day old. Closing Zotero before the next hourly run backs up the latest one.

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
   - Committed as `zotero.sqlite` while Zotero is open; the file itself is never modified
   - Managed by Zotero itself
3. **zotero.sqlite.part***:
   - Created temporarily during backup
   - Automatically cleaned up after successful backup
   - Used to handle large database files in Git

### Conflict Resolution

The script never merges two versions of `zotero.sqlite`:

1. It fast-forwards to other machines' backups
2. If this machine and another machine have both changed the library, there is no merge:
   - You'll receive a "Zotero Backup: Conflict" notification
   - Nothing is committed or pushed, and local files are untouched
   - Every later run stops the same way until the conflict is resolved

To resolve, close Zotero and keep one side:
```bash
# Keep the remote library (discards changes made on this machine)
cd ~/Zotero
git reset --hard origin/master

# Keep this library
cd ~/Zotero
git add -A && git commit -m 'Keep local library' && git merge -X ours origin/master && git push origin master
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

## Troubleshooting

### If the Database Isn't Backed Up While Zotero Is Open

The log (`zoterobck.out` on macOS) says why:

- `zotero.sqlite.bak is not newer than the committed database`: Zotero hasn't made a new `.bak` since the last backup. Normal; close Zotero to back up the latest database
- `could not be verified with sqlite3`: install `sqlite3`, or close Zotero for a full backup
- `Another machine updated the database. Close Zotero to bring it in`: close Zotero and the next run brings in the other machine's library

### If You See "Zotero Backup: Conflict" Notification

The library changed on this machine and on another machine since the last sync. Backup stopped and nothing was overwritten. Every run will stop the same way until you choose one side. Close Zotero, then either:

1. Keep the remote library (discards changes made on this machine):
   ```bash
   cd ~/Zotero
   git reset --hard origin/master
   ```
2. Or keep this library:
   ```bash
   cd ~/Zotero
   git add -A && git commit -m 'Keep local library' && git merge -X ours origin/master && git push origin master
   ```

### High Memory Usage from Git Maintenance

**Symptom:** one or more `git pack-objects` processes each consuming 1-2 GB of RAM, appearing
without you having run any Git command yourself. On macOS they may show up as
`Xcode.app/.../git-core/git pack-objects`.

**Cause.** This backup design commits `zotero.sqlite` (tens of MB) on every cycle. SQLite files
barely delta-compress, so each hourly backup stores a near-complete new copy. Git's automatic
maintenance (`git maintenance run --auto`) is triggered internally by the `fetch`, `commit` and
`push` that `backup.sh` performs, and it then tries to repack that history. `pack-objects` must
hold whole blobs in memory to compute deltas, and with Git's default *unbounded*
`pack.windowMemory` this can reach gigabytes.

Because one backup cycle runs `fetch`, `commit` and `push`, each can spawn its own detached
maintenance run, so two or three overlapping repacks may pile up.

This is self-reinforcing: if a repack is killed before finishing, nothing is absorbed into the
pack and the loose-object backlog grows every cycle, making the next attempt more expensive.
Observed on one 21 GB library: **18.5 GB of loose objects against a 713 MB pack**, with a pack
file that had not been rewritten in two months.

**Diagnosis:**
```bash
# Are repacks running right now, and how big?
ps -Ao pid,rss,etime,command | grep "[p]ack-objects"

# How large is the loose-object backlog? (loose "size" >> "size-pack" is the warning sign)
cd ~/Zotero && git count-objects -vH
```

**Fix — cap Git's packing memory** (safe globally; affects all repositories):
```bash
git config --global pack.windowMemory 128m
git config --global pack.deltaCacheSize 128m
git config --global pack.threads 1
git config --global pack.packSizeLimit 1g
git config --global core.bigFileThreshold 8m
```
`core.bigFileThreshold` matters most here: anything larger is stored without delta compression,
so large `.sqlite`, PDF and HTML blobs are never loaded into a delta window.

**Fix — stop the backup repo from auto-triggering maintenance:**
```bash
cd ~/Zotero
git config --local maintenance.auto false
git config --local gc.auto 0
git config --local gc.autoDetach false
```
Run `git gc` manually when convenient instead.

**Fix — reduce what gets committed.** Ensure the `.bak` files are ignored *and untracked*
(`.gitignore` alone has no effect on already-tracked files):
```bash
cd ~/Zotero
git rm --cached zotero.sqlite.bak zotero.sqlite.1.bak   # --cached keeps them on disk
```

Killing a stuck repack is safe: `git repack -d` only deletes old packs after successfully
writing new ones. Commits, history and the remote are unaffected.

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

`backup.sh` commits **both** the whole `zotero.sqlite` and the 25 MB chunks produced by its
`split` step, so either can be used to restore. Close Zotero first.

1. Get the latest backup from your Git repository
2. In Terminal, go to your Zotero folder:

   If `zotero.sqlite` is tracked directly (the default):
   ```bash
   cd ~/Zotero
   git checkout -- zotero.sqlite
   ```

   If you are restoring from the split chunks instead:
   ```bash
   cd ~/Zotero
   cat zotero.sqlite.part* > zotero.sqlite
   ```

> **Note on the split chunks.** Committing both forms stores the database twice per cycle. If you
> add `zotero.sqlite.part*` to `.gitignore` to save space, use the `git checkout` method above.
> Keep the chunks if your `zotero.sqlite` is approaching 100 MB, since GitHub rejects individual
> files above that limit and the whole-file commit would start failing.

Need help? [Open an issue](https://github.com/paulpengtw/zotero-backup-scripts/issues) on GitHub.
