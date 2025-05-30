#! /bin/sh

notify_conflict() {
    case "$(uname)" in
        "Darwin") # macOS
            osascript -e 'display notification "Please resolve conflicts manually in your Zotero folder" with title "Zotero Backup: Merge Conflict" sound name "Basso"'
            ;;
        "Linux")
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -u critical "Zotero Backup: Merge Conflict" "Please resolve conflicts manually in your Zotero folder"
            fi
            ;;
    esac
}

cd `dirname "$0"`
echo "EXECUTING BACKUP OF `pwd`"

# Attempt fast-forward pull first
if ! git pull --ff-only origin master; then
    # If fast-forward fails, try auto-merge favoring our changes
    if ! git pull -X ours origin master; then
        # If there are still conflicts, notify user and exit
        echo "MERGE CONFLICT DETECTED!"
        echo "Please resolve conflicts manually in $(pwd)"
        echo "After resolving, commit your changes and the backup will resume in the next cycle"
        notify_conflict
        exit 1
    fi
fi

DoBackupFlag=true

Line=$(git status | tail -n 1)
if [ "$Line" = "nothing to commit, working tree clean" ]; then
	DoBackupFlag=false
fi;

if $DoBackupFlag; then
	rm -f zotero.sqlite.part*
	split -b 25M zotero.sqlite "zotero.sqlite.part"
	git add .
	ChangedDocuments=$(git status | grep -E "\.(pdf|html|epub|pptx|docx)$" \
		| sed -E 's/\smodified(.*)/mod \1/' \
		| sed -E 's/\snew(.*)/new \1/' \
		| sed -E 's/\srenamed(.*)/ren \1/' \
		| sed -E 's/\sdeleted(.*)/del \1/' \
		| sed -E 's/([a-z]{3}).*\/([^\/]*.pdf)$/(\1) \2/')
	git commit -m "Daily backup" -m "$ChangedDocuments"
	git push origin master
else
	echo " -> Nothing to backup (no changes since last backup)"
fi;
