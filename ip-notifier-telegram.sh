#!/bin/bash

# ============================================================================
# USER CONFIGURATION
# ============================================================================
BOT_TOKEN="CHANGE-ME"         # Your Bot Token (e.g., 123456789:AbCde...)
CHAT_ID="CHANGE-ME"           # Your Chat ID (e.g., 123456789)
CHECK_INTERVAL=60             # Check frequency in seconds

# File paths
BASE_DIR="${HOME}"
LOG_FILE="${BASE_DIR}/.ip-notifier.log"
STATE_FILE="${BASE_DIR}/.ip-notifier.state"  # Stores the last known IP

# Options
ENABLE_LOGGING=true
NOTIFY_ON_CHANGE_ONLY=true
FORCE_NOTIFICATION=false      # Set to true to force a notification on next run

# IP Lookup Services
IP_SERVICES=(
    "https://api.ipify.org"
    "https://ifconfig.me/ip"
    "https://icanhazip.com"
    "https://api.my-ip.io/ip"
)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_message() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Print to console (stdout)
    echo "[$timestamp] $msg"
    
    # Write to log file if enabled
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "$timestamp | $msg" >> "$LOG_FILE"
    fi
}

check_requirements() {
    for cmd in curl hostname; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "ERROR: Missing required command: $cmd"
            exit 1
        fi
    done
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

get_external_ip() {
    local ip=""
    for service in "${IP_SERVICES[@]}"; do
        # Try to get IP with a short 5-second timeout
        ip=$(curl -s --max-time 5 "$service" | tr -d '[:space:]')
        
        if [ -n "$ip" ] && validate_ip "$ip"; then
            echo "$ip"
            return 0
        fi
    done
    return 1
}

get_local_ip() {
    local ip_local=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -z "$ip_local" ]; then echo "N/A"; else echo "$ip_local"; fi
}

send_telegram() {
    local msg="$1"
    local response
    
    response=$(curl -s --max-time 10 -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$msg" \
        -d parse_mode="Markdown" 2>&1)
        
    if [[ $? -eq 0 && $response == *'"ok":true'* ]]; then
        log_message "Telegram notification sent successfully."
        return 0
    else
        log_message "Failed to send Telegram notification: $response"
        return 1
    fi
}

# ============================================================================
# MAIN LOOP
# ============================================================================

main() {
    check_requirements

    # Validate configuration
    if [ "$BOT_TOKEN" == "CHANGE-ME" ] || [ "$CHAT_ID" == "CHANGE-ME" ]; then
        echo "ERROR: Please configure BOT_TOKEN and CHAT_ID inside the script."
        exit 1
    fi

    log_message "🔁 Starting IP Monitor (Interval: ${CHECK_INTERVAL}s)..."

    # Infinite Loop
    while true; do
        
        # 1. Get Current External IP
        CURRENT_IP=$(get_external_ip)
        
        if [ -z "$CURRENT_IP" ]; then
            log_message "WARNING: Could not retrieve IP from any service. Retrying in ${CHECK_INTERVAL}s..."
            sleep "$CHECK_INTERVAL"
            continue
        fi

        # 2. Get Last Known IP from state file
        if [ -f "$STATE_FILE" ]; then
            LAST_IP=$(cat "$STATE_FILE")
        else
            LAST_IP=""
        fi

        # 3. Check for Changes
        IP_CHANGED=false
        if [ "$CURRENT_IP" != "$LAST_IP" ]; then
            IP_CHANGED=true
        fi

        # 4. Determine if Notification is needed
        SHOULD_NOTIFY=false
        STATUS_MSG="IP Unchanged"

        if [ "$FORCE_NOTIFICATION" = true ]; then
            SHOULD_NOTIFY=true
            STATUS_MSG="Forced Notification"
            FORCE_NOTIFICATION=false # Reset flag
        elif [ "$IP_CHANGED" = true ]; then
            SHOULD_NOTIFY=true
            if [ -z "$LAST_IP" ]; then
                STATUS_MSG="Monitor Started (Initial IP)"
            else
                STATUS_MSG="IP Changed"
            fi
        fi

        # 5. Send Notification if needed
        if [ "$SHOULD_NOTIFY" = true ]; then
            log_message "Status: $STATUS_MSG. Sending notification..."
            
            LOCAL_IP=$(get_local_ip)
            HOSTNAME=$(hostname)
            TIME=$(date '+%Y-%m-%d %H:%M:%S')

            # Build Telegram Message
            MSG="🌐 *IP Monitor Update*"$'\n\n'
            MSG+="📡 *Public IP:* \`$CURRENT_IP\`"$'\n'
            MSG+="🏠 *Local IP:* \`$LOCAL_IP\`"$'\n'
            MSG+="💻 *Host:* \`$HOSTNAME\`"$'\n'
            MSG+="📅 *Time:* \`$TIME\`"$'\n\n'
            
            if [ "$IP_CHANGED" = true ] && [ -n "$LAST_IP" ]; then
                MSG+="🔄 *Old IP:* \`$LAST_IP\`"$'\n'
            fi
            MSG+="✅ *Status:* $STATUS_MSG"

            # Send and update state only on success (or attempt)
            send_telegram "$MSG"
            
            # Save new IP to state file
            echo "$CURRENT_IP" > "$STATE_FILE"
            log_message "State updated. New IP saved to $STATE_FILE"
        else
            log_message "IP unchanged ($CURRENT_IP). No notification sent."
        fi

        # 6. Rotate Log if too large (keep last 500 lines)
        if [ -f "$LOG_FILE" ] && [ $(wc -l < "$LOG_FILE") -gt 1000 ]; then
            tail -n 500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
        fi

        # 7. Wait for next check
        sleep "$CHECK_INTERVAL"
    done
}

# Run the main function
main
