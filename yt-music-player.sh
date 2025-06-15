#!/bin/bash

# Check dependencies
for cmd in yt-dlp mpv fzf jq; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Missing required command: $cmd"
        exit 1
    fi
done

# Config
CACHE_DIR="$HOME/.cache/yt-music"
FAVORITES_FILE="$CACHE_DIR/favorites.json"
mkdir -p "$CACHE_DIR"
touch "$FAVORITES_FILE"

# MPV control socket
MPV_SOCKET="/tmp/mpv-socket"

# Global variables
current_song=""
current_url=""
is_playing=false
queue=()

# Cleanup on exit
cleanup() {
    pkill -f "mpv --input-ipc-server=$MPV_SOCKET" 2>/dev/null
    rm -f "$MPV_SOCKET"
}
trap cleanup EXIT

# Fast search with caching
search_song() {
    local query="$1"
    local cache_file="$CACHE_DIR/search_${query}.json"

    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
    else
        yt-dlp "ytsearch10:$query" --print "%(title)s | %(webpage_url)s" 2>/dev/null | tee "$cache_file"
    fi
}

# Play/pause/resume
play_song() {
    if [[ "$is_playing" == true ]]; then
        echo '{ "command": ["set", "pause", false] }' | socat - "$MPV_SOCKET" 2>/dev/null
    else
        cleanup
        mpv --no-video --input-ipc-server="$MPV_SOCKET" --really-quiet "$current_url" &
        is_playing=true
    fi
}

pause_song() {
    echo '{ "command": ["set", "pause", true] }' | socat - "$MPV_SOCKET" 2>/dev/null
    is_playing=false
}

# Favorites management
add_to_favorites() {
    jq ". + [{\"title\":\"$current_song\", \"url\":\"$current_url\"}]" "$FAVORITES_FILE" > "$FAVORITES_FILE.tmp" && mv "$FAVORITES_FILE.tmp" "$FAVORITES_FILE"
}

# Download current song
download_song() {
    local download_dir="$HOME/Music/YT-Music"
    mkdir -p "$download_dir"
    yt-dlp -x --audio-format mp3 -o "$download_dir/%(title)s.%(ext)s" "$current_url"
    echo "Downloaded to: $download_dir/"
}

# Main menu
show_menu() {
    clear
    echo "================================="
    echo "    YouTube Music Player (TUI)    "
    echo "================================="
    echo "Current: $current_song"
    echo "---------------------------------"
    echo "1) Search and Play"
    echo "2) Play/Pause"
    echo "3) Add to Favorites"
    echo "4) View Favorites"
    echo "5) Download Current Song"
    echo "6) Exit"
    echo "================================="
    read -p "Choose an option (1-6): " choice

    case "$choice" in
        1) # Search and Play
            read -p "Search query: " query
            [[ -z "$query" ]] && return
            results=$(search_song "$query")
            selection=$(echo "$results" | fzf --height=40% --reverse --prompt="Select a song: ")
            [[ -z "$selection" ]] && return
            current_song=$(echo "$selection" | awk -F ' | ' '{print $1}')
            current_url=$(echo "$selection" | awk -F ' | ' '{print $NF}')
            play_song
            ;;
        2) # Play/Pause
            if [[ -z "$current_url" ]]; then
                echo "No song selected!"
                sleep 1
            elif [[ "$is_playing" == true ]]; then
                pause_song
                echo "Paused"
                sleep 0.5
            else
                play_song
                echo "Playing"
                sleep 0.5
            fi
            ;;
        3) # Add to Favorites
            if [[ -n "$current_url" ]]; then
                add_to_favorites
                echo "Added to favorites!"
                sleep 1
            else
                echo "No song selected!"
                sleep 1
            fi
            ;;
        4) # View Favorites
            if [[ -s "$FAVORITES_FILE" ]]; then
                selection=$(jq -r '.[] | "\(.title) | \(.url)"' "$FAVORITES_FILE" | fzf --height=40% --reverse --prompt="Select a favorite: ")
                [[ -z "$selection" ]] && return
                current_song=$(echo "$selection" | awk -F ' | ' '{print $1}')
                current_url=$(echo "$selection" | awk -F ' | ' '{print $NF}')
                play_song
            else
                echo "No favorites yet!"
                sleep 1
            fi
            ;;
        5) # Download
            if [[ -n "$current_url" ]]; then
                download_song
                sleep 2
            else
                echo "No song selected!"
                sleep 1
            fi
            ;;
        6) # Exit
            cleanup
            exit 0
            ;;
        *)
            echo "Invalid option!"
            sleep 0.5
            ;;
    esac
}

# Start the player
while true; do
    show_menu
done