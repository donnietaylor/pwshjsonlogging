BeforeAll {
    # Import the module to test
    $ModulePath = Join-Path $PSScriptRoot '..' 'PwshJsonLogging.psd1'
    Import-Module $ModulePath -Force
}

Describe "PwshJsonLogging Module Tests" {
    
    Context "Module Import" {
        It "Should import the module successfully" {
            Get-Module PwshJsonLogging | Should -Not -BeNullOrEmpty
        }
        
        It "Should export the expected functions" {
            $commands = Get-Command -Module PwshJsonLogging
            $commands.Name | Should -Contain "Write-JsonLog"
            $commands.Name | Should -Contain "Add-JsonLogEntry"
            $commands.Name | Should -Contain "Format-ExceptionForJson"
        }
    }
    
    Context "Format-ExceptionForJson" {
        It "Should format a simple exception correctly" {
            try {
                throw "Test exception message"
            }
            catch {
                $formattedException = Format-ExceptionForJson -Exception $_.Exception
                
                $formattedException.Message | Should -Be "Test exception message"
                $formattedException.Type | Should -Be "System.Management.Automation.RuntimeException"
                $formattedException | Should -HaveProperty "StackTrace"
                $formattedException | Should -HaveProperty "HResult"
            }
        }
        
        It "Should handle exceptions with inner exceptions" {
            try {
                try {
                    throw "Inner exception"
                }
                catch {
                    throw "Outer exception"
                }
            }
            catch {
                $formattedException = Format-ExceptionForJson -Exception $_.Exception
                
                $formattedException.Message | Should -Be "Outer exception"
                $formattedException | Should -HaveProperty "InnerException"
                $formattedException.InnerException.Message | Should -Be "Inner exception"
            }
        }
        
        It "Should handle ArgumentException with ParamName" {
            try {
                throw [System.ArgumentException]::new("Invalid argument", "testParam")
            }
            catch {
                $formattedException = Format-ExceptionForJson -Exception $_.Exception
                
                $formattedException.Message | Should -Match "Invalid argument"
                $formattedException.Type | Should -Be "System.ArgumentException"
                $formattedException | Should -HaveProperty "ParamName"
                $formattedException.ParamName | Should -Be "testParam"
            }
        }
    }
    
    Context "Add-JsonLogEntry" {
        It "Should create a basic JSON log entry" {
            $jsonLog = Add-JsonLogEntry -Level "Info" -Message "Test message"
            $logObject = $jsonLog | ConvertFrom-Json
            
            $logObject.Level | Should -Be "INFO"
            $logObject.Message | Should -Be "Test message"
            $logObject | Should -HaveProperty "Timestamp"
            $logObject.Timestamp | Should -Match "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"
        }
        
        It "Should include structured data when provided" {
            $testData = @{
                UserId = 123
                Action = "Login"
                Success = $true
            }
            
            $jsonLog = Add-JsonLogEntry -Level "Info" -Message "User login" -Data $testData
            $logObject = $jsonLog | ConvertFrom-Json
            
            $logObject | Should -HaveProperty "Data"
            $logObject.Data.UserId | Should -Be 123
            $logObject.Data.Action | Should -Be "Login"
            $logObject.Data.Success | Should -Be $true
        }
        
        It "Should include source when provided" {
            $jsonLog = Add-JsonLogEntry -Level "Debug" -Message "Debug message" -Source "TestFunction"
            $logObject = $jsonLog | ConvertFrom-Json
            
            $logObject | Should -HaveProperty "Source"
            $logObject.Source | Should -Be "TestFunction"
        }
        
        It "Should include formatted exception when provided" {
            try {
                throw "Test exception for logging"
            }
            catch {
                $jsonLog = Add-JsonLogEntry -Level "Error" -Message "Error occurred" -Exception $_.Exception
                $logObject = $jsonLog | ConvertFrom-Json
                
                $logObject | Should -HaveProperty "Exception"
                $logObject.Exception.Message | Should -Be "Test exception for logging"
                $logObject.Exception | Should -HaveProperty "Type"
                $logObject.Exception | Should -HaveProperty "StackTrace"
            }
        }
        
        It "Should validate log levels" {
            { Add-JsonLogEntry -Level "InvalidLevel" -Message "Test" } | Should -Throw
        }
    }
    
    Context "Write-JsonLog" {
        BeforeEach {
            $TestLogFile = Join-Path $TestDrive "test.log"
        }
        
        It "Should write to file when FilePath is specified" {
            Write-JsonLog -Level "Info" -Message "Test file logging" -FilePath $TestLogFile
            
            $TestLogFile | Should -Exist
            $logContent = Get-Content $TestLogFile | ConvertFrom-Json
            $logContent.Message | Should -Be "Test file logging"
            $logContent.Level | Should -Be "INFO"
        }
        
        It "Should append to file when Append switch is used" {
            Write-JsonLog -Level "Info" -Message "First message" -FilePath $TestLogFile
            Write-JsonLog -Level "Warning" -Message "Second message" -FilePath $TestLogFile -Append
            
            $logLines = Get-Content $TestLogFile
            $logLines.Count | Should -Be 2
            
            $firstLog = $logLines[0] | ConvertFrom-Json
            $secondLog = $logLines[1] | ConvertFrom-Json
            
            $firstLog.Message | Should -Be "First message"
            $secondLog.Message | Should -Be "Second message"
        }
        
        It "Should respect minimum log level filtering" {
            $TestLogFile = Join-Path $TestDrive "debug-filter-test.log"
            Write-JsonLog -Level "Debug" -Message "Debug message" -FilePath $TestLogFile -MinimumLevel "Info"
            
            $TestLogFile | Should -Not -Exist
        }
        
        It "Should log messages at or above minimum level" {
            Write-JsonLog -Level "Warning" -Message "Warning message" -FilePath $TestLogFile -MinimumLevel "Info"
            
            $TestLogFile | Should -Exist
            $logContent = Get-Content $TestLogFile | ConvertFrom-Json
            $logContent.Message | Should -Be "Warning message"
            $logContent.Level | Should -Be "WARNING"
        }
        
        It "Should validate log levels" {
            { Write-JsonLog -Level "InvalidLevel" -Message "Test" } | Should -Throw
        }
        
        It "Should validate minimum log levels" {
            { Write-JsonLog -Level "Info" -Message "Test" -MinimumLevel "InvalidLevel" } | Should -Throw
        }
    }
    
    Context "Integration Tests" {
        BeforeEach {
            $TestLogFile = Join-Path $TestDrive "integration.log"
        }
        
        It "Should handle complex logging scenario with all features" {
            $testData = @{
                RequestId = "req-123-456"
                UserAgent = "PowerShell/7.0"
                ResponseTime = 250.5
            }
            
            try {
                throw [System.ArgumentException]::new("Invalid request parameter", "requestId")
            }
            catch {
                Write-JsonLog -Level "Error" -Message "Request processing failed" -Data $testData -Exception $_.Exception -Source "RequestHandler" -FilePath $TestLogFile
            }
            
            $TestLogFile | Should -Exist
            $logContent = Get-Content $TestLogFile | ConvertFrom-Json
            
            # Verify all components are present
            $logContent.Level | Should -Be "ERROR"
            $logContent.Message | Should -Be "Request processing failed"
            $logContent.Source | Should -Be "RequestHandler"
            
            # Verify structured data
            $logContent.Data.RequestId | Should -Be "req-123-456"
            $logContent.Data.UserAgent | Should -Be "PowerShell/7.0"
            $logContent.Data.ResponseTime | Should -Be 250.5
            
            # Verify exception formatting
            $logContent.Exception.Message | Should -Match "Invalid request parameter"
            $logContent.Exception.Type | Should -Be "System.ArgumentException"
            $logContent.Exception.ParamName | Should -Be "requestId"
            $logContent.Exception | Should -HaveProperty "StackTrace"
            
            # Verify timestamp format
            $logContent.Timestamp | Should -Match "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"
        }
        
        It "Should handle multi-line exception messages properly in JSON" {
            $multiLineMessage = @"
This is a multi-line
exception message that
spans several lines
and should be properly
formatted in JSON
"@
            
            try {
                throw $multiLineMessage
            }
            catch {
                Write-JsonLog -Level "Fatal" -Message "Multi-line exception test" -Exception $_.Exception -FilePath $TestLogFile
            }
            
            $TestLogFile | Should -Exist
            $logContent = Get-Content $TestLogFile -Raw | ConvertFrom-Json
            
            $logContent.Exception.Message | Should -Be $multiLineMessage
            $logContent.Level | Should -Be "FATAL"
        }
    }
}

AfterAll {
    # Clean up
    Remove-Module PwshJsonLogging -Force -ErrorAction SilentlyContinue
}