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
    
    # Red: 45-65°C
    if [ "$temp" -ge 45 ]; then
        echo -e "\033[38;5;196m"  # Red
    # Green/Yellow/Orange/Red gradient: 30-44°C
    elif [ "$temp" -ge 30 ]; then
        local range=14  # 44 - 30
        local position=$((temp - 30))
        local color_index=$((position * 4 / range))
        case $color_index in
            0) echo -e "\033[38;5;46m" ;;   # Green
            1) echo -e "\033[38;5;226m" ;;  # Yellow
            2) echo -e "\033[38;5;214m" ;;  # Orange
            *) echo -e "\033[38;5;208m" ;;  # Dark orange
        esac
    # Purple to Light Blue/Green: 5-29°C
    else
        if [ "$temp" -lt 5 ]; then
            temp=5
        fi
        local range=24  # 29 - 5
        local position=$((temp - 5))
        local color_index=$((position * 3 / range))
        case $color_index in
            0) echo -e "\033[38;5;93m" ;;   # Purple
            1) echo -e "\033[38;5;51m" ;;   # Light blue
            *) echo -e "\033[38;5;86m" ;;   # Light green
        esac
    fi
}

# Function to create bar graph
create_bar() {
    local temp=$1
    local min_temp=5
    local max_temp=65
    local bar_length=25
    
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
    
    # Get color
    local color=$(get_color "$temp")
    
    # Build bar
    local bar="${color}"
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    bar+="\033[38;5;240m"  # Dark gray for empty portion
    for ((i=0; i<empty; i++)); do
        bar+="░"
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
    
    # Calculate padding for centered text
    TITLE="🌡️  Drive Temperature Monitor 🌡️"
    # Account for emoji taking up visual space (approximately 4 chars per emoji)
    TITLE_LEN=37
    PAD_LEN=$((TERM_WIDTH - TITLE_LEN - 2))
    if [ $PAD_LEN -lt 0 ]; then PAD_LEN=0; fi
    PADDING=$(printf ' %.0s' $(seq 1 $PAD_LEN))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${BOLD}${YELLOW}${TITLE}${RESET}${PURPLE_BG}${PADDING}${BOLD}${LIGHTBLUE}║${RESET}"
    
    # Temperature scale line
    # "Temperature Scale: " (19) + "5°C" (3) + 8 bars + "65°C" (4) = ~34 visual chars
    SCALE_LEN=36
    SCALE_PAD=$((TERM_WIDTH - SCALE_LEN - 2))
    if [ $SCALE_PAD -lt 0 ]; then SCALE_PAD=0; fi
    SCALE_PADDING=$(printf ' %.0s' $(seq 1 $SCALE_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${BOLD}${WHITE}Temperature Scale: ${BOLD}\033[38;5;93m5°C${RESET}${PURPLE_BG}\033[38;5;93m━\033[38;5;51m━\033[38;5;86m━\033[38;5;46m━\033[38;5;226m━\033[38;5;214m━\033[38;5;208m━\033[38;5;196m━${RESET}${PURPLE_BG}${BOLD}\033[38;5;196m65°C${RESET}${PURPLE_BG}${SCALE_PADDING}${BOLD}${LIGHTBLUE}║${RESET}"
    
    # Refresh info line
    REFRESH_TEXT="Refreshing every ${REFRESH_INTERVAL}s - Press Ctrl+C to exit"
    REFRESH_LEN=${#REFRESH_TEXT}
    REFRESH_PAD=$((TERM_WIDTH - REFRESH_LEN - 3))
    REFRESH_PADDING=$(printf ' %.0s' $(seq 1 $REFRESH_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${REFRESH_TEXT}${RESET}${PURPLE_BG}${REFRESH_PADDING}${BOLD}${LIGHTBLUE}║${RESET}"
    
    # Blank line
    BLANK_PAD=$((TERM_WIDTH - 2))
    BLANK_PADDING=$(printf ' %.0s' $(seq 1 $BLANK_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG}${BLANK_PADDING}${BOLD}${LIGHTBLUE}║${RESET}"
    
    # Temperature range info
    INFO1="• Optimal: 30°C to 45°C (86°F to 113°F)"
    INFO1_LEN=${#INFO1}
    INFO1_PAD=$((TERM_WIDTH - INFO1_LEN - 3))
    INFO1_PADDING=$(printf ' %.0s' $(seq 1 $INFO1_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${INFO1}${RESET}${PURPLE_BG}${INFO1_PADDING}${BOLD}${LIGHTBLUE}║${RESET}"
    
    INFO2="• Acceptable (but concerning): 45°C to 55°C (113°F to 131°F)"
    INFO2_LEN=${#INFO2}
    INFO2_PAD=$((TERM_WIDTH - INFO2_LEN - 3))
    INFO2_PADDING=$(printf ' %.0s' $(seq 1 $INFO2_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${INFO2}${RESET}${PURPLE_BG}${INFO2_PADDING}${BOLD}${LIGHTBLUE}║${RESET}"
    
    INFO3="• Critical/Dangerous: Consistently above 55°C (131°F)"
    INFO3_LEN=${#INFO3}
    INFO3_PAD=$((TERM_WIDTH - INFO3_LEN - 3))
    INFO3_PADDING=$(printf ' %.0s' $(seq 1 $INFO3_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${INFO3}${RESET}${PURPLE_BG}${INFO3_PADDING}${BOLD}${LIGHTBLUE}║${RESET}"
    
    INFO4="• Cold Risk: Below 5°C (41°F)"
    INFO4_LEN=${#INFO4}
    INFO4_PAD=$((TERM_WIDTH - INFO4_LEN - 3))
    INFO4_PADDING=$(printf ' %.0s' $(seq 1 $INFO4_PAD))
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}║${RESET}${PURPLE_BG} ${WHITE}${INFO4}${RESET}${PURPLE_BG}${INFO4_PADDING}${BOLD}${LIGHTBLUE}║${RESET}"
    
    echo -e "${PURPLE_BG}${BOLD}${LIGHTBLUE}╚${BORDER_LINE}╝${RESET}"
    
    # Get hostname and IP address
    HOSTNAME=$(hostname)
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    if [ -z "$IP_ADDRESS" ]; then
        IP_ADDRESS="No IP"
    fi
    
    # Hostname and IP bar
    HOST_INFO="🖥️  ${HOSTNAME} • ${IP_ADDRESS}"
    HOST_LEN=$((${#HOSTNAME} + ${#IP_ADDRESS} + 9))  # Account for emoji and symbols
    HOST_PAD=$((TERM_WIDTH - HOST_LEN))
    if [ $HOST_PAD -lt 0 ]; then HOST_PAD=0; fi
    HOST_PADDING=$(printf ' %.0s' $(seq 1 $HOST_PAD))
    echo -e "${YELLOW_BG}${BLACK}${HOST_INFO}${HOST_PADDING}${RESET}"
    
    # Drive monitoring section border (top)
    echo -e "${DARKBLUE_BG}${BOLD}${LIGHTBLUE}╔${BORDER_LINE}╗${RESET}"
    
    # Get all block devices (excluding loop, ram, etc.)
    drives=$(lsblk -ndo NAME,TYPE | grep disk | awk '{print $1}')
    
    if [ -z "$drives" ]; then
        echo "No drives found"
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
        
        # Truncate model if too long
        model_short="${model:0:30}"
        
        # Convert C to F
        if [ -n "$temp" ] && [ "$temp" -eq "$temp" ] 2>/dev/null; then
            temp_f=$(( (temp * 9 / 5) + 32 ))
        fi
        
        # Calculate available space for model based on terminal width
        # Format: [ drive ] |bar| [ temp ] [ serial ] [ model ]
        # Fixed widths: drive=10, bar=27, temp=16 (with F), serial=16, brackets/spaces=14
        # Total fixed = 83, so model space = TERM_WIDTH - 83
        AVAILABLE_MODEL_WIDTH=$((TERM_WIDTH - 83))
        if [ $AVAILABLE_MODEL_WIDTH -lt 20 ]; then
            AVAILABLE_MODEL_WIDTH=20
        fi
        model_display="${model:0:$AVAILABLE_MODEL_WIDTH}"
        
        # Display drive information with dark blue background
        if [ -n "$temp" ] && [ "$temp" -eq "$temp" ] 2>/dev/null; then
            color=$(get_color "$temp")
            bar=$(create_bar "$temp")
            
            # Calculate padding for model to fill terminal width
            MODEL_PAD=$((AVAILABLE_MODEL_WIDTH - ${#model_display}))
            MODEL_PADDING=$(printf ' %.0s' $(seq 1 $MODEL_PAD))
            
            printf "${DARKBLUE_BG}${LIGHTBLUE}║${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${WHITE}%-8s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} |%s${DARKBLUE_BG}| ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${color}%3s°C / %3s°F${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${WHITE}%-12s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${WHITE}%s${MODEL_PADDING}${RESET}${DARKBLUE_BG}${RESET}\n" \
                "$drive" "$bar" "$temp" "$temp_f" "$serial" "$model_display"
        else
            # Calculate padding for model to fill terminal width
            MODEL_PAD=$((AVAILABLE_MODEL_WIDTH - ${#model_display}))
            MODEL_PADDING=$(printf ' %.0s' $(seq 1 $MODEL_PAD))
            
            printf "${DARKBLUE_BG}${LIGHTBLUE}║${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${BOLD}${WHITE}%-8s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} | ${GRAY}%-25s${RESET}${DARKBLUE_BG} | ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${WHITE}%-14s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${WHITE}%-12s${RESET}${DARKBLUE_BG} ${LIGHTBLUE}]${RESET}${DARKBLUE_BG} ${LIGHTBLUE}[${RESET}${DARKBLUE_BG} ${WHITE}%s${MODEL_PADDING}${RESET}${DARKBLUE_BG}${RESET}\n" \
                "$drive" "No temperature data" "N/A" "$serial" "$model_display"
        fi
    done
    
    # Drive monitoring section border (bottom)
    echo -e "${DARKBLUE_BG}${BOLD}${LIGHTBLUE}╚${BORDER_LINE}╝${RESET}"
    
    echo ""
    
    # Wait before next refresh
    sleep $REFRESH_INTERVAL
done
