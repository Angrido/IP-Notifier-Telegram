#!/bin/bash

# Set your Telegram bot token and chat ID:
BOT_TOKEN="CHANGE-ME"
CHAT_ID="CHANGE-ME"

# Get the current external IP address
IP=$(curl -s https://api.ipify.org)

# Prepare the message
MESSAGE="🌐 Current external IP: $IP"

# Send the message via Telegram
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$MESSAGE" > /dev/null