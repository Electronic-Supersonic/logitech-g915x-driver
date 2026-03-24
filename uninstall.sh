#!/bin/bash

# Configuration (Must match install.sh)
BINARY_NAME="logitech-g915x-driver"
DRIVER_USER="g915x-driver"
RULE_FILE="/etc/udev/rules.d/99-logitech-g915x.rules"
SERVICE_NAME="logig915xdrv.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
INSTALL_DIR="/usr/local/bin"
CONF_DIR="/etc/g915x-driver"

echo "--- G915X Rust Driver Uninstaller ---"

# 1. Stop and disable the service
if systemctl is-active --quiet "$SERVICE_NAME" || systemctl is-enabled --quiet "$SERVICE_NAME"; then
    echo "Stopping and disabling $SERVICE_NAME..."
    sudo systemctl disable --now "$SERVICE_NAME"
fi

# 2. Remove the system files
echo "Removing binary, service, and udev rules..."
[ -f "$SERVICE_FILE" ] && sudo rm "$SERVICE_FILE"
[ -f "$RULE_FILE" ]    && sudo rm "$RULE_FILE"
[ -f "$INSTALL_DIR/$BINARY_NAME" ] && sudo rm "$INSTALL_DIR/$BINARY_NAME"

# 3. Remove the config directory
if [ -d "$CONF_DIR" ]; then
    echo "Removing configuration directory: $CONF_DIR"
    sudo rm -rf "$CONF_DIR"
fi

# 4. Remove the system user
if id -u "$DRIVER_USER" >/dev/null 2>&1; then
    echo "Removing system user: $DRIVER_USER"
    sudo userdel "$DRIVER_USER"
fi

# 5. Reload systemd and udev
echo "Reloading system daemons..."
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "--- Uninstall Complete ---"