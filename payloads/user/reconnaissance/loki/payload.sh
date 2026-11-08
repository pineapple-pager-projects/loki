#!/bin/sh
# Title: Loki
# Description: LAN Orchestrated Key Infiltrator  Autonomous Network Recon Payload
# Author: brAinphreAk
# Version: 2.0
# Category: Reconnaissance
#
# v2 (no-binaries): pure-Python display backend via UI_TAKEOVER + mmap(/dev/fb0).
# No bundled binaries — nmap, python3 and the OpenSSH client are installed from
# opkg at first run. The pineapplepager service is NOT stopped; lib/pagerctl.py
# borrows the framebuffer with UI_TAKEOVER and releases it with UI_RELEASE.
#
# TODO(device): swap the LOG/WAIT_FOR_INPUT launcher prompts for the native
# CONFIRMATION_DIALOG / ERROR_DIALOG / START_SPINNER commands once their exact
# argument formats are verified on-device (kept to proven primitives for now).

_PAYLOAD_TITLE="Loki"
_PAYLOAD_AUTHOR_NAME="brAinphreAk"
_PAYLOAD_VERSION="2.0"
_PAYLOAD_DESCRIPTION="LAN Orchestrated Key Infiltrator  Autonomous Network Recon Payload"

PAYLOAD_DIR="/root/payloads/user/reconnaissance/loki"
DATA_DIR="$PAYLOAD_DIR/data"

cd "$PAYLOAD_DIR" || { LOG "red" "ERROR: $PAYLOAD_DIR not found"; exit 1; }

# ------------------------------------------------------------------
# Environment — bundled binaries are gone; python3/nmap come from mmc (opkg).
# /usr/bin provides the DuckyScript command tools (UI_TAKEOVER, RINGTONE, ...).
# ------------------------------------------------------------------
# opkg paths first (so opkg's nmap-full wins); payload bin/lib last for any
# downloaded attack binaries (sfreerdp/smb2-*) and the paramiko crypto .so stack.
export PATH="/mmc/usr/bin:/usr/bin:/bin:$PAYLOAD_DIR/bin:$PATH"
export LD_LIBRARY_PATH="/mmc/usr/lib:$PAYLOAD_DIR/lib:$LD_LIBRARY_PATH"
export PYTHONPATH="$PAYLOAD_DIR/lib:$PAYLOAD_DIR:$PYTHONPATH"
export CRYPTOGRAPHY_OPENSSL_NO_LEGACY=1
if [ -d "/mmc/usr/share/nmap/scripts" ]; then
    export NMAPDIR="/mmc/usr/share/nmap"
elif [ -d "/usr/share/nmap/scripts" ]; then
    export NMAPDIR="/usr/share/nmap"
fi

# Packages required at runtime (installed to mmc so they survive reboots)
# nmap-full brings the NSE scripts + data (nmap-ssl lacks the scripts dir).
OPKG_PKGS="python3-light python3-ctypes python3-multiprocessing python3-sqlite3 python3-logging python3-urllib python3-email python3-xml python3-openssl nmap-full"

has_net() {
    for ip in $(ip -4 addr 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1); do
        [ "$ip" != "127.0.0.1" ] && return 0
    done
    return 1
}

online() { ping -c1 -W2 8.8.8.8 >/dev/null 2>&1; }

# ------------------------------------------------------------------
# Optional attack binaries (SSH/RDP/SMB) — cross-compiled, not in opkg. If they
# are present (or can be downloaded) the deferred attack modules are enabled;
# otherwise Loki runs with the pure-Python attacks only (FTP/Telnet/MySQL+nmap).
# ------------------------------------------------------------------
BINARIES_URL="https://github.com/pineapple-pager-projects/pineapple_pager_loki/releases/download/v2.0-binaries/loki-binaries-mipsel.tar.gz"

