# 📡 IP Notifier Telegram

A simple Bash script that checks your current external IP address and sends it to your Telegram chat.  
Perfect for monitoring VPN connections, dynamic IPs, or just keeping an eye on what your server is exposing. 🔍

---

## ✨ Features

- 📤 Sends your IP address to Telegram automatically
- 🔁 Easy to schedule via `cron`
- 🔐 Keeps your IP monitoring private (no web UI or third-party dashboards)
- 🐧 Designed for Linux (Debian/Ubuntu tested)

---

## ⚙️ Setup Instructions

### 1. Download the Script 📥

Download the script from GitHub:

```bash
wget https://raw.githubusercontent.com/Angrido/IP-Notifier-Telegram/main/ip-notifier-telegram.sh
chmod +x ip-notifier-telegram.sh
```

---

### 2. Create a Telegram Bot 🤖

1. Open Telegram and search for [@BotFather](https://t.me/BotFather)
2. Type `/newbot` and follow the instructions
3. Copy the **bot token** (it looks like `123456789:ABCDefGhiJkLmNOpQrStUvWxYz`)

---

### 3. Get Your Telegram Chat ID 👤

1. Open Telegram and search for [@userinfobot](https://t.me/userinfobot)
2. Send `/start`
3. Note your **User ID** (a number like `123456789`)

---

### 4. Configure the Script 📝

Open the downloaded script and replace the placeholder values:

```bash
BOT_TOKEN="your_bot_token_here"
CHAT_ID="your_user_id_here"
```

---

### 5. Test It 🔍

Run the script manually to test:

```bash
./ip-notifier-telegram.sh
```

You should receive a Telegram message with your current IP. 🎉

---

### 6. Schedule It with Cron ⏰

To run the script every hour, open your crontab:

```bash
crontab -e
```

Add this line (adjust the path if needed):

```bash
0 * * * * /full/path/to/ip-notifier-telegram.sh
```

---

## 📁 Example Output in Telegram

```
🌐 Current external IP: 123.123.123.0
```