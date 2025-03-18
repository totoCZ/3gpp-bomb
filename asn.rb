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
        
        as_num = origin_data[0].split(" ")[0]
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
  # Add new headers, considering existing ones might or might not be there.
  original_headers = csv_data.headers
  new_headers = ['as_num_domain', 'as_name_domain', 'as_num_rcs', 'as_name_rcs']
  all_headers = original_headers.dup  # Create a copy to avoid modifying the original

  # Add new headers only if they aren't already present.
  new_headers.each do |header|
    all_headers << header unless all_headers.include?(header)
  end
    
  csv << all_headers

  csv_data.each do |row|
    # Initialize AS info (important to do this inside the loop for each row).
    as_domain = { as_num: nil, as_name: nil }
    as_rcs = { as_num: nil, as_name: nil }

    # Process vowifi domain
    if row['vowifi'] == '1'
      # Check if AS info is already present in the source data.  Use row.field() to get the original value.
      if row.field('as_num_domain').to_s.strip.empty?
        puts "processing #{row['domain']}"
        domain_ip = resolve_ip(row['domain'])
        as_domain = domain_ip ? query_cymru_dns(domain_ip) : { as_num: nil, as_name: nil }
      else
        # Keep existing data if present
        as_domain = { as_num: row.field('as_num_domain'), as_name: row.field('as_name_domain') }
      end
    end


    # Process RCS domain
    if row['rcs'] == '1'
      # Check if AS info is already present in the source data.
      if row.field('as_num_rcs').to_s.strip.empty?
        puts "processing #{row['rcs_domain']}"
        rcs_ip = resolve_ip(row['rcs_domain'])
        as_rcs = rcs_ip ? query_cymru_dns(rcs_ip) : { as_num: nil, as_name: nil }
      else
        # Keep existing data if present
        as_rcs = { as_num: row.field('as_num_rcs'), as_name: row.field('as_name_rcs') }
      end
    end


    # Prepare the row to be written, ensuring correct order and handling missing headers.
    row_to_write = []
    all_headers.each do |header|
      case header
      when 'as_num_domain'
        row_to_write << as_domain[:as_num]
      when 'as_name_domain'
        row_to_write << as_domain[:as_name]
      when 'as_num_rcs'
        row_to_write << as_rcs[:as_num]
      when 'as_name_rcs'
        row_to_write << as_rcs[:as_name]
      else
        # Handle cases where the original header is not present in a particular row
        row_to_write << (row.header?(header) ? row[header] : nil)
      end
    end

    csv << row_to_write
  end
end

puts "CSV processing completed! Output saved to #{output_file}"
