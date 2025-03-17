[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "config/config.json"),
    
    [Parameter(Mandatory=$false)]
    [string]$ConnectionsPath = (Join-Path $PSScriptRoot "Connections.json"),
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentUrl,
    
    [Parameter(Mandatory=$false)]
    [switch]$Install,
    
    [Parameter(Mandatory=$false)]
    [switch]$Managed
)

function Write-Log {
    param ([string]$Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
}

function Initialize-Paths {
    $script:RootPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:ManagedZipPath = Join-Path $RootPath "Managed.zip"
    $script:UnmanagedZipPath = Join-Path $RootPath "Unmanaged.zip"
    $script:UnmanagedFolderPath = Join-Path $RootPath "Unmanaged"
    $script:CanvasAppSourcePath = Join-Path $RootPath "CanvasAppSrc"
    $script:ConfigFolder = Join-Path $RootPath "config"
}

function Test-Prerequisites {
    if (!(Test-Path $ConfigPath)) {
        throw "Configuration file not found at: $ConfigPath. Create config.json with: {'SolutionName': 'YourSolutionName'}"
    }
    
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($config.SolutionName)) {
        throw "SolutionName not found in configuration file"
    }
    return $config
}

function Test-ConnectionsJson {
    if (!(Test-Path $ConnectionsPath)) {
        Write-Log "Warning: Connections.json not found at: $ConnectionsPath. Connection IDs will not be updated."
        return $false
    }
    return $true
}

function Initialize-Directories {
    @($ManagedZipPath, $UnmanagedZipPath, $CanvasAppSourcePath, $UnmanagedFolderPath) | ForEach-Object {
        if (Test-Path $_) { Remove-Item $_ -Force -Recurse }
    }
    
    @($CanvasAppSourcePath, $ConfigFolder) | ForEach-Object {
        if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force }
    }
}

function Get-SolutionVersion {
    $now = Get-Date
    return "3.{0}.{1}.{2}" -f $now.ToString("yy"), 
                              $now.ToString("MMdd"), 
                              $now.ToString("HHmm")
}

