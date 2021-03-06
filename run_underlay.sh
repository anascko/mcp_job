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
  sleep 25
  #test wait 

  local env_ip=$(get_ip_for_mac "$vm_mac")

  echo export RECLASS_SYSTEM_BRANCH=$RECLASS_SYSTEM_BRANCH >> vars.conf
  echo export SALT_FORMULAS_IRONIC_BRANCH=$SALT_FORMULAS_IRONIC_BRANCH >> vars.conf
  echo export SALT_FORMULAS_NEUTRON_BRANCH=$SALT_FORMULAS_NEUTRON_BRANCH >> vars.conf
  echo export HOSTNAME=$ENV_NAME >> vars.conf
  echo export MY_IP=$env_ip >> vars.conf

  #Change hostname
  execute_ssh_cmd ${env_ip} root r00tme "echo $ENV_NAME > /etc/hostname; \
  sed -i "s/devstack-generic/$ENV_NAME/g" /etc/hosts; \
  hostname $ENV_NAME; (sleep 1; reboot) &"

  sleep 15

  waitForSSH "${env_ip}"

  bind_resources $LOCK_FILE $ENV_NAME $env_ip

  # Copy run underlay to ironic
  local scp_opts='-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no'
  sshpass -p 'r00tme'  scp $scp_opts  aio-vm.sh  vars.conf root@${env_ip}:/root/
  
  execute_ssh_cmd ${env_ip} root r00tme  "source /root/vars.conf; sh /root/aio-vm.sh"

  echo "Done"

}

main

