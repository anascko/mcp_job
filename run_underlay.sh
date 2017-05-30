#!/bin/bash
set -ex

HELPERS_DIR=$(dirname "$0")/../

ENV_NAME=${DEP_NAME}

LIBVIRT_SOCKET="--connect=qemu:///system"
LOCK_FILE='/home/jenkins/loks/devstack-generic.lock'

source /etc/profile.d/devstack-generic.sh

export LC_ALL=C

echo $ENV_NAME |grep -q "_" && (echo "Can't use char "_" in the hostname"; exit 1)

SRC_VM="devstack-generic-ubuntu-xenial"

source ./devstack-helpers.sh


function waitForSSH {
  local server_ip="$1"
  local BOOT_TIMEOUT=180
  local CHECK_TIMEOUT=30
  local cur_time=0

  LOG_FINISHED="1"
  while [[ "${LOG_FINISHED}" == "1" ]]; do
    sleep $CHECK_TIMEOUT
    time=$(($cur_time+$CHECK_TIMEOUT))
    LOG_FINISHED=$(nc -w 2 $server_ip 22; echo $?)
    if [ ${cur_time} -ge $BOOT_TIMEOUT ]; then
      echo "Can't get to VM in $BOOT_TIMEOUT sec"/root/aio-vm.sh
      exit 1
    fi
  done
}

function main {

  vm_clone ${SRC_VM} ${ENV_NAME}
  local vm_mac=$(get_vm_mac $ENV_NAME $DEVSTACK_NET_NAME)

  virsh start ${ENV_NAME}
  sleep 15 #

  local env_ip=$(get_ip_for_mac "$vm_mac")

  export MY_IP=$env_ip
  export HOSTNAME=$(ENV_NAME).local
  #Change hostname
  execute_ssh_cmd ${env_ip} root r00tme "echo $(ENV_NAME).local > /etc/hostname; \
  sed -i "s/devstack-generic/$ENV_NAME.local/g" /etc/hosts; \
  hostname $ENV_NAME.local; (sleep 1; reboot) &"

  sleep 15

  waitForSSH "${env_ip}"

  bind_resources $LOCK_FILE $ENV_NAME $env_ip

  # Copy run underlay to ironic
  local scp_opts='-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no'
  sshpass -p 'r00tme'  scp $scp_opts  aio-vm.sh root@${env_ip}://root/aio-vm.sh
  
  execute_ssh_cmd ${env_ip} root r00tme  "sh /root/ais-vm.sh"

  echo "Done"

}

main

