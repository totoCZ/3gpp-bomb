#!/usr/bin/env ruby

require 'csv'
require 'ipaddr'
require 'open3'

def parse_mtr_output(output, target_asn)
  extracted_ips = []
  
  output.each_line.reverse_each do |line|
    columns = line.strip.split
    next unless columns.size > 2
    
    asn = columns[1][/AS(\d+)/, 1]
    ip = columns[2] if columns[2] =~ /\b(?:\d{1,3}\.){3}\d{1,3}\b|(?:[a-fA-F0-9:]+:+)+[a-fA-F0-9]+\b/
    
    extracted_ips << ip if asn == target_asn.to_s && ip
  end
  puts "Extracted IPs for ASN #{target_asn} (from last hop first): #{extracted_ips}"
  extracted_ips
end

def ping_ip(ip, attempts = 2)
  # Validate and determine IP version
  ip_addr = IPAddr.new(ip)
  is_ipv6 = ip_addr.ipv6?
  
  # Use ping for IPv4 and ping6 for IPv6 with appropriate parameters
  if is_ipv6
    # -i 0.1: interval between pings, -c: count, -W: timeout in seconds
    cmd = "ping6 -i 0.1 -c #{attempts} #{ip}"
  else
    # -i 0.1: interval between pings, -c: count, -t: TTL (used as timeout approximation)
    cmd = "ping -i 0.1 -c #{attempts} -t 1 #{ip}"
  end
  
  stdout, stderr, status = Open3.capture3(cmd)
  puts "Pinging IP #{ip}: #{status.success? ? 'Success' : 'Failed'}"
  status.success?
rescue IPAddr::InvalidAddressError
  puts "Invalid IP address: #{ip}"
  false
rescue StandardError => e
  puts "Error pinging IP #{ip}: #{e.message}"
  false
end

# Process the CSV file
def process_csv(input_file, output_file)
  csv_data = CSV.read(input_file, headers: true, col_sep: ';')
  
  # Add new columns if they don't exist
  headers = csv_data.headers
  headers << 'ip4' unless headers.include?('ip4')
  headers << 'ip6' unless headers.include?('ip6')

  CSV.open(output_file, 'w', col_sep: ';') do |csv|
    csv << headers # Write headers

    csv_data.each do |row|
      
      if row['vowifi'] == '1' && row['pingable'] == '0'
        domain = row['domain']
        as_num_domain = row['as_num_domain']
        puts "Processing domain: #{domain}"

        # Process IPv4
        if row['ip4'].to_s.strip.empty?
          output, _ = Open3.capture2("sudo mtr -n -r -z -w -c 5 -4 -i 0.5 #{domain}")
          puts "MTR IPv4 Output for #{domain}:\n#{output}"
          row['ip4'] = parse_mtr_output(output, as_num_domain).find { |ip| ping_ip(ip) }
        end

        # Process IPv6
        if row['ip6'].to_s.strip.empty?
          output, _ = Open3.capture2("sudo mtr -n -r -z -w -c 5 -6 -i 0.5 #{domain}")
          puts "MTR IPv6 Output for #{domain}:\n#{output}"
          row['ip6'] = parse_mtr_output(output, as_num_domain).find { |ip| ping_ip(ip) }
        end

        # RCS fallback processing
        if row['rcs'] == '1' && row['rcs_pingable'] == '0' && row['as_num_domain'] == row['as_num_rcs']
          rcs_domain = row['rcs_domain']
          puts "Processing RCS domain: #{rcs_domain}"

          # IPv4 RCS
          if row['ip4'].to_s.strip.empty?
            output, _ = Open3.capture2("sudo mtr -n -r -z -w -c 5 -4 -i 0.5 #{rcs_domain}")
            puts "MTR IPv4 Output for #{rcs_domain}:\n#{output}"
            row['ip4'] = parse_mtr_output(output, as_num_domain).find { |ip| ping_ip(ip) }
          end

          # IPv6 RCS
          if row['ip6'].to_s.strip.empty?
            output, _ = Open3.capture2("sudo mtr -n -r -z -w -c 5 -6 -i 0.5 #{rcs_domain}")
            puts "MTR IPv6 Output for #{rcs_domain}:\n#{output}"
            row['ip6'] = parse_mtr_output(output, as_num_domain).find { |ip| ping_ip(ip) }
          end
        end
      end
      
      csv << row # Write the processed row
    end
  end
end

# Usage example
input_file = 'mcc-mnc.csv'
output_file = 'mcc-mnc_updated.csv'
process_csv(input_file, output_file)
puts "Processing complete. Results written to #{output_file}"
