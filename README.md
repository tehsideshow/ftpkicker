# FTPKicker Script

## Description

The `FTPKicker` script is designed to monitor the status of the `vcc` service on an FTP host. It checks the service status, logs for specific errors, and suggests restarting the service if certain conditions are met. Additionally, it provides system health information, including CPU and memory usage, as well as JVM thread usage and remaining percentage.

## Features

- Checks the status of the `vcc` service.
- Checks system health (CPU and memory usage).
- Checks JVM health (active thread count and remaining thread percentage).
- Searches logs for "Broken pipe" and "ignored - low memory" errors.
- Displays the last log entry for each error type if found.
- Suggests restarting the `vcc` service if errors are detected.
- Color-coded output for better readability.

## Requirements

- `bash`
- `awk`
- `grep`
- `bc`
- `sudo` privileges to check the `vcc` service status and restart the service.

## Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/tehsideshow/ftpkicker.git
    ```

2. Navigate to the script directory:
    ```bash
    cd ftpkicker
    ```

3. Make the script executable:
    ```bash
    chmod +x ftpkicker.sh
    ```

## Usage

Run the script:
```bash
./ftpkicker.sh

## Script Breakdown

### Functions

1. **green_message**
    - Displays a message in green.
    - Usage: `green_message "Your message"`

2. **yellow_message**
    - Displays a message in yellow.
    - Usage: `yellow_message "Your message"`

3. **red_message**
    - Displays a message in red.
    - Usage: `red_message "Your message"`

4. **check_system_health**
    - Checks and displays CPU and memory usage.

5. **check_jvm_health**
    - Checks and displays JVM active thread count, remaining threads percentage, and thread usage percentage.

6. **grep_and_count**
    - Greps a log file for a specific pattern, counts the occurrences in the last 15 minutes, and returns the count and the last entry.
    - Usage: `grep_and_count "pattern"`

7. **check_logs_and_suggest_restart**
    - Checks logs for "Broken pipe" and "ignored - low memory" errors.
    - Displays the count and last entry of each error type.
    - Suggests restarting the `vcc` service if errors are found.

### Main Logic

1. **Initial JVM Health Check**
    - Displays JVM active thread count, remaining threads percentage, and thread usage percentage before performing any other actions.

2. **Check `vcc` Service Status**
    - If `Overall status: STARTED`, the
script confirms the service is running and optionally checks logs for errors.

3. **Check Logs**
    - If requested, the script checks for "Broken pipe" and "ignored - low memory" errors, displays the counts and last entries, and suggests restarting the service if errors are found.

4. **Check System and JVM Health**
    - Displays CPU and memory usage, and JVM active thread count, remaining threads percentage, and thread usage percentage.

## Example Output

```sh
Checking JVM health for vcc service...
JVM Active Thread Count: 100
JVM Thread Remaining: 95.00%
JVM Thread Usage: 5.00%
Checking the status of the vcc service...
Overall status: STARTED
The FTP host appears to still be running and has not crashed.
Would you like to check the logs for any errors? (yes/no): yes
Checking logs for 'Broken pipe' errors...
Number of 'Broken pipe' occurrences in the past 15 minutes: 1
Last 'Broken pipe' entry: [timestamp] [error message]
Checking logs for 'ignored - low memory' warnings...
Number of 'ignored - low memory' occurrences in the past 15 minutes: 0
Checking system health...
CPU Usage: 20.5%
Memory Usage: 2048/8192MB (25.00%)
JVM Active Thread Count: 100
JVM Thread Remaining: 95.00%
JVM Thread Usage: 5.00%

