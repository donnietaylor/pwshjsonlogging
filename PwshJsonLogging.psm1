using namespace System.Collections.Generic

#region Private Functions

<#
.SYNOPSIS
Gets the current timestamp in ISO 8601 format.

.DESCRIPTION
Returns a standardized timestamp string in ISO 8601 format (yyyy-MM-ddTHH:mm:ss.fffZ).

.OUTPUTS
String. The current timestamp in ISO 8601 format.
#>
function Get-TimestampString {
    return [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

<#
.SYNOPSIS
Converts a log level to a numeric value for comparison.

.DESCRIPTION
Converts string log levels to numeric values to enable log level filtering.

.PARAMETER Level
The log level string to convert.

.OUTPUTS
Int. The numeric representation of the log level.
#>
function Get-LogLevelValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Level
    )
    
    switch ($Level.ToUpper()) {
        'DEBUG'   { return 0 }
        'INFO'    { return 1 }
        'WARNING' { return 2 }
        'ERROR'   { return 3 }
        'FATAL'   { return 4 }
        default   { return 1 }
    }
}

#endregion

#region Public Functions

<#
.SYNOPSIS
Formats an exception object for JSON logging.

.DESCRIPTION
Converts an exception object into a structured format suitable for JSON logging,
including the exception message, type, stack trace, and any inner exceptions.

.PARAMETER Exception
The exception object to format.

.OUTPUTS
PSCustomObject. A structured representation of the exception.

.EXAMPLE
try {
    throw "Test error"
} catch {
    $formattedException = Format-ExceptionForJson -Exception $_.Exception
}
#>
function Format-ExceptionForJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.Exception]$Exception
    )
    
    process {
        $exceptionData = [PSCustomObject]@{
            Message    = $Exception.Message
            Type       = $Exception.GetType().FullName
            StackTrace = $Exception.StackTrace
            Source     = $Exception.Source
            HResult    = $Exception.HResult
        }
        
        # Handle inner exceptions recursively
        if ($Exception.InnerException) {
            $exceptionData | Add-Member -MemberType NoteProperty -Name "InnerException" -Value (Format-ExceptionForJson -Exception $Exception.InnerException)
        }
        
        # Handle additional properties for specific exception types
        if ($Exception -is [System.ArgumentException]) {
            $exceptionData | Add-Member -MemberType NoteProperty -Name "ParamName" -Value $Exception.ParamName
        }
        
        return $exceptionData
    }
}

<#
.SYNOPSIS
Creates a structured log entry as a JSON object.

.DESCRIPTION
Creates a structured log entry with timestamp, level, message, and optional additional data
formatted as JSON for consistent logging.

.PARAMETER Level
The log level (Debug, Info, Warning, Error, Fatal).

.PARAMETER Message
The log message.

.PARAMETER Data
Optional hashtable of additional structured data to include in the log entry.

.PARAMETER Exception
Optional exception object to include in the log entry.

.PARAMETER Source
Optional source identifier (e.g., function name, class name).

.OUTPUTS
String. JSON formatted log entry.

.EXAMPLE
Add-JsonLogEntry -Level "Info" -Message "Application started"

.EXAMPLE
Add-JsonLogEntry -Level "Error" -Message "Database connection failed" -Data @{ConnectionString="server=localhost"} -Exception $_.Exception
#>
function Add-JsonLogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error', 'Fatal')]
        [string]$Level,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Data,
        
        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception,
        
        [Parameter(Mandatory = $false)]
        [string]$Source
    )
    
    $logEntry = [PSCustomObject]@{
        Timestamp = Get-TimestampString
        Level     = $Level.ToUpper()
        Message   = $Message
    }
    
    # Add source if provided
    if ($Source) {
        $logEntry | Add-Member -MemberType NoteProperty -Name "Source" -Value $Source
    }
    
    # Add structured data if provided
    if ($Data -and $Data.Count -gt 0) {
        $logEntry | Add-Member -MemberType NoteProperty -Name "Data" -Value $Data
    }
    
    # Add exception if provided
    if ($Exception) {
        $logEntry | Add-Member -MemberType NoteProperty -Name "Exception" -Value (Format-ExceptionForJson -Exception $Exception)
    }
    
    # Convert to JSON with proper formatting for multi-line content
    return ($logEntry | ConvertTo-Json -Depth 10 -Compress)
}

<#
.SYNOPSIS
Writes a structured JSON log entry to the specified output.

.DESCRIPTION
The main logging function that creates structured JSON log entries and outputs them
to the console, file, or custom output stream. Supports multiple log levels and
structured data.

.PARAMETER Level
The log level (Debug, Info, Warning, Error, Fatal).

.PARAMETER Message
The log message.

.PARAMETER Data
Optional hashtable of additional structured data to include in the log entry.

.PARAMETER Exception
Optional exception object to include in the log entry.

.PARAMETER Source
Optional source identifier (e.g., function name, class name).

.PARAMETER FilePath
Optional file path to write the log entry to. If not specified, writes to console.

.PARAMETER MinimumLevel
Minimum log level to output. Entries below this level will be filtered out.

.PARAMETER Append
If specified and FilePath is provided, appends to the file instead of overwriting.

.OUTPUTS
None. Writes JSON log entry to specified output.

.EXAMPLE
Write-JsonLog -Level "Info" -Message "Application started successfully"

.EXAMPLE
Write-JsonLog -Level "Error" -Message "Failed to process request" -Data @{UserId=123; RequestId="abc-123"} -Exception $_.Exception

.EXAMPLE
Write-JsonLog -Level "Warning" -Message "Disk space low" -Data @{DiskPath="C:\"; AvailableGB=2.5} -FilePath "C:\logs\app.log" -Append
#>
function Write-JsonLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error', 'Fatal')]
        [string]$Level,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Data,
        
        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception,
        
        [Parameter(Mandatory = $false)]
        [string]$Source,
        
        [Parameter(Mandatory = $false)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error', 'Fatal')]
        [string]$MinimumLevel = 'Debug',
        
        [Parameter(Mandatory = $false)]
        [switch]$Append
    )
    
    # Check if the log level meets the minimum threshold
    $currentLevelValue = Get-LogLevelValue -Level $Level
    $minimumLevelValue = Get-LogLevelValue -Level $MinimumLevel
    
    if ($currentLevelValue -lt $minimumLevelValue) {
        return
    }
    
    # Create the JSON log entry
    $jsonLogEntry = Add-JsonLogEntry -Level $Level -Message $Message -Data $Data -Exception $Exception -Source $Source
    
    # Output the log entry
    if ($FilePath) {
        # Write to file
        if ($Append) {
            Add-Content -Path $FilePath -Value $jsonLogEntry -Encoding UTF8
        }
        else {
            Set-Content -Path $FilePath -Value $jsonLogEntry -Encoding UTF8
        }
    }
    else {
        # Write to console with appropriate stream based on log level
        switch ($Level.ToUpper()) {
            'DEBUG'   { Write-Verbose $jsonLogEntry }
            'INFO'    { Write-Information $jsonLogEntry -InformationAction Continue }
            'WARNING' { Write-Warning $jsonLogEntry }
            'ERROR'   { Write-Error $jsonLogEntry }
            'FATAL'   { Write-Error $jsonLogEntry }
        }
    }
}

#endregion

# Export public functions
Export-ModuleMember -Function @(
    'Write-JsonLog',
    'Add-JsonLogEntry', 
    'Format-ExceptionForJson'
)