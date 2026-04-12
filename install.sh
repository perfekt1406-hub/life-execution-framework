#!/usr/bin/env bash
set -euo pipefail

# ── Resolve paths ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/life-framework.html"
GATE_SCRIPT="$HOME/.local/bin/life-framework-daily.sh"
STAMP_FILE="\$HOME/.local/state/life-framework-last-open"
DAY_START_HOUR=3
DAY_START_MIN=30

if [[ ! -f "$TARGET" ]]; then
  echo "ERROR: life-framework.html not found next to this script ($SCRIPT_DIR)"
  exit 1
fi

# ── Detect OS ───────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Linux)   PLATFORM="linux" ;;
  Darwin)  PLATFORM="macos" ;;
  MSYS*|MINGW*|CYGWIN*)
    echo "ERROR: On Windows, run install.ps1 in PowerShell instead."
    exit 1
    ;;
  *)
    echo "ERROR: Unsupported OS: $OS"
    exit 1
    ;;
esac

echo "Detected platform: $PLATFORM"

# ── Write gate script (OS-specific date/open commands) ──────────────────────
mkdir -p "$(dirname "$GATE_SCRIPT")"

if [[ "$PLATFORM" == "linux" ]]; then
  cat > "$GATE_SCRIPT" <<GATE
#!/usr/bin/env bash
STAMP_FILE="$STAMP_FILE"
TARGET="$TARGET"
DAY_START_HOUR=$DAY_START_HOUR
DAY_START_MIN=$DAY_START_MIN

mkdir -p "\$(dirname "\$STAMP_FILE")"

current_hour=\$(date +%-H)
current_min=\$(date +%-M)
today=\$(date +%Y-%m-%d)

if (( current_hour < DAY_START_HOUR || (current_hour == DAY_START_HOUR && current_min < DAY_START_MIN) )); then
  logical_date=\$(date -d "yesterday" +%Y-%m-%d)
else
  logical_date="\$today"
fi

last_open=\$(cat "\$STAMP_FILE" 2>/dev/null)

if [[ "\$last_open" == "\$logical_date" ]]; then
  exit 0
fi

echo "\$logical_date" > "\$STAMP_FILE"

sleep 3
xdg-open "\$TARGET"
GATE

elif [[ "$PLATFORM" == "macos" ]]; then
  cat > "$GATE_SCRIPT" <<GATE
#!/usr/bin/env bash
STAMP_FILE="$STAMP_FILE"
TARGET="$TARGET"
DAY_START_HOUR=$DAY_START_HOUR
DAY_START_MIN=$DAY_START_MIN

mkdir -p "\$(dirname "\$STAMP_FILE")"

current_hour=\$(date +%H | sed 's/^0//')
current_min=\$(date +%M | sed 's/^0//')
today=\$(date +%Y-%m-%d)

if (( current_hour < DAY_START_HOUR || (current_hour == DAY_START_HOUR && current_min < DAY_START_MIN) )); then
  logical_date=\$(date -v-1d +%Y-%m-%d)
else
  logical_date="\$today"
fi

last_open=\$(cat "\$STAMP_FILE" 2>/dev/null)

if [[ "\$last_open" == "\$logical_date" ]]; then
  exit 0
fi

echo "\$logical_date" > "\$STAMP_FILE"

sleep 3
open "\$TARGET"
GATE
fi

chmod +x "$GATE_SCRIPT"
echo "Wrote gate script: $GATE_SCRIPT"

# ── Register autostart ─────────────────────────────────────────────────────

register_xdg_autostart() {
  local dir="$HOME/.config/autostart"
  local file="$dir/life-framework-daily.desktop"
  mkdir -p "$dir"
  cat > "$file" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Life Framework Daily
Comment=Open Life Framework on first login of the day
Exec=$GATE_SCRIPT
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
  echo "Wrote XDG autostart entry: $file"
}

