#!/bin/bash
# Copies the live Switchless user data into userdata/ in this repo, so the
# word lists get version history and survive a mistake or a wiped machine.
#
# Why this exists: ~/Library/Application Support/Switchless/ holds the custom
# phrases and the smart mixed-mode English word list, it is the only copy, and
# this machine has no Time Machine destination configured. The repo is private,
# so personal vocabulary does not leak.
#
# Usage: scripts/backup_userdata.sh            copy live data into the repo
#        scripts/backup_userdata.sh --restore  copy the repo's data back
#        scripts/backup_userdata.sh --diff     show what differs, change nothing

set -euo pipefail

LIVE="$HOME/Library/Application Support/Switchless"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP="$REPO_DIR/userdata"

if [ ! -d "$LIVE" ]; then
    echo "error: no live data folder at $LIVE" >&2
    echo "       (is Switchless installed and has it been run at least once?)" >&2
    exit 1
fi

case "${1:-}" in
    --diff)
        if [ ! -d "$BACKUP" ]; then
            echo "no backup yet; run without arguments to create one"
            exit 0
        fi
        diff -ru "$BACKUP" "$LIVE" && echo "identical"
        ;;
    --restore)
        # Restoring overwrites files the input method is reading, so make the
        # blast radius explicit and let the caller back out.
        echo "This will overwrite the live data in:"
        echo "  $LIVE"
        echo "with the copy in:"
        echo "  $BACKUP"
        printf "Type 'restore' to continue: "
        read -r reply
        [ "$reply" = "restore" ] || { echo "aborted"; exit 1; }
        mkdir -p "$LIVE"
        rsync -a --delete "$BACKUP"/ "$LIVE"/
        echo "restored; Switchless reloads the files on its own within a few seconds"
        ;;
    "")
        mkdir -p "$BACKUP"
        rsync -a --delete "$LIVE"/ "$BACKUP"/
        echo "backed up to $BACKUP"
        ls -la "$BACKUP"
        echo
        echo "Commit it to keep the history:"
        echo "  git -C \"$REPO_DIR\" add userdata && git -C \"$REPO_DIR\" commit -m 'Back up Switchless user data'"
        ;;
    *)
        echo "usage: $(basename "$0") [--diff|--restore]" >&2
        exit 1
        ;;
esac
