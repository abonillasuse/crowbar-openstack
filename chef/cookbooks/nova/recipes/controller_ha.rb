# Copyright 2014 SUSE
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

unless node[:nova][:ha][:enabled]
  log "HA support for nova is disabled"
  return
end

log "HA support for nova is enabled"

cluster_admin_ip = CrowbarPacemakerHelper.cluster_vip(node, "admin")

haproxy_loadbalancer "nova-api" do
  address "0.0.0.0"
  port node[:nova][:ports][:api]
  use_ssl node[:nova][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "nova", "nova-controller", "api")
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "nova-api-ec2" do
  address "0.0.0.0"
  port node[:nova][:ports][:api_ec2]
  use_ssl node[:nova][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "nova", "nova-controller", "api_ec2")
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "nova-metadata" do
  address cluster_admin_ip
  port node[:nova][:ports][:metadata]
  use_ssl node[:nova][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "nova", "nova-controller", "metadata")
  action :nothing
end.run_action(:create)

if node[:nova][:use_novnc]
  haproxy_loadbalancer "nova-novncproxy" do
    address "0.0.0.0"
    port node[:nova][:ports][:novncproxy]
    use_ssl node[:nova][:novnc][:ssl][:enabled]
    servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "nova", "nova-controller", "novncproxy")
    action :nothing
  end.run_action(:create)
else
  haproxy_loadbalancer "nova-xvpvncproxy" do
    address "0.0.0.0"
    port node[:nova][:ports][:xvpvncproxy]
    use_ssl false
    servers CrowbarPacemakerHelper.haproxy_servers_for_service(node, "nova", "nova-controller", "xvpvncproxy")
    action :nothing
  end.run_action(:create)
end
if node[:nova][:use_serial]
  haproxy_loadbalancer "nova-serialproxy" do
    address "0.0.0.0"
    port node[:nova][:ports][:serialproxy]
    use_ssl node[:nova][:serial][:ssl][:enabled]
    servers CrowbarPacemakerHelper.haproxy_servers_for_service(node,
      "nova",
      "nova-controller",
      "serialproxy")
    action :nothing
  end.run_action(:create)
end
# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-nova_before_ha"

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-nova_ha_resources"

transaction_objects = []
primitives = []

services = %w(api cert conductor consoleauth scheduler)
if node[:nova][:use_novnc]
  services << "novncproxy"
else
  services << "xvpvncproxy"
end
if node[:nova][:use_serial]
  services << "serialproxy"
end

services.each do |service|
  primitive_name = "nova-#{service}"
  if %w(rhel suse).include?(node[:platform_family])
    primitive_ra = "service:openstack-nova-#{service}"
  else
    primitive_ra = "service:nova-#{service}"
  end

  pacemaker_primitive primitive_name do
    agent primitive_ra
    op node[:nova][:ha][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end

  primitives << primitive_name
  transaction_objects << "pacemaker_primitive[#{primitive_name}]"
end

group_name = "g-nova-controller"
pacemaker_group group_name do
  members primitives
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_group[#{group_name}]"

clone_name = "cl-#{group_name}"
pacemaker_clone clone_name do
  rsc group_name
  meta ({ "clone-max" => CrowbarPacemakerHelper.num_corosync_nodes(node) })
  action :update
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end
transaction_objects << "pacemaker_clone[#{clone_name}]"

location_name = openstack_pacemaker_controller_only_location_for clone_name
transaction_objects << "pacemaker_location[#{location_name}]"

pacemaker_transaction "nova controller" do
  cib_objects transaction_objects
  # note that this will also automatically start the resources
  action :commit_new
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_order_only_existing "o-#{clone_name}" do
  ordering ["postgresql", "rabbitmq", "cl-keystone", clone_name]
  score "Optional"
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

crowbar_pacemaker_sync_mark "create-nova_ha_resources"
