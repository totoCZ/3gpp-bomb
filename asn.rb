#!/usr/bin/env ruby

require 'csv'
require 'resolv'

def resolve_ip(domain)
  begin
    resolver = Resolv::DNS.new
    ip_address = resolver.getaddress(domain)
    return ip_address.to_s  # Convert to string for easy use
  rescue Resolv::ResolvError => e
    # Handle resolution failures (e.g., domain doesn't exist)
    puts "Error resolving #{domain}: #{e.message}"
    return nil # Or raise the error, or return a default value
  end
end

# Function to query Cymru DNS for ASN info
def query_cymru_dns(ip)
  reversed_ip = ip.split('.').reverse.join('.')
  origin_query = "#{reversed_ip}.origin.asn.cymru.com"

  begin
    Resolv::DNS.open do |dns|
      # First query for ASN and basic info
      origin_resources = dns.getresources(origin_query, Resolv::DNS::Resource::IN::TXT)
      if origin_resources.any?
        origin_data = origin_resources.first.data.split('|').map(&:strip)
        as_num = origin_data[0]

        # If we got an AS number, query for the AS name
        if as_num
          as_name_query = "AS#{as_num}.asn.cymru.com"
          as_name_resources = dns.getresources(as_name_query, Resolv::DNS::Resource::IN::TXT)
          if as_name_resources.any?
            as_name_data = as_name_resources.first.data.split('|').map(&:strip)
            as_name = as_name_data.last  # AS Name is typically the last element
            return { as_num: as_num, as_name: as_name }
          end
        end
      end
    end
  rescue StandardError => e
    puts "DNS lookup failed for #{ip}: #{e.message}"
  end

  { as_num: nil, as_name: nil }
end

# Read CSV, process data, and write output
input_file = 'mcc-mnc.csv'
output_file = 'mcc-mnc_updated.csv'

csv_data = CSV.read(input_file, col_sep: ';', headers: true)
CSV.open(output_file, 'w', col_sep: ';') do |csv|
  csv << csv_data.headers + ['as_num_domain', 'as_name_domain', 'as_num_rcs', 'as_name_rcs']
  
  csv_data.each do |row|
    as_domain = { as_num: nil, as_name: nil }
    as_rcs = { as_num: nil, as_name: nil }
    
    if row['vowifi'] == '1'
      domain_ip = resolve_ip(row['domain'])
      as_domain = domain_ip ? query_cymru_dns(domain_ip) : { as_num: nil, as_name: nil }
    end
    
    if row['rcs'] == '1'
      rcs_ip = resolve_ip(row['rcs_domain'])
      as_rcs = rcs_ip ? query_cymru_dns(rcs_ip) : { as_num: nil, as_name: nil }
    end
    
    csv << row.fields + [as_domain[:as_num], as_domain[:as_name], as_rcs[:as_num], as_rcs[:as_name]]
  end
end

puts "CSV processing completed! Output saved to #{output_file}"
