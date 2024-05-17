
# FTPKicker Script

## Description

The `FTPKicker` script is designed to monitor the status of the `vcc` service on an FTP host. It checks the service status, logs for specific errors, and suggests restarting the service if certain conditions are met. Additionally, it provides system health information, including CPU and memory usage, as well as JVM memory usage.

## Features

- Checks the status of the `vcc` service.
- Checks system health (CPU and memory usage).
- Checks JVM health (memory usage and remaining memory percentage).
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

## Usage

1. **Make the script executable:**

    ```sh
    chmod +x ftpkicker.sh
    ```

2. **Run the script:**

    ```sh
    ./ftpkicker.sh
    ```

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
    - Checks and displays JVM memory usage and remaining memory percentage.

6. **grep_and_count**
    - Greps a log file for a specific pattern, counts the occurrences in the last 15 minutes, and returns the count and the last entry.
    - Usage: `grep_and_count "pattern"`

7. **check_logs_and_suggest_restart**
    - Checks logs for "Broken pipe" and "ignored - low memory" errors.
    - Displays the count and last entry of each error type.
    - Suggests restarting the `vcc` service if errors are found.

### Main Logic

1. **Check `vcc` Service Status**
    - If `Overall status: STARTED`, the script confirms the service is running and optionally checks logs for errors.

2. **Check Logs**
    - If requested, the script checks for "Broken pipe" and "ignored - low memory" errors, displays the counts and last entries, and suggests restarting the service if errors are found.

3. **Check System and JVM Health**
    - Displays CPU and memory usage, and JVM memory usage and remaining memory percentage.

## Example Output

```sh
Checking system health...
CPU Usage: 12.3%
Memory Usage: 2048/8192MB (25.00%)
Overall status: STARTED
The FTP host appears to still be running and has not crashed.
Would you like to check the logs for any errors? (yes/no): yes
Checking logs for 'Broken pipe' errors...
Number of 'Broken pipe' occurrences in the past 15 minutes: 1
Last 'Broken pipe' entry: [timestamp] [error message]
Checking logs for 'ignored - low memory' warnings...
Number of 'ignored - low memory' occurrences in the past 15 minutes: 0
JVM Memory Usage: 512 MB / 2048 MB
JVM Memory Remaining: 75.00%
