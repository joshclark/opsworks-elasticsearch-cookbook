#
# based on https://gist.github.com/joemiller/6049831
#

module AwsHelper

  def self.findEphemeralDrives

    devices =  %x{ls /dev/sd* /dev/xvd* 2> /dev/null}.split("\n")


    root_drive=`df -h | grep -v grep | awk 'NR==2{print $1}'`.chomp

    if root_drive == "/dev/xvda1"
      Chef::Log.info "Detected 'xvd' drive naming scheme (root: #{root_drive})"
      driveScheme = 'xvd'
    else
      Chef::Log.info "Detected 'sd' drive naming scheme (root: #{root_drive})"
      driveScheme = 'sd'
    end

    metadataBaseUrl="http://169.254.169.254/2012-01-12"
    drives = Array.new

    ephemerals = %x{curl --silent #{metadataBaseUrl}/meta-data/block-device-mapping/ | grep ephemeral}.split("\n")

    ephemerals.each do |e|
      Chef::Log.info "Probing #{e}..."
      deviceName = `curl --silent #{metadataBaseUrl}/meta-data/block-device-mapping/#{e}`


      # might have to conver 'sdb' => 'xvdb'
      deviceName.gsub!("sd", driveScheme)
      deviceName = "/dev/#{deviceName}"

      # test that the device actually exists since you can request more ephemeral drives than are available
      # for an instance type and the meta-data API will happily tell you it exists when it really does not.
      if File.stat(deviceName).blockdev?
        Chef::Log.info "Detected ephemeral disk: #{deviceName}"
        drives << deviceName
      else
        Chef::Log.info "Ephemeral disk #{e}, #{deviceName} is not present. Skipping."
      end

      if drives.length == 0
        Chef::Log.info "No ephemeral drives detected.  Nothing to do."
        return
      end
    end

    drives
  end

end
