VOLTAGE_NUMBER="0.3"
# Path to TXT file containing clock periods (located in the parent folder)
TXT_FILE="./clock.txt"
# Path to construct.py file in the child folder (0.4V)
CONSTRUCT_FILE="/afs/ece.cmu.edu/usr/tongwu2/mflowgen/designs/125PSL$VOLTAGE_NUMBER/construct.py"
# Destination for the reports
DEST_DIR="/afs/andrew.cmu.edu/usr19/tongwu2/Documents/"
# Path to child folder where commands need to be run
CHILD_FOLDER="./build"
# Max iterations
MAX_RUNS=15
    # Create a backup of the original file
    cp "$TXT_FILE" "${TXT_FILE}.bak"

# Function to extract the next clock period from the TXT file
get_next_clock_period() {
    # Read the first line from the TXT (assuming it has one clock period value per line)
    local next_value=$(head -n 1 "$TXT_FILE")
    
    # Remove the used line from the TXT to simulate moving to the next
    tail -n +2 "$TXT_FILE" > temp.txt && mv temp.txt "$TXT_FILE"
    
    echo "$next_value"
}

# Function to update the clock period in construct.py
update_clock_period() {
    local new_value=$1
    # Use sed to replace the 'clock_period' value in line 28
    sed -i "28s/'clock_period' *: *[0-9.]*,/'clock_period'   : ${new_value},/" "$CONSTRUCT_FILE"
}

# Loop for the specified number of times 
for (( i=1; i<=$MAX_RUNS; i++ ))
do
    echo "Run $i of $MAX_RUNS"

    # Get the next clock period from the TXT file
    new_clock_period=$(get_next_clock_period)
    
    # Check if a valid clock period was retrieved
    if [ -z "$new_clock_period" ]; then
        echo "No more clock periods available in the TXT file. Exiting."
        break
    fi

    echo "Updating clock period to $new_clock_period"

    # Update the construct.py file with the new clock period
    update_clock_period "$new_clock_period"

    # Change directory back to child folder to run mflowgen
    echo "Running the design at $PWD-----------"
    # Change directory to child folder
    cd "$CHILD_FOLDER" || { echo "Child folder not found"; exit 1; }

    # Run make clean-all
    make clean-all
    wait
    # Use sed to replace line 22 with the new value
    #sed -i "22s/adk_name = 'asap7'/adk_name = 'asap7$VOLTAGE_NUMBER'/" "$CONSTRUCT_FILE"
    #echo "Line 22 in $CONSTRUCT_FILE has been updated to 'adk_name = 'asap7$VOLTAGE_NUMBER''"
    mflowgen run --design /afs/ece.cmu.edu/usr/tongwu2/mflowgen/designs/125PSL"$VOLTAGE_NUMBER"/
    wait

    echo "--------------make 1666666 ------------"
    make 16
    echo "---------------------finish ---------------"
    wait
    # Check if the mflowgen command was successful
    if [ $? -eq 0 ]; then
        echo "mflowgen run completed successfully"
        # Rename and move the reports file
        report_file="run5_${new_clock_period}.html"
        mv ./16-cadence-innovus-signoff/reports/metrics.html "../${report_file}"
        echo "Report moved to ../${report_file}"
    else
        echo "mflowgen run failed, skipping this iteration"
        cd - > /dev/null
        continue
    fi

    # Change back to the parent folder before the next iteration
    cd - > /dev/null

    echo "Run $i completed successfully"
    echo "------------------------------------"
done

echo "All runs completed."

# Restore the original clock periods file from backup
rm "$TXT_FILE"
mv "${TXT_FILE}.bak" "$TXT_FILE"

:
