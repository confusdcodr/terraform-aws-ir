#!/bin/bash

# configure path
export PATH=$PATH:/usr/local/bin:/usr/sbin:/root/.local/bin:/.local/bin
echo 'export PATH=/root/.local/bin:/usr/sbin:/.local/bin:$PATH' >> /home/ec2-user/.profile

BIN_DIR=/home/ec2-user/.local/bin
mkdir -p $BIN_DIR

# install dependencies
yum update -y
yum install nmap git python python2-pip python-argparse gcc gcc-c++ glib2-devel subversion -y
yum install cmake openssl-devel libX11-devel libXi-devel libXtst-devel libXinerama-devel -y
pip install paramiko

# get target ip addresses
BasicLinuxTarget_PrivateIp=$(aws ec2 describe-instances --region ${target_region} --filters "Name=tag:Type,Values=App Server Linux" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PrivateIpAddress" | tr -d \") 
BasicWindowsTarget_PrivateIp=$(aws ec2 describe-instances --region ${target_region} --filters "Name=tag:Type,Values=App Server Windows" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].PrivateIpAddress" | tr -d \")
export privateIP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`

BasicLinuxTarget=$(aws ec2 describe-instances --region ${target_region} --filters "Name=tag:Type,Values=App Server Linux" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" | tr -d \") 
BasicWindowsTarget=$(aws ec2 describe-instances --region ${target_region} --filters "Name=tag:Type,Values=App Server Windows" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" | tr -d \")

svn checkout https://github.com/confusdcodr/terraform-guardduty-demo/trunk/scripts /home/ec2-user/scripts
svn checkout https://github.com/confusdcodr/terraform-guardduty-demo/trunk/artifacts /home/ec2-user/artifacts

# generate ssh keys
KEY_PATH="/home/ec2-user/compromised_keys"
mv $KEY_PATH/never_used_sample_key.foo $KEY_PATH/compromised.pem
FILE="$KEY_PATH/compromised.pem"
for FILE in {1..20}; do cp $KEY_PATH/compromised.pem $KEY_PATH/compromised$FILE.pem; done
echo "Compromised ssh keys generated"

# get IP addresses of targets
IP_SCRIPT_PATH=/home/ec2-user/scripts/localIps.sh
echo "BASIC_LINUX_TARGET=$BasicLinuxTarget_PrivateIp" >> $IP_SCRIPT_PATH
echo -n "BASIC_WINDOWS_TARGET=$BasicWindowsTarget_PrivateIp" >> $IP_SCRIPT_PATH
echo -n "RED_TEAM_IP=$(wget -q -O - http://169.254.169.254/latest/meta-data/local-ipv4)" >> $IP_SCRIPT_PATH
echo "IP addresses of targets captured"

# get instance-ids of targets
echo -n "BASIC_LINUX_INSTANCE=$BasicLinuxTarget" >> $IP_SCRIPT_PATH
echo -n "BASIC_WINDOWS_INSTANCE=$BasicWindowsTarget" >> $IP_SCRIPT_PATH
echo -n "RED_TEAM_INSTANCE=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)" >> $IP_SCRIPT_PATH
echo "Instance IDs of targets captured"

# install hydra
mkdir $BIN_DIR/thc-hydra
git clone -b "8.3" https://github.com/vanhauser-thc/thc-hydra $BIN_DIR/thc-hydra
cd $BIN_DIR/thc-hydra
$BIN_DIR/thc-hydra/configure
make
make install
echo "Hydra installed"

# install FreeRDP
mkdir $BIN_DIR/FreeRDP
git clone git://github.com/FreeRDP/FreeRDP.git $BIN_DIR/FreeRDP
cd $BIN_DIR/FreeRDP
cmake -DCMAKE_BUILD_TYPE=Debug -DWITH_SSE2=ON .
make install
echo '/usr/local/lib/freerdp' >> /etc/ld.so.conf.d/freerdp.conf
ln -s /usr/local/bin/xfreerdp /usr/bin/xfreerdp
echo "FreeRDP installed"

# install crowbar
sudo yum install -y epel-release
sudo yum install -y python36 python36-pip
cd /home/ec2-user
git clone https://github.com/galkan/crowbar $BIN_DIR/crowbar
chown -R ec2-user: /home/ec2-user

chmod +x /home/ec2-user/scripts/*.sh
chmod +x $BIN_DIR/crowbar/crowbar.py
echo "Crowbar installed"