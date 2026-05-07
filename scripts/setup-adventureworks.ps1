$secpw = ConvertTo-SecureString 'demo!pass123' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential('.\sqladmin', $secpw)

# Grant SYSTEM sysadmin via sqladmin PSSession
try {
    $sb = {
        sqlcmd -E -Q "ALTER SERVER ROLE sysadmin ADD MEMBER [NT AUTHORITY\SYSTEM]"
    }
    $session = New-PSSession -ComputerName localhost -Credential $cred -ErrorAction Stop
    Invoke-Command -Session $session -ScriptBlock $sb
    Remove-PSSession $session
    Start-Sleep -Seconds 2
    Write-Output "SYSTEM granted sysadmin"
} catch {
    Write-Output "PSSession failed: $_"
}

# Restore AdventureWorks
$restore = "RESTORE DATABASE [AdventureWorks2022] FROM DISK = N'C:\SQLData\AdventureWorks2022.bak' WITH MOVE N'AdventureWorks2022' TO N'C:\SQLData\AdventureWorks2022.mdf', MOVE N'AdventureWorks2022_log' TO N'C:\SQLData\AdventureWorks2022_log.ldf', REPLACE"
sqlcmd -E -Q $restore -t 120
Write-Output "RESTORE_COMPLETE"
sqlcmd -E -Q "SELECT name, state_desc FROM sys.databases"
