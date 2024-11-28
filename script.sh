#!/bin/bash

# Define output files and directories
OUTPUT_LOG="stats.log"
OUTPUT_DIR="output"
TEMP_FILE=$(mktemp)
INTERFACE="en0"

# Function to display ASCII art
print_ascii_art() {
    echo "#######################################"
    echo "#                                     #"
    echo "#         .        *        .         #"
    echo "#      *       _____       *          #"
    echo "#    .       /     \\       .         #"
    echo "#         | () () |         *         #"
    echo "#          \\  ^  /                   #"
    echo "#           |||||           *         #"
    echo "#         * |||||   .                 #"
    echo "#    .                          *     #"
    echo "#         Yunus' Traf Statter 2.0     #"
    echo "#                                     #"
    echo "#######################################"
    echo
}

# Function to check if gnuplot is installed
check_gnuplot() {
    if ! command -v gnuplot &> /dev/null; then
        echo "Warning: gnuplot is not installed. Charts will not be generated."
        GENERATE_CHARTS=false
    else
        GENERATE_CHARTS=true
    fi
}

# Trap for cleanup and stats generation
trap 'stop_animation; generate_stats; cleanup' EXIT

# Function to generate stats
generate_stats() {
    echo "Analyzing captured traffic..."

    # Initialize log file
    echo "Network Traffic Summary:" > "$OUTPUT_LOG"

    # Create output directory for CSV files
    mkdir -p "$OUTPUT_DIR"

    # List of devices in the network
    echo -e "\nList of Devices in the Network:" >> "$OUTPUT_LOG"
    echo "IP Address" > "$OUTPUT_DIR/list_of_devices.csv"
    tshark -r "$TEMP_FILE" -T fields -e ip.addr | sort | uniq | tee -a "$OUTPUT_LOG" >> "$OUTPUT_DIR/list_of_devices.csv"

    # List of all visited IPs by all users in network
    echo -e "\nList of All Visited IPs by All Users in Network:" >> "$OUTPUT_LOG"
    echo "Source IP,Destination IP" > "$OUTPUT_DIR/all_visited_ips.csv"
    tshark -r "$TEMP_FILE" -Y "ip.src && ip.dst" -T fields -e ip.src -e ip.dst -E separator=, | \
        sort | uniq | tee -a "$OUTPUT_LOG" >> "$OUTPUT_DIR/all_visited_ips.csv"

    # List of most visited IPs
    echo -e "\nList of Most Visited IPs:" >> "$OUTPUT_LOG"
    echo "IP Address,Count" > "$OUTPUT_DIR/most_visited_ips.csv"
    tshark -r "$TEMP_FILE" -Y "ip.dst" -T fields -e ip.dst | sort | uniq -c | sort -nr | \
        awk '{printf "%-15s %s\n", $2, $1}' | tee -a "$OUTPUT_LOG" | \
        awk '{print $1 "," $2}' >> "$OUTPUT_DIR/most_visited_ips.csv"

    # List of most requesting network devices
    echo -e "\nList of Most Requesting Network Devices:" >> "$OUTPUT_LOG"
    echo "IP Address,Count" > "$OUTPUT_DIR/most_requesting_devices.csv"
    tshark -r "$TEMP_FILE" -Y "ip.src" -T fields -e ip.src | sort | uniq -c | sort -nr | \
        awk '{printf "%-15s %s\n", $2, $1}' | tee -a "$OUTPUT_LOG" | \
        awk '{print $1 "," $2}' >> "$OUTPUT_DIR/most_requesting_devices.csv"

    # List of data packet sizes from most to least sorted by device in the network
    echo -e "\nList of Data Packet Sizes from Most to Least Sorted by Device:" >> "$OUTPUT_LOG"
    echo "IP Address,Total Bytes" > "$OUTPUT_DIR/data_packet_sizes.csv"
    tshark -r "$TEMP_FILE" -Y "ip.src" -T fields -e ip.src -e frame.len -E separator=, | \
        awk -F',' '{bytes[$1]+=$2} END {for (ip in bytes) print ip "," bytes[ip]}' | sort -t',' -k2 -nr | \
        tee -a "$OUTPUT_LOG" >> "$OUTPUT_DIR/data_packet_sizes.csv"

    # URLs visited by devices
    echo -e "\nURLs Visited by Devices:" >> "$OUTPUT_LOG"
    echo "Domain,Count" > "$OUTPUT_DIR/urls_visited.csv"
    tshark -r "$TEMP_FILE" -Y "dns.qry.name" -T fields -e dns.qry.name \
        -E separator=, -E quote=d | \
        awk -F',' '{
            gsub(/"/,"",$0);
            if($1) {
                count[$1]++;
            }
        }
        END {
            for (domain in count) {
                print domain "," count[domain];
            }
        }' | sort -t',' -k2 -nr | tee -a "$OUTPUT_LOG" >> "$OUTPUT_DIR/urls_visited.csv"

    # Traffic volume over time (only in log and chart, not in CSV)
    echo -e "\nTraffic Volume by Time:" >> "$OUTPUT_LOG"
    tshark -r "$TEMP_FILE" -T fields -e frame.time_relative -e frame.len \
        -E separator=, -E occurrence=f | \
        awk -F',' '{
            if($1 && $2) {
                total+=$2;
                printf "%.1f,%s\n", $1, total;
            }
        }' > temp_time_volume.log

    # Generate traffic volume chart if gnuplot is available
    if [ "$GENERATE_CHARTS" = true ]; then
        generate_chart temp_time_volume.log "Traffic Volume (Bytes) over Time" "Time (s)" "Bytes"
    else
        echo "Skipping chart generation due to missing gnuplot."
    fi

    echo "Analysis complete. Results saved to $OUTPUT_LOG and CSV files in the '$OUTPUT_DIR' directory."
}

