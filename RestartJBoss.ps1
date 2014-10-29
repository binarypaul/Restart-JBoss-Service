<#  
.SYNOPSIS  
    Restarts JBOSS Service
.DESCRIPTION  
    Stops JBOSS Service, JBoss EAP 6.2
    Verifies no Java processes running
    Backs up the log back.log.bak
    Starts JBOSS Service
    Verifies the log contains proper data
    Sends email on status of JBoss server

    -v1.0 - Created
    -v1.1 - Added variable for process name, functions to verify log and query process, and code in execution to ensure no java processes are running to support the 
        JBoss server is stopped and to ensure that the log contains data that validates the JBoss server is running. Remove function GetDate, it did not serve purpose
    -v1.2 - Updated emails and IPs
    
.NOTES  
    File Name       :   restartJBOSS.ps1  
    Author          :   Paul Lizer, paul@bianryinterrupt.com
    Prerequisite    :   PowerShell V1
    Version         :   1.1 (2014 10 29)     
#>

<#***************************************************
                       Variables
***************************************************#>

# Service that is being restarted
    $strServiceDisplayName = "JBoss EAP 6.2"
    $strServiceName = "JBOSSEAP62SVC"
# Process that is being monitored
    $strProcessName = "Java"
# Location of the log file that is being renamed
    $strLogLocation = "E:\appian\bin\jboss\jboss-eap-6.2\standalone\log\"
    $strLogName = "server"
    $strLogType = ".log"
# Log Date
    $dateLog = get-date -UFormat "%Y%m%d%H%M%S"
# Emails
    $strEmailTo = "first.last@domain.com"
    $strEmailFrom = "Name <first.last@domain.com>"
    $strEmailErrorTo = "first.last@domain.com"
    
# STMP server IP Address
    $smtpServer = "000.000.000.000"
# Wait times in seconds
    $intStopWait = 300
    $intStartWait = 900

# Get Computer Name 
    $objComputer = get-childitem env:computername
    $strComputerName = $objComputer.Value

<#***************************************************
                       Functions
-----------------------------------------------------
LogToConsole ($bolTimeStamp, $strStyle, $strTempColor, $strStatement)
TitleBar ($strServiceName, $strServiceStatus, $strStatement)
GetTime return $strTime
RenameLog
VerifyLog return $strLogVerified
Email ($emailSubject, $emailBody)
StartService ($strServiceName)
StopService ($strServiceName)
QueryService ($strServiceName) return $objService.Status
QueryProcess ($strProcessName) return $strProcessStatus

***************************************************#>

Function LogToConsole ($bolTimeStamp, $strStyle, $strTempColor, $strStatement) {
    <#----------------------
        Updates the Console window
    -----------------------#>
    
    # Set console font color to white
        $strOriginalColor = "White"

    # If color is requested then perform color change
        If ($strTempColor){
            # Changes font color in console window to let user know of status
                $host.ui.RawUI.ForegroundColor = $strTempColor
        }

        # If timestamp is requested then add time
            If ($bolTimeStamp -eq "Yes") {
                [string]$strTime = GetTime
                $strStatement = ($strTime + ": " + $strStatement)
            }
        # Send statement to console
            Write-Host $strStatement
        # Return console font color to original
            $host.ui.RawUI.ForegroundColor = $strOriginalColor  
}

Function TitleBar ($strServiceName, $strServiceStatus, $strStatement){
    <#----------------------
        Updates console title bar
    -----------------------#>

    # Update the title bar
        $host.ui.rawui.WindowTitle="Server: "+ $strComputerName + ", Service Name: " + $strServiceName + ", Service Status: " + $strServiceStatus + ", Performing: " + $strStatement
}

Function TitleBarCountDown ($intWait, $intCount, $strStatement){
    <#----------------------
        Updates console title bar
    -----------------------#>

    # Update the title bar
        $host.ui.rawui.WindowTitle="Total wait "+ $intWait + " seconds. " + $intCount + ", seconds remain. " + $strStatement
}


