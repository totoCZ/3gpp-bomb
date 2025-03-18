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
  rcs_domain = "config.rcs.mnc#{formatted_mnc}.mcc#{mcc}.pub.3gppnetwork.org"

  begin
    # Use Resolv to check if the domain resolves
    Resolv::DNS.new.getaddress(rcs_domain)
    rcs = 1
  rescue Resolv::ResolvError
    rcs = 0
  end
  
  rcs_pingable = ping_host(rcs_domain) ? 1 : 0  if rcs == 1 # Only ping if DNS resolves

  return rcs, rcs_pingable, rcs_domain
end

def process_csv(input_filename, output_filename)
  # Read the CSV file
  csv_data = CSV.read(input_filename, headers: true, col_sep: ';')

  # Add new columns
  csv_data.headers << 'rcs'
  csv_data.headers << 'rcs_pingable'
    csv_data.headers << 'rcs_domain'

  # Process each row
  csv_data.each do |row|
    mcc = row['MCC']
    mnc = row['MNC']

    rcs, rcs_pingable, rcs_domain = check_dns_and_ping(mcc, mnc)

    row['rcs'] = rcs
    row['rcs_pingable'] = rcs_pingable
    row['rcs_domain'] = rcs_domain
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
