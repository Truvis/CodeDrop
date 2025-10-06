#!/bin/bash

# Drive Temperature Monitor with Color Coding & Bar Graph
# Displays all drives with temperatures color-coded from green (cool) to red (hot)
# Temperature scale now uses a 1-color-per-degree map for 30°C..65°C
# Truvis Thornton [ http://truv.is ]

# ============================================================================
# Configuration Variables
# ============================================================================

# Time window for min/max statistics (in hours)
# Default: 24 hours
STATS_TIME_WINDOW=24

# Hide drives with no temperature data (N/A)
# Options: true | false
HIDE_NA_DRIVES=false

# Temperature display format
# Options: "both" | "celsius" | "fahrenheit"
TEMP_DISPLAY="both"

# Use in-memory tracking instead of file-based logging
# Options: true | false
# When true: Stats are tracked in memory only (lost on restart)
# When false: Stats are logged to LOG_FILE for persistence
USE_MEMORY_TRACKING=false

# Refresh interval in seconds
REFRESH_INTERVAL=2

# Log file location (only used when USE_MEMORY_TRACKING=false)
LOG_FILE="/var/log/drive_temps.log"

# ============================================================================

# Check if running as root (needed for smartctl)
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# Check if smartmontools is installed
if ! command -v smartctl &> /dev/null; then
    echo "smartctl not found. Please install smartmontools:"
    echo "  Ubuntu/Debian: sudo apt install smartmontools"
    echo "  RHEL/CentOS:   sudo yum install smartmontools"
    echo "  Arch:          sudo pacman -S smartmontools"
    exit 1
fi

# Color map for 30°C .. 65°C (one color code per degree).
# Index 0 -> 30°C, Index 35 -> 65°C
COLOR_MAP=(22 22 28 28 34 34 34 40 40 46 46 70 76 112 190 11 11 220 220 214 214 214 208 208 202 202 210 210 167 167 167 131 131 124 88 1)

# Function to get color based on temperature (foreground)
get_color() {
    local temp=$1

    # If temp is between 30 and 65 use the provided per-degree map
    if [ "$temp" -ge 30 ] && [ "$temp" -le 65 ]; then
        local idx=$((temp - 30))
        local code="${COLOR_MAP[$idx]}"
        if [ -n "$code" ]; then
            echo -e "\033[38;5;${code}m"
            return
        fi
    fi

    # Fallback gradient for temps outside 30..65
    if [ "$temp" -gt 65 ]; then
        echo -e "\033[38;5;52m"   # Very dark red
    elif [ "$temp" -ge 61 ]; then
        echo -e "\033[38;5;88m"
    elif [ "$temp" -ge 55 ]; then
        echo -e "\033[38;5;202m"
    elif [ "$temp" -ge 50 ]; then
        echo -e "\033[38;5;208m"
    elif [ "$temp" -ge 45 ]; then
        echo -e "\033[38;5;214m"
    elif [ "$temp" -ge 40 ]; then
        echo -e "\033[38;5;221m"
    elif [ "$temp" -ge 35 ]; then
        echo -e "\033[38;5;193m"
    elif [ "$temp" -ge 30 ]; then
        echo -e "\033[38;5;154m"
    elif [ "$temp" -ge 25 ]; then
        echo -e "\033[38;5;46m"
    elif [ "$temp" -ge 20 ]; then
        echo -e "\033[38;5;48m"
    elif [ "$temp" -ge 16 ]; then
        echo -e "\033[38;5;50m"
    else
        echo -e "\033[38;5;93m"   # Purple (very cool)
    fi
}

