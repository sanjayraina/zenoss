#  Oracle Java
#
package { "java-1.6.0-openjdk":
    ensure => absent,
}

package { "wget":
    ensure => installed,
    require => Package['java-1.6.0-openjdk'],
}

## Oracle JDK 1.6 update 33

$jdk_url = "http://javadl.sun.com/webapps/download/AutoDL?BundleId=47146"
$jdk_file = "jre-6u30-linux-x64-rpm.bin"

exec { "download-jdk":
        command => "/usr/bin/wget -O /var/tmp/$jdk_file $jdk_url",
        creates => "/var/tmp/$jdk_file",
        require => Package["wget"],
}

file { "/var/tmp/$jdk_file":
    mode => 655,
}

exec { "install-jdk":
          command => "/bin/sh /var/tmp/$jdk_file",
          creates => "/usr/bin/java",
          require => [ Exec["download-jdk"] ],
}

# ZenOSS repos
#
exec { "zenoss-repo":
        command => "/bin/rpm -Uvh http://deps.zenoss.com/yum/zenossdeps-4.2.x-1.el6.noarch.rpm",
        creates => "/etc/yum.repos.d/zenossdeps.repo",
}

exec { "yum-clean":
        command => "/usr/bin/yum clean all",
        require => [ Exec["zenoss-repo"] ],
}

exec { "zends":
    command => "/usr/bin/yum -y --nogpgcheck localinstall /vagrant/zends-5.5.37-1.r81755.el6.x86_64.rpm",
    creates => "/opt/zends",
    require => Exec["install-jdk"],
}

# Ensure ports are open
service { 'iptables':
    ensure => stopped,
	enable => false,
}
service { 'ip6tables':
    ensure => stopped,
	enable => false,
}

service { 'zends':
    ensure => running,
	enable => true,
    require => Exec['zends'],
}

exec { "zenoss-resmgr":
    command => "/usr/bin/yum -y --nogpgcheck localinstall /vagrant/zenoss_resmgr-4.2.5-2108.el6.x86_64.rpm",
    creates => "/opt/zenoss/zenossresmgr",
    require => Exec['zends'],
}

service { 'rabbitmq-server':
    ensure => running,
	enable => true,
    require => Exec['zenoss-resmgr'],
}

service { 'memcached':
    ensure => running,
	enable => true,
    require => Exec['zenoss-resmgr'],
}

service { 'snmpd':
    ensure => running,
	enable => true,
    require => Exec['zenoss-resmgr'],
}

exec { "zenoss-tuner":
    command => "/usr/bin/wget -O /opt/zenoss/bin/mysqltuner.pl --no-check-certificate mysqltuner.pl",
    creates => "/opt/zenoss/bin/mysqltuner.pl",
	user => 'zenoss',
    require => Exec['zenoss-resmgr'],
}
file { "/opt/zenoss/bin/mysqltuner.pl":
    mode => 755,
}

exec { "zenup":
    command => "/usr/bin/yum -y --nogpgcheck localinstall /vagrant/zenup-1.1.0.267.869d67a-1.el6.x86_64.rpm",
    creates => "/opt/zenup",
}

exec { "zenoss-register":
    command => "/opt/zenup/bin/zenup init /vagrant/zenoss_resmgr-4.2.5-2108.el6-pristine-SP316.tgz /opt/zenoss",
    creates => "/opt/zenoss/Products",
	user => 'zenoss',
    require => Exec['zenup'],
}

service { 'zenoss':
    ensure => running,
	enable => true,
    require => Exec['zenoss-tuner'],
}