# Cleanup function
cleanup() {
    echo "Cleaning up temporary files..."
    rm -f "$TEMP_FILE" temp_time_volume.log
}

# Function to show animation
show_animation() {
    local animation=("|" "/" "-" "\\")
    local i=0
    while :; do
        printf "\rCapturing traffic... %s" "${animation[i % ${#animation[@]}]}"
        sleep 1
        ((i++))
    done
}

# Function to stop animation
stop_animation() {
    if [[ -n "$ANIMATION_PID" ]]; then
        kill "$ANIMATION_PID" 2>/dev/null
        wait "$ANIMATION_PID" 2>/dev/null
        printf "\rCapture stopped.                 \n"
    fi
}

# Function to generate charts using gnuplot
generate_chart() {
    local input_file="$1"
    local title="$2"
    local xlabel="$3"
    local ylabel="$4"
    local output_file="chart_${RANDOM}.png"

    echo "set terminal png size 800,600" > temp_plot.gp
    echo "set output '$output_file'" >> temp_plot.gp
    echo "set title '$title'" >> temp_plot.gp
    echo "set xlabel '$xlabel'" >> temp_plot.gp
    echo "set ylabel '$ylabel'" >> temp_plot.gp
    echo "set grid" >> temp_plot.gp
    echo "set datafile separator ','" >> temp_plot.gp
    echo "plot '$input_file' using 1:2 with lines title '$ylabel'" >> temp_plot.gp

    gnuplot temp_plot.gp
    echo "Chart saved to $output_file"
    rm -f temp_plot.gp
}

# Main script execution
print_ascii_art
echo "Starting traffic capture on $INTERFACE. Enter your sudo password if prompted."

# Check if gnuplot is installed
check_gnuplot

# Test initial capture to validate
sudo tshark -i "$INTERFACE" -a duration:5 -c 1 -w "$TEMP_FILE" > /dev/null 2>&1 &
TSHARK_PID=$!

# Wait briefly to see if capture starts
sleep 3

if [[ ! -s "$TEMP_FILE" ]]; then
    echo "Error: No traffic detected or interface $INTERFACE is not valid."
    kill "$TSHARK_PID" 2>/dev/null
    cleanup
    exit 1
fi

# Start actual capture and animation
sudo tshark -i "$INTERFACE" -w "$TEMP_FILE" > /dev/null 2>&1 &
TSHARK_PID=$!

show_animation &
ANIMATION_PID=$!

wait "$TSHARK_PID"
