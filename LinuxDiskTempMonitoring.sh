#!/bin/bash

# Drive Temperature Monitor with Color Coding & Bar Graph
# Displays all drives with temperatures color-coded from green (cool) to red (hot)
# Temperature scale: 25°C (green) to 55°C (red)
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

# Function to get color based on temperature
get_color() {
    local temp=$1

    # Red: 45°C and above
    if [ "$temp" -ge 45 ]; then
        echo -e "\033[38;5;196m"  # Red
    # Dark orange: 42-44°C
    elif [ "$temp" -ge 42 ]; then
        echo -e "\033[38;5;208m"  # Dark orange
    # Orange: 40-41°C
    elif [ "$temp" -ge 40 ]; then
        echo -e "\033[38;5;214m"  # Orange
    # Yellow: 35-39°C
    elif [ "$temp" -ge 35 ]; then
        echo -e "\033[38;5;226m"  # Yellow
    # Green: 30-34°C (optimal)
    elif [ "$temp" -ge 30 ]; then
        echo -e "\033[38;5;46m"  # Green
    # Light green: 22-29°C
    elif [ "$temp" -ge 22 ]; then
        echo -e "\033[38;5;86m"  # Light green
    # Light blue: 15-21°C
    elif [ "$temp" -ge 15 ]; then
        echo -e "\033[38;5;51m"  # Light blue
    # Purple: below 15°C (cold)
    else
        echo -e "\033[38;5;93m"  # Purple
    fi
}

# Function to get background color based on temperature
get_bg_color() {
    local temp=$1

    # Red: 45°C and above
    if [ "$temp" -ge 45 ]; then
        echo -e "\033[48;5;196m"  # Red bg
    # Dark orange: 42-44°C
    elif [ "$temp" -ge 42 ]; then
        echo -e "\033[48;5;208m"  # Dark orange bg
    # Orange: 40-41°C
    elif [ "$temp" -ge 40 ]; then
        echo -e "\033[48;5;214m"  # Orange bg
    # Yellow: 35-39°C
    elif [ "$temp" -ge 35 ]; then
        echo -e "\033[48;5;226m"  # Yellow bg
    # Green: 30-34°C (optimal)
    elif [ "$temp" -ge 30 ]; then
        echo -e "\033[48;5;46m"  # Green bg
    # Light green: 22-29°C
    elif [ "$temp" -ge 22 ]; then
        echo -e "\033[48;5;86m"  # Light green bg
    # Light blue: 15-21°C
    elif [ "$temp" -ge 15 ]; then
        echo -e "\033[48;5;51m"  # Light blue bg
    # Purple: below 15°C (cold)
    else
        echo -e "\033[48;5;93m"  # Purple bg
    fi
}

