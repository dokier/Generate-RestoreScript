<#
.SYNOPSIS
  Generate a restore script output with relocation
.DESCRIPTION
  This simple script generates a restore script output with relocation by getting the latest full backup information from your source sql instance
  and getting the default data and log path from destination.
.PARAMETER Source
    Source SQL Instance - The script will query msdb to get the latest full backup information.
.PARAMETER Destination
    Destination SQL Instance - The script gets the default data and log path from the destination server and generates a restore script output with relocation.
.INPUTS
  None
.OUTPUTS
  restore_yyyyMMddHHmmss.sql file is stored in the same path as the powershell script.
.NOTES
  Version:        1.0
  Author:         Daniel Berber
  Creation Date:  2018-03-22
  Purpose/Change: Easy way to generate restore script with relocation (WITH MOVE)
  
.EXAMPLE
  Generate-RestoreScript -Source SQLServerSource\Instance1 -Destination SQLServerDest\Instance1
#>

#---------------------------------------------------------[Parameters]------------------------------------------------------------

param([string]$Source,
      [string]$Destination)

#---------------------------------------------------------[Initializations]-------------------------------------------------------
    
#Generate output path in the same location as the script
$Path = (Get-Item -Path ".\" -Verbose).FullName
$DateTime = (Get-Date -Format "yyyyMMddHHmmss")
$OutputFile = $Path+"\restore_$DateTime.sql"

#Get SMO Assembly version in the environment. Discrepancies generate errors with Smo.RelocateFile
$sqlServerSnapinVersion = (Get-Command Restore-SqlDatabase).ImplementingType.Assembly.GetName().Version.ToString()

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Get Last Full Backup from Source SQL Instance
$LastBackup = Invoke-sqlcmd -ServerInstance $Source -Database msdb -Query "WITH LastBackUp AS
(
SELECT  bs.database_name,
        bs.backup_size,
        bs.backup_start_date,
        bmf.physical_device_name,
        Position = ROW_NUMBER() OVER( PARTITION BY bs.database_name ORDER BY bs.backup_start_date DESC )
FROM  msdb.dbo.backupmediafamily bmf
JOIN msdb.dbo.backupmediaset bms ON bmf.media_set_id = bms.media_set_id
JOIN msdb.dbo.backupset bs ON bms.media_set_id = bs.media_set_id
WHERE   bs.[type] = 'D'
--AND bs.is_copy_only = 0
)
SELECT 
        sd.name AS [Database],
        CAST(backup_size / 1048576 AS DECIMAL(10, 2) ) AS [BackupSizeMB],
        backup_start_date AS [Last Full DB Backup Date],
        physical_device_name AS [BackupFileLocation]
FROM sys.databases AS sd
LEFT JOIN LastBackUp AS lb
    ON sd.name = lb.database_name
    AND Position = 1
	where sd.database_id > 4
ORDER BY [Database]" 

 #Connect to Destination using Windows Authentication via SMO
 $smoserver = new-object Microsoft.SqlServer.Management.Smo.Server $Destination;
 #Get Data & Log Path from Destination using SMO
 $DataPath = $smoserver.Settings.DefaultFile;
 $LogPath = $smoserver.Settings.DefaultLog;


 $LastBackup | ForEach-Object { 
     
     $smoRestore = new-object("Microsoft.SqlServer.Management.Smo.Restore") 

     $backupDeviceItem = new-object Microsoft.SqlServer.Management.Smo.BackupDeviceItem $_.BackupFileLocation, 'File';
     
     $smoRestore.Devices.Add($backupDeviceItem)

     foreach ($dbfile in $smoRestore.ReadFileList($smoserver)){

     $smoRestoreDBFile = New-Object("Microsoft.SqlServer.Management.Smo.RelocateFile")
     $smoRestoreLogFile = New-Object("Microsoft.SqlServer.Management.Smo.RelocateFile")

     $DBFileName = $dbfile.PhysicalName | Split-Path -Leaf
        if($dbfile.Type -eq 'L'){
            $newfile = [System.IO.Path]::Combine( $LogPath, $DBFileName)
            $smoRestoreLogFile.LogicalFileName = $dbfile.LogicalName
            $smoRestoreLogFile.PhysicalFileName = $newfile
            $smoRestore.RelocateFiles.Add($smoRestoreLogFile) | Out-Null
            } 
        else {
            $newfile = [System.IO.Path]::Combine( $DataPath, $DBFileName)
            $smoRestoreDBFile.LogicalFileName = $dbfile.LogicalName
            $smoRestoreDBFile.PhysicalFileName = $newfile
            $smoRestore.RelocateFiles.Add($smoRestoreDBFile) | Out-Null
            }
        }
            Restore-SqlDatabase -ServerInstance $Destination -Database $_.Database -RelocateFile $smoRestore.RelocateFiles -BackupFile $_.BackupFileLocation -RestoreAction Database -Script | Out-File -Append $OutputFile
    }