# Function to get background color based on temperature
get_bg_color() {
    local temp=$1

    # Keep existing background gradient. This can be updated to a per-degree map if desired.
    if [ "$temp" -ge 63 ]; then
        echo -e "\033[48;5;88m"
    elif [ "$temp" -ge 61 ]; then
        echo -e "\033[48;5;124m"
    elif [ "$temp" -ge 59 ]; then
        echo -e "\033[48;5;160m"
    elif [ "$temp" -ge 57 ]; then
        echo -e "\033[48;5;196m"
    elif [ "$temp" -ge 55 ]; then
        echo -e "\033[48;5;202m"
    elif [ "$temp" -ge 53 ]; then
        echo -e "\033[48;5;208m"
    elif [ "$temp" -ge 52 ]; then
        echo -e "\033[48;5;214m"
    elif [ "$temp" -ge 50 ]; then
        echo -e "\033[48;5;215m"
    elif [ "$temp" -ge 48 ]; then
        echo -e "\033[48;5;220m"
    elif [ "$temp" -ge 46 ]; then
        echo -e "\033[48;5;221m"
    elif [ "$temp" -ge 44 ]; then
        echo -e "\033[48;5;226m"
    elif [ "$temp" -ge 42 ]; then
        echo -e "\033[48;5;227m"
    elif [ "$temp" -ge 40 ]; then
        echo -e "\033[48;5;228m"
    elif [ "$temp" -ge 38 ]; then
        echo -e "\033[48;5;192m"
    elif [ "$temp" -ge 36 ]; then
        echo -e "\033[48;5;228m"
    elif [ "$temp" -ge 35 ]; then
        echo -e "\033[48;5;193m"
    elif [ "$temp" -ge 34 ]; then
        echo -e "\033[48;5;157m"
    elif [ "$temp" -ge 33 ]; then
        echo -e "\033[48;5;120m"
    elif [ "$temp" -ge 32 ]; then
        echo -e "\033[48;5;82m"
    elif [ "$temp" -ge 30 ]; then
        echo -e "\033[48;5;46m"
    elif [ "$temp" -ge 28 ]; then
        echo -e "\033[48;5;47m"
    elif [ "$temp" -ge 26 ]; then
        echo -e "\033[48;5;48m"
    elif [ "$temp" -ge 24 ]; then
        echo -e "\033[48;5;49m"
    elif [ "$temp" -ge 22 ]; then
        echo -e "\033[48;5;50m"
    elif [ "$temp" -ge 20 ]; then
        echo -e "\033[48;5;51m"
    elif [ "$temp" -ge 18 ]; then
        echo -e "\033[48;5;45m"
    elif [ "$temp" -ge 16 ]; then
        echo -e "\033[48;5;39m"
    elif [ "$temp" -ge 14 ]; then
        echo -e "\033[48;5;33m"
    else
        echo -e "\033[48;5;93m"
    fi
}