register_i3() {
  local config="$HOME/.config/i3/config"
  if [[ ! -f "$config" ]]; then
    echo "WARN: i3 config not found at $config — skipping i3 registration"
    return
  fi
  if grep -q 'life-framework-daily' "$config"; then
    echo "i3 autostart already present — skipping"
    return
  fi
  printf '\n# [life-framework-daily] -- added by installer\nexec --no-startup-id %s\n' "$GATE_SCRIPT" >> "$config"
  echo "Appended exec to i3 config: $config"
}

register_sway() {
  local config="$HOME/.config/sway/config"
  if [[ ! -f "$config" ]]; then
    echo "WARN: sway config not found at $config — skipping sway registration"
    return
  fi
  if grep -q 'life-framework-daily' "$config"; then
    echo "sway autostart already present — skipping"
    return
  fi
  printf '\n# [life-framework-daily] -- added by installer\nexec %s\n' "$GATE_SCRIPT" >> "$config"
  echo "Appended exec to sway config: $config"
}

register_hyprland() {
  local config="$HOME/.config/hypr/hyprland.conf"
  if [[ ! -f "$config" ]]; then
    echo "WARN: Hyprland config not found at $config — skipping Hyprland registration"
    return
  fi
  if grep -q 'life-framework-daily' "$config"; then
    echo "Hyprland autostart already present — skipping"
    return
  fi
  printf '\n# [life-framework-daily] -- added by installer\nexec-once = %s\n' "$GATE_SCRIPT" >> "$config"
  echo "Appended exec-once to Hyprland config: $config"
}

register_systemd() {
  local dir="$HOME/.config/systemd/user"
  local file="$dir/life-framework-daily.service"
  mkdir -p "$dir"
  cat > "$file" <<UNIT
[Unit]
Description=Life Framework Daily
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=$GATE_SCRIPT

[Install]
WantedBy=graphical-session.target
UNIT
  systemctl --user daemon-reload
  systemctl --user enable life-framework-daily.service
  echo "Wrote and enabled systemd user service: $file"
}

register_launchagent() {
  local dir="$HOME/Library/LaunchAgents"
  local file="$dir/com.user.life-framework-daily.plist"
  mkdir -p "$dir"
  cat > "$file" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.user.life-framework-daily</string>
  <key>ProgramArguments</key>
  <array>
    <string>$GATE_SCRIPT</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST
  launchctl unload "$file" 2>/dev/null || true
  launchctl load "$file"
  echo "Wrote and loaded LaunchAgent: $file"
}

# ── Dispatch ────────────────────────────────────────────────────────────────

if [[ "$PLATFORM" == "macos" ]]; then
  register_launchagent
  echo ""
  echo "Done! Life Framework will open in your default browser on each macOS login (once per day)."

elif [[ "$PLATFORM" == "linux" ]]; then
  DE="${XDG_CURRENT_DESKTOP:-}"
  echo "Detected desktop: ${DE:-<none>}"

  case "$DE" in
    *GNOME*|*KDE*|*XFCE*|*LXDE*|*LXQt*|*Cinnamon*|*X-Cinnamon*|*MATE*|*Budgie*|*Pantheon*)
      register_xdg_autostart
      ;;
    *sway*|*Sway*)
      register_sway
      ;;
    *Hyprland*|*hyprland*)
      register_hyprland
      ;;
    *i3*)
      register_i3
      ;;
    *)
      # Fallback: try to detect WM config files, otherwise use XDG (most environments support it)
      if [[ -f "$HOME/.config/i3/config" ]]; then
        register_i3
      elif [[ -f "$HOME/.config/sway/config" ]]; then
        register_sway
      elif [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
        register_hyprland
      elif command -v systemctl &>/dev/null; then
        register_systemd
      else
        register_xdg_autostart
        echo "NOTE: Could not detect your desktop. Installed XDG autostart as a safe default."
      fi
      ;;
  esac

  echo ""
  echo "Done! Life Framework will open in your default browser on each login (once per day)."
fi

echo ""
echo "  Stamp file: ~/.local/state/life-framework-last-open"
echo "  To test now: $GATE_SCRIPT"
echo "  To force re-open tomorrow: rm ~/.local/state/life-framework-last-open"
