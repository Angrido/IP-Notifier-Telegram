#!/bin/bash

# Set your Telegram bot token and chat ID:
BOT_TOKEN="CHANGE-ME"
CHAT_ID="CHANGE-ME"

# ============================================================================
# CONFIGURATION OPTIONS
# ============================================================================
LOG_FILE="${HOME}/.ip-notifier-telegram.log"       # Path to log file
ENABLE_LOGGING=true                                 # Enable/disable logging
NOTIFY_ON_CHANGE_ONLY=true                          # Only notify if IP changed
FORCE_NOTIFICATION=false                            # Force notification regardless of change

# IP Lookup Services (in order of preference)
IP_SERVICES=(
    "https://api.ipify.org"
    "https://ifconfig.me/ip"
    "https://icanhazip.com"
    "https://api.my-ip.io/ip"
)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Print error message and exit
error_exit() {
    echo "ERROR: $1" >&2
    log_message "ERROR: $1"
    exit 1
}

# Log message to file
log_message() {
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
    fi
}

# Check if required commands are available
check_requirements() {
    local missing_commands=()
    
    for cmd in curl hostname; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        error_exit "Missing required commands: ${missing_commands[*]}"
    fi
}

# Validate IP address format
validate_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ $ip =~ $regex ]]; then
        # Check each octet is <= 255
        IFS='.' read -ra OCTETS <<< "$ip"
        for octet in "${OCTETS[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Get external IP with fallback support
get_external_ip() {
    local ip=""
    
    for service in "${IP_SERVICES[@]}"; do
        log_message "Trying IP service: $service"
        
        # Try to get IP with 10 second timeout, max 3 retries
        for attempt in {1..3}; do
            ip=$(curl -s --max-time 10 "$service" 2>/dev/null)
            
            # Trim whitespace
            ip=$(echo "$ip" | xargs)
            
            if [ -n "$ip" ] && validate_ip "$ip"; then
                log_message "Successfully retrieved IP: $ip from $service (attempt $attempt)"
                echo "$ip"
                return 0
            fi
            
            if [ $attempt -lt 3 ]; then
                log_message "Attempt $attempt failed, retrying in 2 seconds..."
                sleep 2
            fi
        done
        
        log_message "Failed to get IP from $service after 3 attempts"
    done
    
    error_exit "Failed to retrieve external IP from all services"
}

# Get local IP address
get_local_ip() {
    local local_ip=""
    
    # Try different methods based on OS
    if command -v ip &> /dev/null; then
        # Linux with ip command - get all IPs and filter for 192.168.x.x first
        local_ip=$(ip addr show | grep -oP 'inet \K192\.168\.\d+\.\d+' | head -1)
        
        # If no 192.168.x.x found, try 10.x.x.x
        if [ -z "$local_ip" ]; then
            local_ip=$(ip addr show | grep -oP 'inet \K10\.\d+\.\d+\.\d+' | head -1)
        fi
        
        # If still nothing, use default route method
        if [ -z "$local_ip" ]; then
            local_ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
        fi
    elif command -v hostname &> /dev/null; then
        # Universal fallback - prefer 192.168.x.x
        local all_ips=$(hostname -I 2>/dev/null)
        
        # Try to find 192.168.x.x address first
        local_ip=$(echo "$all_ips" | tr ' ' '\n' | grep '^192\.168\.' | head -1)
        
        # If no 192.168.x.x, try 10.x.x.x
        if [ -z "$local_ip" ]; then
            local_ip=$(echo "$all_ips" | tr ' ' '\n' | grep '^10\.' | head -1)
        fi
        
        # Otherwise take first IP
        if [ -z "$local_ip" ]; then
            local_ip=$(echo "$all_ips" | awk '{print $1}')
        fi
        
        # macOS alternative
        if [ -z "$local_ip" ]; then
            local_ip=$(ipconfig getifaddr en0 2>/dev/null)
        fi
    fi
    
    # Final fallback
    if [ -z "$local_ip" ]; then
        local_ip="N/A"
    fi
    
    echo "$local_ip"
}

# Get last known IP from log
get_last_ip() {
    if [ ! -f "$LOG_FILE" ]; then
        echo ""
        return
    fi
    
    # Extract last IP from log (format: YYYY-MM-DD HH:MM:SS | IP: xxx.xxx.xxx.xxx)
    local last_ip=$(grep "IP:" "$LOG_FILE" | tail -1 | awk -F'IP: ' '{print $2}' | awk '{print $1}')
    echo "$last_ip"
}

