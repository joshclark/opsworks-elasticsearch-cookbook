file "#{node.elasticsearch[:nginx][:dir]}/sites-enabled/default" do
  action :delete
  force_unlink: true
  notifies :reload, 'service[nginx]'
end
