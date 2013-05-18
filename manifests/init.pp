# == Class: dhcp
#
# Full description of class dhcp here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if it
#   has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should not be used in preference to class parameters  as of
#   Puppet 2.6.)
#
# === Examples
#
#  class { dhcp:
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ]
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2013 Your name here, unless otherwise noted.
#
class dhcp(
	$ddns_update => 'none',
	$authoritative => false,
	$opts => [],
	$autoupdate => false,
) {

	if $autoupdate == true {
		$package_ensure = latest
	} elsif $autoupdate == false {
		$package_ensure = present
	} else {
		fail('autoupdate parameter must be either true or false')
	}

	package { 'isc-dhcp-server':
		ensure => $package_ensure,
	}

	file { '/etc/dhcp/dhcpd.conf':
		ensure => present,
		require => [ Package['isc-dhcp-server'], File['/etc/dhcp/subnets.d'] ],
		owner => 'root',
		group => 'root',
		mode => '0644', 
		template => template('dhcp/dhcpd.conf.erb')
	}

	service { 'isc-dhcp-server':
		ensure => running,
		enable => true,
		hasstatus => true,
		require => [ Package['isc-dhcp-server'], File['/etc/dhcp/dhcpd.conf'] ],
		subscribe => File['/etc/dhcp/dhcpd.conf']
	}

	file { '/etc/dhcp/subnets.d':
			ensure  => directory,
			require => Package['dhcp']
	}
}

class dhcp::subnet(
	$subnet => $title,
	$netmask => '255.255.255.0',
	$range_from => undef,
	$range_to => undef,
	$broadcast => undef,
	$ntp_server => undef,
	$domain_name => undef,
	$domain_name_servers => '8.8.8.8 8.8.8.4',
	$pxe => false,
	$pxe_filename => 'pxelinux.0',
	$pxe_next_server => $::ipaddress,
	$ensure => 'present'
) {

	if !defined(Class['dhcp']) {
		fail("You must include the dhcp base class before using dhcp defined resources")
	}

	validate_re($ensure, '^(present|absent)$',"${ensure} is not supported for ensure. Allowed values are 'present' and 'absent'.")

	if !$range_from or !$range_to {
		fail("You must define both range_to and range_from")
	}

	if !ip_within_range($range_from, $subnet) or !ip_within_range($range_to, $subnet) {
		fail("The range defined must within the subnet")
	}

	if ip_within_range($broadcast, $range_from, $range_to) {
		fail("The broadcast address cannot be within the dhcp lease range")	
	}

	if ip_within_range($ntp_server, $range_from, $range_to) {
		fail("The ntp server you have defined is within the dhcp lease range")	
	}

	if ip_within_range($pxe_next_server, $range_from, $range_to) {
		fail("The next server for pxe you have defined is within the dhcp lease range")	
	}

	if !defined(File['/etc/dhcp/subnets.d']) {
		file { '/etc/dhcp/subnets.d':
			ensure  => directory,
			require => Package['dhcp'],
		}
	}

	file { "${subnet}.conf":
		ensure => $ensure,
		path => "/etc/dhcp/subnets.d/${subnet}.conf",
		template => template('dhcp/subnet.conf.erb'),
		owner => 'root',
		group => 'root',
		mode => '0644',
		require => [ Package['dhcp'], File['/etc/dhcp/subnets.d'] ],
		notify => Service['isc-dhcp-server']
	}

}
