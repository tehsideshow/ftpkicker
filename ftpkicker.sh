#!/bin/bash

# Define the log file path
LOG_FILE="/home/five9inf/vcc-work/log/server.log"

# Function to display a message in green
green_message() {
  echo -e "\e[32m$1\e[0m"
}

# Function to display a message in yellow
yellow_message() {
  echo -e "\e[33m$1\e[0m"
}

# Function to display a message in red
red_message() {
  echo -e "\e[31m$1\e[0m"
}

# Check the status of the vcc service
STATUS_OUTPUT=$(sudo service vcc status)

# Function to check system health
check_system_health() {
  yellow_message "Checking system health..."
  CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
  MEMORY_USAGE=$(free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }')
  green_message "CPU Usage: $CPU_USAGE"
  green_message "$MEMORY_USAGE"
}

# Function to check JVM health for vcc service
check_jvm_health() {
  yellow_message "Checking JVM health for vcc service..."
  JVM_PID=$(pgrep -f vcc)

  if [ -z "$JVM_PID" ]; then
    echo "Could not find the JVM process for vcc service."
    return
  fi

  JVM_MEMORY_USED=0
  JVM_MEMORY_MAX=0

  for PID in $JVM_PID; do
    if [ -d /proc/$PID ]; then
      USED=$(grep VmRSS /proc/$PID/status | awk '{print $2}')
      MAX=$(grep VmSize /proc/$PID/status | awk '{print $2}')

      JVM_MEMORY_USED=$((JVM_MEMORY_USED + USED))
      JVM_MEMORY_MAX=$((JVM_MEMORY_MAX + MAX))
    fi
  done

  if [ -z "$JVM_MEMORY_USED" ] || [ -z "$JVM_MEMORY_MAX" ] || [ "$JVM_MEMORY_MAX" -eq 0 ]; then
    echo "Could not retrieve JVM memory information."
    return
  fi

  JVM_MEMORY_USED=$(($JVM_MEMORY_USED / 2))
  JVM_MEMORY_MAX=$(($JVM_MEMORY_MAX / 2))

  JVM_MEMORY_USED_MB=$(echo "$JVM_MEMORY_USED / 1024" | bc)
  JVM_MEMORY_MAX_MB=$(echo "$JVM_MEMORY_MAX / 1024" | bc)
  JVM_MEMORY_REMAINING_PERCENT=$(echo "scale=2; 100 - (($JVM_MEMORY_USED / $JVM_MEMORY_MAX) * 100)" | bc)

  green_message "JVM Memory Usage: $JVM_MEMORY_USED_MB MB / $JVM_MEMORY_MAX_MB MB"
  green_message "JVM Memory Remaining: $JVM_MEMORY_REMAINING_PERCENT%"
}

# Function to grep and count occurrences in the log file
grep_and_count() {
  local pattern=$1
  local result=$(grep "$pattern" "$LOG_FILE" | awk -v d1="$(date --date='15 minutes ago' '+%Y-%m-%d %H:%M:%S')" -v d2="$(date '+%Y-%m-%d %H:%M:%S')" '$0 >= d1 && $0 <= d2')
  local count=$(echo "$result" | wc -l)
  local last_entry=$(echo "$result" | tail -1)
  echo "$count:$last_entry"
}

# Function to check logs and suggest restart if necessary
check_logs_and_suggest_restart() {
  # Check for "Broken pipe" in the log file in the past 15 minutes
  yellow_message "Checking logs for 'Broken pipe' errors..."
  BROKEN_PIPE_RESULT=$(grep_and_count "Broken pipe")
  BROKEN_PIPE_COUNT=$(echo "$BROKEN_PIPE_RESULT" | cut -d: -f1)
  BROKEN_PIPE_LAST=$(echo "$BROKEN_PIPE_RESULT" | cut -d: -f2-)
  if [ "$BROKEN_PIPE_COUNT" -gt 0 ]; then
    red_message "Number of 'Broken pipe' occurrences in the past 15 minutes: $BROKEN_PIPE_COUNT"
    red_message "Last 'Broken pipe' entry: $BROKEN_PIPE_LAST"
  else
    echo "Number of 'Broken pipe' occurrences in the past 15 minutes: $BROKEN_PIPE_COUNT"
  fi
  
  # Check for "ignored - low memory" in the log file in the past 15 minutes
  yellow_message "Checking logs for 'ignored - low memory' warnings..."
  LOW_MEMORY_RESULT=$(grep_and_count "ignored - low memory")
  LOW_MEMORY_COUNT=$(echo "$LOW_MEMORY_RESULT" | cut -d: -f1)
  LOW_MEMORY_LAST=$(echo "$LOW_MEMORY_RESULT" | cut -d: -f2-)
  if [ "$LOW_MEMORY_COUNT" -gt 0 ]; then
    red_message "Number of 'ignored - low memory' occurrences in the past 15 minutes: $LOW_MEMORY_COUNT"
    red_message "Last 'ignored - low memory' entry: $LOW_MEMORY_LAST"
  else
    echo "Number of 'ignored - low memory' occurrences in the past 15 minutes: $LOW_MEMORY_COUNT"
  fi

  # Suggest a restart if there is more than 0 occurrence of "Broken pipe" or "ignored - low memory"
  if [ "$BROKEN_PIPE_COUNT" -gt 0 ] || [ "$LOW_MEMORY_COUNT" -gt 0 ]; then
    echo "There have been more than 0 'Broken pipe' or 'ignored - low memory' occurrences in the past 15 minutes. It is suggested to restart the FTP host."
    read -p "Would you like to run 'sudo service vcc restart' on the host? (yes/no): " RESTART_CHOICE
    if [ "$RESTART_CHOICE" == "yes" ]; then
      echo "Restarting the FTP host..."
      sudo service vcc restart
      green_message "The host is restarting."
    else
      echo "Skipping the restart."
    fi
  fi
}

# Check if the overall status is STARTED
if echo "$STATUS_OUTPUT" | grep -q "Overall status: STARTED"; then
  green_message "Overall status: STARTED"
  green_message "The FTP host appears to still be running and has not crashed."
  
  # Ask the user if they would like to check the logs for any errors
  read -p "Would you like to check the logs for any errors? (yes/no): " CHECK_LOGS_CHOICE
  if [ "$CHECK_LOGS_CHOICE" == "yes" ]; then
    check_logs_and_suggest_restart
  else
    echo "Skipping log check."
  fi

  # Check system health and JVM health
  check_system_health
  check_jvm_health

else
  # Check for "Broken pipe" in the status output
  if echo "$STATUS_OUTPUT" | grep -q "Broken pipe"; then
    red_message "There is likely an issue with the vcc service (Broken pipe). Checking the logs..."
  fi

  # Check logs and suggest restart if necessary
  check_logs_and_suggest_restart

  # Check system health and JVM health
  check_system_health
  check_jvm_health
fi
