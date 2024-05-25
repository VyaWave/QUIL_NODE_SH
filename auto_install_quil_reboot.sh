#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
  echo "please change root user to run this script"
  echo "try 'sudo su' to change to root user"
  exit 1
fi

if [ ! -d "/root/.albert_config" ]; then
  mkdir /root/.albert_config
  chmod -R 777 /root/.albert_config
fi
echo "############################################"
echo ""
echo "             *IMPORTANT*                    "
echo ""
echo "SAVE LISTED FILES TO YOUR PC"
echo "  /www/ceremonyclient/node/.config/keys.yml"
echo "  /www/ceremonyclient/node/.config/config.yml"
echo "  /root/wallet1.bak"
echo ""
echo ""
echo "                          -- by SESXueLan"
echo "###########################################"
sleep 3

#################### environment ##########################
install_environment() {
  cd /root

  ufw disable

  apt-get update
  apt install cpulimit -y
  apt install zip -y
  apt install unzip -y
  apt install curl build-essential make gcc jq git -y
  apt install lz4 -y

  if [ ! -d "/www" ]; then
    mkdir -p /www
    chmod -R 777 /www
  fi
  cd /root
  if [ ! -d "/root/.asdf" ]; then
    git clone https://github.com/asdf-vm/asdf.git /root/.asdf --branch v0.14.0
  fi

  if [ $(grep -c "asdf.sh" /root/.bashrc) -ne '0' ]; then
    echo "asdf config exists, skip..."
  else
    chmod +x .asdf/asdf.sh
    chmod +x .asdf/completions/asdf.bash
    echo '. $HOME/.asdf/asdf.sh' >>/root/.bashrc
    echo '. $HOME/.asdf/completions/asdf.bash' >>/root/.bashrc
  fi

  source /root/.bashrc
  source /root/.asdf/asdf.sh
  source /root/.asdf/completions/asdf.bash

  if [[ $(asdf plugin list) =~ "golang" ]]; then
    echo "exists golang plugin, skip..."
  else
    asdf plugin add golang https://github.com/asdf-community/asdf-golang.git
  fi

  if [ ! -d "/root/.asdf/installs/golang/1.20.14" ]; then
    asdf install golang 1.20.14
  fi
  if [ ! -d "/root/.asdf/installs/golang/1.22.1" ]; then
    asdf install golang 1.22.1
  fi

  if [[ $(grep ^"net.core.rmem_max=600000000"$ /etc/sysctl.conf) ]]; then
    echo "\net.core.rmem_max=600000000\" found inside /etc/sysctl.conf, skipping..."
  else
    echo -e "\n# Change made to increase buffer sizes for better network performance for ceremonyclient\nnet.core.rmem_max=600000000" | tee -a /etc/sysctl.conf >/dev/null
  fi

  if [[ $(grep ^"net.core.wmem_max=600000000"$ /etc/sysctl.conf) ]]; then
    echo "\net.core.wmem_max=600000000\" found inside /etc/sysctl.conf, skipping..."
  else
    echo -e "\n# Change made to increase buffer sizes for better network performance for ceremonyclient\nnet.core.wmem_max=600000000" | tee -a /etc/sysctl.conf >/dev/null
  fi
  sysctl -p
}
################################################

