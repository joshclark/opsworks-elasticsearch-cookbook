file "#{node.elasticsearch[:nginx][:dir]}/sites-enabled/default" do
  action :delete
  force_unlink true
  manage_symlink_source true
  notifies :reload, 'service[nginx]'
end
