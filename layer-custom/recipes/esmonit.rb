config_dir = "/etc/monit.d"

directory config_dir do
  owner node[:user][:username]
  group node[:user][:username]
  recursive true
end

template "#{config_dir}/elasticsearch-monit.conf" do
  source "elasticsearch.monitrc.conf.erb"
  mode 0440
  owner "root"
  group "root"
end
