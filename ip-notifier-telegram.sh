#!/bin/bash
umask 077

CHECK_INTERVAL=60
NOTIFICATION_DELAY=5

BASE_DIR="${HOME}"
LOG_FILE="${BASE_DIR}/.ip-notifier.log"
STATE_FILE="${BASE_DIR}/.ip-notifier.state"
CONFIG_FILE="${BASE_DIR}/.ip-notifier.conf.enc"

ENABLE_LOGGING=true
FORCE_NOTIFICATION=false

BOT_TOKEN=""
CHAT_ID=""

IP_SERVICES=(
    "https://api.ipify.org"
    "https://ifconfig.me/ip"
    "https://icanhazip.com"
    "https://api.my-ip.io/ip"
)

log_message() {
    local msg="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $msg"
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "$timestamp | $msg" >> "$LOG_FILE"
    fi
}

check_requirements() {
    for cmd in curl hostname openssl; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "ERROR: Missing required command: $cmd"
            exit 1
        fi
    done
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        for octet in "${BASH_REMATCH[@]:1}"; do
            if (( octet > 255 )); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

get_external_ip() {
    local ip=""
    for service in "${IP_SERVICES[@]}"; do
        ip=$(curl -s --max-time 5 "$service" | tr -d '[:space:]')
        if [ -n "$ip" ] && validate_ip "$ip"; then
            echo "$ip"
            return 0
        fi
    done
    return 1
}

get_local_ip() {
    local ip_local
    ip_local=$(hostname -I 2>/dev/null | awk '{print $1}')
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
        log_message "Failed to send Telegram notification: ${response:0:200}"
        return 1
    fi
}

encrypt_config() {
    local token="$1"
    local chat_id="$2"
    local passphrase="$3"
    printf 'BOT_TOKEN=%s\nCHAT_ID=%s\n' "$token" "$chat_id" | \
        openssl enc -aes-256-cbc -salt -pbkdf2 -pass "pass:${passphrase}" -out "$CONFIG_FILE" 2>/dev/null
    return $?
}

decrypt_config() {
    local passphrase="$1"
    local plaintext
    plaintext=$(openssl enc -aes-256-cbc -d -salt -pbkdf2 -pass "pass:${passphrase}" -in "$CONFIG_FILE" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    # Validate decrypted content format before loading
    if ! echo "$plaintext" | grep -q '^BOT_TOKEN=' || ! echo "$plaintext" | grep -q '^CHAT_ID='; then
        return 1
    fi
    eval "$plaintext"
    return 0
}

validate_telegram_credentials() {
    local response
    response=$(curl -s --max-time 10 -X POST \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="IP Notifier: credentials verified successfully." 2>&1)
    if [[ $? -eq 0 && $response == *'"ok":true'* ]]; then
        return 0
    fi
    return 1
}

prompt_passphrase_decrypt() {
    local attempts=0
    local max_attempts=3
    local passphrase
    while (( attempts < max_attempts )); do
        read -rsp "Enter passphrase to unlock credentials: " passphrase
        echo
        if decrypt_config "$passphrase"; then
            echo "Credentials loaded successfully."
            return 0
        fi
        attempts=$((attempts + 1))
        echo "Wrong passphrase. Attempts remaining: $((max_attempts - attempts))"
    done
    echo "Too many failed attempts. Exiting."
    exit 1
}

setup_credentials() {
    echo ""
    echo "=== First Time Setup ==="
    echo ""
    echo "You need a Telegram Bot Token and Chat ID."
    echo "Create a bot via @BotFather and get your Chat ID from @userinfobot."
    echo ""

    read -rp "Enter your Bot Token: " input_token
    if [[ -z "$input_token" ]]; then
        echo "Bot Token cannot be empty. Exiting."
        exit 1
    fi

    read -rp "Enter your Chat ID: " input_chat_id
    if [[ -z "$input_chat_id" ]]; then
        echo "Chat ID cannot be empty. Exiting."
        exit 1
    fi

    echo ""
    echo "Testing Telegram credentials..."
    BOT_TOKEN="$input_token"
    CHAT_ID="$input_chat_id"
    if ! validate_telegram_credentials; then
        echo "Telegram API test failed. Please verify your Bot Token and Chat ID."
        exit 1
    fi
    echo "Credentials are valid."
    echo ""

    local passphrase1 passphrase2
    read -rsp "Set a passphrase to encrypt your credentials: " passphrase1
    echo
    read -rsp "Confirm passphrase: " passphrase2
    echo

    if [[ "$passphrase1" != "$passphrase2" ]]; then
        echo "Passphrases do not match. Exiting."
        exit 1
    fi
    if [[ -z "$passphrase1" ]]; then
        echo "Passphrase cannot be empty. Exiting."
        exit 1
    fi

    if encrypt_config "$BOT_TOKEN" "$CHAT_ID" "$passphrase1"; then
        echo "Credentials encrypted and saved."
    else
        echo "Failed to encrypt credentials. Exiting."
        exit 1
    fi
}

start_monitoring() {
    log_message "Starting IP Monitor (Interval: ${CHECK_INTERVAL}s)..."

    while true; do
        CURRENT_IP=$(get_external_ip)

        if [ -z "$CURRENT_IP" ]; then
            log_message "WARNING: Could not retrieve IP. Retrying in ${CHECK_INTERVAL}s..."
            sleep "$CHECK_INTERVAL"
            continue
        fi

        if [ -f "$STATE_FILE" ]; then
            LAST_IP=$(cat "$STATE_FILE")
            if ! validate_ip "$LAST_IP"; then
                log_message "WARNING: Invalid IP in state file, treating as empty."
                LAST_IP=""
            fi
        else
            LAST_IP=""
        fi

        IP_CHANGED=false
        if [ "$CURRENT_IP" != "$LAST_IP" ]; then
            IP_CHANGED=true
        fi

        SHOULD_NOTIFY=false
        STATUS_MSG="IP Unchanged"

        if [ "$FORCE_NOTIFICATION" = true ]; then
            SHOULD_NOTIFY=true
            STATUS_MSG="Forced Notification"
            FORCE_NOTIFICATION=false
        elif [ "$IP_CHANGED" = true ]; then
            SHOULD_NOTIFY=true
            if [ -z "$LAST_IP" ]; then
                STATUS_MSG="Monitor Started (Initial IP)"
            else
                STATUS_MSG="IP Changed"
            fi
        fi

        if [ "$SHOULD_NOTIFY" = true ]; then
            # Delay and recheck on actual IP change (not initial or forced)
            if [ "$IP_CHANGED" = true ] && [ -n "$LAST_IP" ]; then
                log_message "IP change detected ($LAST_IP -> $CURRENT_IP). Waiting ${NOTIFICATION_DELAY}s to confirm..."
                sleep "$NOTIFICATION_DELAY"
                RECHECK_IP=$(get_external_ip)
                if [ -n "$RECHECK_IP" ] && [ "$RECHECK_IP" = "$LAST_IP" ]; then
                    log_message "IP reverted to $LAST_IP. Change was temporary, skipping notification."
                    continue
                fi
                if [ -n "$RECHECK_IP" ]; then
                    CURRENT_IP="$RECHECK_IP"
                fi
            fi

            log_message "Status: $STATUS_MSG. Sending notification..."

            LOCAL_IP=$(get_local_ip)
            HOSTNAME=$(hostname)
            TIME=$(date '+%Y-%m-%d %H:%M:%S')

            MSG="🌐 *IP Monitor Update*"$'\n\n'
            MSG+="📡 *Public IP:* \`$CURRENT_IP\`"$'\n'
            MSG+="🏠 *Local IP:* \`$LOCAL_IP\`"$'\n'
            MSG+="💻 *Host:* \`$HOSTNAME\`"$'\n'
            MSG+="📅 *Time:* \`$TIME\`"$'\n\n'

            if [ "$IP_CHANGED" = true ] && [ -n "$LAST_IP" ]; then
                MSG+="🔄 *Old IP:* \`$LAST_IP\`"$'\n'
            fi
            MSG+="✅ *Status:* $STATUS_MSG"

            send_telegram "$MSG"

            echo "$CURRENT_IP" > "$STATE_FILE"
            log_message "State updated. New IP saved."
        else
            log_message "IP unchanged ($CURRENT_IP). No notification sent."
        fi

        if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 1000 ]; then
            tail -n 500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
        fi

        sleep "$CHECK_INTERVAL"
    done
}

start_background() {
    echo "Starting monitoring in background..."
    BOT_TOKEN="$BOT_TOKEN" CHAT_ID="$CHAT_ID" \
        nohup "$0" --run-monitor > /dev/null 2>&1 &
    local pid=$!
    echo "Monitor started in background (PID: ${pid})"
    echo "To stop: kill ${pid}"
    exit 0
}

reconfigure() {
    rm -f "$CONFIG_FILE"
    BOT_TOKEN=""
    CHAT_ID=""
    setup_credentials
    show_menu
}

show_menu() {
    echo ""
    echo "=== IP Notifier Telegram ==="
    echo "[1] Start monitoring (foreground)"
    echo "[2] Start monitoring (background)"
    echo "[3] Reconfigure credentials"
    echo "[4] Exit"
    echo ""
    read -rp "Select an option: " choice
    case "$choice" in
        1) start_monitoring ;;
        2) start_background ;;
        3) reconfigure ;;
        4) echo "Goodbye."; exit 0 ;;
        *) echo "Invalid option."; show_menu ;;
    esac
}

# --- Entrypoint ---
check_requirements

if [[ "${1:-}" == "--run-monitor" ]]; then
    if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        start_monitoring
    else
        echo "Error: credentials not available for background mode."
        exit 1
    fi
    exit 0
fi

echo ""
echo "=== IP Notifier Telegram ==="

if [[ -f "$CONFIG_FILE" ]]; then
    prompt_passphrase_decrypt
else
    setup_credentials
fi

show_menu
