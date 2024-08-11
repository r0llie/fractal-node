#!/bin/bash

# Colors for the banner and text formatting
BANNER_COLOR="\e[1;34m" # Bold Blue
RESET_COLOR="\e[0m"      # Reset to default color
TEXT_COLOR="\e[1;32m"    # Bold Green
ERROR_COLOR="\e[1;31m"   # Bold Red

# Customizable User Settings
# These are the settings the user can modify as needed
WALLET_NAME="wallet"  # Name of the wallet to be created
INSTALL_DIR="/root/fractald"  # Installation directory
GITHUB_REPO="fractal-bitcoin/fractald-release"  # GitHub repository to fetch the latest release

# Function to display the rolling banner with custom ASCII art
roll_banner() {
  while true; do
    clear
    echo -e "${BANNER_COLOR}"
    echo -e "░       ░░░░      ░░░  ░░░░░░░░  ░░░░░░░"
    echo -e "▒  ▒▒▒▒  ▒▒  ▒▒▒▒  ▒▒  ▒▒▒▒▒▒▒▒  ▒▒▒▒▒▒▒"
    echo -e "▓       ▓▓▓  ▓▓▓▓  ▓▓  ▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓"
    echo -e "█  ███  ███  ████  ██  ████████  ███████"
    echo -e "█  ████  ███      ███        ██        █"
    echo -e "                                        "
    echo -e "${RESET_COLOR}"
    sleep 1
  done
}

# Start the banner in the background
roll_banner &

# Store the banner process ID to kill it later
BANNER_PID=$!

# Update and upgrade the system packages
echo -e "${TEXT_COLOR}Updating and upgrading system packages...${RESET_COLOR}"
sudo apt update && sudo apt upgrade -y

# Install necessary packages
echo -e "${TEXT_COLOR}Installing required packages...${RESET_COLOR}"
sudo apt install curl build-essential pkg-config libssl-dev git wget jq make gcc chrony -y

# Node Installation
# Fetch the latest release version from GitHub
echo -e "${TEXT_COLOR}Fetching the latest release of Fractal Node...${RESET_COLOR}"
LATEST_RELEASE=$(curl -s https://api.github.com/repos/${GITHUB_REPO}/releases/latest | jq -r '.tag_name')

# Construct the download URL using the latest release version
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${LATEST_RELEASE}/fractald-${LATEST_RELEASE}-x86_64-linux-gnu.tar.gz"

# Download the Fractal Node repository
echo -e "${TEXT_COLOR}Downloading Fractal Node from ${DOWNLOAD_URL}...${RESET_COLOR}"
wget ${DOWNLOAD_URL} -O ${INSTALL_DIR}/fractald-${LATEST_RELEASE}-x86_64-linux-gnu.tar.gz

# Extract the downloaded file
echo -e "${TEXT_COLOR}Extracting Fractal Node...${RESET_COLOR}"
mkdir -p ${INSTALL_DIR}
tar -zxvf ${INSTALL_DIR}/fractald-${LATEST_RELEASE}-x86_64-linux-gnu.tar.gz -C ${INSTALL_DIR}

# Navigate to the extracted folder and create a data directory
echo -e "${TEXT_COLOR}Creating data directory...${RESET_COLOR}"
cd ${INSTALL_DIR}/fractald-${LATEST_RELEASE}-x86_64-linux-gnu && mkdir data

# Copy the configuration file to the data directory
echo -e "${TEXT_COLOR}Copying configuration file...${RESET_COLOR}"
cp ./bitcoin.conf ./data

# Create a systemd service for the Fractal Node
echo -e "${TEXT_COLOR}Creating systemd service for Fractal Node...${RESET_COLOR}"
sudo tee /etc/systemd/system/fractald.service > /dev/null <<EOF
[Unit]
Description=Fractal Node
After=network.target

[Service]
User=root
WorkingDirectory=${INSTALL_DIR}/fractald-${LATEST_RELEASE}-x86_64-linux-gnu
ExecStart=${INSTALL_DIR}/fractald-${LATEST_RELEASE}-x86_64-linux-gnu/bin/bitcoind -datadir=${INSTALL_DIR}/fractald-${LATEST_RELEASE}-x86_64-linux-gnu/data/ -maxtipage=504576000
Restart=always
RestartSec=3
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the fractald service
echo -e "${TEXT_COLOR}Enabling and starting the Fractal Node service...${RESET_COLOR}"
sudo systemctl daemon-reload
sudo systemctl enable fractald
sudo systemctl start fractald

# Create a new wallet
echo -e "${TEXT_COLOR}Creating a new wallet named ${WALLET_NAME}...${RESET_COLOR}"
cd ${INSTALL_DIR}/fractald-${LATEST_RELEASE}-x86_64-linux-gnu/bin
./bitcoin-wallet -wallet=${WALLET_NAME} -legacy create

# Retrieve the wallet's private key and display it
echo -e "${TEXT_COLOR}Retrieving the wallet's private key...${RESET_COLOR}"
PRIVATE_KEY=$(./bitcoin-wallet -wallet=/root/.bitcoin/wallets/${WALLET_NAME}/wallet.dat -dumpfile=/root/.bitcoin/wallets/${WALLET_NAME}/MyPK.dat dump | awk -F 'checksum,' '/checksum/ {print $2}')


# Display the wallet information and private key with a reminder
echo -e "${TEXT_COLOR}Fractal Node installation and wallet creation completed successfully!${RESET_COLOR}"
echo -e "${ERROR_COLOR}IMPORTANT: Please back up your private key and store it in a secure location.${RESET_COLOR}"
echo -e "${TEXT_COLOR}Your Private Key: ${ERROR_COLOR}${PRIVATE_KEY}${RESET_COLOR}"
echo -e "${TEXT_COLOR}Wallet Name: ${WALLET_NAME}${RESET_COLOR}"
echo -e "${TEXT_COLOR}Wallet Location: /root/.bitcoin/wallets/${WALLET_NAME}/wallet.dat${RESET_COLOR}"

# Keep the information on the screen
read -p "Press Enter after you have safely backed up your private key..."
kill $BANNER_PID
clear

# Check the logs of the Fractal Node service
echo -e "${TEXT_COLOR}Checking Fractal Node logs...${RESET_COLOR}"
sudo journalctl -u fractald -fo cat

