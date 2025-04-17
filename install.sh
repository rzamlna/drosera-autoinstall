#!/bin/bash

set -e

echo ">>> [1/9] Update & install dependencies"
sudo apt update && sudo apt upgrade -y
sudo apt install curl git jq lz4 build-essential -y

echo ">>> [2/9] Install Go"
cd $HOME
GO_VERSION="1.21.1"
wget https://golang.org/dl/go$GO_VERSION.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
rm go$GO_VERSION.linux-amd64.tar.gz
echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile

echo ">>> [3/9] Clone Drosera repo & build"
cd $HOME
git clone https://github.com/0xmoei/Drosera-Network
cd Drosera-Network
make install

echo ">>> [4/9] Setup chain config"
CHAIN_ID="drosera_11983-1"
NODE_MONIKER="drosera-node"
droserad config chain-id $CHAIN_ID
droserad config keyring-backend test
droserad config node tcp://localhost:26657

echo ">>> [5/9] Initialize node"
droserad init "$NODE_MONIKER" --chain-id $CHAIN_ID

echo ">>> [6/9] Download genesis and addrbook"
curl -Ls https://raw.githubusercontent.com/0xmoei/Drosera-Network/main/genesis.json > ~/.drosera/config/genesis.json
curl -Ls https://snapshots-testnet.nodejumper.io/drosera-testnet/addrbook.json > ~/.drosera/config/addrbook.json

echo ">>> [7/9] Setup Cosmovisor"
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest
mkdir -p ~/.drosera/cosmovisor/genesis/bin
cp $(which droserad) ~/.drosera/cosmovisor/genesis/bin/
ln -s ~/.drosera/cosmovisor/genesis ~/.drosera/cosmovisor/current
sudo ln -s ~/.drosera/cosmovisor/current/bin/droserad /usr/local/bin/droserad

echo ">>> [8/9] Create systemd service"
sudo tee /etc/systemd/system/droserad.service > /dev/null <<EOF
[Unit]
Description=Drosera Node
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) start
Restart=on-failure
RestartSec=3
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.drosera"
Environment="DAEMON_NAME=droserad"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=$PATH:/usr/local/go/bin:$HOME/go/bin"

[Install]
WantedBy=multi-user.target
EOF

echo ">>> [9/9] Start node"
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable droserad
sudo systemctl start droserad

echo ">>> DONE! You can check logs with: journalctl -fu droserad -o cat"
