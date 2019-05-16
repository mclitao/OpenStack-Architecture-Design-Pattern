#!/usr/bin/env bash
if [ $PWD != $HOME ] ; then echo "USAGE: $0 Must be run from $HOME"; exit 1 ; fi

stack_name=adpcloud

time openstack overcloud deploy --verbose \
 --templates /usr/share/openstack-tripleo-heat-templates \
 -e /home/stack/templates/global-config.yaml \
 -e /home/stack/templates/cloud-names.yaml \
 -e /home/stack/templates/enable-tls.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/tls-endpoints-public-ip.yaml \
 -e /home/stack/templates/inject-trust-anchor.yaml \
 -e /home/stack/templates/scheduler_hints_env.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/docker.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/docker-ha.yaml  \
 -e /home/stack/templates/overcloud_images.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/net-bond-with-vlans.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/network-management.yaml  \
 -e /home/stack/templates/network-environment.yaml \
 -e /home/stack/templates/ips-from-pool-all.yaml \
 -e /home/stack/templates/ceph-storage-environment.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
 --timeout 210 \
 --ntp-server ntp.nict.jp \
 --log-file ./overcloud_deploy.log \
 --stack $stack_name

# -e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml  \
# -e /usr/share/openstack-tripleo-heat-templates/environments/disable-telemetry.yaml  \
# -e /usr/share/openstack-tripleo-heat-templates/ci/environments/ovb-ha.yaml  \
