#!/bin/bash

# Simple GUI YouTube Music Player (with yad, mpv, yt-dlp)

# Check dependencies
for cmd in yt-dlp mpv yad; do
    if ! command -v $cmd >/dev/null; then
        yad --text="Missing required command: $cmd" --button=OK
        exit 1
    fi
done

# Get search query
query=$(yad --entry --title="🎵 YouTube Music Search" --text="Enter a search term:" --width=400 --window-icon=audio-x-generic --borders=10 --center)

[ -z "$query" ] && exit 0

# Fetch top 10 results
results=$(yt-dlp "ytsearch10:$query" --print "%(title)s | %(webpage_url)s" 2>/dev/null)

[ -z "$results" ] && yad --text="No results found." && exit 1

# Let user pick one
choice=$(echo "$results" | yad --list --title="🎧 Choose Track" --column="Track" --width=600 --height=400 --center --window-icon=audio-x-generic --borders=10 --dark-theme)

[ -z "$choice" ] && exit 0

# Extract URL (after last pipe)
url=$(echo "$choice" | awk -F ' | ' '{print $NF}')

# Play it
yad --notification --text="Playing: $(echo "$choice" | cut -d'|' -f1)" --image=audio-x-generic --command="echo"
mpv --no-video --really-quiet --input-terminal=no "$url"
