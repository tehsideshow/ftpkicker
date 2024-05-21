#!/bin/bash

# Define the log file path
LOG_FILE="/home/five9inf/vcc-work/log/server.log"
MAX_THREADS=32770  # Adjusted maximum thread limit for the JVM

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

# Function to check JVM health for vcc service using /proc
check_jvm_health() {
  yellow_message "Checking JVM health for vcc service..."
  JVM_PID=$(pgrep -f vcc)

  if [ -z "$JVM_PID" ]; then
    echo "Could not find the JVM process for vcc service."
    return
  fi

  JVM_THREAD_COUNT=0
  JVM_MEMORY_USED_MB=0

  for PID in $JVM_PID; do
    if [ -d /proc/$PID ]; then
      THREADS=$(grep Threads /proc/$PID/status | awk '{print $2}')
      JVM_THREAD_COUNT=$((JVM_THREAD_COUNT + THREADS))
      JVM_MEMORY_USED_KB=$(grep VmRSS /proc/$PID/status | awk '{print $2}')
      JVM_MEMORY_USED_MB=$((JVM_MEMORY_USED_MB + JVM_MEMORY_USED_KB / 1024))
    fi
  done

  # Detect JVM size
  if [ $JVM_MEMORY_USED_MB -le 4096 ]; then
    MAX_JVM_MEMORY=4096
  elif [ $JVM_MEMORY_USED_MB -le 4850 ]; then
    MAX_JVM_MEMORY=4850
  elif [ $JVM_MEMORY_USED_MB -le 8192 ]; then
    MAX_JVM_MEMORY=8192
  else
    MAX_JVM_MEMORY=16384
  fi

  JVM_THREAD_USAGE_PERCENT=$(echo "scale=2; ($JVM_THREAD_COUNT * 100) / $MAX_THREADS" | bc)
  JVM_THREAD_REMAINING_PERCENT=$(echo "scale=2; 100 - $JVM_THREAD_USAGE_PERCENT" | bc)
  JVM_MEMORY_USAGE_PERCENT=$(echo "scale=2; ($JVM_MEMORY_USED_MB * 100) / $MAX_JVM_MEMORY" | bc)
  JVM_MEMORY_REMAINING_PERCENT=$(echo "scale=2; 100 - $JVM_MEMORY_USAGE_PERCENT" | bc)

  green_message "JVM Active Thread Count: $JVM_THREAD_COUNT"
  green_message "JVM Thread Usage: $JVM_THREAD_USAGE_PERCENT%"
  green_message "JVM Thread Remaining: $JVM_THREAD_REMAINING_PERCENT%"
  green_message "JVM Memory Used: ${JVM_MEMORY_USED_MB}MB"
  green_message "JVM Memory Usage: $JVM_MEMORY_USAGE_PERCENT%"
  green_message "JVM Memory Remaining: $JVM_MEMORY_REMAINING_PERCENT%"
  green_message "Assumed JVM Max Memory: ${MAX_JVM_MEMORY}MB"
}

# Function to display a progress bar
show_progress() {
  local duration=$1
  local interval=0.1
  local max_steps=$(echo "$duration / $interval" | bc)
  for ((i = 0; i <= max_steps; i++)); do
    echo -n "#"
    sleep $interval
  done
  echo ""
}

# Initial message indicating the start of the health check
yellow_message "Starting health check for FTP VCC..."
show_progress 3

# Check who is logged in
yellow_message "Checking logged-in users..."
CURRENT_USER=$(whoami)
LOGGED_IN_USERS=$(who | awk '{print $1}' | sort | uniq)
if [ "$LOGGED_IN_USERS" == "$CURRENT_USER" ]; then
  green_message "No other users are working on this host. Proceeding with the script..."
else
  yellow_message "Other users are logged in:"
  echo "$LOGGED_IN_USERS"
  yellow_message "Please make sure no other user is already taking action on this server, especially a restart."
  read -p "Press Enter to continue if it's safe to proceed..."
fi

# Initial check of JVM health
check_jvm_health

# Check the status of the vcc service
yellow_message "Checking the status of the vcc service..."
show_progress 3
STATUS_OUTPUT=$(sudo service vcc status)

# Check for specific error in the status output
if echo "$STATUS_OUTPUT" | grep -q "java.io.InterruptedIOException: timeout"; then
  red_message "Detected 'java.io.InterruptedIOException: timeout' error in the vcc service status."
  read -p "Would you like to run 'sudo service vcc restart' on the host? (yes/no): " RESTART_CHOICE
  if [ "$RESTART_CHOICE" == "yes" ]; then
    # Perform the restart
    green_message "The host is restarting."
    sudo service vcc restart
    # Check system health and JVM health after restart
    check_system_health
    check_jvm_health
  else
    echo "Skipping the restart."
  fi
  exit 0
