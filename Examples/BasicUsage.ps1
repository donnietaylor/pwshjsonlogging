# Basic Usage Examples for PwshJsonLogging Module

# Import the module
Import-Module ../PwshJsonLogging.psd1 -Force

Write-Host "PwshJsonLogging Basic Usage Examples" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Example 1: Simple logging
Write-Host "`nExample 1: Simple Info Log" -ForegroundColor Yellow
Write-JsonLog -Level "Info" -Message "Application started successfully"

# Example 2: Warning with structured data
Write-Host "`nExample 2: Warning with Structured Data" -ForegroundColor Yellow
$userData = @{
    UserId = 12345
    Username = "john.doe"
    Action = "Login"
    Timestamp = Get-Date
    Success = $true
}
Write-JsonLog -Level "Warning" -Message "User authentication completed" -Data $userData

# Example 3: Error with exception
Write-Host "`nExample 3: Error with Exception" -ForegroundColor Yellow
try {
    # Simulate an error
    Get-Content "NonExistentFile.txt" -ErrorAction Stop
}
catch {
    Write-JsonLog -Level "Error" -Message "File operation failed" -Exception $_.Exception -Source "FileReader"
}

# Example 4: File logging
Write-Host "`nExample 4: File Logging" -ForegroundColor Yellow
$logFile = "/tmp/example-app.log"

# Log to file
Write-JsonLog -Level "Info" -Message "Starting batch process" -FilePath $logFile -Source "BatchProcessor"

# Append to file
$processData = @{
    BatchId = "batch-001"
    RecordsProcessed = 1000
    Duration = "00:02:30"
}
Write-JsonLog -Level "Info" -Message "Batch processing completed" -Data $processData -FilePath $logFile -Append -Source "BatchProcessor"

Write-Host "Log file created: $logFile" -ForegroundColor Cyan
Write-Host "Contents:" -ForegroundColor Cyan
Get-Content $logFile | ForEach-Object { Write-Host $_ -ForegroundColor White }

# Clean up
Remove-Item $logFile -ErrorAction SilentlyContinue

# Example 5: Complex scenario with multi-line exception
Write-Host "`nExample 5: Complex Multi-line Exception" -ForegroundColor Yellow
$complexError = @"
Failed to process user request.
Error details:
- Invalid user ID format
- Database connection timeout
- Retry limit exceeded
Contact system administrator for assistance.
"@

try {
    throw [System.InvalidOperationException]::new($complexError)
}
catch {
    $requestContext = @{
        RequestId = "req-789-xyz"
        UserId = "invalid-user-123"
        Endpoint = "/api/users/profile"
        Method = "GET"
        ClientIP = "192.168.1.50"
        UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }
    
    Write-JsonLog -Level "Fatal" -Message "Critical request processing failure" -Data $requestContext -Exception $_.Exception -Source "UserController"
}

# Example 6: Log level filtering
Write-Host "`nExample 6: Log Level Filtering" -ForegroundColor Yellow
Write-Host "Setting minimum level to 'Warning' - Debug and Info messages will be filtered out" -ForegroundColor Cyan

Write-JsonLog -Level "Debug" -Message "This debug message will not appear" -MinimumLevel "Warning"
Write-JsonLog -Level "Info" -Message "This info message will not appear" -MinimumLevel "Warning"
Write-JsonLog -Level "Warning" -Message "This warning message will appear" -MinimumLevel "Warning"
Write-JsonLog -Level "Error" -Message "This error message will appear" -MinimumLevel "Warning"

Write-Host "`n✅ All examples completed!" -ForegroundColor Green