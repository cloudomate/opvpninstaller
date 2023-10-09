#!/bin/bash

base_dir="/etc/openvpn/easy-rsa"
output_file="client1.ovpn"
base_config="/home/ysj/coderepo/g42cloud/test/client-configs/base.conf"
port="1194"

create_server()
{
terraform init
terraform apply -auto-approve
}

create_client_config()
{
EIP=$(terraform output -raw eip) 
scp -i ~/.ssh/onkey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ./openvpnas.sh root@$EIP:~/
ssh -i ~/.ssh/onkey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$EIP bash pkill apt
ssh -i ~/.ssh/onkey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$EIP bash openvpnas.sh
config=$(ssh -i ~/.ssh/onkey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$EIP cat /etc/openvpn/easy-rsa/client1.ovpn)
cat /home/ysj/coderepo/g42cloud/test/client-configs/base.conf > $output_file
echo "
remote $EIP $port" >> $output_file

echo "$config" >> $output_file

}

create_server
install_config