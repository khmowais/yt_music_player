#!/bin/bash

# Check dependencies
for cmd in yt-dlp mpv fzf; do
    if ! command -v $cmd >/dev/null; then
        echo "Missing required command: $cmd"
        exit 1
    fi
done

# Global variables
current_song=""
current_url=""
queue=()
favorites=()
is_playing=false
download_dir="$HOME/yt_music_downloads"

# Create download directory if it doesn't exist
mkdir -p "$download_dir"

# Function to play the song
play_song() {
    if [ "$is_playing" = true ]; then
        echo "Already playing: $current_song"
        return
    fi
    mpv --no-video --really-quiet --input-terminal=no "$current_url" &
    is_playing=true
    echo "Playing: $current_song"
}

# Function to pause the song
pause_song() {
    if [ "$is_playing" = false ]; then
        echo "Nothing is playing."
        return
    fi
    pkill -SIGSTOP mpv
    is_playing=false
    echo "Paused: $current_song"
}

# Function to skip to the next song in the queue
skip_song() {
    if [ ${#queue[@]} -gt 0 ]; then
        current_url="${queue[0]}"
        current_song="${current_url##*/}"
        queue=("${queue[@]:1}")
        play_song
    else
        echo "No more songs in the queue."
    fi
}

# Function to add the song to the favorites list
add_to_favorites() {
    favorites+=("$current_song | $current_url")
    echo "Added to favorites: $current_song"
}

# Function to search and select a song
search_song() {
    echo "Enter search term:"
    read query
    if [ -z "$query" ]; then
        echo "Search query is empty."
        return
    fi

    # Get top 10 search results
    results=$(yt-dlp "ytsearch10:$query" --print "%(title)s | %(webpage_url)s" 2>/dev/null)

    # If no results
    if [ -z "$results" ]; then
        echo "No results found."
        return
    fi

    # Show results and select one
    selected=$(echo "$results" | fzf --height 40% --border --preview 'echo {}' --preview-window=up:10)
    if [ -z "$selected" ]; then
        echo "No song selected."
        return
    fi

    current_song=$(echo "$selected" | awk -F ' | ' '{print $1}')
    current_url=$(echo "$selected" | awk -F ' | ' '{print $NF}')
    queue+=("$current_url")
    echo "Selected: $current_song"
}

# Function to display current queue
display_queue() {
    if [ ${#queue[@]} -eq 0 ]; then
        echo "Queue is empty."
    else
        echo "Current Queue:"
        for i in "${!queue[@]}"; do
            echo "$((i + 1)). ${queue[$i]}"
        done
    fi
}

# Function to display favorites
display_favorites() {
    if [ ${#favorites[@]} -eq 0 ]; then
        echo "No favorites added."
    else
        echo "Favorites:"
        for i in "${!favorites[@]}"; do
            echo "$((i + 1)). ${favorites[$i]}"
        done
    fi
}

# Function to download the song
download_song() {
    if [ -z "$current_url" ]; then
        echo "No song selected to download."
        return
    fi

    echo "Downloading $current_song..."
    yt-dlp -o "$download_dir/%(title)s.%(ext)s" "$current_url"
    echo "Downloaded: $current_song"
}

# Function to show menu options
show_menu() {
    echo "============================="
    echo "  YouTube Music Player"
    echo "============================="
    echo "1. Search and Play"
    echo "2. Play/Pause"
    echo "3. Skip"
    echo "4. View Queue"
    echo "5. Add to Favorites"
    echo "6. View Favorites"
    echo "7. Download Current Song"
    echo "8. Exit"
    echo "============================="
    echo -n "Choose an option: "
}

# Main loop for user interaction
while true; do
    show_menu
    read -n 1 option

    case $option in
        1) search_song ;;
        2) 
            if [ "$is_playing" = true ]; then
                pause_song
            else
                play_song
            fi
            ;;
        3) skip_song ;;
        4) display_queue ;;
        5) add_to_favorites ;;
        6) display_favorites ;;
        7) download_song ;;
        8) exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done
