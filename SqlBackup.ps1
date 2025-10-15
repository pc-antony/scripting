# SqlBackup.ps1
#
# This script exports an Azure SQL Database to a BACPAC file in an Azure Blob Storage container using Managed Identity for authentication.
#
# Parameters:
# - resourcegroup: The name of the resource group containing the SQL server.
# - servername: The name of the SQL server.
# - databasename: The name of the database to export.
# - storageaccount: The name of the Azure Storage account. 
# - container: The name of the Blob Storage container where the BACPAC file will be stored.
# - aamanagedidentityresid: The resource ID of the Managed Identity with access to the Storage account.
# - sqlmanagedidentityresid: The resource ID of the Managed Identity with access to the SQL Database.
# - sqladminresid: The resource ID of the SQL Admininstrator User.
#
# Warning! The aamanagedidentityresid must reside in the database with the Backup Operator Role
# Example: 
#           CREATE USER "id-aa-sqlimst-pwc-vss-dev-uks-001" FROM EXTERNAL PROVIDER;
#           ALTER ROLE db_backupoperator ADD MEMBER "id-aa-sqlimst-pwc-vss-dev-uks-001";
#
# Note: Ensure that the Managed Identities have the necessary permissions on both the SQL Database and the Storage account.
#
#

param(
    [Parameter(Mandatory=$true)]
    [string]$resourcegroup,
    [Parameter(Mandatory=$true)]
    [string]$servername,
    [Parameter(Mandatory=$true)]
    [string]$databasename,
    [Parameter(Mandatory=$true)]
    [string]$storageaccount,
    [Parameter(Mandatory=$true)]
    [string]$container,
    [Parameter(Mandatory=$true)]
    [string]$aamanagedidentityresid,
    [Parameter(Mandatory=$true)]
    [string]$sqlmanagedidentityresid,
    [Parameter(Mandatory=$true)]
    [string]$sqladminresid
)

Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
Install-Module Az.Sql -Repository PSGallery -Force
Import-Module Az.Sql

$timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
$bacpacName = "$databasename-$timestamp.bacpac"
$storageUri = "https://$storageaccount.blob.core.windows.net/$container/$bacpacName"
$aaidentityName = Split-Path $aamanagedidentityresid -Leaf
$dbidentityName = Split-Path $sqlmanagedidentityresid -Leaf

Write-Output "Connecting to Managed Identity: $aaidentityName"

# Authenticate with Managed Identity
Connect-AzAccount -Identity -AccountId $aamanagedidentityresid | Out-Null

Write-Output "Exporting $databasename to $storageUri using SQL Administrator Credentials: $dbidentityName"

# Start export using managed identity
$exportJob = New-AzSqlDatabaseExport `
  -ResourceGroupName $resourcegroup `
  -ServerName $servername `
  -DatabaseName $databasename `
  -StorageKeyType "ManagedIdentity" `
  -StorageKey $sqlmanagedidentityresid `
  -StorageUri $storageUri `
  -AdministratorLogin $sqlmanagedidentityresid `
  -AuthenticationType ManagedIdentity `
  -ErrorAction SilentlyContinue `
  -ErrorVariable bkuperr

if($exportJob) {
  Write-Output "Export started."
} else {
  # Something has gone wrong with the execution of the command
  Write-Error "Failed to start export due to an problem with issuing the AzSqlDatabaseExport command. Error details: $($bkuperr)"
  Disconnect-AzAccount | Out-Null
  Write-Output "Disconnected from Managed Identity session."
  exit 1
}

# Monitor the export status
Write-Output "Monitoring export status..."
$JobCompleted = $false
while($JobCompleted -eq $false) {
  Start-Sleep -Seconds 30
  $exportStatus = Get-AzSqlDatabaseImportExportStatus `
    -OperationStatusLink $exportJob.OperationStatusLink `
    -ErrorVariable bkuperr `
    -ErrorAction SilentlyContinue
  if($exportStatus.Status -ne "InProgress") {
    $JobCompleted = $true 
  } else {
    Write-Output "Export Stage: $($exportStatus.Status). Current status: $($exportStatus.StatusMessage)"
  }
}

if($exportStatus.Status -eq "Succeeded") {
  Write-Output "Export completed successfully."
} else {
  Write-Error "Export failed with status: $($exportStatus.Status). Error details: $($bkuperr)"
}
# Disconnect the session
Disconnect-AzAccount | Out-Null
Write-Output "Disconnected from $($aaidentityName) Managed Identity session."
