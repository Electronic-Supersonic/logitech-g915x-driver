BINARY_NAME=logitech-g915x-driver
CONFIG_NAME=mapping.conf
DRIVER_USER=g915x-driver
RULE_FILE=/etc/udev/rules.d/99-logitech-g915x.rules
SERVICE_NAME=logig915xdrv.service
SERVICE_FILE=/etc/systemd/system/$(SERVICE_NAME)
INSTALL_DIR=/usr/local/bin
CONF_DIR=/etc/g915x-driver

.PHONY: all build install uninstall clean

all: build

build:
	cargo build --release

install: build
	# 1. Create System User
	@id -u $(DRIVER_USER) >/dev/null 2>&1 || (echo "Creating system user..." && sudo useradd -r -s /usr/bin/nologin -G input $(DRIVER_USER))

	# 2. Stop service if running
	@sudo systemctl stop $(SERVICE_NAME) 2>/dev/null || true

	# 3. Install Binary
	sudo cp -f target/release/$(BINARY_NAME) $(INSTALL_DIR)/
	sudo chown root:root $(INSTALL_DIR)/$(BINARY_NAME)
	sudo chmod 755 $(INSTALL_DIR)/$(BINARY_NAME)

	# 4. Setup Config
	sudo mkdir -p $(CONF_DIR)
	@[ -f $(CONFIG_NAME) ] && sudo cp -f $(CONFIG_NAME) $(CONF_DIR)/ || echo "Warning: $(CONFIG_NAME) not found in current dir"
	sudo chown -R root:$(DRIVER_USER) $(CONF_DIR)
	sudo chmod 644 $(CONF_DIR)/$(CONFIG_NAME)

	# 5. Install Rules
	@echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c356", OWNER="$(DRIVER_USER)", MODE="0660"' | sudo tee $(RULE_FILE) > /dev/null
	@echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c547", OWNER="$(DRIVER_USER)", MODE="0660"' | sudo tee -a $(RULE_FILE) > /dev/null
	@echo 'SUBSYSTEM=="event*", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c356", OWNER="$(DRIVER_USER)", MODE="0660"' | sudo tee -a $(RULE_FILE) > /dev/null
	@echo 'SUBSYSTEM=="event*", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c547", OWNER="$(DRIVER_USER)", MODE="0660"' | sudo tee -a $(RULE_FILE) > /dev/null

	# 6. Install Service
	@printf "[Unit]\nDescription=Logitech G915X driver\nAfter=multi-user.target\n\n[Service]\nType=simple\nUser=$(DRIVER_USER)\nEnvironment=\"G915X_CONFIG=$(CONF_DIR)/$(CONFIG_NAME)\"\nExecStart=$(INSTALL_DIR)/$(BINARY_NAME)\nRestart=always\nRestartSec=3\nStandardOutput=journal\nStandardError=journal\n\n[Install]\nWantedBy=multi-user.target\n" | sudo tee $(SERVICE_FILE) > /dev/null

	# 7. Reload and Start
	sudo udevadm control --reload-rules && sudo udevadm trigger
	sudo systemctl daemon-reload
	sudo systemctl enable --now $(SERVICE_NAME)
	@echo "--- Install Complete ---"

uninstall:
	@sudo systemctl disable --now $(SERVICE_NAME) 2>/dev/null || true
	@sudo rm -f $(SERVICE_FILE) $(RULE_FILE) $(INSTALL_DIR)/$(BINARY_NAME)
	@sudo rm -rf $(CONF_DIR)
	@sudo userdel $(DRIVER_USER) 2>/dev/null || true
	@sudo systemctl daemon-reload
	@sudo udevadm control --reload-rules && sudo udevadm trigger
	@echo "--- Uninstall Complete ---"

clean:
	cargo clean