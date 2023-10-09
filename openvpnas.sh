#!/bin/bash

# script to install OpenVPN Access Server on Ubuntu 20.04 LTS OpenVPN 2.4.7

base_dir="/etc/openvpn/easy-rsa"

# Update and upgrade system
apt-get update -y

# Install OpenVPN and Easy-RSA
apt-get install openvpn easy-rsa -y

# Copy Easy-RSA files to OpenVPN directory
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa

# Define variables for CA Certificate
echo '
set_var EASYRSA_REQ_COUNTRY    "IN"
set_var EASYRSA_REQ_PROVINCE   "New Delhi"
set_var EASYRSA_REQ_CITY       "New Delhi"
set_var EASYRSA_REQ_ORG        "iamysj"
set_var EASYRSA_REQ_EMAIL      "admin@iamysj.com"
set_var EASYRSA_REQ_OU         "Community"
set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"
' > vars

# Initialize the PKI (Public Key Infrastructure) and create CA (Certificate Authority)
printf "yes\n" | ./easyrsa init-pki
printf "password\n" | ./easyrsa build-ca nopass

# Generate server key, signed by CA
printf "password\n" | ./easyrsa build-server-full server nopass

# Generate HMAC signature
openvpn --genkey --secret pki/private/ta.key

# Generate client key, signed by CA
printf "password\n" | ./easyrsa build-client-full client1 nopass

# Copy the necessary files to the OpenVPN directory
cp $base_dir/pki/private/{server.key,ta.key} /etc/openvpn
cp $base_dir/pki/ca.crt /etc/openvpn
cp $base_dir/pki/issued/server.crt /etc/openvpn


# # create server.conf
cat << EOF > /etc/openvpn/server.conf
;local 10.8.0.1
port 1194
proto udp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh none
tls-crypt /etc/openvpn/ta.key
cipher AES-256-GCM
auth SHA256
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
verb 3
EOF


# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' | tee -a /etc/sysctl.conf
sysctl -p

# Set up NAT for internet access
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

# Save iptables rules
export DEBIAN_FRONTEND=noninteractive

# echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
# echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections

printf "y\n" | apt-get -y install iptables-persistent
printf "y\n" | netfilter-persistent save

# Start and enable OpenVPN service
systemctl start openvpn@server
systemctl enable openvpn@server
systemctl restart openvpn@server

cat <(echo -e '<ca>') \
    $base_dir/pki/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    $base_dir/pki/issued/client1.crt \
    <(echo -e '</cert>\n<key>') \
    $base_dir/pki/private/client1.key \
    <(echo -e '</key>\n<tls-crypt>') \
    $base_dir/pki/private/ta.key \
    <(echo -e '</tls-crypt>') \
    > $base_dir/client1.ovpn