Function GetTime {
    <#----------------------
        Determines the time
    -----------------------#>

    # Time for log file creation and logging
        $strTime = Get-Date -displayhint Time                
    # Returns the time
        return $strTime  

}

Function RenameLog {
    <#----------------------
        Renames the log
    -----------------------#>

    # Tests to ensure the log exists
        $testPath = Test-Path ($strLogLocation + $strLogName + $strLogType)
        LogToConsole "Yes" "" "White" ("Test if log exists: " + $testPath)
        # If the log exists then perform steps required to rename it
            If ($testPath) {
                # Test if renamed file exists
                    $testPath = Test-Path ($strLogLocation + $strLogName + "-" + $dateLog + $strLogType)
                    LogToConsole "Yes" "" "White" ("Test if log exists: " + $testPath)
                    # While the log is not update continue to try to update it
                        While (!$testPath) {
                            # Rename the log
                                Rename-Item -path ($strLogLocation + $strLogName + $strLogType) -newname ($strLogName + "-" + $dateLog + $strLogType)
                            # Test if rename was successful
                                $testPath = Test-Path ($strLogLocation + $strLogName + "-" + $dateLog + $strLogType)
                            # If file renamed succesfully log to console
                                If ($testPath) {
                                    LogToConsole "Yes" "" "Green" ("Rename " + $strLogLocation + $strLogName + $strLogType + " to " + $strLogName + "-" + $dateLog + $strLogType)
                        }   
            } Else {
                Email "$strComputerName Log does not exist" "Unable to rename log as it does not exist on $strComputerName" $True
                LogToConsole "Yes" "" "Red" "Log does not exist"
            }

}

Function VerifyLog {
    <#----------------------
        Verifies the log contains the proper data validating the JBoss server is running
    -----------------------#>

    # Tests to ensure the log exists
        $testPath = Test-Path ($strLogLocation + $strLogName + $strLogType)
        LogToConsole "Yes" "" "White" ("Test if log exists: " + $testPath)
        # If the log exists then perform steps to verify content
            If ($testPath) {
                # Review content of the file for select string
                    $strLogContent = Get-Content ($strLogLocation + $strLogName + $strLogType) | Select-String -Pattern "Started 1299 of 1391 services"
                # If content existed update verified string and log to console
                    If ($strLogContent) {
                        $strLogVerified = $True
                        LogToConsole "Yes" "" "Green" "Log contents verifed. JBoss server started successfully."
                    } Else {
                        $strLogVerified = $False
                        LogToConsole "Yes" "" "Yellow" "Log contents not verifed. JBoss server has not started."
                    }

            } Else {
                # If the file doesn't exist yet, it is clearly not verified, update console and verified variable
                    $strLogVerified = $False
                    LogToConsole "Yes" "" "Yellow" "Log does not exist"
            }
        # return variable to exection
            return $strLogVerified

}

Function Email ($emailSubject, $emailBody, $emailError) {
    <#----------------------
        Sends emails
    -----------------------#>
    
    # If email is an error message, send to error email personnel
        If ($emailError) {
                $emailTo = $strEmailErrorTo
        } Else {
                $emailTo = $strEmailTo
        }
    # Try to send the email, if problem occurs capture error and log it to console
        Try {
            # Send email
                Send-Mailmessage -to $emailTo -from $strEmailFrom -subject $emailSubject -body $emailBody -dno onSuccess, onFailure -smtpServer $smtpServer
        }
        Catch {
            # Grab error message
                $ErrorMessage = $_.Exception.Message
            # Log error to console
                LogToConsole "Yes" "" "Red" "Email Delivery Failed. Error Message is $ErrorMessage"

        }
        Finally {
            # Log success to console
                LogToConsole "Yes" "" "Green" "Email Delivery Success"
        }
}

Function StartService ($strServiceName) {
    <#----------------------
        Starts servives
    -----------------------#>

    # Try to start service, if problem occurs email error to troubleshooting personnel
        Try {
            # Start the service
                Start-Service $strServiceName
        }
        Catch {
            # Grab error message
                $ErrorMessage = $_.Exception.Message
            # Grab error name
                $FailedItem = $_.Exception.ItemName
            # Email error
                Email "$strComputerName, JBoss Start Service Failed" "$strComputerName Start Service failed: $FailedItem. The error message was $ErrorMessage" $True
            # Stop PowerShell
                Break
        }
        Finally {
            # Log to console successful service start
                LogToConsole "Yes" "" "Green" "Service Started"
        }
}

Function StopService ($strServiceName) {
    <#----------------------
        Stops services
    -----------------------#>

    # Try to stop service, if problem occurs email error to troubleshooting personnel
        Try {
            # Stop the service
                Stop-Service $strServiceName
        }
        Catch {
            # Grab error message
                $ErrorMessage = $_.Exception.Message
            # Grab error name
                $FailedItem = $_.Exception.ItemName
            # Email error
                Email "$strComputerName, JBoss Stop Service Failed" "$strComputerName Stop Service failed: $FailedItem. The error message was $ErrorMessage" $True
            # Stop PowerShell
                Break
        }
        Finally {
            # Log to console successful service stop
                LogToConsole "Yes" "" "Green" "Service Stopping"
        }
}

Function QueryService ($strServiceName) {
    <#----------------------
        Query service to get status
    -----------------------#>

    # Try to query the service, if problem occurs email error to troubleshooting personnel
        Try {
            # Get the status of the service
                $objService = Get-Service | Where-Object {$_.Name -eq $strServiceName}
        }
        Catch {
            # Grab error message
                $ErrorMessage = $_.Exception.Message
            # Grab error name
                $FailedItem = $_.Exception.ItemName
            # Email error
                Email "$strComputerName, JBoss Query Service Failed" "$strComputerName Query Service failed: $FailedItem. The error message was $ErrorMessage" $True
            # Stop PowerShell
                Break
        } 

        # return the stauts of the service
                return $objService.Status
}

Function QueryProcess ($strProcessName) {
    <#----------------------
        Query process to get status
    -----------------------#>

    # Try to query the process, if problem occurs email error to troubleshooting personnel
        Try {
            # Get the status of the process
                $objProcess = Get-Process $strProcessName
        }
        Catch {
            # Grab error message
                $ErrorMessage = $_.Exception.Message
            # Grab error name
                $FailedItem = $_.Exception.ItemName
            # Email error
                Email "$strComputerName, Java Query Process Failed" "$strComputerName Java Query Process failed: $FailedItem. The error message was $ErrorMessage" $True
            # Stop PowerShell
                Break
        } 

        # Sets the process status
            If ($objProcess){
                $strProcessStatus = "Exists"
            } Else {
                $strProcessStatus = "Does not Exist"
            }

        # return the status of the process
            return $strProcessStatus
}

<#***************************************************
                       Execution
***************************************************#>

<#----------------------
    Stopping Service
-----------------------#>
    # Determine Status of the Service
        $strServiceStatus = QueryService $strServiceName
    # Log status to console and update Title bar
        LogToConsole "Yes" "" "White" ("Service: " + $strServiceName + " is " + $strServiceStatus)
        TitleBar $strServiceName $strServiceStatus "Stopping Service"
    # If the service is running, stop it
        If ($strServiceStatus -eq "Running"){
            # Determine if the Java Process is running
                $strProcessStatus = QueryProcess $strProcessName
            # Log status to console
                LogToConsole "Yes" "" "White" ("Process: " + $strProcessName + " " + $strProcessStatus)
            # Keep trying to stop the JBoss service while Java Processes exist
                While ($strProcessStatus -eq "Exists") {
                    # Keep trying to stop it every 60 seconds until it is stopped
                        While ($strServiceStatus -ne "Stopped"){
                            # Stop service
                                StopService $strServiceName
                            # Loop to update the titlebar and wait while the Service and Server stops
                                for ($x = 0; $x -le $intStopWait; $x++){
                                    # Wait 15 minutes
                                        Start-Sleep -s 1
                                        TitleBarCountDown $intStopWait ($intStopWait - $x) ("Stopping " + $strServiceName)
                                }
                            # Qeury service
                                $strServiceStatus = QueryService $strServiceName
                            # Log status to console and update title bar
                                LogToConsole "Yes" "" "White" ("Service: " + $strServiceName + " is " + $strServiceStatus)
                                TitleBar $strServiceName $strServiceStatus "Stopping Service"
                        }

                    # Determine if the Java Process is running
                        $strProcessStatus = QueryProcess $strProcessName
                    # Log status to console
                        LogToConsole "Yes" "" "White" ("Process: " + $strProcessName + " " + $strProcessStatus)
                }
        } Else {
            # Log status to console and update title bar
                LogToConsole "Yes" "" "Yellow" "Service already stopped. Moving on to next step: renaming log."  
        }

<#----------------------
    Renaming Log
-----------------------#> 
    # Rename the log
        RenameLog

<#----------------------
    Starting Service
-----------------------#>
    # Determine status of service
        $strServiceStatus = QueryService $strServiceName
    # Log status to console and title bar
        LogToConsole "Yes" "" "White" ("Service: " + $strServiceName + "is " + $strServiceStatus)
        TitleBar $strServiceName $strServiceStatus "Starting Service"

    # If service is stopped, start it
        If ($strServiceStatus -eq "Stopped"){
            # Verify log contents
                $strLogVerified = VerifyLog
            # Log status to console
                LogToConsole "Yes" "" "White" ("Log Verified: " + $strLogVerified)
            # Keep verifying log content until it is validated
                While ($strLogVerified -eq $False) {
                    # Keep trying to start the service every 60 seconds until it is running
                        While ($strServiceStatus -ne "Running"){
                            # Start service
                                StartService $strServiceName
                            # Loop to update the titlebar and wait while the Service and Server starts
                                for ($x = 0; $x -le $intStartWait; $x++){
                                    # Wait 15 minutes
                                        Start-Sleep -s 1
                                        TitleBarCountDown $intStartWait ($intStartWait - $x) ("Starting " + $strServiceName)
                                }
                            # Query service
                                $strServiceStatus = QueryService $strServiceName
                            # Log status to console and title bar
                                LogToConsole "Yes" "" "White" ("Service: " + $strServiceName + "is " + $strServiceStatus)
                                TitleBar $strServiceName $strServiceStatus "Starting Service"
                        }

                    # Verify log contents
                        $strLogVerified = VerifyLog
                    # Log status to console
                        LogToConsole "Yes" "" "White" ("Log Verified: " + $strLogVerified)
                }
        } Else {
            # Log status to console
                LogToConsole "Yes" "" "Yellow" "Service already started. Moving on to next step: emailing status."  

        }

<#----------------------
    Emailing Status
-----------------------#>
    # Update title bar
        TitleBar $strServiceName $strServiceStatus "Emailing Status"
    If (($strServiceStatus -eq "Running") -and ($strLogVerified -eq $True)) {
        # Log Name 
            $strLog = ($strLogName + "-" + $dateLog + $strLogType)
        # Email status of service and steps performed 
            Email "$strComputerName $strServiceDisplayName Service Restarted Successfully" "$strServiceDisplayName Service is running. Server.log.bak file renamed to $strLog."
        # Log status to console
            LogToConsole "Yes" "" "Green" "$strComputerName $strServiceDisplayName Service Restarted Successfully."  
    } Else {
        # Email status of service and steps performed 
            Email "$strComputerName $strServiceDisplayName Service Failed to Restart" "Review server $strComputerName and ensure $strServiceDisplayName is running."
        # Log status to console
            LogToConsole "Yes" "" "Red" "$strComputerName $strServiceDisplayName Service Failed to Restart."  
    }