fi

# Function to check system health
check_system_health() {
  yellow_message "Checking system health..."
  CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
  MEMORY_USAGE=$(free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }')
  green_message "CPU Usage: $CPU_USAGE"
  green_message "$MEMORY_USAGE"
}

# Function to grep and count occurrences in the log file
grep_and_count() {
  local pattern=$1
  local from_time=$(date --date='5 minutes ago' '+%Y-%m-%d %H:%M:%S')
  local to_time=$(date '+%Y-%m-%d %H:%M:%S')
  local count=$(egrep "$pattern" "$LOG_FILE" | awk -v d1="$from_time" -v d2="$to_time" '$0 >= d1 && $0 <= d2' | wc -l)
  local last_entry=$(egrep "$pattern" "$LOG_FILE" | awk -v d1="$from_time" -v d2="$to_time" '$0 >= d1 && $0 <= d2' | tail -1)
  echo "$count:$last_entry"
}

# Function to check logs and suggest restart if necessary
check_logs_and_suggest_restart() {
  # Check for "Broken pipe" in the log file in the past 5 minutes
  yellow_message "Checking logs for 'Broken pipe' errors..."
  BROKEN_PIPE_RESULT=$(grep_and_count "Broken pipe")
  BROKEN_PIPE_COUNT=$(echo "$BROKEN_PIPE_RESULT" | cut -d: -f1)
  BROKEN_PIPE_LAST=$(echo "$BROKEN_PIPE_RESULT" | cut -d: -f2-)
  if [ "$BROKEN_PIPE_COUNT" -gt 0 ]; then
    red_message "Number of 'Broken pipe' occurrences in the past 5 minutes: $BROKEN_PIPE_COUNT"
    red_message "Last 'Broken pipe' entry: $BROKEN_PIPE_LAST"
  else
    echo "Number of 'Broken pipe' occurrences in the past 5 minutes: $BROKEN_PIPE_COUNT"
  fi

  # Check for "ignored - low memory" in the log file in the past 5 minutes
  yellow_message "Checking logs for 'ignored - low memory' warnings..."
  LOW_MEMORY_RESULT=$(grep_and_count "ignored - low memory")
  LOW_MEMORY_COUNT=$(echo "$LOW_MEMORY_RESULT" | cut -d: -f1)
  LOW_MEMORY_LAST=$(echo "$LOW_MEMORY_RESULT" | cut -d: -f2-)
  if [ "$LOW_MEMORY_COUNT" -gt 0 ]; then
    red_message "Number of 'ignored - low memory' occurrences in the past 5 minutes: $LOW_MEMORY_COUNT"
    red_message "Last 'ignored - low memory' entry: $LOW_MEMORY_LAST"
  else
    echo "Number of 'ignored - low memory' occurrences in the past 5 minutes: $LOW_MEMORY_COUNT"
  fi

  # Suggest a restart if there is more than 0 occurrence of "Broken pipe" or "ignored - low memory"
  if [ "$BROKEN_PIPE_COUNT" -gt 0 ] || [ "$LOW_MEMORY_COUNT" -gt 0 ]; then
    echo "There have been more than 0 'Broken pipe' or 'ignored - low memory' occurrences in the past 5 minutes. It is suggested to restart the FTP host."
    read -p "Would you like to run 'sudo service vcc restart' on the host? (yes/no): " RESTART_CHOICE
    if [ "$RESTART_CHOICE" == "yes" ]; then
      # Perform the restart
      green_message "The host is restarting."
      sudo service vcc restart
      # Check system health and JVM health after restart
      check_system_health
      check_jvm_health
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

  # Check system health and JVM health if no restart is performed
  if [ "$CHECK_LOGS_CHOICE" != "yes" ] || [ "$RESTART_CHOICE" != "yes" ]; then
    check_system_health
    check_jvm_health
  fi

else
  # Check for "Broken pipe" in the status output
  if echo "$STATUS_OUTPUT" | grep -q "Broken pipe"; then
    red_message "There is likely an issue with the vcc service (Broken pipe)."
    read -p "Would you like to run 'sudo service vcc restart' on the host? (yes/no): " RESTART_CHOICE
    if [ "$RESTART_CHOICE" == "yes" ]; then
      # Perform the restart
      green_message "The host is restarting."
      sudo service vcc restart
      # Check system health and JVM health after restart
      check_system_health
      check_jvm_health
    else
      echo "Skipping the restart."
    fi
  fi
fi
