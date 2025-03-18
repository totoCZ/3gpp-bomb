#!/usr/bin/env ruby


require 'csv'
require 'resolv'

def macos?
  RUBY_PLATFORM.downcase.include?("darwin")
end

def ping_host(host)
  if macos?
    # Optimized for macOS: use built-in ping command with count of 1 and timeout of 2 seconds.
    #  This is generally much faster and more reliable than Ruby's built-in ping libraries.
    #  `system` returns true on success (exit code 0), false otherwise.
    system("ping -c 1 -t 2 #{host} > /dev/null 2>&1")  # Redirect output to /dev/null to avoid printing
  else
    # Fallback for other OSes (e.g., Linux).  Use Net::Ping::External for broader compatibility,
    # though it might be slower.
    pinger = Net::Ping::External.new(host)
    pinger.timeout = 2 # Set a timeout (in seconds)
    pinger.ping?
  end
end


def check_dns_and_ping(mcc, mnc)
  # Format MNC with leading zeros if necessary
  formatted_mnc = format('%03d', mnc.to_i)
  domain = "epdg.epc.mnc#{formatted_mnc}.mcc#{mcc}.pub.3gppnetwork.org"

  begin
    # Use Resolv to check if the domain resolves
    Resolv::DNS.new.getaddress(domain)
    vowifi = 1
  rescue Resolv::ResolvError
    vowifi = 0
  end
  
  pingable = ping_host(domain) ? 1 : 0  if vowifi == 1 # Only ping if DNS resolves

  return vowifi, pingable, domain
end

def process_csv(input_filename, output_filename)
  # Read the CSV file
  csv_data = CSV.read(input_filename, headers: true, col_sep: ';')

  # Add new columns
  csv_data.headers << 'vowifi'
  csv_data.headers << 'pingable'
    csv_data.headers << 'domain'

  # Process each row
  csv_data.each do |row|
    mcc = row['MCC']
    mnc = row['MNC']

    vowifi, pingable, domain = check_dns_and_ping(mcc, mnc)

    row['vowifi'] = vowifi
    row['pingable'] = pingable
    row['domain'] = domain
  end

  # Write the updated data to a new CSV file
  CSV.open(output_filename, 'wb', col_sep: ';') do |csv|
    csv << csv_data.headers
    csv_data.each do |row|
      csv << row
    end
  end
end



# --- Main execution ---

input_file = 'mcc-mnc.csv'
output_file = 'mcc-mnc_updated.csv'

process_csv(input_file, output_file)

puts "CSV processing complete.  Output written to #{output_file}"