# Function to create bar graph starting at 28°C
create_bar_with_temp() {
    local temp=$1
    local temp_f=$2
    local min_temp=28
    local max_temp=65
    local bar_length=$((max_temp - min_temp + 1))  # 38 degrees range (28-65°C) plus 1 for the <= 28 block

    # Build bar with CJK brackets
    local bar="｢"

    # Determine how many blocks to fill
    local filled=0

    if [ "$temp" -le "$min_temp" ]; then
        # Show only 1 block for temps at or below 28°C
        filled=1
        # Choose color based on temp
        local block_color
        if [ "$temp" -le 5 ]; then
            # Bright purple for 5°C and below
            block_color="\033[38;5;93m"
        else
            # Light blue for 6-28°C
            block_color="\033[38;5;117m"
        fi
        bar+="${block_color}■${RESET}"
    else
        # Clamp max temperature
        if [ "$temp" -gt "$max_temp" ]; then
            temp=$max_temp
        fi

        # Add 1 block per degree above 28°C
        filled=$((temp - min_temp + 1))

        # First block represents 28°C and below (light blue)
        bar+="\033[38;5;117m■${RESET}"

        # Add blocks for each degree above 28°C with gradient
        for ((i=1; i<filled; i++)); do
            local actual_temp=$((min_temp + i))
            local pos_color
            pos_color=$(get_color "$actual_temp")
            bar+="${pos_color}■${RESET}"
        done
    fi

    # Add empty blocks for remaining degrees
    local empty=$((bar_length - filled))
    for ((i=0; i<empty; i++)); do
        bar+="\033[48;5;232m\033[38;5;240m■\033[0m"
    done

    # Get the color for the actual current temperature for the display
    local current_temp_color
    current_temp_color=$(get_color "$temp")
    
    # Build temperature display based on TEMP_DISPLAY setting
    local temp_display
    if [ "$TEMP_DISPLAY" = "celsius" ]; then
        # Celsius only: "35°C  "
        temp_display="${current_temp_color}${temp}°C${RESET}"
        local visible_len=${#temp}
        local padding=$((5 - visible_len))  # Target 5 chars for C-only
        if [ $padding -lt 0 ]; then padding=0; fi
        temp_display="${temp_display}$(printf ' %.0s' $(seq 1 $padding))"
    elif [ "$TEMP_DISPLAY" = "fahrenheit" ]; then
        # Fahrenheit only: "95°F  " or "104°F "
        temp_display="${current_temp_color}$(printf "%3d" "$temp_f")°F${RESET}"
        local visible_len=$((${#temp_f} + 2))
        local padding=$((6 - visible_len))  # Target 6 chars for F-only
        if [ $padding -lt 0 ]; then padding=0; fi
        temp_display="${temp_display}$(printf ' %.0s' $(seq 1 $padding))"
    else
        # Both (default): "35°C/95°F  " or "40°C/104°F "
        local visible_len=$((${#temp} + 10))
        local padding=$((9 - visible_len))
        if [ $padding -lt 0 ]; then padding=0; fi
        local spacing=$(printf ' %.0s' $(seq 1 $padding))
        temp_display="${current_temp_color}${temp}°C${RESET}${BOLD}${WHITE}/${RESET}${current_temp_color}$(printf "%3d" "$temp_f")°F${RESET}${spacing}"
    fi
    
    bar+="\033[0m｣ ${temp_display}"

    echo -e "$bar"
}

# Reset color
RESET="\033[0m"
BOLD="\033[1m"
BLUE="\033[38;5;33m"
CYAN="\033[38;5;51m"
LIGHTBLUE="\033[38;5;117m"
GRAY="\033[38;5;240m"
YELLOW="\033[38;5;226m"
WHITE="\033[38;5;15m"
BLACK="\033[38;5;16m"
DARKBLUE_BG="\033[48;5;17m"
PURPLE_BG="\033[48;5;54m"
TEMPINFO_BG="\033[48;5;240m"
YELLOW_BG="\033[48;5;220m"

# In-memory tracking storage (associative array)
declare -A MEMORY_LOG

# Function to log temperature
log_temperature() {
    local drive=$1
    local temp=$2
    local timestamp=$(date +%s)
    
    if [ "$USE_MEMORY_TRACKING" = "true" ]; then
        # Store in memory with format: timestamp|drive|temp
        MEMORY_LOG["${timestamp}:${drive}"]="${timestamp}|${drive}|${temp}"
    else
        # Store in file
        echo "${timestamp}|${drive}|${temp}" >> "$LOG_FILE"
    fi
}

# Function to get min/max temps within the configured time window for a drive
get_stats() {
    local drive=$1
    local cutoff=$(($(date +%s) - (STATS_TIME_WINDOW * 3600)))  # Convert hours to seconds

    if [ "$USE_MEMORY_TRACKING" = "true" ]; then
        # Get temps from memory
        local temps=""
        for key in "${!MEMORY_LOG[@]}"; do
            local entry="${MEMORY_LOG[$key]}"
            local timestamp
            local entry_drive
            local temp
            timestamp=$(echo "$entry" | cut -d'|' -f1)
            entry_drive=$(echo "$entry" | cut -d'|' -f2)
            temp=$(echo "$entry" | cut -d'|' -f3)
            
            if [ "$entry_drive" = "$drive" ] && [ "$timestamp" -ge "$cutoff" ]; then
                temps="${temps}${temp}"$'\n'
            fi
        done
        
        if [ -z "$temps" ]; then
            echo "N/A|N/A"
            return
        fi
        
        # Calculate min and max
        local min
        local max
        min=$(echo "$temps" | grep -v '^$' | sort -n | head -1)
        max=$(echo "$temps" | grep -v '^$' | sort -n | tail -1)
        echo "${min}|${max}"
    else
        # Get temps from file
        if [ ! -f "$LOG_FILE" ]; then
            echo "N/A|N/A"
            return
        fi

        # Get temps for this drive within the time window
        local temps
        temps=$(awk -F'|' -v d="$drive" -v c="$cutoff" '$1 >= c && $2 == d {print $3}' "$LOG_FILE")

        if [ -z "$temps" ]; then
            echo "N/A|N/A"
            return
        fi

        # Calculate min and max
        local min
        local max
        min=$(echo "$temps" | sort -n | head -1)
        max=$(echo "$temps" | sort -n | tail -1)
        echo "${min}|${max}"
    fi
}

# Function to clean old log entries (older than configured time window)
clean_old_logs() {
    local cutoff=$(($(date +%s) - (STATS_TIME_WINDOW * 3600)))  # Convert hours to seconds
    
    if [ "$USE_MEMORY_TRACKING" = "true" ]; then
        # Clean old entries from memory
        for key in "${!MEMORY_LOG[@]}"; do
            local entry="${MEMORY_LOG[$key]}"
            local timestamp
            timestamp=$(echo "$entry" | cut -d'|' -f1)
            
            if [ "$timestamp" -lt "$cutoff" ]; then
                unset MEMORY_LOG["$key"]
            fi
        done
    else
        # Clean old entries from file
        if [ ! -f "$LOG_FILE" ]; then
            return
        fi

        local temp_file=$(mktemp)

        # Keep only entries within the time window
        awk -F'|' -v c="$cutoff" '$1 >= c' "$LOG_FILE" > "$temp_file"
        
        # Only update the log file if the temp file was created successfully
        if [ -s "$temp_file" ]; then
            mv "$temp_file" "$LOG_FILE"
        else
            # If temp file is empty but log file exists, it means all entries are old
            # Keep the file but make it empty
            if [ -f "$LOG_FILE" ]; then
                > "$LOG_FILE"
            fi
            rm -f "$temp_file"
        fi
    fi
}

# Trap Ctrl+C to exit cleanly
trap 'echo -e "\n${GRAY}Monitoring stopped.${RESET}"; exit 0' INT

# Main monitoring loop
while true; do
    # Clean old log entries once per iteration
    clean_old_logs

    # Clear screen
    clear

    # Get terminal width
    TERM_WIDTH=$(tput cols)

    # Create border line
    BORDER_LINE=$(printf '═%.0s' $(seq 1 $((TERM_WIDTH - 2))))

    # Print header box with full terminal width
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}╔${BORDER_LINE}╗${RESET}"

    # Title line
    TITLE="Drive Temperature Monitor - Version 2 [ Truvis Thornton - http://truv.is ]"
    TITLE_LEN=${#TITLE}
    # Account for the space after ║ and before ║ (2 spaces total) plus the two ║ chars (2)
    PAD_LEN=$((TERM_WIDTH - TITLE_LEN - 4))
    if [ $PAD_LEN -lt 0 ]; then PAD_LEN=0; fi
    PADDING=$(printf ' %.0s' $(seq 1 $PAD_LEN))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${BOLD}${YELLOW}${TITLE}${PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    # Refresh info line with time window
    if [ "$USE_MEMORY_TRACKING" = "true" ]; then
        REFRESH_TEXT="Refreshing every ${REFRESH_INTERVAL}s - Stats Window: ${STATS_TIME_WINDOW}h (In-Memory) - Press Ctrl+C to exit"
    else
        REFRESH_TEXT="Refreshing every ${REFRESH_INTERVAL}s - Stats Window: ${STATS_TIME_WINDOW}h - Press Ctrl+C to exit"
    fi
    REFRESH_LEN=${#REFRESH_TEXT}
    REFRESH_PAD=$((TERM_WIDTH - REFRESH_LEN - 4))
    if [ $REFRESH_PAD -lt 0 ]; then REFRESH_PAD=0; fi
    REFRESH_PADDING=$(printf ' %.0s' $(seq 1 $REFRESH_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${REFRESH_TEXT}${RESET}${PURPLE_BG}${REFRESH_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    # Separator line after refresh info
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}╠${BORDER_LINE}╣${RESET}"

    # Temperature range info based on color mapping (bars start at 28°C)
    # Note: Emoji is counted as ~4 bytes but displays as 2 columns
    # We need to calculate visible length separately from the colored string
    INFO1="${LIGHTBLUE}🌡️${RESET} Cool: ≤28°C (≤82°F) - Light Blue (1 block)"
    INFO1_VISIBLE="🌡️ Cool: ≤28°C (≤82°F) - Light Blue (1 block)"
    INFO1_LEN=${#INFO1_VISIBLE}
    INFO1_PAD=$((TERM_WIDTH - INFO1_LEN - 3))  # -3 to compensate for emoji display width
    if [ $INFO1_PAD -lt 0 ]; then INFO1_PAD=0; fi
    INFO1_PADDING=$(printf ' %.0s' $(seq 1 $INFO1_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${TEMPINFO_BG} ${LIGHTBLUE}🌡️${RESET}${TEMPINFO_BG}${WHITE} Cool: ≤28°C (≤82°F) - Light Blue (1 block)${RESET}${TEMPINFO_BG}${INFO1_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    INFO2="\033[38;5;46m🌡️${RESET} Optimal: 29°C to 45°C (84°F to 113°F) - Green to Yellow"
    INFO2_VISIBLE="🌡️ Optimal: 29°C to 45°C (84°F to 113°F) - Green to Yellow"
    INFO2_LEN=${#INFO2_VISIBLE}
    INFO2_PAD=$((TERM_WIDTH - INFO2_LEN - 3))
    if [ $INFO2_PAD -lt 0 ]; then INFO2_PAD=0; fi
    INFO2_PADDING=$(printf ' %.0s' $(seq 1 $INFO2_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${TEMPINFO_BG} \033[38;5;46m🌡️${RESET}${TEMPINFO_BG}${WHITE} Optimal: 29°C to 45°C (84°F to 113°F) - Green to Yellow${RESET}${TEMPINFO_BG}${INFO2_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    INFO3="\033[38;5;208m🌡️${RESET} Warm: 46°C to 55°C (115°F to 131°F) - Orange to Brown/Red"
    INFO3_VISIBLE="🌡️ Warm: 46°C to 55°C (115°F to 131°F) - Orange to Brown/Red"
    INFO3_LEN=${#INFO3_VISIBLE}
    INFO3_PAD=$((TERM_WIDTH - INFO3_LEN - 3))
    if [ $INFO3_PAD -lt 0 ]; then INFO3_PAD=0; fi
    INFO3_PADDING=$(printf ' %.0s' $(seq 1 $INFO3_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${TEMPINFO_BG} \033[38;5;208m🌡️${RESET}${TEMPINFO_BG}${WHITE} Warm: 46°C to 55°C (115°F to 131°F) - Orange to Brown/Red${RESET}${TEMPINFO_BG}${INFO3_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    INFO4="\033[38;5;196m🌡️${RESET} Critical: 56°C to 65°C (133°F to 149°F) - Red to Bright Magenta"
    INFO4_VISIBLE="🌡️ Critical: 56°C to 65°C (133°F to 149°F) - Red to Bright Magenta"
    INFO4_LEN=${#INFO4_VISIBLE}
    INFO4_PAD=$((TERM_WIDTH - INFO4_LEN - 3))
    if [ $INFO4_PAD -lt 0 ]; then INFO4_PAD=0; fi
    INFO4_PADDING=$(printf ' %.0s' $(seq 1 $INFO4_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${TEMPINFO_BG} \033[38;5;196m🌡️${RESET}${TEMPINFO_BG}${WHITE} Critical: 56°C to 65°C (133°F to 149°F) - Red to Bright Magenta${RESET}${TEMPINFO_BG}${INFO4_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}╚${BORDER_LINE}╝${RESET}"

    # Get hostname and IP address
    HOSTNAME=$(hostname)
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    if [ -z "$IP_ADDRESS" ]; then
        IP_ADDRESS="No IP"
    fi

    # Hostname section border (top)
    echo -e "${YELLOW_BG}${BLACK}╔${BORDER_LINE}╗${RESET}"

    # Hostname and IP bar with borders
    HOST_INFO="🖥️ ${HOSTNAME} • 🖧 ${IP_ADDRESS}"
    HOST_LEN=$((${#HOSTNAME} + ${#IP_ADDRESS} + 11))  # Account for symbols, spaces, and emojis
    HOST_PAD=$((TERM_WIDTH - HOST_LEN))  # Account for borders and spaces
    if [ $HOST_PAD -lt 0 ]; then
        HOST_PAD=0
        # Truncate hostname if too long
        MAX_HOST_LEN=$((TERM_WIDTH - ${#IP_ADDRESS} - 14))
        if [ $MAX_HOST_LEN -gt 0 ]; then
            HOSTNAME="${HOSTNAME:0:$MAX_HOST_LEN}"
            HOST_INFO="🖥️ ${HOSTNAME} • 🖧 ${IP_ADDRESS}"
            HOST_PAD=1
        fi
    fi
    HOST_PADDING=$(printf ' %.0s' $(seq 1 $HOST_PAD))
    echo -e "${YELLOW_BG}${BLACK}║${RESET}${YELLOW_BG}${BLACK} ${HOST_INFO}${HOST_PADDING} ${RESET}${YELLOW_BG}${BLACK}║${RESET}"

    # Drive monitoring section border (top with T-connection)
    echo -e "${YELLOW_BG}${BLACK}╠${BORDER_LINE}╣${RESET}"

    # T-border line
    echo -e "${BOLD}${LIGHTBLUE}╠${BORDER_LINE}╣${RESET}"

    # Calculate dynamic column widths based on terminal width
    # Fixed/minimum column widths:
    DRIVE_WIDTH=10        # "[ DRIVE    ]"
    TEMP_BAR_WIDTH=55     # Temperature bar with brackets and value
    SERIAL_WIDTH=26       # "[ SERIAL                 ]"
    
    # Calculate stats width based on TEMP_DISPLAY
    if [ "$TEMP_DISPLAY" = "celsius" ]; then
        STATS_WIDTH=20    # For C-only display
    elif [ "$TEMP_DISPLAY" = "fahrenheit" ]; then
        STATS_WIDTH=22    # For F-only display
    else
        STATS_WIDTH=29    # For both C/F display
    fi
    
    # Calculate remaining space for MODEL column
    FIXED_WIDTHS=$((DRIVE_WIDTH + TEMP_BAR_WIDTH + STATS_WIDTH + SERIAL_WIDTH + 12))  # 12 for spacing
    MODEL_WIDTH=$((TERM_WIDTH - FIXED_WIDTHS + 1))  # +1 to bring closing bracket closer (reduced from +3)
    
    # Ensure minimum widths
    if [ $MODEL_WIDTH -lt 20 ]; then
        MODEL_WIDTH=20
    fi

    # Header row values
    HEADER_DRIVE="DRIVE"
    HEADER_GRAPH="TEMPERATURE GRAPH"
    HEADER_SERIAL="SERIAL"
    HEADER_MODEL="MODEL"
    
    # Set stats header based on temperature display format
    if [ "$TEMP_DISPLAY" = "celsius" ]; then
        HEADER_STATS="${STATS_TIME_WINDOW}H MIN/MAX (C)"
    elif [ "$TEMP_DISPLAY" = "fahrenheit" ]; then
        HEADER_STATS="${STATS_TIME_WINDOW}H MIN/MAX (F)"
    else
        HEADER_STATS="${STATS_TIME_WINDOW}H MIN/MAX (C/F)"
    fi

    # Calculate padding for "TEMPERATURE GRAPH" header
    GRAPH_HEADER_LEN=${#HEADER_GRAPH}
    GRAPH_PAD_LEFT=$(( (TEMP_BAR_WIDTH - GRAPH_HEADER_LEN) / 2 ))
    GRAPH_PAD_RIGHT=$(( TEMP_BAR_WIDTH - GRAPH_HEADER_LEN - GRAPH_PAD_LEFT ))
    GRAPH_LEFT_PAD=$(printf ' %.0s' $(seq 1 $GRAPH_PAD_LEFT))
    GRAPH_RIGHT_PAD=$(printf ' %.0s' $(seq 1 $GRAPH_PAD_RIGHT))

    # Calculate header stats padding
    STATS_HEADER_LEN=${#HEADER_STATS}
    STATS_PAD_NEEDED=$((STATS_WIDTH - STATS_HEADER_LEN - 4))  # -4 for brackets and spaces
    if [ $STATS_PAD_NEEDED -lt 0 ]; then STATS_PAD_NEEDED=0; fi

    # Calculate serial padding
    SERIAL_HEADER_LEN=${#HEADER_SERIAL}
    SERIAL_PAD_NEEDED=$((SERIAL_WIDTH - SERIAL_HEADER_LEN - 4))
    if [ $SERIAL_PAD_NEEDED -lt 0 ]; then SERIAL_PAD_NEEDED=0; fi

    # Calculate model padding - need to account for all the formatting correctly
    MODEL_HEADER_LEN=${#HEADER_MODEL}
    MODEL_PAD_NEEDED=$((MODEL_WIDTH - MODEL_HEADER_LEN - 2))  # -6 for brackets and spaces
    if [ $MODEL_PAD_NEEDED -lt 0 ]; then MODEL_PAD_NEEDED=0; fi

    # Print header row with left ║ border, with dark blue background
    printf "${LIGHTBLUE}║${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${CYAN}%-8s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} %s${BOLD}${CYAN}%s${RESET}${DARKBLUE_BG}%s ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${CYAN}%s%-${STATS_PAD_NEEDED}s${RESET}${DARKBLUE_BG}${LIGHTBLUE}]${RESET}${DARKBLUE_BG}  ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${CYAN}%s%-${SERIAL_PAD_NEEDED}s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${CYAN}%s%-${MODEL_PAD_NEEDED}s ${RESET}${DARKBLUE_BG}${LIGHTBLUE}]${RESET}${LIGHTBLUE}║${RESET}\n" \
        "$HEADER_DRIVE" "$GRAPH_LEFT_PAD" "$HEADER_GRAPH" "$GRAPH_RIGHT_PAD" "$HEADER_STATS" "" "$HEADER_SERIAL" "" "$HEADER_MODEL" ""

    # Separator line with dashes (with left border)
    SEP_WIDTH=$((TERM_WIDTH - 4))
    SEPARATOR=$(printf -- '-%.0s' $(seq 1 $SEP_WIDTH))
    printf "${LIGHTBLUE}║${RESET} ${GRAY}${SEPARATOR}${RESET} ${LIGHTBLUE}║${RESET}\n"

    # Get all block devices (excluding loop, ram, etc.)
    drives=$(lsblk -ndo NAME,TYPE | grep disk | awk '{print $1}')

    if [ -z "$drives" ]; then
        echo -e "${LIGHTBLUE}║${RESET} ${WHITE}No drives found${RESET}"
        # Drive monitoring section border (bottom)
        echo -e "${BOLD}${LIGHTBLUE}╚${BORDER_LINE}╝${RESET}"
        echo ""
        sleep $REFRESH_INTERVAL
        continue
    fi

    # Process each drive
    for drive in $drives; do
        device="/dev/$drive"

        # Get drive model
        model=$(smartctl -i "$device" 2>/dev/null | grep "Device Model:" | cut -d: -f2 | xargs)
        if [ -z "$model" ]; then
            model=$(smartctl -i "$device" 2>/dev/null | grep "Model Number:" | cut -d: -f2 | xargs)
        fi
        if [ -z "$model" ]; then
            model=$(smartctl -i "$device" 2>/dev/null | grep "Product:" | cut -d: -f2 | xargs)
        fi
        if [ -z "$model" ]; then
            model="Unknown Model"
        fi

        # Get drive serial number
        serial=$(smartctl -i "$device" 2>/dev/null | grep "Serial Number:" | cut -d: -f2 | xargs)
        if [ -z "$serial" ]; then
            serial=$(smartctl -i "$device" 2>/dev/null | grep "Serial number:" | cut -d: -f2 | xargs)
        fi
        if [ -z "$serial" ]; then
            serial="N/A"
        fi
        
        # Truncate serial to fit in column
        serial_display_width=$((SERIAL_WIDTH - 4))  # Account for brackets and spaces
        serial="${serial:0:$serial_display_width}"

        # Get temperature
        temp=$(smartctl -A "$device" 2>/dev/null | grep -i "Temperature_Celsius" | awk '{print $10}')
        if [ -z "$temp" ]; then
            temp=$(smartctl -A "$device" 2>/dev/null | grep -i "Temperature" | head -n1 | awk '{print $10}')
        fi
        if [ -z "$temp" ]; then
            temp=$(smartctl -a "$device" 2>/dev/null | grep -i "Current Drive Temperature:" | awk '{print $4}')
        fi

        # Truncate model to fit in dynamic column width
        model_display_width=$((MODEL_WIDTH - 4))  # Account for brackets and spaces
        model_display="${model:0:$model_display_width}"

        # Get stats for this drive within the configured time window
        stats=$(get_stats "$drive")
        min_temp=$(echo "$stats" | cut -d'|' -f1)
        max_temp=$(echo "$stats" | cut -d'|' -f2)

        # Format stats display with colors based on TEMP_DISPLAY setting
        if [ "$min_temp" = "N/A" ]; then
            if [ "$TEMP_DISPLAY" = "celsius" ]; then
                stats_display="${GRAY}N/A${RESET}"
                stats_pad=$((STATS_WIDTH - 7))  # "N/A" + brackets
            elif [ "$TEMP_DISPLAY" = "fahrenheit" ]; then
                stats_display="${GRAY}N/A${RESET}"
                stats_pad=$((STATS_WIDTH - 7))
            else
                stats_display="${GRAY}N/A${RESET}"
                stats_pad=$((STATS_WIDTH - 7))
            fi
        else
            min_color=$(get_color "$min_temp")
            max_color=$(get_color "$max_temp")
            min_temp_f=$(( (min_temp * 9 / 5) + 32 ))
            max_temp_f=$(( (max_temp * 9 / 5) + 32 ))
            
            if [ "$TEMP_DISPLAY" = "celsius" ]; then
                stats_display="${min_color}${min_temp}°C${RESET} - ${max_color}${max_temp}°C${RESET}"
                visible_len=$((${#min_temp} + ${#max_temp} + 5))
                stats_pad=$((STATS_WIDTH - visible_len - 4))
            elif [ "$TEMP_DISPLAY" = "fahrenheit" ]; then
                min_temp_f_formatted=$(printf "%3d" "$min_temp_f")
                max_temp_f_formatted=$(printf "%3d" "$max_temp_f")
                stats_display="${min_color}${min_temp_f_formatted}°F${RESET} - ${max_color}${max_temp_f_formatted}°F${RESET}"
                visible_len=$((3 + 3 + 7))
                stats_pad=$((STATS_WIDTH - visible_len - 4))
            else
                min_temp_f_formatted=$(printf "%3d" "$min_temp_f")
                max_temp_f_formatted=$(printf "%3d" "$max_temp_f")
                stats_display="${min_color}${min_temp}°C${RESET}${BOLD}${WHITE}/${RESET}${min_color}${min_temp_f_formatted}°F${RESET} - ${max_color}${max_temp}°C${RESET}${BOLD}${WHITE}/${RESET}${max_color}${max_temp_f_formatted}°F${RESET}"
                visible_len=$((${#min_temp} + 3 + ${#max_temp} + 3 + 13))
                stats_pad=$((STATS_WIDTH - visible_len - 4))
            fi
        fi
        if [ $stats_pad -lt 0 ]; then stats_pad=0; fi

        # Display drive information
        if [ -n "$temp" ] && [ "$temp" -eq "$temp" ] 2>/dev/null; then
            temp_f=$(( (temp * 9 / 5) + 32 ))
            bar=$(create_bar_with_temp "$temp" "$temp_f")

            # Log the temperature
            log_temperature "$drive" "$temp"

            # Build the line with bar and temperature (with left border)
            printf "${LIGHTBLUE}║${RESET} ${LIGHTBLUE}[${RESET} ${BOLD}${WHITE}%-8s${RESET} ${LIGHTBLUE}]${RESET} %s    ${LIGHTBLUE}[${RESET} " "$drive" "$bar"
            echo -ne "$stats_display"
            printf "%-${stats_pad}s${LIGHTBLUE}]${RESET}  ${LIGHTBLUE}[${RESET} ${WHITE}%-${serial_display_width}s${RESET} ${LIGHTBLUE}]${RESET} ${LIGHTBLUE}[${RESET} ${WHITE}%-${model_display_width}s   ${RESET}${LIGHTBLUE}]${RESET}${LIGHTBLUE}║${RESET}\n" \
                "" "$serial" "$model_display"
        else
            # Skip this drive if HIDE_NA_DRIVES is enabled
            if [ "$HIDE_NA_DRIVES" = "true" ]; then
                continue
            fi
            
            # Create a "No temperature data" bar matching the same length as temp bars
            no_temp_bar="｢"
            for ((i=0; i<38; i++)); do
                no_temp_bar+="\033[48;5;0m\033[38;5;240m■\033[0m"
            done
            no_temp_bar+="\033[0m｣ ${GRAY}N/A${RESET}          "

            printf "${LIGHTBLUE}║${RESET} ${LIGHTBLUE}[${RESET} ${BOLD}${WHITE}%-8s${RESET} ${LIGHTBLUE}]${RESET} " "$drive"
            echo -ne "$no_temp_bar"
            printf "  ${LIGHTBLUE}[${RESET} ${GRAY}%-3s${RESET}%-${stats_pad}s${LIGHTBLUE}]${RESET}  ${LIGHTBLUE}[${RESET} ${WHITE}%-${serial_display_width}s${RESET} ${LIGHTBLUE}]${RESET} ${LIGHTBLUE}[${RESET} ${WHITE}%-${model_display_width}s   ${RESET}${LIGHTBLUE}]${RESET}${LIGHTBLUE}║${RESET}\n" \
                "N/A" "" "$serial" "$model_display"
        fi
    done

    # Drive monitoring section border (bottom)
    echo -e "${BOLD}${LIGHTBLUE}╚${BORDER_LINE}╝${RESET}"

    echo ""

    # Wait before next refresh
    sleep $REFRESH_INTERVAL
done
