#!/usr/bin/env ruby

require 'csv'
require 'resolv'

def resolve_ips(domain)
  ip4 = ''
  ip6 = ''

  begin
    resolver = Resolv::DNS.new
    ip4_resources = resolver.getresources(domain, Resolv::DNS::Resource::IN::A)
    ip6_resources = resolver.getresources(domain, Resolv::DNS::Resource::IN::AAAA)

    ip4 = ip4_resources.map(&:address).join(';') unless ip4_resources.empty?
    ip6 = ip6_resources.map(&:address).join(';') unless ip6_resources.empty?

  rescue Resolv::ResolvError => e
    # Handle resolution errors (e.g., domain not found, timeout)
    #puts "Error resolving #{domain}: #{e.message}"
    # Return empty strings if resolution fails
  end
  [ip4, ip6]
end



def process_csv(input_file, output_file)
  CSV.open(output_file, 'wb', col_sep: ';') do |output_csv|
    # Write header (assuming input CSV has a header, adapt if not)
    headers = CSV.read(input_file, headers: true, col_sep: ';').headers
    
    # Add new columns, while preventing duplicates
    headers_to_add = ['ip4', 'ip6']
    headers_to_add.each { |header| headers << header unless headers.include?(header) }

    output_csv << headers
    
    #added begin to gracefully catch exceptions at the overall level.
    begin
      CSV.foreach(input_file, headers: true, col_sep: ';') do |row|
        vowifi = row['vowifi'].to_i  # Convert to integer for comparison
        pingable = row['pingable'].to_i
        as_num_domain = row['as_num_domain']  #Keep as string
        as_num_rcs = row['as_num_rcs']     #Keep as string
        rcs_pingable = row['rcs_pingable'].to_i
        domain = row['domain']
        rcs_domain = row['rcs_domain']

        ip4 = '' #initialize here instead of inside conditional blocks.
        ip6 = ''

        if vowifi == 1
          if pingable == 1
            ip4, ip6 = resolve_ips(domain)
          elsif pingable == 0 && as_num_domain == as_num_rcs && rcs_pingable == 1
            ip4, ip6 = resolve_ips(rcs_domain)
          end
        end

        row['ip4'] = ip4
        row['ip6'] = ip6

        output_csv << row  # Write the updated row to the output CSV

      end
    rescue CSV::MalformedCSVError => e
        puts "Error: Invalid CSV format in #{input_file}: #{e.message}"
    rescue Errno::ENOENT => e #catch file not found.
        puts "Error: Input file not found: #{input_file}"
    rescue StandardError => e # catch-all for other errors
      puts "An unexpected error occurred: #{e.message}"
      puts e.backtrace.join("\n") # Print the backtrace for debugging
    end
  end
end

# --- Main execution ---

input_csv_file = "mcc-mnc.csv"
output_csv_file = "mcc-mnc_updated.csv"

process_csv(input_csv_file, output_csv_file)

puts "CSV processing complete.  Output written to #{output_csv_file}"
