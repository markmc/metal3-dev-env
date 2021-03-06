#!/usr/bin/env bash
set -x

source lib/logging.sh
source lib/common.sh

# Kill and remove the running ironic containers
for name in ironic ironic-inspector dnsmasq httpd mariadb; do
    sudo ${CONTAINER_RUNTIME} ps | grep -w "$name$" && sudo ${CONTAINER_RUNTIME} kill $name
    sudo ${CONTAINER_RUNTIME} ps --all | grep -w "$name$" && sudo ${CONTAINER_RUNTIME} rm $name -f
done

# Remove existing pod
if [[ "${CONTAINER_RUNTIME}" == "podman" ]]; then
  if  sudo ${CONTAINER_RUNTIME} pod exists ironic-pod ; then
      sudo ${CONTAINER_RUNTIME} pod rm ironic-pod -f
  fi
fi

ANSIBLE_FORCE_COLOR=true ansible-playbook \
    -e "working_dir=$WORKING_DIR" \
    -e "num_masters=$NUM_MASTERS" \
    -e "num_workers=$NUM_WORKERS" \
    -e "extradisks=$VM_EXTRADISKS" \
    -e "virthost=$HOSTNAME" \
    -e "manage_baremetal=$MANAGE_BR_BRIDGE" \
    -i vm-setup/inventory.ini \
    -b -vvv vm-setup/teardown-playbook.yml

sudo rm -rf /etc/NetworkManager/conf.d/dnsmasq.conf
# There was a bug in this file, it may need to be recreated.
if [ "$MANAGE_PRO_BRIDGE" == "y" ]; then
    sudo ifdown provisioning || true
    sudo rm -f /etc/sysconfig/network-scripts/ifcfg-provisioning || true
fi
# Leaving this around causes issues when the host is rebooted
if [ "$MANAGE_BR_BRIDGE" == "y" ]; then
    sudo ifdown baremetal || true
    sudo rm -f /etc/sysconfig/network-scripts/ifcfg-baremetal || true
fi
