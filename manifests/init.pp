class dhcp(
	$ddns_update = 'none',
	$authoritative = false,
	$default_lease_time = 12600,
	$max_lease_time = 24000,
	$opts = [],
	$autoupdate = false,
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

	concat { '/etc/dhcp/dhcpd.conf':
		require => [ Package['isc-dhcp-server'], File['/etc/dhcp/subnets.d/'] ],
		owner => 'root',
		group => 'root',
		mode => '0644'
	}

	concat::fragment{"dhcpd.config":
		target  => "/etc/dhcp/dhcpd.conf",
		order   => 00,
		content => template("dhcp/dhcpd.conf.erb")
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
			require => Package['isc-dhcp-server']
	}
}

define dhcp::subnet(
	$subnet = $title,
	$netmask = '255.255.255.0',
	$routers = undef,
	$range_from = undef,
	$range_to = undef,
	$broadcast = undef,
	$ntp_server = undef,
	$domain_name = undef,
	$domain_name_servers = "8.8.8.8, 8.8.8.4",
	$pxe = false,
	$pxe_filename = 'pxelinux.0',
	$pxe_next_server = $::ipaddress,
	$ensure = 'present'
) {

	if !defined(Class['dhcp']) {
		fail("You must include the dhcp base class before using dhcp defined resources")
	}

	validate_re($ensure, '^(present|absent)$',"${ensure} is not supported for ensure. Allowed values are 'present' and 'absent'.")

	if !$range_from or !$range_to {
		fail("You must define both range_to and range_from")
	}

	if !ip_within_range($range_from, "${subnet}/${netmask}") or !ip_within_range($range_to, "${subnet}/${netmask}") {
		fail("The range defined must within the subnet")
	}

	if $broadcast and ip_within_range($broadcast, $range_from, $range_to) {
		fail("The broadcast address cannot be within the dhcp lease range")	
	}


	if $ntp_server and ip_within_range($ntp_server, $range_from, $range_to) {
		fail("The ntp server you have defined is within the dhcp lease range")	
	}

	if $pxe_next_server and ip_within_range($pxe_next_server, $range_from, $range_to) {
		fail("The next server for pxe you have defined is within the dhcp lease range")	
	}

	if !defined(File['/etc/dhcp/subnets.d/']) {
		file { '/etc/dhcp/subnets.d':
			ensure  => directory,
			require => Package['isc-dhcp-server'],
		}
	}

	file { "${subnet}.conf":
		ensure => $ensure,
		path => "/etc/dhcp/subnets.d/${subnet}.conf",
		content => template('dhcp/subnet.conf.erb'),
		owner => 'root',
		group => 'root',
		mode => '0644',
		require => [ Package['isc-dhcp-server'], File['/etc/dhcp/subnets.d/'] ],
		notify => Service['isc-dhcp-server']
	}

	#concat { "/etc/dhcp/dhcpd.conf" : }

	concat::fragment {"dhcp.subnet.${subnet}":,
		ensure => $ensure,
		target  => "/etc/dhcp/dhcpd.conf",
		content => "include \"/etc/dhcp/subnets.d/${subnet}.conf\";\n",
	}

}
