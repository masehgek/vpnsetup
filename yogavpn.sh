#!/bin/bash
# Script setup VPS dengan instalasi VPN, Xray, SSH Websocket, dan konfigurasi domain
# Ingatlah bahwa harta dan tahta hanya sementara, jangan lupa sholat dan persiapkan akhirat

# --- Warna untuk output ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
purple='\e[35;1m'
cyan='\e[36;1m'
BRed='\e[1;31m'
BGreen='\e[1;32m'
BYellow='\e[1;33m'
BBlue='\e[1;34m'
NC='\e[0m' # No Color

# Fungsi warna untuk echo
purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
cyan() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

# Bersihkan layar dan masuk ke home root
cd /root || exit
rm -f setup.sh
clear

# --- Fungsi menampilkan penggunaan data VPN (vnstat) ---
show_vpn_usage() {
  local IFACE="enp0s6"
  echo -e "\n${BGreen}=== VPN Data Usage Report for interface $IFACE ===${NC}"
  echo -e "${BBlue}Daily Usage:${NC}"
  vnstat -i "$IFACE" -d | tail -n +3 | head -n 7 | awk '{print $2, $3, $4, $5, $6, $7}'
  echo ""
  echo -e "${BBlue}Monthly Usage:${NC}"
  vnstat -i "$IFACE" -m | tail -n +3 | head -n 12 | awk '{print $2, $3, $4, $5, $6, $7}'
  echo ""
  read -rp "Press enter to return to menu..."
  menu
}

# --- Menu utama ---
menu() {
  clear
  echo -e "${BBlue}                     VPN MENU                     ${NC}"
  echo -e "${BYellow}----------------------------------------------------------${NC}"
  echo -e "${BGreen} 1) Show VPN Data Usage (Daily & Monthly) ${NC}"
  echo -e "${BGreen} 2) Other menu option (placeholder)         ${NC}"
  echo -e "${BGreen} 0) Exit                                   ${NC}"
  echo -e "${BYellow}----------------------------------------------------------${NC}"
  echo -ne "Select menu: "
  read -r opt
  case $opt in
    1) show_vpn_usage ;;
    2) echo -e "${BGreen}Other menu option selected.${NC}"; sleep 2; menu ;;
    0) clear; exit 0 ;;
    *) echo -e "${BRed}Invalid option!${NC}"; sleep 2; menu ;;
  esac
}

# --- Cek apakah script dijalankan sebagai root ---
if [ "${EUID}" -ne 0 ]; then
  echo -e "${red}You need to run this script as root${NC}"
  sleep 5
  exit 1
fi

# --- Cek virtualisasi, tolak OpenVZ ---
if [ "$(systemd-detect-virt)" == "openvz" ]; then
  clear
  echo -e "${red}OpenVZ is not supported${NC}"
  echo "For VPS with KVM and VMWare virtualization ONLY"
  sleep 5
  exit 1
fi

# --- Perbaiki /etc/hosts jika hostname tidak sesuai ---
localip=$(hostname -I | awk '{print $1}')
hst=$(hostname)
dart=$(awk -v h="$hst" '$2 == h {print $2}' /etc/hosts)
if [[ "$hst" != "$dart" ]]; then
  echo "$localip $hst" >> /etc/hosts
fi

# --- Buat folder dan file domain jika belum ada ---
mkdir -p /etc/xray /etc/v2ray
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain

# --- Cek dan install linux headers kernel yang sesuai ---
kernel_ver=$(uname -r)
REQUIRED_PKG="linux-headers-$kernel_ver"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' "$REQUIRED_PKG" 2>/dev/null | grep "install ok installed")

echo -e "[ ${BBlue}NOTES${NC} ] Checking kernel headers package: $REQUIRED_PKG"
if [ -z "$PKG_OK" ]; then
  echo -e "[ ${BRed}WARNING${NC} ] Package $REQUIRED_PKG not installed. Installing..."
  apt-get update -y
  apt-get install -y "$REQUIRED_PKG"
  echo -e "[ ${BBlue}NOTES${NC} ] If installation error occurs, please run:"
  echo -e "  apt update && apt upgrade -y && reboot"
  echo -e "Then run this script again."
  read -rp "Press enter to continue..."
else
  echo -e "[ ${BGreen}INFO${NC} ] Kernel headers package is installed."
fi

# --- Fungsi konversi detik ke jam, menit, detik ---
secs_to_human() {
  echo "Installation time : $(( $1 / 3600 )) hours $(( ($1 / 60) % 60 )) minutes $(( $1 % 60 )) seconds"
}
start_time=$(date +%s)

# --- Set zona waktu dan matikan IPv6 ---
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

# --- Install paket dasar ---
echo -e "[ ${BGreen}INFO${NC} ] Installing required packages..."
apt-get update -y
apt-get install -y git curl python2 vnstat

# --- Setup vnstat untuk interface enp0s6 ---
vnstat -u -i enp0s6
systemctl enable vnstat
systemctl restart vnstat

echo -e "[ ${BGreen}INFO${NC} ] Installation files ready."
sleep 1

# --- Setup folder dan file konfigurasi IP ---
mkdir -p /var/lib/
echo "IP=" > /var/lib/ipvps.conf

# --- Setup domain VPS ---
clear
echo -e "${BBlue}                     SETUP DOMAIN VPS     ${NC}"
echo -e "${BYellow}----------------------------------------------------------${NC}"
echo -e "${BGreen} 1. Use Domain Random / Gunakan Domain Random ${NC}"
echo -e "${BGreen} 2. Choose Your Own Domain / Gunakan Domain Sendiri ${NC}"
echo -e "${BYellow}----------------------------------------------------------${NC}"
read -rp "Input 1 or 2 / pilih 1 atau 2 : " dns_choice

