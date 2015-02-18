#
# Author:: Mike Heffner (<mike@librato.com>)
# Cookbook Name:: ec2
# Recipe:: raid_ephemeral
#
# Copyright 2011, Librato, Inc.
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

#
# Sets up a RAID device on the ephemeral instance store drives.
# Modeled after:
# https://github.com/riptano/CassandraClusterAMI/blob/master/.startcassandra.py
#

# Remove EC2 default /mnt from fstab
ruby_block "remove_mnt_from_fstab" do
  block do
    lines = File.readlines("/etc/fstab")
    File.open("/etc/fstab", "w") do |f|
      lines.each do |l|
        f << l unless l.include?("/mnt")
      end
    end
  end
  only_if {File.read("/etc/fstab").include?("/mnt")}
end

ruby_block "format_drives" do
  block do
    devices = %x{ls /dev/sd* /dev/xvd* 2> /dev/null}.split("\n").
      delete_if{|d| ["/dev/sda", "/dev/sda1", "/dev/xvda", "/dev/xvda1"].include?(d)}

    Chef::Log.info("Formatting drives #{devices.join(",")}")

    # Create one giant Linux partition per drive
    fmtcmd=",,L\n"
    devices.each do |dev|
      system("umount #{dev}")

      # Clear "invalid flag 0x0000 of partition table 4" by issuing a
      # write
      IO.popen("fdisk -c -u #{dev}", "w") do |f|
        f.puts "w\n"
      end

      IO.popen("sfdisk -L --no-reread #{dev}", "w") do |f|
        f.puts fmtcmd
      end
    end
  end

  # XXX: fix this
  not_if {File.exist?("/dev/sdc1") || File.exist?("/dev/xvdc1")}
end

package "mdadm"
package "xfsprogs"

ruby_block "create_raid" do
  block do
    # Get partitions
    parts = %x{ls /dev/sd*[0-9] /dev/xvd*[0-9] 2> /dev/null}.split("\n").
      delete_if{|d| ["/dev/sda1", "/dev/xvda1"].include?(d)}
    parts = parts.sort

    Chef::Log.info("Partitions to raid: #{parts.join(",")}")

    # Unmount
    parts.each do |part|
      system("umount #{part}")
    end

    # Wait for devices to settle.
    system("sleep 3")

    args = ['--create /dev/md0',
            '--chunk=256',
            "--level #{node[:ec2][:raid_level]}"]

    # Smaller nodes only have one RAID device
    if parts.length == 1
      args << '--force'
    end

    args << "--raid-devices #{parts.length}"

    #
    # We try up to 3 times to make this raid array.
    #
    try = 1
    tries = 3
    failed_create = false
    begin
      failed_create = false

      r = system("mdadm #{args.join(' ')} #{parts.join(' ')}")
      puts "Failed to create raid" unless r

      # Scan
      File.open("/etc/mdadm/mdadm.conf", "w") do |f|
        f << "DEVICE #{parts.join(' ')}\n"
      end
      system("sleep 5")

      # Write out the ARRAY details to mdadm.conf. Only use the
      # UUID to increase chance it will be found after a restart.
      #
      uuid = %x{mdadm --detail /dev/md0 | grep UUID}.chomp
      if uuid.length > 0
        uuid = uuid.split(" ").last
        File.open("/etc/mdadm/mdadm.conf", "a") do |f|
          f << "ARRAY /dev/md0 UUID=#{uuid}\n"
        end
        system("sleep 5")
      else
        puts "Failed to initialize raid device"
      end

      # Put the raid device into the ramfs
      r = system("update-initramfs -u")
      puts "Failed to update the initramfs" unless r

      r = system("blockdev --setra #{node[:ec2][:raid_read_ahead]} /dev/md0")
      puts "Failed to set read-ahead" unless r
      system("sleep 10")

      r = system("mkfs.xfs -f -q /dev/md0")
      unless r
        puts "Failed to format raid device"
        system("mdadm --stop /dev/md0")
        system("mdadm --zero-superblock #{parts.first}")

        try += 1
        failed_create = true
      end
    end while failed_create && try <= tries

    exit 1 if failed_create
  end

  not_if {File.exist?("/dev/md0")}
end

ruby_block "add_raid_device_to_fstab" do
  block do
    File.open("/etc/fstab", "a") do |f|
      fstab = ['/dev/md0', node[:ec2][:raid_mount], 'xfs',
               'defaults,nobootwait,noatime', '0', '0']
      f << "#{fstab.join("\t")}\n"
    end
  end

  not_if {File.read("/etc/fstab").include?(node[:ec2][:raid_mount])}
end

ruby_block "mount_raid" do
  block do
    system("mkdir -p #{node[:ec2][:raid_mount]}")
    r = system("mount #{node[:ec2][:raid_mount]}")
    exit 1 unless r
  end

  not_if {File.read("/proc/mounts").include?(node[:ec2][:raid_mount])}
end

# The daily mdadm scan will not run unless it knows where to send the results
ruby_block "add_email_address_to_mdadm_config" do
  block do
    File.open("/etc/mdadm/mdadm.conf", "a") do |f|
      f << "MAILADDR root\n"
    end
  end

  not_if {File.read("/etc/mdadm/mdadm.conf").include?("MAILADDR")}
end
