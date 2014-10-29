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
