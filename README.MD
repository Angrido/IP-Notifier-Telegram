<div align="center">

# 🌐 IP Notifier Telegram

_Monitor and receive instant notifications of your public IP address changes directly on Telegram_

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?logo=telegram&logoColor=white)](https://telegram.org/)

</div>

---

## 📋 Description

**IP Notifier Telegram** is a robust Bash script that monitors your public IP address in **real-time** and sends automatic notifications via Telegram when a change is detected.

Unlike simple cron scripts, this version runs as a continuous service, checking your IP at defined intervals (default: 60s) and maintaining a state file for 100% accuracy.

## ✨ Features

⚡ **Real-Time Monitoring** — Continuously checks IP (loop-based, no Cron needed)  
🔄 **Auto-Retry** — Multi-service support with automatic fallback and connection retries  
📊 **State Persistence** — Uses a state file to remember IP across restarts  
📝 **Logging** — Tracks history and errors in `~/.ip-notifier.log`  
🎯 **Smart Notifications** — Sends messages only when IP actually changes  
🛡️ **Robust** — Handles network failures gracefully without crashing

## 🚀 Quick Start

### 1. Configure Telegram Bot

1. Create a bot with [@BotFather](https://t.me/BotFather) and save the **HTTP API Token**.
2. Get your numeric `chat_id` from [@userinfobot](https://t.me/userinfobot).

### 2. Download

You can download the script directly using `wget`:

```bash
wget https://raw.githubusercontent.com/angrido/ip-notifier-telegram/main/ip-notifier-telegram.sh
```

### 3. Configure the Script

Edit the file to set your credentials:

```bash
nano ip-notifier-telegram.sh
```

Change these lines:

```bash
BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrs..."  # Your Bot Token
CHAT_ID="123456789"                           # Your Chat ID
CHECK_INTERVAL=60                             # Check every 60 seconds
```

### 4. Run (Test Mode)

Make it executable and run it to test:

```bash
chmod +x ip-notifier-telegram.sh
./ip-notifier-telegram.sh
```

## ⚙️ Running in Background (24/7)

To keep the script running even after you close the terminal (SSH/Logout), use `nohup`:

**Start the monitor:**

```bash
nohup ./ip-notifier-telegram.sh > /dev/null 2>&1 &
```

**Check if it's running:**

```bash
ps aux | grep ip-notifier
```

**Stop the monitor:**

```bash
pkill -f ip-notifier
```

## 📂 Files Created

The script creates the following files in your home directory (`$HOME`):

- `.ip-notifier.state`: Stores the last known IP address.
- `.ip-notifier.log`: Log file with timestamps of checks and changes.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
