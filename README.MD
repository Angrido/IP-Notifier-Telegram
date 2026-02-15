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

Unlike simple cron scripts, this version runs as a continuous service, checking your IP at defined intervals (default: 60s) and maintaining a state file for 100% accuracy. Credentials are encrypted locally with AES-256-CBC and managed through an interactive setup wizard.

## ✨ Features

⚡ **Real-Time Monitoring** — Continuously checks IP (loop-based, no Cron needed)
🔐 **Encrypted Credentials** — Bot Token and Chat ID stored encrypted (AES-256-CBC via OpenSSL)
🖥️ **Interactive Menu** — Setup wizard and startup menu with foreground/background options
🔄 **Auto-Retry** — Multi-service support with automatic fallback and connection retries
🕐 **Change Confirmation** — Delays and rechecks IP changes to avoid false positives
📊 **State Persistence** — Uses a state file to remember IP across restarts
📝 **Logging** — Tracks history and errors in `~/.ip-notifier.log`
🎯 **Smart Notifications** — Sends messages only when IP actually changes
🛡️ **Robust** — Handles network failures gracefully without crashing

## 🚀 Quick Start

### 1. Prerequisites

Make sure the following commands are available on your system:

- `curl`
- `hostname`
- `openssl`

### 2. Download

You can download the script directly using `wget`:

```bash
wget https://raw.githubusercontent.com/angrido/ip-notifier-telegram/main/ip-notifier-telegram.sh
```

### 3. Run

Make it executable and launch it:

```bash
chmod +x ip-notifier-telegram.sh
./ip-notifier-telegram.sh
```

On the first run, the interactive setup wizard will guide you through the configuration:

1. Create a bot with [@BotFather](https://t.me/BotFather) and save the **HTTP API Token**.
2. Get your numeric `chat_id` from [@userinfobot](https://t.me/userinfobot).
3. Enter your **Bot Token** and **Chat ID** when prompted.
4. The script will validate the credentials by sending a test message.
5. Set a **passphrase** to encrypt and save your credentials locally.

### 4. Startup Menu

After setup (or on subsequent runs after unlocking with your passphrase), the interactive menu is displayed:

```
=== IP Notifier Telegram ===
[1] Start monitoring (foreground)
[2] Start monitoring (background)
[3] Reconfigure credentials
[4] Exit
```

| Option | Description |
|--------|-------------|
| **1** | Runs the monitor in the current terminal session. Logs are printed to screen. |
| **2** | Runs the monitor in background via `nohup`. The PID is shown so you can stop it later. |
| **3** | Deletes the encrypted config and restarts the setup wizard. |
| **4** | Exits the script. |

## ⚙️ Running in Background (24/7)

Select option **2** from the menu to start monitoring in background:

```
Select an option: 2
Starting monitoring in background...
Monitor started in background (PID: 12345)
To stop: kill 12345
```

**Check if it's running:**

```bash
ps aux | grep ip-notifier
```

**Stop the monitor:**

```bash
kill <PID>
```

## 📂 Files Created

The script creates the following files in your home directory (`$HOME`):

| File | Description |
|------|-------------|
| `.ip-notifier.conf.enc` | Encrypted credentials (Bot Token and Chat ID). |
| `.ip-notifier.state` | Stores the last known IP address. |
| `.ip-notifier.log` | Log file with timestamps of checks and changes. |

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
