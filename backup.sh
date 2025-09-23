#! /bin/sh

# Function to check if Zotero is running and wait for it to close
check_zotero() {
    local attempts=0
    local max_attempts=3
    
    while [ $attempts -lt $max_attempts ]; do
        case "$(uname)" in
            "Darwin") # macOS
                if ! pgrep -x "Zotero" > /dev/null; then
                    # Wait an additional 5 seconds after Zotero closes to ensure files are released
                    sleep 5
                    return 0
                fi
                osascript -e 'display notification "Please close Zotero for backup to proceed. Waiting..." with title "Zotero Backup: Waiting" sound name "Basso"'
                ;;
            "Linux")
                if ! pgrep -x "zotero" > /dev/null; then
                    sleep 5
                    return 0
                fi
                if command -v notify-send >/dev/null 2>&1; then
                    notify-send -u critical "Zotero Backup: Waiting" "Please close Zotero for backup to proceed. Waiting..."
                fi
                ;;
        esac
        sleep 20
        attempts=$((attempts + 1))
    done
    
    # If we get here, Zotero didn't close after max attempts
    case "$(uname)" in
        "Darwin") # macOS
            osascript -e 'display notification "Backup cancelled - please close Zotero and try again later" with title "Zotero Backup: Cancelled" sound name "Basso"'
            ;;
        "Linux")
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -u critical "Zotero Backup: Cancelled" "Backup cancelled - please close Zotero and try again later"
            fi
            ;;
    esac
    return 1
}

# Function to notify about conflicts
notify_conflict() {
    case "$(uname)" in
        "Darwin") # macOS
            osascript -e 'display notification "Please close Zotero and run backup manually to resolve" with title "Zotero Backup: Merge Conflict" sound name "Basso"'
            ;;
        "Linux")
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -u critical "Zotero Backup: Merge Conflict" "Please close Zotero and run backup manually to resolve"
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

cd /Users/cheng/Zotero
echo "EXECUTING BACKUP OF $(pwd)"

# Check if Zotero is running and wait for it to close
if ! check_zotero; then
    echo "WARNING: Zotero is still running after maximum wait time. Backup cancelled."
    exit 1
fi

# Clean up any existing part files before starting
rm -f zotero.sqlite.part*

# Ensure we have the latest changes
git fetch origin master

# Check if we're behind the remote
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/master)

if [ "$LOCAL" != "$REMOTE" ]; then
    # If we're behind, try to merge
    if ! git merge origin/master --ff-only; then
        # If fast-forward fails, try to resolve automatically
        if ! git merge origin/master -X ours; then
            echo "MERGE CONFLICT DETECTED!"
            notify_conflict
            exit 1
        fi
    fi
fi

# Check if there are any changes to commit
if ! git diff --quiet HEAD || ! git diff --cached --quiet; then
    # Split large files
    split -b 25M zotero.sqlite "zotero.sqlite.part"
    
    # Stage all changes
    git add .
    
    # Track document changes for commit message
    ChangedDocuments=$(git status | grep -E "\.(pdf|html|epub|pptx|docx)$" \
    | sed -E 's/\smodified(.*)/mod \1/' \
    | sed -E 's/\snew(.*)/new \1/' \
    | sed -E 's/\srenamed(.*)/ren \1/' \
    | sed -E 's/\sdeleted(.*)/del \1/' \
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
