#!/bin/bash

# ============================================================================
# USER CONFIGURATION
# ============================================================================
BOT_TOKEN="CHANGE-ME"
CHAT_ID="CHANGE-ME"

# File paths
BASE_DIR="${HOME}"
LOG_FILE="${BASE_DIR}/.ip-notifier.log"
STATE_FILE="${BASE_DIR}/.ip-notifier.state"  # File dedicato per salvare l'ultimo IP

# Options
ENABLE_LOGGING=true
NOTIFY_ON_CHANGE_ONLY=true
FORCE_NOTIFICATION=false

# IP Lookup Services
IP_SERVICES=(
    "https://api.ipify.org"
    "https://ifconfig.me/ip"
    "https://icanhazip.com"
    "https://api.my-ip.io/ip"
)

# ============================================================================
# FUNCTIONS
# ============================================================================

log_message() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    # Stampa a video se eseguito manualmente (terminale)
    if [ -t 1 ]; then
        echo "[$timestamp] $msg"
    fi
    # Scrive nel file di log
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "$timestamp | $msg" >> "$LOG_FILE"
    fi
}

error_exit() {
    log_message "ERROR: $1"
    exit 1
}

check_requirements() {
    for cmd in curl hostname; do
        if ! command -v "$cmd" &> /dev/null; then
            error_exit "Missing required command: $cmd"
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
        # Timeout ridotto a 5s per velocità
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
    if [ -z "$ip_local" ]; then
        echo "N/A"
    else
        echo "$ip_local"
    fi
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
        log_message "Telegram notification sent."
        return 0
    else
        log_message "Failed to send Telegram: $response"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # 1. Check Requirements
    check_requirements

    if [ "$BOT_TOKEN" == "CHANGE-ME" ]; then
        echo "Configura BOT_TOKEN e CHAT_ID nello script!"
        exit 1
    fi

    # 2. Get Current IP
    CURRENT_IP=$(get_external_ip)
    
    if [ -z "$CURRENT_IP" ]; then
        error_exit "Could not retrieve external IP from any service."
    fi

    # 3. Get Last IP (from state file, not logs!)
    if [ -f "$STATE_FILE" ]; then
        LAST_IP=$(cat "$STATE_FILE")
    else
        LAST_IP=""
    fi

    # 4. Compare
    IP_CHANGED=false
    if [ "$CURRENT_IP" != "$LAST_IP" ]; then
        IP_CHANGED=true
    fi

    # 5. Notify Logic
    SHOULD_NOTIFY=false
    STATUS_MSG="IP Unchanged"

    if [ "$FORCE_NOTIFICATION" = true ]; then
        SHOULD_NOTIFY=true
        STATUS_MSG="Forced Notification"
    elif [ "$IP_CHANGED" = true ]; then
        SHOULD_NOTIFY=true
        if [ -z "$LAST_IP" ]; then
            STATUS_MSG="First Run (New IP)"
        else
            STATUS_MSG="IP Changed"
        fi
    fi

    if [ "$SHOULD_NOTIFY" = true ]; then
        log_message "Status: $STATUS_MSG. Sending notification..."
        
        LOCAL_IP=$(get_local_ip)
        HOSTNAME=$(hostname)
        TIME=$(date '+%Y-%m-%d %H:%M:%S')

        # Costruzione messaggio pulita
        MSG="🌐 *IP Notification*"$'\n\n'
        MSG+="📡 *Public IP:* \`$CURRENT_IP\`"$'\n'
        MSG+="🏠 *Local IP:* \`$LOCAL_IP\`"$'\n'
        MSG+="💻 *Host:* \`$HOSTNAME\`"$'\n'
        MSG+="📅 *Time:* \`$TIME\`"$'\n\n'
        
        if [ "$IP_CHANGED" = true ] && [ -n "$LAST_IP" ]; then
            MSG+="🔄 *Old IP:* \`$LAST_IP\`"$'\n'
        fi
        MSG+="✅ *Status:* $STATUS_MSG"

        send_telegram "$MSG"
        
        # Aggiorna il file di stato SOLO se la notifica o il rilevamento ha avuto successo
        echo "$CURRENT_IP" > "$STATE_FILE"
        log_message "State updated. New IP saved."
    else
        log_message "IP unchanged ($CURRENT_IP). No notification sent."
    fi

    # Gestione rotazione log (semplificata)
    if [ -f "$LOG_FILE" ] && [ $(wc -l < "$LOG_FILE") -gt 1000 ]; then
        tail -n 500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

main
