#!/bin/bash

set -eux

mkdir -p $HOME/.undercloud-live
LOG=$HOME/.undercloud-live/undercloud.log

exec > >(tee -a $LOG)
exec 2>&1

echo ##########################################################
echo Starting run of undercloud.sh at `date`

PIP_DOWNLOAD_CACHE=${PIP_DOWNLOAD_CACHE:-""}

if [ -z "$PIP_DOWNLOAD_CACHE" ]; then
    mkdir -p $HOME/.cache/pip
    PIP_DOWNLOAD_CACHE=$HOME/.cache/pip
    export PIP_DOWNLOAD_CACHE
fi

# /var/lock/subsys not always created in F19, and it is needed by openvswitch.
# See: https://bugzilla.redhat.com/show_bug.cgi?id=986667
sudo mkdir -p /var/lock/subsys

$(dirname $0)/install-control.sh

# Switch over to use iptables instead of firewalld
# This is needed by os-refresh-config
sudo systemctl stop firewalld
sudo systemctl mask firewalld
sudo touch /etc/sysconfig/iptables
sudo systemctl enable iptables
sudo systemctl enable ip6tables
sudo systemctl start iptables
sudo systemctl start ip6tables

# Perform substitution of static configuration
source /etc/sysconfig/undercloud-live-config

sed -i "s/192.0.2.1/$UNDERCLOUD_CONTROL_IP/g" /var/lib/heat-cfntools/cfn-init-data
sed -i "s/eth1/$LEAF_PUBLIC_INTERFACE/g" /var/lib/heat-cfntools/cfn-init-data

# starts all services and run os-refresh-config
sudo systemctl daemon-reload
UCL_USER=$USER sudo -E os-collect-config --one-time --force

echo "undercloud.sh run complete."
