#
#
# XXX: this only supports 0 at the current time
default[:ec2][:raid_level] = 0
default[:ec2][:raid_read_ahead] = 512
default[:ec2][:raid_mount] = "/mnt"

# EC2 AMI tools

default[:ec2][:ami_tools_version] = "1.5.2"
default[:ec2][:ami_tools_url] = "http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools-1.5.2.zip"
default[:ec2][:ami_tools_sha] = "0c3c20491a3631c92d21c205354d2ac21a872ba502173aa5e3c79ad1d8a27ea2"
default[:ec2][:ami_tools_install_dir] = "/opt"

# Java DNS TTL
default[:ec2][:java_dns_ttl] = 0
