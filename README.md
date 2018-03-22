# Generate-RestoreScript
Simple PowerShell script to generate a restore script with relocation.

#SYNOPSIS
  Generate a restore script output with relocation
#DESCRIPTION
  This simple script generates a restore script output with relocation by getting the latest full backup information from your source sql instance and getting the default data and log path from destination.
#PARAMETER Source
    Source SQL Instance - The script will query msdb to get the latest full backup information.
#PARAMETER Destination
    Destination SQL Instance - The script gets the default data and log path from the destination server and generates a restore script output with relocation.
#INPUTS
  None
#OUTPUTS
  restore_yyyyMMddHHmmss.sql file is stored in the same path as the powershell script.
#NOTES
  Version:        1.0
  Author:         Daniel Berber
  Creation Date:  2018-03-22
  Purpose/Change: Easy way to generate restore script with relocation (WITH MOVE)
  
#EXAMPLE
  Generate-RestoreScript -Source SQLServerSource\Instance1 -Destination SQLServerDest\Instance1