if [[ "$dns_choice" == "1" ]]; then
  wget -q https://raw.githubusercontent.com/givpn/AutoScriptXray/master/ssh/cf -O cf
  chmod +x cf
  ./cf
elif [[ "$dns_choice" == "2" ]]; then
  read -rp "Enter Your Domain / masukan domain : " dom
  echo "IP=$dom" > /var/lib/ipvps.conf
  echo "$dom" > /root/scdomain
  echo "$dom" > /etc/xray/scdomain
  echo "$dom" > /etc/xray/domain
  echo "$dom" > /etc/v2ray/domain
  echo "$dom" > /root/domain
else
  echo -e "${red}Invalid option!${NC}"
  exit 1
fi

echo -e "${BGreen}Domain setup done!${NC}"
sleep 2
clear

# --- Install SSH Websocket ---
echo -e "${yellow}-----------------------------------${NC}"
echo -e "${BGreen}      Install SSH Websocket           ${NC}"
echo -e "${yellow}-----------------------------------${NC}"
sleep 1
clear
wget -q https://raw.githubusercontent.com/givpn/AutoScriptXray/master/ssh/ssh-vpn.sh -O ssh-vpn.sh
chmod +x ssh-vpn.sh
./ssh-vpn.sh

# --- Install Xray ---
echo -e "${yellow}-----------------------------------${NC}"
echo -e "${BGreen}          Install XRAY              ${NC}"
echo -e "${yellow}-----------------------------------${NC}"
sleep 1
clear
wget -q https://raw.githubusercontent.com/givpn/AutoScriptXray/master/xray/ins-xray.sh -O ins-xray.sh
chmod +x ins-xray.sh
./ins-xray.sh

wget -q https://raw.githubusercontent.com/givpn/AutoScriptXray/master/sshws/insshws.sh -O insshws.sh
chmod +x insshws.sh
./insshws.sh
clear

# --- Setup profile untuk auto menu ---
cat > /root/.profile << 'EOF'
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
menu
EOF

chmod 644 /root/.profile

# --- Bersihkan file log lama jika ada ---
rm -f /root/log-install.txt /etc/afak.conf
touch /etc/log-create-ssh.log
touch /etc/log-create-vmess.log
touch /etc/log-create-vless.log
touch /etc/log-create-trojan.log
touch /etc/log-create-shadowsocks.log

# --- Bersihkan history shell ---
history -c

# --- Simpan versi server ---
serverV=$(curl -sS https://raw.githubusercontent.com/givpn/AutoScriptXray/master/menu/versi)
echo "$serverV" > /opt/.ver

# --- Simpan IP VPS ---
curl -sS ipv4.icanhazip.com > /etc/myipvps

# --- Tampilkan banner dan info port ---
cat << EOF | tee -a /root/log-install.txt

==================================================================
      ___                                    ___         ___      
     /  /\        ___           ___         /  /\       /__/\     
    /  /:/_      /  /\         /__/\       /  /::\      \  \:\    
   /  /:/ /\    /  /:/         \  \:\     /  /:/\:\      \  \:\   
  /  /:/_/::\  /__/::\          \  \:\   /  /:/~/:/  _____\__\:\  
 /__/:/__\/\:\ \__\/\:\__   ___  \__\:\ /__/:/ /:/  /__/::::::::\ 
 \  \:\ /~~/:/    \  \:\/\ /__/\ |  |:| \  \:\/:/   \  \:\~~\~~\/ 
  \  \:\  /:/      \__\::/ \  \:\|  |:|  \  \::/     \  \:\  ~~~  
   \  \:\/:/       /__/:/   \  \:\__|:|   \  \:\      \  \:\      
    \  \::/        \__\/     \__\::::/     \  \:\      \  \:\     
     \__\/                       ~~~~       \__\/       \__\/ 1.0 
==================================================================

   >>> Service & Port
   - OpenSSH                  : 22
   - SSH Websocket            : 80
   - SSH SSL Websocket        : 443
   - Stunnel4                 : 222, 777
   - Dropbear                 : 109, 143
   - Badvpn                   : 7100-7900
   - Nginx                    : 81
   - Vmess WS TLS             : 443
   - Vless WS TLS             : 443
   - Trojan WS TLS            : 443
   - Shadowsocks WS TLS       : 443
   - Vmess WS none TLS        : 80
   - Vless WS none TLS        : 80
   - Trojan WS none TLS       : 80
   - Shadowsocks WS none TLS  : 80
   - Vmess gRPC               : 443
   - Vless gRPC               : 443
   - Trojan gRPC              : 443
   - Shadowsocks gRPC         : 443

=============================Contact==============================
---------------------------t.me/givpn-----------------------------
==================================================================

EOF

# --- Hapus file setup dan installer sementara ---
rm -f /root/setup.sh /root/ins-xray.sh /root/insshws.sh

# --- Setup systemd service ws-stunnel ---
echo -e "[ ${BGreen}INFO${NC} ] Setting up ws-stunnel systemd service..."

cat > /etc/systemd/system/ws-stunnel.service << EOF
[Unit]
Description=SSH Over Websocket
Documentation=https://google.com
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
Restart=on-failure
ExecStart=/usr/bin/python2 -O /usr/local/bin/ws-stunnel 443

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon dan aktifkan service
systemctl daemon-reload
systemctl enable ws-stunnel.service
systemctl restart ws-stunnel.service

# Cek status service
systemctl status ws-stunnel.service --no-pager

# --- Tampilkan waktu instalasi ---
secs_to_human $(( $(date +%s) - start_time )) | tee -a /root/log-install.txt

echo -e ""
echo -e "${yellow}Auto reboot in 10 seconds...${NC}"
sleep 10
reboot
