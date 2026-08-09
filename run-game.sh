#!/usr/bin/env bash
# run-game.sh — Launch this LÖVE game folder on Windows from inside WSL.
#
# LÖVE lives on the *Windows* side; the game lives in the WSL filesystem, which
# Windows can't reach via a drive letter. So this script maps the game folder
# to its UNC path (\\wsl.localhost\<distro>\...) with wslpath and hands it to
# love.exe through WSL2 interop, then returns while the window stays open.
#
# This script supports two layouts:
#   * The script's own directory IS the game (it has main.lua) → running it with
#     no args launches that game. That's the layout of this repo.
#   * The script's directory is a *container* of game subfolders → no-args lists
#     them, or pass the subfolder name to launch one.
#
# Usage (from anywhere):
#   ./run-game.sh            # if this dir is a game, launch it; else list games
#   ./run-game.sh list       # list game subfolders (container layout)
#   ./run-game.sh <game-dir> # launch a named subfolder (container layout)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Hard-coded Windows LÖVE install (WSL drives mount at /mnt/c).
LOVE_EXE="/mnt/c/Program Files/LOVE/love.exe"

list_games() {
	for d in "$REPO_DIR"/*/ "$REPO_DIR"/prototypes/*/; do
		if [ -f "$d/main.lua" ]; then
			echo "  $(basename "$d")"
		fi
	done
}

# --- resolve what to launch ----------------------------------------------

if [ -f "$REPO_DIR/main.lua" ]; then
	# This directory is itself a game: that's the only thing here.
	if [ "$#" -ge 1 ] && [ "$1" != "list" ] && [ "$1" != "-l" ]; then
		echo "ERROR: this folder is a single game (main.lua here); no subgames to launch." >&2
		exit 1
	fi
	GAME_NAME="$(basename "$REPO_DIR")"
	GAME_DIR="$REPO_DIR"
else
	# This directory is a container of game subfolders, like pi_test.
	if [ "$#" -lt 1 ] || [ "$1" = "-l" ] || [ "$1" = "list" ]; then
		echo "Available LÖVE games:"
		list_games
		exit 0
	fi
	GAME_NAME="$1"
	GAME_DIR="$REPO_DIR/$GAME_NAME"
	if [ ! -d "$GAME_DIR" ] && [ -d "$REPO_DIR/prototypes/$GAME_NAME" ]; then
		# container-of-containers: prototypes/<name> is a game too
		GAME_DIR="$REPO_DIR/prototypes/$GAME_NAME"
	fi
	if [ ! -d "$GAME_DIR" ]; then
		echo "ERROR: no such game folder: $GAME_NAME (expected at $GAME_DIR or prototypes/)" >&2
		exit 1
	fi
fi

# --- checks ---------------------------------------------------------------

if [ ! -f "$GAME_DIR/main.lua" ]; then
	echo "ERROR: $GAME_DIR has no main.lua — not a LÖVE game." >&2
	exit 1
fi
if [ ! -f "$LOVE_EXE" ]; then
	echo "ERROR: love.exe not found at $LOVE_EXE" >&2
	exit 1
fi

# Map /home/... to a Windows-readable UNC path.
GAME_WIN="$(wslpath -w "$GAME_DIR")"
echo "Running '$GAME_NAME' with $LOVE_EXE on $GAME_WIN ..."

# Launch through WSL2 interop, backgrounded so this shell returns.
"$LOVE_EXE" "$GAME_WIN" &
echo "Launched. Press Esc in the game window to quit."
