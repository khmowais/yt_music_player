#!/bin/bash
# YT Music Player with Fuzzy TUI (using yt-dlp, mpv, fzf)
# Check dependencies

for cmd in yt-dlp mpv fzf; do
    if ! command -v $cmd >/dev/null; then
        echo "❌ Missing required command: $cmd"
        exit 1
    fi
done

# Ask user for a search query
read -rp "🔍 Search YouTube: " query
[ -z "$query" ] && echo "No query entered. Exiting." && exit 0

# Get top 10 search results (title + URL)
results=$(yt-dlp "ytsearch10:$query" --print "%(title)s | %(webpage_url)s" 2>/dev/null)

# If no results
[ -z "$results" ] && echo "❌ No results found." && exit 1

# Pick one with fzf
choice=$(echo "$results" | fzf --prompt="🎵 Choose a track: ")

# If nothing selected
[ -z "$choice" ] && echo "❌ Nothing selected." && exit 1

# Extract URL
url=$(echo "$choice" | awk -F ' | ' '{print $NF}')

# Play audio only
echo "🎧 Now playing: $choice"
mpv --no-video --really-quiet --input-terminal=no "$url"