#################### initia ####################
install_initia() {
  cd /www
  (
    cat <<EOF
journalctl -u  initia -f
EOF
  ) >/root/initia_node_log.sh
  chmod +x /root/initia_node_log.sh
  (
    cat <<EOF
journalctl -u  slinky -f
EOF
  ) >/root/initia_oracle_log.sh
  chmod +x /root/initia_oracle_log.sh

  (
    cat <<EOF
curl -s localhost:26657/status | jq .result | jq .sync_info
EOF
  ) >/root/initia_node_status.sh
  chmod +x /root/initia_node_status.sh

  git clone https://github.com/initia-labs/initia.git
  (
    cat <<EOF
export GOROOT=/root/.asdf/installs/golang/1.22.1/go
export GOPATH=\$HOME/gowork_initia
export GOBIN=\$GOPATH/bin
export GO111MODULE=on
export PATH=\$GOPATH:\$GOBIN:\$GOROOT/bin:\$PATH
EOF
  ) >initia_profile
  source initia_profile
  cd initia
  asdf local golang 1.22.1
  git checkout v0.2.12
  make install

  initiad init "$(hostname)" --chain-id=initiation-1
  initiad config set client chain-id initiation-1

  curl -s https://initia.s3.ap-southeast-1.amazonaws.com/initiation-1/genesis.json >~/.initia/config/genesis.json
  wget -O $HOME/.initia/config/addrbook.json https://rpc-initia-testnet.trusted-point.com/addrbook.json
  PEERS="40d3f977d97d3c02bd5835070cc139f289e774da@168.119.10.134:26313,841c6a4b2a3d5d59bb116cc549565c8a16b7fae1@23.88.49.233:26656,e6a35b95ec73e511ef352085cb300e257536e075@37.252.186.213:26656,2a574706e4a1eba0e5e46733c232849778faf93b@84.247.137.184:53456,ff9dbc6bb53227ef94dc75ab1ddcaeb2404e1b0b@178.170.47.171:26656,edcc2c7098c42ee348e50ac2242ff897f51405e9@65.109.34.205:36656,07632ab562028c3394ee8e78823069bfc8de7b4c@37.27.52.25:19656,028999a1696b45863ff84df12ebf2aebc5d40c2d@37.27.48.77:26656,140c332230ac19f118e5882deaf00906a1dba467@185.219.142.119:53456,1f6633bc18eb06b6c0cab97d72c585a6d7a207bc@65.109.59.22:25756,065f64fab28cb0d06a7841887d5b469ec58a0116@84.247.137.200:53456,767fdcfdb0998209834b929c59a2b57d474cc496@207.148.114.112:26656,093e1b89a498b6a8760ad2188fbda30a05e4f300@35.240.207.217:26656,12526b1e95e7ef07a3eb874465662885a586e095@95.216.78.111:26656"
  seeds="2eaa272622d1ba6796100ab39f58c75d458b9dbc@34.142.181.82:26656,c28827cb96c14c905b127b92065a3fb4cd77d7f6@testnet-seeds.whispernode.com:25756"
  sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.initia/config/config.toml
  sed -i.bak -e "s/^seeds *=.*/seeds = \"$seeds\"/" ~/.initia/config/config.toml

  pruning="custom" &&
    pruning_keep_recent="100" &&
    pruning_keep_every="0" &&
    pruning_interval="10" &&
    sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.initia/config/app.toml &&
    sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.initia/config/app.toml &&
    sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.initia/config/app.toml &&
    sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.initia/config/app.toml

  cd /root

  tee /etc/systemd/system/initia.service <<EOF >/dev/null
[Unit]
Description=initia daemon
After=network-online.target
[Service]
User=$USER
ExecStart=$(which initiad) start
Restart=on-failure
RestartSec=3
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload &&
    systemctl enable initia &&
    systemctl restart initia

  initiad config set client node tcp://127.0.0.1:26657

  # 预言机
  cd /www
  source initia_profile
  git clone https://github.com/skip-mev/slinky.git
  git checkout v0.4.3
  cd slinky
  make build
  tee /etc/systemd/system/slinky.service >/dev/null <<EOF
[Unit]
Description=slinky
After=network-online.target
[Service]
User=$USER
WorkingDirectory=/www/slinky
ExecStart=/www/slinky/build/slinky --oracle-config-path ./config/core/oracle.json --market-map-endpoint 0.0.0.0:9090
StandardOutput=syslog
StandardError=syslog
Restart=always
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable slinky.service
  systemctl start slinky.service

  chmod 777 /root/.initia/config/app.toml
  sed -i -e 's/^enabled = "false"/enabled = "true"/' \
    -e 's/^oracle_address = ""/oracle_address = "127.0.0.1:8080"/' \
    -e 's/^client_timeout = "2s"/client_timeout = "500ms"/' \
    -e 's/^metrics_enabled = "false"/metrics_enabled = "false"/' \
    $HOME/.initia/config/app.toml

  systemctl restart initia

  cd /root

  (
    initiad keys add wallet1 <<!
12345678
12345678
!
  ) >wallet1.bak 2>&1

  (
    cat <<EOF
initiad query bank balances $(cat /root/wallet1.bak | grep -oE "^- address:.+" | sed "s/- address://" | sed "s/ //")
EOF
  ) >/root/initia_balance.sh
  chmod +x /root/initia_balance.sh

  touch /root/.albert_config/initia_installed
  # 剩下的参考：https://mirror.xyz/exploring.eth/QGF7FymfPeaicgO9UGkGD2ltrlV-fJAsUWvvl_FjcH8
}
################################################