function Export-Solutions-Parallel {
    param ([string]$SolutionName)
    
    # Create script blocks for managed and unmanaged exports
    $managedScriptBlock = {
        param ($SolutionName, $ZipPath)
        pac solution export --name $SolutionName --path $ZipPath --managed true
        # Return success status
        if (Test-Path $ZipPath) { return $true } else { return $false }
    }
    
    $unmanagedScriptBlock = {
        param ($SolutionName, $ZipPath)
        pac solution export --name $SolutionName --path $ZipPath --managed false
        # Return success status
        if (Test-Path $ZipPath) { return $true } else { return $false }
    }
    
    Write-Log "Starting parallel solution exports..."
    
    # Start both jobs concurrently
    $managedJob = Start-Job -ScriptBlock $managedScriptBlock -ArgumentList $SolutionName, $ManagedZipPath
    $unmanagedJob = Start-Job -ScriptBlock $unmanagedScriptBlock -ArgumentList $SolutionName, $UnmanagedZipPath
    
    # Show progress while jobs are running
    $jobsRunning = $true
    $spinner = @('|', '/', '-', '\')
    $spinnerIndex = 0
    
    while ($jobsRunning) {
        $statusMessage = "Exporting solutions $($spinner[$spinnerIndex]) "
        Write-Host -NoNewline "`r$statusMessage"
        
        Start-Sleep -Milliseconds 250
        $spinnerIndex = ($spinnerIndex + 1) % $spinner.Length
        
        # Check if all jobs are completed
        $jobsRunning = ($managedJob.State -eq 'Running') -or ($unmanagedJob.State -eq 'Running')
    }
    
    Write-Host ""  # Clear the spinner line
    
    # Wait for and receive the results
    $managedResult = Receive-Job -Job $managedJob -Wait
    $unmanagedResult = Receive-Job -Job $unmanagedJob -Wait
    
    # Clean up jobs
    Remove-Job -Job $managedJob, $unmanagedJob
    
    # Check results
    if (-not $managedResult) {
        Write-Log "Warning: Managed solution export may have failed"
    } else {
        Write-Log "Managed solution export completed"
    }
    
    if (-not $unmanagedResult) {
        Write-Log "Warning: Unmanaged solution export may have failed"
    } else {
        Write-Log "Unmanaged solution export completed"
    }
    
    # Verify files exist
    if (!(Test-Path $ManagedZipPath)) {
        throw "Managed solution export failed: File not found at $ManagedZipPath"
    }
    
    if (!(Test-Path $UnmanagedZipPath)) {
        throw "Unmanaged solution export failed: File not found at $UnmanagedZipPath"
    }
}

function Expand-CanvasApps {
    Get-ChildItem -Path "$UnmanagedFolderPath/CanvasApps" -Filter *.msapp -Recurse | ForEach-Object {
        $appSourcePath = Join-Path $CanvasAppSourcePath $_.BaseName
        Write-Log "Unpacking Canvas App: $($_.BaseName)"
        pac canvas unpack --msapp $_.FullName --sources $appSourcePath
    }
}

function New-DeploymentSettings {
    $devConfig = Join-Path $ConfigFolder "dev.json"
    pac solution create-settings -z $ManagedZipPath -s $devConfig
    
    @("test", "prod") | ForEach-Object {
        $targetConfig = Join-Path $ConfigFolder "$_.json"
        if (!(Test-Path $targetConfig)) {
            Write-Log "Creating $_.json..."
            Copy-Item -Path $devConfig -Destination $targetConfig
        }
    }
}

function Update-ConnectionReferences {
    param (
        [string]$ConnectionsJsonPath
    )
    
    if (!(Test-Path $ConnectionsJsonPath)) {
        Write-Log "Connections.json not found. Skipping connection reference updates."
        return
    }
    
    try {
        $connectionsData = Get-Content $ConnectionsJsonPath -Raw | ConvertFrom-Json
        
        # Process Test.json
        $testJsonPath = Join-Path $ConfigFolder "test.json"
        if (Test-Path $testJsonPath) {
            Write-Log "Updating connection references in test.json..."
            Update-ConnectionIds -ConfigFilePath $testJsonPath -ConnectionsData $connectionsData -Environment "Test"
        }
        
        # Process Prod.json
        $prodJsonPath = Join-Path $ConfigFolder "prod.json"
        if (Test-Path $prodJsonPath) {
            Write-Log "Updating connection references in prod.json..."
            Update-ConnectionIds -ConfigFilePath $prodJsonPath -ConnectionsData $connectionsData -Environment "Prod"
        }
    }
    catch {
        Write-Log "Error updating connection references: $_"
    }
}

function Update-ConnectionIds {
    param (
        [string]$ConfigFilePath,
        [PSCustomObject]$ConnectionsData,
        [string]$Environment
    )
    
    # Read the config file
    $configJson = Get-Content $ConfigFilePath -Raw | ConvertFrom-Json
    $modified = $false
    
    # Check if ConnectionReferences exists
    if ($configJson.ConnectionReferences) {
        foreach ($reference in $configJson.ConnectionReferences) {
            $connectorId = $reference.ConnectorId
            
            # Check if this connector ID exists in the connections data for this environment
            if ($ConnectionsData.$Environment.$connectorId) {
                $connectionId = $ConnectionsData.$Environment.$connectorId
                
                # Update the connection ID
                $reference.ConnectionId = $connectionId
                $modified = $true
                Write-Log "  Updated $($reference.LogicalName) with connection ID: $connectionId"
            }
        }
        
        # Save the updated config file if changes were made
        if ($modified) {
            $configJson | ConvertTo-Json -Depth 20 | Set-Content $ConfigFilePath
            Write-Log "  Saved updated connection references to $ConfigFilePath"
        }
        else {
            Write-Log "  No matching connection references found to update in $ConfigFilePath"
        }
    }
    else {
        Write-Log "  No ConnectionReferences found in $ConfigFilePath"
    }
}

function Install-Solution {
    param (
        [string]$SolutionPath, 
        [string]$EnvironmentUrl,
        [string]$SolutionType = "Unmanaged"
    )
    
    if (-not (Test-Path $SolutionPath)) {
        throw "Solution file not found at: $SolutionPath"
    }
    
    # Check if environment URL is provided and valid
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
        if (-not ($EnvironmentUrl -match '^https:\/\/[a-zA-Z0-9.-]+\.dynamics\.com$')) {
            throw "Invalid Environment URL format: $EnvironmentUrl"
        }
        
        Write-Log "Importing $SolutionType solution to $EnvironmentUrl..."
    } else {
        Write-Log "Importing $SolutionType solution to current authenticated environment..."
    }
    
    # Build import command based on environment URL
    $importCommand = if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
        "pac solution import -f -a -pc -p `"$SolutionPath`""
    } else {
        "pac solution import -f -a -pc -p `"$SolutionPath`""
    }
    
    # Execute import command
    $importResult = Invoke-Expression $importCommand 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Solution import failed: $importResult"
    }
    
    Write-Log "Successfully imported $SolutionType solution"
}

