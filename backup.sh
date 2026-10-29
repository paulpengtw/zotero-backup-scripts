#! /bin/sh

# Function to check if Zotero is running
zotero_running() {
    case "$(uname)" in
        "Darwin") # macOS
            # Zotero 7+ names its macOS binary "zotero" (lowercase); match either
            pgrep -ix "zotero" > /dev/null
            ;;
        "Linux")
            pgrep -x "zotero" > /dev/null
            ;;
        *)
            # Can't tell, so assume it is running and leave the live database alone
            return 0
            ;;
    esac
}

# Function to stage changes while Zotero is running. Zotero keeps an exclusive
# lock on zotero.sqlite and holds recent changes in zotero.sqlite-wal, so a copy
# of the live files can mix two states and fail to open. Stage everything else,
# and stand in Zotero's own backup (zotero.sqlite.bak) for zotero.sqlite.
stage_with_zotero_open() {
    git add -A -- . ':(exclude)*.sqlite' ':(exclude)*.sqlite-*' ':(exclude)*.sqlite.tmp*'

    if [ ! -f zotero.sqlite.bak ]; then
        echo "No zotero.sqlite.bak yet; database not backed up this run."
        return
    fi

    # Zotero refreshes the .bak about once a day, so it can be older than the
    # database committed by the last backup with Zotero closed
    BAK_TIME=$(stat -f %m zotero.sqlite.bak 2>/dev/null || stat -c %Y zotero.sqlite.bak)
    COMMITTED_TIME=$(git log -1 --format=%ct -- zotero.sqlite)
    if [ "$BAK_TIME" -le "${COMMITTED_TIME:-0}" ]; then
        echo "zotero.sqlite.bak is not newer than the committed database; database not backed up this run."
        return
    fi

    # Check a copy, so Zotero can't replace the .bak between the check and the commit
    SNAPSHOT=$(mktemp) || return
    cp zotero.sqlite.bak "$SNAPSHOT"
    if [ "$(sqlite3 "file:$SNAPSHOT?immutable=1" 'PRAGMA quick_check;' 2>&1)" != "ok" ]; then
        echo "zotero.sqlite.bak could not be verified with sqlite3; database not backed up this run."
        rm -f "$SNAPSHOT"
        return
    fi

    # Commit the .bak as zotero.sqlite without touching the live file. The .bak
    # is self-contained, so drop the WAL files rather than pair them with it.
    BLOB=$(git hash-object -w "$SNAPSHOT")
    rm -f "$SNAPSHOT"
    git update-index --cacheinfo 100644,"$BLOB",zotero.sqlite
    git rm -q --cached --ignore-unmatch zotero.sqlite-wal zotero.sqlite-shm
    echo "Database backed up from zotero.sqlite.bak"
}

# Function to notify about conflicts
notify_conflict() {
    case "$(uname)" in
        "Darwin") # macOS
            osascript -e 'display notification "Library changed here and on another machine. Backup stopped, nothing overwritten. See zoterobck.out" with title "Zotero Backup: Conflict" sound name "Basso"'
            ;;
        "Linux")
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -u critical "Zotero Backup: Conflict" "Library changed here and on another machine. Backup stopped, nothing overwritten. See zoterobck.out"
            fi
            ;;
    esac
}

# Function to cleanup temporary files
cleanup() {
    rm -f "$LOCKFILE"
    # Only clean up part files - leave .bak files for Zotero to manage
    rm -f zotero.sqlite.part*
}

# Set up lockfile with timeout
LOCKFILE="/tmp/zotero-backup.lock"
LOCKFILE_TIMEOUT=3600  # 1 hour timeout

if [ -e "$LOCKFILE" ]; then
    LOCKFILE_TIME=$(stat -f %m "$LOCKFILE" 2>/dev/null || stat -c %Y "$LOCKFILE")
    CURRENT_TIME=$(date +%s)
    
    if [ $((CURRENT_TIME - LOCKFILE_TIME)) -lt $LOCKFILE_TIMEOUT ]; then
        echo "Backup already in progress"
        exit 1
    else
        echo "Removing stale lockfile"
        rm -f "$LOCKFILE"
    fi
fi

touch "$LOCKFILE"

# Ensure cleanup on script exit
trap cleanup EXIT

cd "${ZOTERO_DIR:-$HOME/Zotero}" || exit 1
echo "EXECUTING BACKUP OF $(pwd)"

if zotero_running; then
    ZOTERO_OPEN=1
    echo "Zotero is running; backing up its own database backup (zotero.sqlite.bak) instead of the live database"
else
    ZOTERO_OPEN=0
    # Give a Zotero that only just closed time to release its files
    sleep 5
fi

# Clean up any existing part files before starting
rm -f zotero.sqlite.part*

# Ensure we have the latest changes
git fetch origin master

# A merge must never rewrite the database under a running Zotero
if [ $ZOTERO_OPEN = 1 ] && ! git diff --quiet HEAD...origin/master -- '*.sqlite' '*.sqlite-*' '*.sqlite.tmp*'; then
    echo "Another machine updated the database. Close Zotero to bring it in; backup skipped."
    exit 1
fi

# Bring in other machines' backups, but only as a fast-forward. Git cannot
# merge two versions of zotero.sqlite, so if this machine and another one have
# both changed the library, stop instead of overwriting either side.
if ! git merge --ff-only origin/master; then
    echo "CONFLICT: the library changed on this machine and on origin/master since the last sync."
    echo "Nothing was committed, merged or pushed; local files are untouched."
    echo "To resolve, close Zotero and keep one side:"
    echo "  keep the remote library: git reset --hard origin/master"
    echo "  keep this library:       git add -A && git commit -m 'Keep local library' && git merge -X ours origin/master && git push origin master"
    notify_conflict
    exit 1
fi

# Check if there are any changes to commit
if ! git diff --quiet HEAD || ! git diff --cached --quiet; then
    if [ $ZOTERO_OPEN = 1 ]; then
        stage_with_zotero_open
    else
        # Split large files
        split -b 25M zotero.sqlite "zotero.sqlite.part"

        # Stage all changes
        git add .
    fi

    if git diff --cached --quiet; then
        echo " -> Nothing to backup (no changes since last backup)"
        exit 0
    fi

    # Track document changes for commit message
    ChangedDocuments=$(git -c core.quotePath=false status | grep -E "\.(pdf|html|epub|pptx|docx)$" \
    | sed -E 's/[[:space:]]modified(.*)/mod \1/' \
    | sed -E 's/[[:space:]]new(.*)/new \1/' \
    | sed -E 's/[[:space:]]renamed(.*)/ren \1/' \
    | sed -E 's/[[:space:]]deleted(.*)/del \1/' \
    | sed -E 's/([a-z]{3}).*\/([^\/]*.pdf)$/(\1) \2/')
    
    # Commit and push changes
    if git commit -m "Backup $(date '+%Y-%m-%d %H:%M:%S')" -m "$ChangedDocuments"; then
        if git push origin master; then
            # Clean up part files after successful push
            rm -f zotero.sqlite.part*
            echo "Backup completed successfully"
        else
            echo "Push failed. Will retry in next backup cycle."
            exit 1
        fi
    else
        echo "Commit failed. Will retry in next backup cycle."
        exit 1
    fi
else
    echo " -> Nothing to backup (no changes since last backup)"
fi