# Rotate log file if it gets too large (keep last 1000 lines)
rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        local line_count=$(wc -l < "$LOG_FILE")
        if [ "$line_count" -gt 1000 ]; then
            log_message "Rotating log file (current size: $line_count lines)"
            tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp"
            mv "${LOG_FILE}.tmp" "$LOG_FILE"
        fi
    fi
}

# Send Telegram message
send_telegram_message() {
    local message=$1
    local response
    
    response=$(curl -s --max-time 10 -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$message" \
        -d parse_mode="Markdown" 2>&1)
    
    if [ $? -eq 0 ] && [[ $response == *'"ok":true'* ]]; then
        log_message "Telegram notification sent successfully"
        return 0
    else
        log_message "Failed to send Telegram notification: $response"
        return 1
    fi
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

main() {
    log_message "========== Script started =========="
    
    # Check requirements
    check_requirements
    
    # Validate configuration
    if [ "$BOT_TOKEN" = "CHANGE-ME" ] || [ "$CHAT_ID" = "CHANGE-ME" ]; then
        error_exit "Please configure BOT_TOKEN and CHAT_ID at the top of this script"
    fi
    
    # Get current external IP
    log_message "Retrieving external IP address..."
    EXTERNAL_IP=$(get_external_ip)
    
    # Get additional information
    HOSTNAME=$(hostname)
    LOCAL_IP=$(get_local_ip)
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check if IP has changed
    LAST_IP=$(get_last_ip)
    IP_CHANGED=false
    
    if [ -z "$LAST_IP" ]; then
        log_message "First run - no previous IP found"
        IP_CHANGED=true
    elif [ "$EXTERNAL_IP" != "$LAST_IP" ]; then
        log_message "IP changed: $LAST_IP → $EXTERNAL_IP"
        IP_CHANGED=true
    else
        log_message "IP unchanged: $EXTERNAL_IP"
    fi
    
    # Determine if we should send notification
    SHOULD_NOTIFY=false
    
    if [ "$FORCE_NOTIFICATION" = true ]; then
        SHOULD_NOTIFY=true
        log_message "Forcing notification (FORCE_NOTIFICATION=true)"
    elif [ "$NOTIFY_ON_CHANGE_ONLY" = true ]; then
        if [ "$IP_CHANGED" = true ]; then
            SHOULD_NOTIFY=true
        fi
    else
        SHOULD_NOTIFY=true
    fi
    
    # Build and send message if needed
    if [ "$SHOULD_NOTIFY" = true ]; then
        # Build rich Telegram message with Markdown formatting using $'\n' for proper newlines
        MESSAGE=$'🌐 *IP Notification*\n\n'
        MESSAGE+=$'📡 *External IP:* '"\`$EXTERNAL_IP\`"$'\n'
        MESSAGE+=$'🏠 *Local IP:* '"\`$LOCAL_IP\`"$'\n'
        MESSAGE+=$'💻 *Hostname:* '"\`$HOSTNAME\`"$'\n'
        MESSAGE+=$'📅 *Time:* '"\`$CURRENT_TIME\`"$'\n'
        
        if [ -n "$LAST_IP" ] && [ "$LAST_IP" != "$EXTERNAL_IP" ]; then
            MESSAGE+=$'\n🔄 *Previous IP:* '"\`$LAST_IP\`"$'\n'
            MESSAGE+=$'✅ *Status:* IP Address Changed'
        elif [ -z "$LAST_IP" ]; then
            MESSAGE+=$'\n✅ *Status:* First Run'
        else
            MESSAGE+=$'\n✅ *Status:* IP Unchanged'
        fi
        
        log_message "Sending Telegram notification..."
        if send_telegram_message "$MESSAGE"; then
            log_message "Notification sent successfully"
        else
            log_message "Failed to send notification"
        fi
    else
        log_message "Skipping notification (IP unchanged and NOTIFY_ON_CHANGE_ONLY=true)"
    fi
    
    # Log current IP
    log_message "IP: $EXTERNAL_IP"
    
    # Rotate log if needed
    rotate_log
    
    log_message "========== Script completed =========="
}

# Run main function
main
