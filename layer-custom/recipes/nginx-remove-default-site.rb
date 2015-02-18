file "#{node.elasticsearch[:nginx][:dir]}/sites-enabled" do
  action :delete
  notifies :reload, 'service[nginx]'
end