try {
    Initialize-Paths
    
    if ($Install) {
        # Set appropriate solution path and type based on the Managed flag
        $solutionType = if ($Managed) { "Managed" } else { "Unmanaged" }
        $solutionPath = if ($Managed) { $ManagedZipPath } else { $UnmanagedZipPath }
        $isManagedFlag = if ($Managed) { "true" } else { "false" }
        
        # Check if solution exists
        if (!(Test-Path $solutionPath)) {
            # Try to export solution if it doesn't exist
            Write-Log "$solutionType solution package not found. Attempting to export..."
            $config = Test-Prerequisites
            
            # Create solution export job
            $exportScriptBlock = {
                param ($SolutionName, $ZipPath, $IsManagedFlag)
                pac solution export --name $SolutionName --path $ZipPath --managed $IsManagedFlag
                if (Test-Path $ZipPath) { return $true } else { return $false }
            }
            
            $exportJob = Start-Job -ScriptBlock $exportScriptBlock -ArgumentList $config.SolutionName, $solutionPath, $isManagedFlag
            Write-Log "Exporting $solutionType solution..."
            $null = Receive-Job -Job $exportJob -Wait
            Remove-Job -Job $exportJob
            
            if (!(Test-Path $solutionPath)) {
                throw "Failed to export $solutionType solution. Please run the script without -Install first to generate the solution packages."
            }
        }
        
        Install-Solution -SolutionPath $solutionPath -EnvironmentUrl $EnvironmentUrl -SolutionType $solutionType
    } else {
        $config = Test-Prerequisites
        $hasConnectionsJson = Test-ConnectionsJson
        Initialize-Directories
        
        $version = Get-SolutionVersion
        Write-Log "Setting solution version to $version"
        pac solution online-version --solution-name $config.SolutionName --solution-version $version
        
        # Use the parallel export function instead of the sequential one
        Export-Solutions-Parallel -SolutionName $config.SolutionName
        
        Write-Log "Unpacking unmanaged solution..."
        pac solution unpack -z $UnmanagedZipPath -f $UnmanagedFolderPath
        
        Expand-CanvasApps
        New-DeploymentSettings
        
        # Update connection references if Connections.json is available
        if ($hasConnectionsJson) {
            Write-Log "Updating connection references from Connections.json..."
            Update-ConnectionReferences -ConnectionsJsonPath $ConnectionsPath
        }
    }
    
    Write-Log "Script completed successfully"
    exit 0
}
catch {
    Write-Log "Error: $_"
    exit 1
}