#!/bin/bash

# Configuration
BINARY_NAME="logitech-g915x-driver"
CONFIG_NAME="mapping.conf"
DRIVER_USER="g915x-driver"
RULE_FILE="/etc/udev/rules.d/99-logitech-g915x.rules"
SERVICE_NAME="logig915xdrv.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
INSTALL_DIR="/usr/local/bin"
CONF_DIR="/etc/g915x-driver"

echo "--- G915X Rust Driver Setup ---"

# 1. Stop existing service to release hardware/file locks
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Stopping existing driver service..."
    sudo systemctl stop "$SERVICE_NAME"
fi

# 2. Create System User
if ! id -u "$DRIVER_USER" >/dev/null 2>&1; then
    echo "Creating system user: $DRIVER_USER"
    sudo useradd -r -s /usr/bin/nologin "$DRIVER_USER"
    sudo usermod -aG input "$DRIVER_USER"
fi

# 3. Build and Install Binary
echo "Building Rust binary..."
cargo build --release
sudo cp -f "./target/release/$BINARY_NAME" "$INSTALL_DIR/"
sudo chown root:root "$INSTALL_DIR/$BINARY_NAME"
sudo chmod 755 "$INSTALL_DIR/$BINARY_NAME"

# 4. Setup Config
echo "Configuring $CONF_DIR..."
sudo mkdir -p "$CONF_DIR"
if [ -f "./$CONFIG_NAME" ]; then
    sudo cp -f "./$CONFIG_NAME" "$CONF_DIR/"
fi
sudo chown -R root:"$DRIVER_USER" "$CONF_DIR"
sudo chmod 644 "$CONF_DIR/$CONFIG_NAME"

# 5. Install Udev Rules
echo "Installing udev rules..."
sudo tee "$RULE_FILE" > /dev/null <<EOF
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c356", OWNER="$DRIVER_USER", MODE="0660"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c547", OWNER="$DRIVER_USER", MODE="0660"
SUBSYSTEM=="event*", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c356", OWNER="$DRIVER_USER", MODE="0660"
SUBSYSTEM=="event*", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c547", OWNER="$DRIVER_USER", MODE="0660"
EOF

# 6. Create Systemd Service
echo "Creating systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Logitech G915X driver
After=multi-user.target

[Service]
Type=simple
User=$DRIVER_USER
Environment="G915X_CONFIG=$CONF_DIR/$CONFIG_NAME"
ExecStart=$INSTALL_DIR/$BINARY_NAME
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 7. Reload and Start
echo "Applying changes and starting driver..."
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo systemctl daemon-reload
sudo systemctl enable --now "$SERVICE_NAME"

echo "--- Setup Complete ---"
systemctl status "$SERVICE_NAME"