[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "config/config.json"),
    
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentUrl = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Install
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

function Test-PacCli {
    $pacVersion = & pac help --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "PowerApps CLI (PAC) is not installed or not in PATH"
    }
    Write-Log "PAC CLI Version: $pacVersion"
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

function Export-Solutions {
    param ([string]$SolutionName)
    
    Write-Log "Exporting managed solution..."
    pac solution export --name $SolutionName --path $ManagedZipPath --managed true
    
    Write-Log "Exporting unmanaged solution..."
    pac solution export --name $SolutionName --path $UnmanagedZipPath --managed false
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

function Install-Solution {
    param ([string]$SolutionPath, [string]$EnvironmentUrl)
    
    if (-not (Test-Path $SolutionPath)) {
        throw "Solution file not found at: $SolutionPath"
    }
    
    if (-not ($EnvironmentUrl -match '^https:\/\/[a-zA-Z0-9.-]+\.dynamics\.com$')) {
        throw "Invalid Environment URL format"
    }
    
    Write-Log "Importing solution..."
    $importResult = & pac solution import -f -a -pc -p $SolutionPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Solution import failed: $importResult"
    }
}

try {
    Test-PacCli
    Initialize-Paths
    
    if ($Install) {
        Install-Solution -SolutionPath $UnmanagedZipPath -EnvironmentUrl $EnvironmentUrl
    } else {
        $config = Test-Prerequisites
        Initialize-Directories
        
        $version = Get-SolutionVersion
        Write-Log "Setting solution version to $version"
        pac solution online-version --solution-name $config.SolutionName --solution-version $version
        
        Export-Solutions -SolutionName $config.SolutionName
        
        Write-Log "Unpacking unmanaged solution..."
        pac solution unpack -z $UnmanagedZipPath -f $UnmanagedFolderPath
        
        Expand-CanvasApps
        New-DeploymentSettings
    }
    
    Write-Log "Script completed successfully"
    exit 0
}
catch {
    Write-Log "Error: $_"
    exit 1
}