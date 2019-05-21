#!/usr/bin/env bash

if [ $PWD != $HOME ] ; then echo "USAGE: $0 Must be run from $HOME"; exit 1 ; fi

source ~/stackrc

# Generate container image list definition.
openstack overcloud container image prepare \
 --namespace=registry.access.redhat.com/rhosp13 \
 --push-destination=192.168.110.1:8787 \
 --prefix=openstack- \
 --tag-from-label {version}-{release}  \
 --output-env-file=/home/stack/templates/overcloud_images.yaml \
 --output-images-file /home/stack/local_registry_images.yaml \
 -e /home/stack/templates/roles_data.yaml \
 -e /home/stack/templates/global-config.yaml \
 -e /home/stack/templates/cloud-names.yaml \
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
 -e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-mds.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/manila-cephfsganesha-config.yaml \
 -e /usr/share/openstack-tripleo-heat-templates/environments/cinder-backup.yaml 

# Pull and Push container images to local registry .
sudo openstack overcloud container image upload \
--config-file /home/stack/local_registry_images.yaml --verbose

