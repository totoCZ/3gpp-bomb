#!/usr/bin/env ruby

require 'csv'

# Function to get last pingable IP using mtr
def get_last_pingable_ip(domain)
  # Run mtr command and capture output
  output = `sudo mtr -r -c 10 --no-dns #{domain}`
  
  # Split into lines and reverse to find last responsive hop
  lines = output.split("\n")
  lines.reverse_each do |line|
    # Match IP address pattern and check if it has response stats
    if line =~ /(\d+\.\d+\.\d+\.\d+)/
      ip = $1
      # Check if there's a response time/loss% in the line
      if line =~ /\d+\.\d+%\s+\d+/ || line =~ /\d+\.\d+ms/
        return ip unless ip == "0.0.0.0" # Skip if it's just a placeholder IP
      end
    end
  end
  return nil # Return nil if no pingable IP found
end

# Input and output file names
input_file = "mcc-mnc.csv"
output_file = "mcc-mnc_updated.csv"

# Read CSV and process
csv_data = CSV.read(input_file, headers: true, col_sep: ";")
headers = csv_data.headers
headers << "alternative_ip" unless headers.include?("alternative_ip")

new_rows = []
csv_data.each do |row|
  pingable = row["pingable"]&.to_i
  vowifi = row["vowifi"]&.to_i
  
  # Process only rows where pingable==0 and vowifi==1
  if pingable == 0 && vowifi == 1
    domain = row["domain"]
    puts "Processing traceroute for #{domain}..."
    alt_ip = get_last_pingable_ip(domain)
    row["alternative_ip"] = alt_ip || ""
    puts "Found alternative IP: #{alt_ip || 'none'}"
  else
    row["alternative_ip"] ||= "" # Empty string if not processed
  end
  new_rows << row
end

# Write updated CSV
CSV.open(output_file, "w") do |csv|
  csv << headers
  new_rows.each do |row|
    csv << row
  end
end

puts "Processing complete. Output written to #{output_file}"