# Function to create bar graph with temperature overlaid
create_bar_with_temp() {
    local temp=$1
    local temp_f=$2
    local min_temp=5
    local max_temp=65
    local bar_length=50  # Increased to accommodate text

    # Clamp temperature
    if [ "$temp" -lt "$min_temp" ]; then
        temp=$min_temp
    elif [ "$temp" -gt "$max_temp" ]; then
        temp=$max_temp
    fi

    # Calculate filled portion
    local range=$((max_temp - min_temp))
    local position=$((temp - min_temp))
    local filled=$((position * bar_length / range))
    local empty=$((bar_length - filled))

    # Get colors
    local color=$(get_color "$temp")
    local bg_color=$(get_bg_color "$temp")

    # Create temperature text
    local temp_text=$(printf "%3s°C / %3s°F" "$temp" "$temp_f")
    local text_len=${#temp_text}
    local text_pos=1  # Place at left side (position 1 for padding)
    local text_end=$((text_pos + text_len))

    # Build bar with temperature text in the middle
    local bar=""

    # Build filled portion
    for ((i=0; i<filled; i++)); do
        if [ $i -ge $text_pos ] && [ $i -lt $text_end ]; then
            # We're in the text area - add one character of text with colored background
            local char_index=$((i - text_pos))
            local char="${temp_text:$char_index:1}"
            bar+="${bg_color}\033[38;5;16m${char}"
        else
            # Regular filled block
            bar+="${color}█"
        fi
    done

    # Build empty portion
    for ((i=filled; i<bar_length; i++)); do
        if [ $i -ge $text_pos ] && [ $i -lt $text_end ]; then
            # We're in the text area - add one character of text with gray background
            local char_index=$((i - text_pos))
            local char="${temp_text:$char_index:1}"
            bar+="\033[48;5;240m\033[38;5;255m${char}"
        else
            # Regular empty block with grey background
            bar+="\033[48;5;240m\033[38;5;255m░"
        fi
    done

    bar+="\033[0m"

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

    # Temperature scale line with ranges in colors (green at 30°C, red starts at 45°C, goes to 65°C)
    SCALE_LEN=63
    SCALE_PAD=$((TERM_WIDTH - SCALE_LEN - 4))
    if [ $SCALE_PAD -lt 0 ]; then SCALE_PAD=0; fi
    SCALE_PADDING=$(printf ' %.0s' $(seq 1 $SCALE_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${BOLD}${WHITE}Temp Scale: 5°C/41°F ${RESET}${PURPLE_BG}\033[48;5;93m\033[38;5;231m 5 \033[0m${PURPLE_BG}\033[48;5;51m\033[38;5;16m 15 \033[0m${PURPLE_BG}\033[48;5;86m\033[38;5;16m 22 \033[0m${PURPLE_BG}\033[48;5;46m\033[38;5;16m 30 \033[0m${PURPLE_BG}\033[48;5;226m\033[38;5;16m 35 \033[0m${PURPLE_BG}\033[48;5;214m\033[38;5;16m 40 \033[0m${PURPLE_BG}\033[48;5;208m\033[38;5;16m 42 \033[0m${PURPLE_BG}\033[48;5;196m\033[38;5;231m 45 \033[0m${RESET}${PURPLE_BG} ${BOLD}${WHITE}65°C/149°F${RESET}${PURPLE_BG}${SCALE_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

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

    # Temperature range info
    INFO1="• Optimal: 30°C to 45°C (86°F to 113°F)"
    INFO1_LEN=${#INFO1}
    INFO1_PAD=$((TERM_WIDTH - INFO1_LEN - 4))
    if [ $INFO1_PAD -lt 0 ]; then INFO1_PAD=0; fi
    INFO1_PADDING=$(printf ' %.0s' $(seq 1 $INFO1_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${INFO1}${RESET}${PURPLE_BG}${INFO1_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    INFO2="• Acceptable (but concerning): 45°C to 55°C (113°F to 131°F)"
    INFO2_LEN=${#INFO2}
    INFO2_PAD=$((TERM_WIDTH - INFO2_LEN - 4))
    if [ $INFO2_PAD -lt 0 ]; then INFO2_PAD=0; fi
    INFO2_PADDING=$(printf ' %.0s' $(seq 1 $INFO2_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${INFO2}${RESET}${PURPLE_BG}${INFO2_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    INFO3="• Critical/Dangerous: Consistently above 55°C (131°F)"
    INFO3_LEN=${#INFO3}
    INFO3_PAD=$((TERM_WIDTH - INFO3_LEN - 4))
    if [ $INFO3_PAD -lt 0 ]; then INFO3_PAD=0; fi
    INFO3_PADDING=$(printf ' %.0s' $(seq 1 $INFO3_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${INFO3}${RESET}${PURPLE_BG}${INFO3_PADDING} ${RESET}${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}"

    INFO4="• Cold Risk: Below 5°C (41°F)"
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
    HOST_INFO="${HOSTNAME} • ${IP_ADDRESS}"
    HOST_LEN=$((${#HOSTNAME} + ${#IP_ADDRESS} + 3))  # Account for symbols and spaces
    HOST_PAD=$((TERM_WIDTH - HOST_LEN - 4))  # Account for borders and spaces
    if [ $HOST_PAD -lt 0 ]; then
        HOST_PAD=0
        # Truncate hostname if too long
        MAX_HOST_LEN=$((TERM_WIDTH - ${#IP_ADDRESS} - 14))
        if [ $MAX_HOST_LEN -gt 0 ]; then
            HOSTNAME="${HOSTNAME:0:$MAX_HOST_LEN}"
            HOST_INFO="${HOSTNAME} • ${IP_ADDRESS}"
            HOST_PAD=1
        fi
    fi
    HOST_PADDING=$(printf ' %.0s' $(seq 1 $HOST_PAD))
    echo -e "${YELLOW_BG}${BLACK}║${RESET}${YELLOW_BG}${BLACK} ${HOST_INFO}${HOST_PADDING} ${RESET}${YELLOW_BG}${BLACK}║${RESET}"

    # Drive monitoring section border (top with T-connection)
    echo -e "${YELLOW_BG}${BLACK}╠${BORDER_LINE}╣${RESET}"

    # Dark blue T-border line
    echo -e "${DARKBLUE_BG}${BOLD}${LIGHTBLUE}╠${BORDER_LINE}╣${RESET}"

    # Header row for columns
    HEADER_DRIVE="DRIVE"
    HEADER_GRAPH="TEMPERATURE GRAPH"
    HEADER_SERIAL="SERIAL"
    HEADER_MODEL="MODEL"

    # Calculate padding for centered "TEMPERATURE GRAPH" in the 50-char bar area
    GRAPH_HEADER_LEN=${#HEADER_GRAPH}
    GRAPH_PAD_LEFT=$(( (50 - GRAPH_HEADER_LEN) / 2 ))
    GRAPH_PAD_RIGHT=$(( 50 - GRAPH_HEADER_LEN - GRAPH_PAD_LEFT ))
    GRAPH_LEFT_PAD=$(printf ' %.0s' $(seq 1 $GRAPH_PAD_LEFT))
    GRAPH_RIGHT_PAD=$(printf ' %.0s' $(seq 1 $GRAPH_PAD_RIGHT))

    # Available model width calculation (adjusted for wider bar)
    AVAILABLE_MODEL_WIDTH=$((TERM_WIDTH - 91))
    if [ $AVAILABLE_MODEL_WIDTH -lt 20 ]; then
        AVAILABLE_MODEL_WIDTH=20
    fi

    # Print header row
    printf "${DARKBLUE_BG}${LIGHTBLUE}║${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${CYAN}%-8s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${GRAY}|${RESET}${DARKBLUE_BG}%s${BOLD}${CYAN}%s${GRAY}%s${RESET}${DARKBLUE_BG}${GRAY}|${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${CYAN}%-12s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${CYAN}%-${AVAILABLE_MODEL_WIDTH}s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}║${RESET}\n" \
        "$HEADER_DRIVE" "$GRAPH_LEFT_PAD" "$HEADER_GRAPH" "$GRAPH_RIGHT_PAD" "$HEADER_SERIAL" "$HEADER_MODEL"

    # Separator line with dashes
    SEP_WIDTH=$((TERM_WIDTH - 4))
    SEPARATOR=$(printf -- '-%.0s' $(seq 1 $SEP_WIDTH))
    printf "${DARKBLUE_BG}${LIGHTBLUE}║${RESET}${DARKBLUE_BG} ${GRAY}${SEPARATOR}${RESET}${DARKBLUE_BG} ${LIGHTBLUE}║${RESET}\n"

    # Get all block devices (excluding loop, ram, etc.)
    drives=$(lsblk -ndo NAME,TYPE | grep disk | awk '{print $1}')

    if [ -z "$drives" ]; then
        echo -e "${DARKBLUE_BG}${LIGHTBLUE}║${RESET}${DARKBLUE_BG} ${WHITE}No drives found${RESET}${DARKBLUE_BG}$(printf ' %.0s' $(seq 1 $((TERM_WIDTH - 20))))${LIGHTBLUE}║${RESET}"
        # Drive monitoring section border (bottom)
        echo -e "${DARKBLUE_BG}${BOLD}${LIGHTBLUE}╚${BORDER_LINE}╝${RESET}"
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
        AVAILABLE_MODEL_WIDTH=$((TERM_WIDTH - 91))
        if [ $AVAILABLE_MODEL_WIDTH -lt 20 ]; then
            AVAILABLE_MODEL_WIDTH=20
        fi
        model_display="${model:0:$AVAILABLE_MODEL_WIDTH}"

        # Display drive information with dark blue background
        if [ -n "$temp" ] && [ "$temp" -eq "$temp" ] 2>/dev/null; then
            temp_f=$(( (temp * 9 / 5) + 32 ))
            bar=$(create_bar_with_temp "$temp" "$temp_f")

            # Build the line with temperature embedded in bar
            printf "${DARKBLUE_BG}${LIGHTBLUE}║${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${WHITE}%-8s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} |%s${DARKBLUE_BG}| ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${WHITE}%-12s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${WHITE}%-${AVAILABLE_MODEL_WIDTH}s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}║${RESET}\n" \
                "$drive" "$bar" "$serial" "$model_display"
        else
            # Create a centered "No temperature data" message in the bar area (50 chars to match bar length)
            NO_TEMP_MSG="              No temperature data               "

            printf "${DARKBLUE_BG}${LIGHTBLUE}║${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${WHITE}%-8s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG}  |${GRAY}%s${RESET}${DARKBLUE_BG}|  ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${WHITE}%-12s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${WHITE}%-${AVAILABLE_MODEL_WIDTH}s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}║${RESET}\n" \
                "$drive" "$NO_TEMP_MSG" "$serial" "$model_display"
        fi
    done

    # Drive monitoring section border (bottom)
    echo -e "${DARKBLUE_BG}${BOLD}${LIGHTBLUE}╚${BORDER_LINE}╝${RESET}"

    echo ""

    # Wait before next refresh
    sleep $REFRESH_INTERVAL
done