#################### quil ######################
install_quil() {
  cd /www
  (
    cat <<EOF
#!/bin/bash
# 兼容zsh
export DISABLE_AUTO_TITLE="true"

session="QuilNode"
tmux has-session -t \$session
if [ \$? = 0 ];then
    tmux attach-session -t \$session
    exit
fi

tmux new-session -d -s \$session
tmux send-keys -t \$session:0 'cd /www/ceremonyclient/node/' C-m
tmux send-keys -t \$session:0 '. /www/quil_profile' C-m
tmux send-keys -t \$session:0 '/root/gowork_quil/bin/node ./..' C-m
#tmux new-window -t \$session:1
#tmux send-keys -t \$session:1 'cd /www/ceremonyclient/node/' C-m
# tmux send-keys -t \$session:1 'cpulimit -e node --limit 90 -b' C-m
EOF
  ) >/root/start.sh
  chmod +x /root/start.sh

  (
    cat <<EOF
grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo
# grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetTokenInfo
EOF
  ) >/root/check.sh
  chmod +x /root/check.sh

  (
    cat <<EOF
export GOROOT=/root/.asdf/installs/golang/1.20.14/go
export GOPATH=\$HOME/gowork_quil
export GOBIN=\$GOPATH/bin
export GO111MODULE=on
export PATH=\$GOPATH:\$GOBIN:\$GOROOT/bin:\$PATH
EOF
  ) >quil_profile
  source quil_profile
  source /root/.asdf/asdf.sh
  source /root/.asdf/completions/asdf.bash
  asdf global golang 1.20.14

  (
    cat <<EOF
source /www/quil_profile
EOF
  ) >>/root/.bashrc
  source /root/.bashrc

  (
    cat <<EOF
@reboot /root/start.sh
00 00 * * * /usr/sbin/reboot
EOF
  ) >/var/spool/cron/crontabs/root

  crontab -u root /var/spool/cron/crontabs/root
  service cron restart

  go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

  git clone https://github.com/QuilibriumNetwork/ceremonyclient.git

  cd /www/ceremonyclient/node
  asdf local golang 1.20.14

  GOEXPERIMENT=arenas go run ./... &

  while true; do
    if [ -f "/www/ceremonyclient/node/.config/config.yml" ]; then
      sleep 10
      # 结束进程
      process_count=$(ps -ef | grep "exe/node" | grep -v grep | wc -l)
      process_pids=$(ps -ef | grep "exe/node" | grep -v grep | awk '{print $2}' | xargs)

      if [ $process_count -gt 0 ]; then
        echo "killing processes $process_pids"
        kill $process_pids

        child_process_count=$(pgrep -P $process_pids | wc -l)
        child_process_pids=$(pgrep -P $process_pids | xargs)
        if [ $child_process_count -gt 0 ]; then
          echo "killing child processes $child_process_pids"
          kill $child_process_pids
        else
          echo "no child processes running"
        fi
      else
        echo "no processes running"
      fi
      # 修改文件
      sed -i 's|listenGrpcMultiaddr: ""|listenGrpcMultiaddr: "/ip4/0.0.0.0/tcp/8337"|g' /www/ceremonyclient/node/.config/config.yml
      sed -i 's|listenRESTMultiaddr: ""|listenRESTMultiaddr: "/ip4/0.0.0.0/tcp/8338"|g' /www/ceremonyclient/node/.config/config.yml
      break
    else
      echo "config file not exists, waiting..."
      sleep 30
    fi

    sleep 10
  done

  cd /www/ceremonyclient/node
  GOEXPERIMENT=arenas go clean -v -n -a ./...
  rm /root/gowork_quil/bin/node
  GOEXPERIMENT=arenas go install ./...

  touch /root/.albert_config/quil_installed
}
################################################

# 测试用
#touch /root/.albert_config/initia_installed

install_environment

# 注释 initia
# if [ ! -f "/root/.albert_config/initia_installed" ]; then
#   install_initia
# fi

if [ ! -f "/root/.albert_config/quil_installed" ]; then
  install_quil
fi

sleep 3
# quil 快照同步请手动操作
reboot
