require "ipaddr"

module Puppet::Parser::Functions
	newfunction(:ip_within_range, :type => :rvalue, :doc => "Return true if IP address is within a specified range.") do |args|

		raise Puppet::ParseError, "ip_within_range requires at least 3 arguments" unless args.length.between?(2,3)
		
		begin
			ip_to_test = IPAddr.new(args[0])
			if args.length == 2
				range= IPAddr.new(args[1])
				return range===ip_to_test
			else
				range_min = IPAddr.new(args[1])
				range_max = IPAddr.new(args[2])
				return (range_min..range_max)===ip_to_test
			end
		rescue ArgumentError => e
	        raise Puppet::ParseError, e.to_s
		end 
	end
end		