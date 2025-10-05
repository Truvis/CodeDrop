#!/bin/bash

# Drive Temperature Monitor with Color Coding & Bar Graph
# Displays all drives with temperatures color-coded from green (cool) to red (hot)
# Temperature scale now uses a 1-color-per-degree map for 30°C..65°C
# Truvis Thornton [ http://truv.is ]

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
    # Use printf to ensure F temp is always 3 digits wide (padded with spaces if needed)
    local temp_display
    temp_display=$(printf "%s°C / %3d°F" "$temp" "$temp_f")
    bar+="\033[0m｣ ${current_temp_color}${temp_display}\033[0m"

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
YELLOW_BG="\033[48;5;220m"

# Refresh interval in seconds
REFRESH_INTERVAL=2

# Trap Ctrl+C to exit cleanly
trap 'echo -e "\n${GRAY}Monitoring stopped.${RESET}"; exit 0' INT

# Main monitoring loop
while true; do
    # Clear screen
    clear

    # Get terminal width
    TERM_WIDTH=$(tput cols)

    # Create border line
    BORDER_LINE=$(printf '═%.0s' $(seq 1 $((TERM_WIDTH - 2))))

    # Print header box with full terminal width
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}╔${BORDER_LINE}╗${RESET}"

    # Title line
    TITLE="Drive Temperature Monitor - Version 1 [ Truvis Thornton - http://truv.is ]"
    TITLE_LEN=${#TITLE}
    # Account for the space after ║ and before ║ (2 spaces total) plus the two ║ chars (2)
    PAD_LEN=$((TERM_WIDTH - TITLE_LEN - 4))
    if [ $PAD_LEN -lt 0 ]; then PAD_LEN=0; fi
    PADDING=$(printf ' %.0s' $(seq 1 $PAD_LEN))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${BOLD}${YELLOW}${TITLE}${PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    # Refresh info line
    REFRESH_TEXT="Refreshing every ${REFRESH_INTERVAL}s - Press Ctrl+C to exit"
    REFRESH_LEN=${#REFRESH_TEXT}
    REFRESH_PAD=$((TERM_WIDTH - REFRESH_LEN - 4))
    if [ $REFRESH_PAD -lt 0 ]; then REFRESH_PAD=0; fi
    REFRESH_PADDING=$(printf ' %.0s' $(seq 1 $REFRESH_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${REFRESH_TEXT}${RESET}${PURPLE_BG}${REFRESH_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    # Blank line
    BLANK_PAD=$((TERM_WIDTH - 4))
    if [ $BLANK_PAD -lt 0 ]; then BLANK_PAD=0; fi
    BLANK_PADDING=$(printf ' %.0s' $(seq 1 $BLANK_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${BLANK_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    # Temperature range info based on color mapping (bars start at 28°C)
    INFO1="• Cool: ≤28°C (≤82°F) - Light Blue (1 block)"
    INFO1_LEN=${#INFO1}
    INFO1_PAD=$((TERM_WIDTH - INFO1_LEN - 4))
    if [ $INFO1_PAD -lt 0 ]; then INFO1_PAD=0; fi
    INFO1_PADDING=$(printf ' %.0s' $(seq 1 $INFO1_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${INFO1}${RESET}${PURPLE_BG}${INFO1_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    INFO2="• Optimal: 29°C to 45°C (84°F to 113°F) - Green to Yellow"
    INFO2_LEN=${#INFO2}
    INFO2_PAD=$((TERM_WIDTH - INFO2_LEN - 4))
    if [ $INFO2_PAD -lt 0 ]; then INFO2_PAD=0; fi
    INFO2_PADDING=$(printf ' %.0s' $(seq 1 $INFO2_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${INFO2}${RESET}${PURPLE_BG}${INFO2_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    INFO3="• Warm: 46°C to 55°C (115°F to 131°F) - Orange to Brown/Red"
    INFO3_LEN=${#INFO3}
    INFO3_PAD=$((TERM_WIDTH - INFO3_LEN - 4))
    if [ $INFO3_PAD -lt 0 ]; then INFO3_PAD=0; fi
    INFO3_PADDING=$(printf ' %.0s' $(seq 1 $INFO3_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${INFO3}${RESET}${PURPLE_BG}${INFO3_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    INFO4="• Critical: 56°C to 65°C (133°F to 149°F) - Red to Bright Magenta"
    INFO4_LEN=${#INFO4}
    INFO4_PAD=$((TERM_WIDTH - INFO4_LEN - 4))
    if [ $INFO4_PAD -lt 0 ]; then INFO4_PAD=0; fi
    INFO4_PADDING=$(printf ' %.0s' $(seq 1 $INFO4_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${INFO4}${RESET}${PURPLE_BG}${INFO4_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

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

    # Header row for columns
    HEADER_DRIVE="DRIVE"
    HEADER_GRAPH="TEMPERATURE GRAPH"
    HEADER_SERIAL="SERIAL"
    HEADER_MODEL="MODEL"

    # Calculate padding for "TEMPERATURE GRAPH" header
    # The temperature column includes: ｢ (1) + bar (40) + ｣ (1) + space (1) + temp text (~14) = ~57 chars
    # We want to center "TEMPERATURE GRAPH" in this space
    TEMP_COL_WIDTH=57
    GRAPH_HEADER_LEN=${#HEADER_GRAPH}
    GRAPH_PAD_LEFT=$(( (TEMP_COL_WIDTH - GRAPH_HEADER_LEN) / 2 ))
    GRAPH_PAD_RIGHT=$(( TEMP_COL_WIDTH - GRAPH_HEADER_LEN - GRAPH_PAD_LEFT ))
    GRAPH_LEFT_PAD=$(printf ' %.0s' $(seq 1 $GRAPH_PAD_LEFT))
    GRAPH_RIGHT_PAD=$(printf ' %.0s' $(seq 1 $GRAPH_PAD_RIGHT))

    # Available model width calculation
    AVAILABLE_MODEL_WIDTH=$((TERM_WIDTH - 100))
    if [ $AVAILABLE_MODEL_WIDTH -lt 20 ]; then
        AVAILABLE_MODEL_WIDTH=20
    fi

    # Print header row with proper alignment and dark blue background (without background on borders)
    printf "${LIGHTBLUE}║${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${CYAN}%-8s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} %s${BOLD}${CYAN}%s${RESET}${DARKBLUE_BG}%s  ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${CYAN}%-12s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${CYAN}%-${AVAILABLE_MODEL_WIDTH}s${RESET}${DARKBLUE_BG}${LIGHTBLUE}]${RESET}${DARKBLUE_BG}     ${RESET}${LIGHTBLUE}║${RESET}\n" \
        "$HEADER_DRIVE" "$GRAPH_LEFT_PAD" "$HEADER_GRAPH" "$GRAPH_RIGHT_PAD" "$HEADER_SERIAL" "$HEADER_MODEL"

    # Separator line with dashes
    SEP_WIDTH=$((TERM_WIDTH - 4))
    SEPARATOR=$(printf -- '-%.0s' $(seq 1 $SEP_WIDTH))
    printf "${LIGHTBLUE}║${RESET} ${GRAY}${SEPARATOR}${RESET} ${LIGHTBLUE}║${RESET}\n"

    # Get all block devices (excluding loop, ram, etc.)
    drives=$(lsblk -ndo NAME,TYPE | grep disk | awk '{print $1}')

    if [ -z "$drives" ]; then
        echo -e "${LIGHTBLUE}║${RESET} ${WHITE}No drives found${RESET}$(printf ' %.0s' $(seq 1 $((TERM_WIDTH - 20))))${LIGHTBLUE}║${RESET}"
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
        serial="${serial:0:12}"  # Truncate to 12 chars

        # Get temperature
        temp=$(smartctl -A "$device" 2>/dev/null | grep -i "Temperature_Celsius" | awk '{print $10}')
        if [ -z "$temp" ]; then
            temp=$(smartctl -A "$device" 2>/dev/null | grep -i "Temperature" | head -n1 | awk '{print $10}')
        fi
        if [ -z "$temp" ]; then
            temp=$(smartctl -a "$device" 2>/dev/null | grep -i "Current Drive Temperature:" | awk '{print $4}')
        fi

        # Calculate available space for model based on terminal width
        AVAILABLE_MODEL_WIDTH=$((TERM_WIDTH - 100))
        if [ $AVAILABLE_MODEL_WIDTH -lt 20 ]; then
            AVAILABLE_MODEL_WIDTH=20
        fi
        model_display="${model:0:$AVAILABLE_MODEL_WIDTH}"

        # Display drive information
        if [ -n "$temp" ] && [ "$temp" -eq "$temp" ] 2>/dev/null; then
            temp_f=$(( (temp * 9 / 5) + 32 ))
            bar=$(create_bar_with_temp "$temp" "$temp_f")

            # Build the line with bar and temperature (added 6 spaces before serial bracket)
            printf "${LIGHTBLUE}║${RESET} ${LIGHTBLUE}[${RESET} ${BOLD}${WHITE}%-8s${RESET} ${LIGHTBLUE}]${RESET} %s      ${LIGHTBLUE}[${RESET} ${WHITE}%-12s${RESET} ${LIGHTBLUE}]${RESET} ${LIGHTBLUE}[${RESET} ${WHITE}%-${AVAILABLE_MODEL_WIDTH}s${RESET}${LIGHTBLUE}]${RESET}     ${LIGHTBLUE}║${RESET}\n" \
                "$drive" "$bar" "$serial" "$model_display"
        else
            # Create a "No temperature data" bar matching the same length as temp bars
            # Bar length = (max_temp - min_temp + 1) = (65 - 28 + 1) = 38
            no_temp_bar="｢"
            for ((i=0; i<38; i++)); do
                no_temp_bar+="\033[48;5;0m\033[38;5;240m■\033[0m"
            done
            # Add extra spacing after N/A to match temperature display width
            # Temperature format is "XX°C / XXXF" with padding = 14 chars total, N/A is 3 chars, so add 11 spaces
            no_temp_bar+="\033[0m｣ \033[38;5;240mN/A\033[0m           "

            # Match the format of temperature-enabled drives - need to use echo for escape codes (4 spaces before serial bracket for N/A)
            printf "${LIGHTBLUE}║${RESET} ${LIGHTBLUE}[${RESET} ${BOLD}${WHITE}%-8s${RESET} ${LIGHTBLUE}]${RESET} " "$drive"
            echo -ne "$no_temp_bar"
            printf "    ${LIGHTBLUE}[${RESET} ${WHITE}%-12s${RESET} ${LIGHTBLUE}]${RESET} ${LIGHTBLUE}[${RESET} ${WHITE}%-${AVAILABLE_MODEL_WIDTH}s${RESET}${LIGHTBLUE}]${RESET}     ${LIGHTBLUE}║${RESET}\n" \
                "$serial" "$model_display"
        fi
    done

    # Drive monitoring section border (bottom)
    echo -e "${BOLD}${LIGHTBLUE}╚${BORDER_LINE}╝${RESET}"

    echo ""

    # Wait before next refresh
    sleep $REFRESH_INTERVAL
done
