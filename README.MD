<div align="center">

# 🌐 IP Notifier Telegram

_Monitor and receive instant notifications of your public IP address changes directly on Telegram_

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?logo=telegram&logoColor=white)](https://telegram.org/)

</div>

---

## 📋 Description

**IP Notifier Telegram** is a lightweight and reliable Bash script that monitors your public IP address and sends automatic notifications via Telegram when it detects changes. Perfect for dynamic servers, home labs, and devices with non-static IP addresses.

## ✨ Features

🔄 **Auto-Retry** — Multi-service support with automatic fallback  
📊 **Complete Logging** — IP history tracking with automatic log rotation  
🎯 **Smart Notifications** — Sends messages only when IP changes  
🛡️ **Robust** — Advanced IP validation and error handling  
⚡ **Lightweight** — Zero external dependencies besides `curl`

## 🚀 Quick Start

1. **Configure Telegram bot:**
   - Create a bot with [@BotFather](https://t.me/BotFather)
   - Get your `chat_id` from [@userinfobot](https://t.me/userinfobot)

2. **Edit the script:**
   ```bash
   BOT_TOKEN="your-bot-token"
   CHAT_ID="your-chat-id"
   ```

3. **Run:**
   ```bash
   chmod +x ip-notifier-telegram.sh
   ./ip-notifier-telegram.sh
   ```

## ⚙️ Automation

**Cron (every 15 minutes):**
```bash
*/15 * * * * /full/path/to/ip-notifier-telegram.sh
```
