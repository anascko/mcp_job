#!/bin/bash
echo $HOSTNAME
echo $ENV   ENV
echo $DEP_NAME "DEP_NAME"
echo $SALT_FORMULAS_IRONIC_BRANCH "SALT_FORMULAS_IRONIC_BRANCH"


git clone https://github.com/jumpojoy/mcp-underlay-aio /root/mcp-underlay-aio
bash /root/mcp-underlay-aio/scripts/aio-setup.sh

cp /srv/salt/reclass/nodes/example-node.local.yml /srv/salt/reclass/nodes/$HOSTNAME.yml
sed -i s/example-node/$(hostname)/ /srv/salt/reclass/nodes/$HOSTNAME.yml
sed -i s/#MY_IP/$MY_IP/ /srv/salt/reclass/nodes/$HOSTNAME.yml

salt "$HOSTNAME" state.apply salt
salt-call saltutil.refresh_pillar

salt "$HOSTNAME" state.apply linux
#salt "$HOSTNAME" state.apply ntp,openssh

salt "$HOSTNAME" state.apply memcached
salt "$HOSTNAME" state.apply rabbitmq
salt "$HOSTNAME" state.apply mysql

salt "$HOSTNAME" state.apply keystone
salt "$HOSTNAME" state.apply apache
salt "$HOSTNAME" state.apply neutron
salt "$HOSTNAME" state.apply ironic
salt "$HOSTNAME" state.apply tftpd_hpa

apt-get install -y python-ironicclient

salt "$HOSTNAME" state.apply baremetal_simulator

source /root/keystonercv3
openstack baremetal node list
local_ip=$(ip route get 4.2.2.1 | awk '/via/ {print $7}')
cirros_md5=$(md5sum /var/www/httproot/cirros-0.3.5-x86_64-disk.img | awk '{print $1}')
port_id=$(openstack baremetal port list --node n1 -f value -c UUID)
port_address=$(openstack baremetal port list --node n1 -f value -c Address)
vif_id=$(openstack port create --mac-address $port_address --network baremetal-flat-network n1-port -f value -c id)
openstack baremetal port set $port_id --extra vif_port_id=$vif_id

if [[ `ip netns list | wc -l` == "0"]]; then
systemctl restart neutron-dhcp-agent
fi

sleep 15
ip netns list

openstack baremetal node set n1 --instance-info image_checksum=$cirros_md5
openstack baremetal node set n1 --instance-info image_source=http://$local_ip/cirros-0.3.5-x86_64-disk.img
openstack baremetal node deploy n1


ironic node-list