enable_deferred_actions() {
    for f in "$PAYLOAD_DIR"/actions/_deferred/*.py; do
        [ -f "$f" ] && cp "$f" "$PAYLOAD_DIR/actions/" 2>/dev/null
    done
}

have_attack_bins() {
    [ -f "$PAYLOAD_DIR/bin/sfreerdp" ] || [ -d "$PAYLOAD_DIR/lib/cryptography" ]
}

fetch_attack_binaries() {
    if have_attack_bins; then
        enable_deferred_actions; return 0
    fi
    online || return 0                       # offline: leave attacks disabled
    LOG ""
    LOG "yellow" "Optional attack binaries (SSH / RDP / SMB)"
    LOG "These add SSH, RDP and SMB brute force + file theft."
    LOG "Without them Loki still runs nmap recon/vuln plus"
    LOG "FTP / Telnet / MySQL brute force (no binaries needed)."
    LOG "green" "GREEN = Download    RED = Skip"
    while true; do
        B=$(WAIT_FOR_INPUT 2>/dev/null)
        case "$B" in
            GREEN|A) break ;;
            RED|B) LOG "Skipping optional binaries."; return 0 ;;
        esac
    done
    LOG "cyan" "Fetching optional attack binaries (SSH/RDP/SMB)..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$BINARIES_URL" -o /tmp/loki_binz.tgz 2>/dev/null
    else
        wget -qO /tmp/loki_binz.tgz "$BINARIES_URL" 2>/dev/null
    fi
    if [ -s /tmp/loki_binz.tgz ]; then
        tar xzf /tmp/loki_binz.tgz -C "$PAYLOAD_DIR" 2>/dev/null
        rm -f /tmp/loki_binz.tgz
    fi
    if have_attack_bins; then
        enable_deferred_actions
        LOG "green" "Attack binaries installed — SSH/RDP/SMB enabled."
    fi
}

bootstrap_deps() {
    NEED=""
    command -v python3 >/dev/null 2>&1 || NEED="python3"
    python3 -c 'import ctypes' 2>/dev/null || NEED="$NEED ctypes"
    command -v nmap >/dev/null 2>&1 || NEED="$NEED nmap"
    # nmap-ssl has no NSE scripts dir; require nmap-full for vuln scanning
    [ -d /mmc/usr/share/nmap/scripts ] || [ -d /usr/share/nmap/scripts ] || NEED="$NEED nmap-scripts"
    [ -z "$NEED" ] && return 0

    LOG ""
    LOG "yellow" "=== FIRST-RUN SETUP ==="
    LOG "Missing: $NEED"
    LOG "Loki will install python3 + nmap + ssh client"
    LOG "to the SD card (mmc). This needs internet and runs once."
    LOG ""
    if ! online; then
        LOG "red" "No internet connection."
        LOG "Connect the Pager to a network with internet,"
        LOG "then relaunch Loki to finish setup."
        LOG ""
        LOG "Press any button to exit..."
        WAIT_FOR_INPUT >/dev/null 2>&1
        return 1
    fi
    LOG "green" "GREEN = Install now    RED = Exit"
    while true; do
        B=$(WAIT_FOR_INPUT 2>/dev/null)
        case "$B" in
            GREEN|A) break ;;
            RED|B) LOG "Exiting."; return 1 ;;
        esac
    done
    LOG "Updating package lists..."
    opkg update 2>&1 | while IFS= read -r l; do LOG "  $l"; done
    LOG "Installing to mmc: $OPKG_PKGS"
    opkg -d mmc install $OPKG_PKGS 2>&1 | while IFS= read -r l; do LOG "  $l"; done
    # verify essentials
    if command -v python3 >/dev/null 2>&1 && python3 -c 'import ctypes' 2>/dev/null \
       && command -v nmap >/dev/null 2>&1; then
        LOG "green" "Setup complete!"
        sleep 1
        return 0
    fi
    LOG "red" "Setup failed — check the connection and retry."
    LOG "Press any button to exit..."
    WAIT_FOR_INPUT >/dev/null 2>&1
    return 1
}

# ------------------------------------------------------------------
# Splash / start gate
# ------------------------------------------------------------------
LOG ""
LOG "green" "Loki for WiFi Pineapple Pager"
LOG "cyan" "by *brAinphreAk*"
LOG ""
LOG "yellow" "Features:"
LOG "cyan" "  - Automated network reconnaissance"
LOG "cyan" "  - Port scanning with nmap"
LOG "cyan" "  - SSH/SMB/FTP/Telnet/RDP/SQL brute force"
LOG "cyan" "  - Data exfiltration"
LOG "cyan" "  - Vulnerability scanning"
LOG "cyan" "  - Web UI and theme support"
LOG ""

# Install dependencies if needed (no bundled binaries in v2)
bootstrap_deps || exit 0

# Enable SSH/RDP/SMB attacks if their binaries are present or downloadable
fetch_attack_binaries

# Require a usable network to scan
if ! has_net; then
    LOG ""
    LOG "red" "=== NO NETWORK CONNECTED ==="
    LOG "Connect via WiFi client (wlan0cli) or Ethernet/USB,"
    LOG "then relaunch Loki."
    LOG ""
    LOG "Press any button to exit..."
    WAIT_FOR_INPUT >/dev/null 2>&1
    exit 1
fi

LOG ""
LOG "green" "GREEN = Start"
LOG "red" "RED = Exit"
while true; do
    B=$(WAIT_FOR_INPUT 2>/dev/null)
    case "$B" in
        GREEN|A) break ;;
        RED|B) LOG "Exiting."; exit 0 ;;
    esac
done

mkdir -p "$DATA_DIR" 2>/dev/null

# ------------------------------------------------------------------
# Hold the display for the WHOLE session here, not per Python process.
# loki_menu.py launches Loki.py as a subprocess; if each grabbed/released
# UI_TAKEOVER the daemon would reclaim the screen in the gaps (UI flicker).
# PAGERCTL_EXTERNAL_TAKEOVER tells pagerctl.py to skip its own takeover.
# ------------------------------------------------------------------
export PAGERCTL_EXTERNAL_TAKEOVER=1
UI_TAKEOVER
trap 'UI_RELEASE 2>/dev/null' EXIT INT TERM

# ------------------------------------------------------------------
# Main loop. Exit 42 = hand off to another payload; 99 = Loki main menu.
# ------------------------------------------------------------------
NEXT_PAYLOAD_FILE="$DATA_DIR/.next_payload"
while true; do
    cd "$PAYLOAD_DIR"
    python3 loki_menu.py
    EXIT_CODE=$?

    if [ "$EXIT_CODE" -eq 42 ] && [ -f "$NEXT_PAYLOAD_FILE" ]; then
        NEXT_SCRIPT=$(cat "$NEXT_PAYLOAD_FILE")
        rm -f "$NEXT_PAYLOAD_FILE"
        if [ -f "$NEXT_SCRIPT" ]; then
            sh "$NEXT_SCRIPT"
            [ $? -eq 42 ] && continue
        fi
    fi
    [ "$EXIT_CODE" -eq 99 ] && continue
    break
done

exit 0
