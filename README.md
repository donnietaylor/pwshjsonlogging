# PwshJsonLogging

A PowerShell module for structured JSON logging with multi-line exception support. This module provides a JSON alternative to traditional text-based logging, making it easier to parse logs programmatically and handle complex multi-line exception messages.

## Features

- **JSON Structured Logging**: All log entries are formatted as JSON for easy parsing
- **Multi-line Exception Support**: Properly handles exception messages that span multiple lines
- **Multiple Log Levels**: Support for Debug, Info, Warning, Error, and Fatal levels
- **Structured Data**: Include additional structured data with your log entries
- **Exception Formatting**: Automatic formatting of .NET exceptions with stack traces and inner exceptions
- **Flexible Output**: Log to console or files with optional appending
- **Log Level Filtering**: Set minimum log levels to control output verbosity
- **Source Tracking**: Include source information (function name, class, etc.) in log entries

## Installation

1. Download or clone this repository
2. Import the module:
   ```powershell
   Import-Module /path/to/PwshJsonLogging.psd1
   ```

## Quick Start

### Basic Logging
```powershell
# Simple info message
Write-JsonLog -Level "Info" -Message "Application started successfully"

# Warning with structured data
$userData = @{ UserId = 123; Action = "Login" }
Write-JsonLog -Level "Warning" -Message "User login attempt" -Data $userData
```

### Exception Logging
```powershell
try {
    # Some operation that might fail
    throw "Something went wrong"
}
catch {
    Write-JsonLog -Level "Error" -Message "Operation failed" -Exception $_.Exception -Source "MyFunction"
}
```

### File Logging
```powershell
# Log to file
Write-JsonLog -Level "Info" -Message "Process completed" -FilePath "C:\logs\app.log"

# Append to existing file
Write-JsonLog -Level "Error" -Message "Error occurred" -FilePath "C:\logs\app.log" -Append
```

## Functions

### Write-JsonLog
The main logging function that creates and outputs JSON log entries.

**Parameters:**
- `Level` (required): Log level (Debug, Info, Warning, Error, Fatal)
- `Message` (required): The log message
- `Data` (optional): Hashtable of additional structured data
- `Exception` (optional): Exception object to include in the log
- `Source` (optional): Source identifier (e.g., function name)
- `FilePath` (optional): File path to write the log to
- `MinimumLevel` (optional): Minimum log level to output (default: Debug)
- `Append` (optional): Append to file instead of overwriting

### Add-JsonLogEntry
Creates a JSON log entry without outputting it. Useful for custom output handling.

**Parameters:**
- `Level` (required): Log level (Debug, Info, Warning, Error, Fatal)
- `Message` (required): The log message
- `Data` (optional): Hashtable of additional structured data
- `Exception` (optional): Exception object to include in the log
- `Source` (optional): Source identifier

### Format-ExceptionForJson
Formats an exception object for JSON logging, including inner exceptions.

**Parameters:**
- `Exception` (required): The exception object to format

## Examples

### Complex Logging Scenario
```powershell
$requestData = @{
    RequestId = "req-123-456"
    UserAgent = "PowerShell/7.0"
    ResponseTime = 250.5
    IPAddress = "192.168.1.100"
}

try {
    # Simulate a request processing error
    throw [System.ArgumentException]::new("Invalid request parameter", "requestId")
}
catch {
    Write-JsonLog `
        -Level "Error" `
        -Message "Request processing failed" `
        -Data $requestData `
        -Exception $_.Exception `
        -Source "RequestHandler" `
        -FilePath "C:\logs\api.log" `
        -Append
}
```

**Output:**
```json
{
  "Timestamp": "2025-09-16T02:22:24.298Z",
  "Level": "ERROR",
  "Message": "Request processing failed",
  "Source": "RequestHandler",
  "Data": {
    "RequestId": "req-123-456",
    "ResponseTime": 250.5,
    "UserAgent": "PowerShell/7.0",
    "IPAddress": "192.168.1.100"
  },
  "Exception": {
    "Message": "Invalid request parameter (Parameter 'requestId')",
    "Type": "System.ArgumentException",
    "StackTrace": "...",
    "Source": null,
    "HResult": -2147024809,
    "ParamName": "requestId"
  }
}
```

### Multi-line Exception Handling
```powershell
$multiLineError = @"
Database connection failed.
Connection string: server=localhost;database=mydb
Timeout occurred after 30 seconds.
Please check network connectivity.
"@

try {
    throw $multiLineError
}
catch {
    Write-JsonLog -Level "Fatal" -Message "Database connectivity issue" -Exception $_.Exception
}
```

The module properly preserves multi-line exception messages within the JSON structure.

### Log Level Filtering
```powershell
# This debug message won't be logged because minimum level is Info
Write-JsonLog -Level "Debug" -Message "Debug info" -MinimumLevel "Info"

# This warning will be logged because it's at or above Info level
Write-JsonLog -Level "Warning" -Message "Important warning" -MinimumLevel "Info"
```

## Log Entry Structure

Every log entry contains the following fields:

- `Timestamp`: ISO 8601 formatted UTC timestamp
- `Level`: Log level (DEBUG, INFO, WARNING, ERROR, FATAL)
- `Message`: The log message
- `Source` (optional): Source identifier if provided
- `Data` (optional): Structured data if provided
- `Exception` (optional): Formatted exception information if provided

## Requirements

- PowerShell 5.1 or later
- Compatible with Windows PowerShell and PowerShell Core

## License

This project is open source. Please refer to the license file for details.
