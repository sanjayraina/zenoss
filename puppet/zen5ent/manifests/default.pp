include stdlib
# Create mount points for the file systems
#
exec { '/var/lib/docker':
  command => "mkdir -p /var/lib/docker",
  path => "/bin",
  creates => "/var/lib/docker",
}
exec { '/opt/serviced/var/volumes':
  command => "mkdir -p /opt/serviced/var/volumes",
  path => "/bin",
  creates => "/opt/serviced/var/volumes",
}

# Create the file systems
#
exec { "make-ext4":
  command => "mkfs.ext4 -F /dev/sdb1",
  path => "/sbin",
  unless => '/bin/mount | /bin/grep "/var/lib/docker"',
  require => Exec["/var/lib/docker"],
}
package { "btrfs-tools":
  ensure => installed,
  require => Exec['/opt/serviced/var/volumes'],
}
exec { "make-btrfs":
  command => "mkfs.btrfs --nodiscard /dev/sdc1",
  path => "/sbin",
  unless => '/bin/mount | /bin/grep "/opt/serviced/var/volumes"',
  require => Package["btrfs-tools"],
}

# Mount file systems
#
mount { "/var/lib/docker":
  device => "/dev/sdb1",
  fstype => "ext4",
  ensure => "mounted",
  options => "defaults",
  atboot => "true",
  require => Exec["make-ext4"],
}
mount { "/opt/serviced/var/volumes":
  device => "/dev/sdc1",
  fstype => "btrfs",
  ensure => "mounted",
  options => "rw,noatime,nodatacow,skip_balance",
  atboot => "true",
  require => Exec["make-btrfs"],
}

# disable firewall
#
exec { 'disable-firewall':
    command => "ufw disable",
    path => "/usr/sbin",
}

# Install docker
#
exec { "docker-repo":
  command => 'echo "deb http://get.docker.com/ubuntu docker main" > /etc/apt/sources.list.d/docker.list',
  path => "/bin",
  require => Mount["/var/lib/docker"],
}

# Install Docker public key
exec { "docker-key":
  command => "apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9; apt-get update",
  path => "/usr/bin/:/bin/",
  require => Exec["docker-repo"],
}

package {"lxc-docker-1.5.0":
  ensure => installed,
  require => Exec["docker-key"], 
}

# Add Docker Opts
#
exec { "add-docker-opts":
  command => "echo 'DOCKER_OPTS=\"-s devicemapper --dns=172.17.42.1\"' >> /etc/default/docker",
  path => "/bin",
  require => Package["lxc-docker-1.5.0"],
}

# Restart docker
service { 'docker':
    ensure => running,
    enable => true,
    require => Exec["add-docker-opts"],
}

# Install ZenOSS OpenPGP public key
exec { "zenoss-key":
  command => "apt-key adv --keyserver keys.gnupg.net --recv-keys AA5A1AD7",
  path => "/usr/bin/:/bin/",
  require => Service["docker"],
}

# Add ZenOSS repository
#
exec { "zenoss-repo":
  command => 'echo "deb [ arch=amd64 ] http://get.zenoss.io/apt/ubuntu trusty universe" > /etc/apt/sources.list.d/zenoss.list',
  path => "/bin",
  require => Exec["zenoss-key"],
}

#  Update repo
exec { "update-repo":
  command => "apt-get update",
  path => "/usr/bin",
  require => Exec["zenoss-repo"],
}

# Install ntp
#
package { "ntp":
  ensure => installed,
  require => Exec["update-repo"], 
}

#Install Zenoss core service template
#
package { "zenoss-resmgr-service":
  ensure => installed,
  require => Exec["update-repo"], 
}

# Change volume type
# /etc/default/serviced
file_line { "serviced":
  path => "/etc/default/serviced",
  line => "SERVICED_FS_TYPE=btrfs",
  require => Package["zenoss-resmgr-service"],
}

# Start serviced
service { 'serviced':
    ensure => running,
    enable => true,
    require => Package["zenoss-resmgr-service"],
}
