#
# Cookbook Name:: kafka
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'apt'
include_recipe 'kafka::java'

version_tag = "kafka_#{node['kafka']['scala_version']}-#{node['kafka']['version']}"
download_url = ::File.join(node["kafka"]["mirror"], "#{node['kafka']['version']}/#{version_tag}.tgz")
download_path = ::File.join(Chef::Config[:file_cache_path], "#{version_tag}.tgz")

%w{
  curl
  vim
}.each do |v|
  package v do
    action :install
  end
end

log 'version check' do
  message "Version tag is: #{download_path}"
  level :warn
end

user "kafka" do
  comment "kafka"
  system true
  shell "/bin/false"
end

directory "#{node['kafka']['install_dir']}/logs/kafka-log-0" do
  recursive true
  mode '0755'
end

remote_file download_path do
  source download_url
  backup false
  not_if { ::File.exist?(::File.join(node["kafka"]["install_dir"], version_tag)) }
end

execute "unzip kafka source" do
  command "tar -zxvf #{download_path} -C #{node['kafka']['install_dir']}"
  not_if { ::File.exist?(::File.join(node["kafka"]["install_dir"], version_tag)) }
end

template "#{node['kafka']['install_dir']}/#{version_tag}/config/server.properties" do
  source "properties/server.properties.erb"
  mode "0644"
end

directory node["kafka"]["install_dir"] do
  recursive true
  owner 'kafka'
  mode '0755'
end

execute "chown-kafka-dirs" do
  command "chown -R kafka #{node['kafka']['install_dir']}"
  user "root"
  action :run
end

#TODO -- need to add a "not_if" statement to detect if it's already running
script "kafka-init" do
  interpreter "bash"
  cwd "#{node['kafka']['install_dir']}/#{version_tag}"
  code <<-EOH
    sudo bin/zookeeper-server-start.sh config/zookeeper.properties &
	sudo bin/kafka-server-start.sh config/server.properties &
  EOH
end
