# PP-ALM (Power Platform ALM Automation)

## Overview

PP-ALM automates Power Platform solution management, deployment, and installation across environments.

## Features

- 🔄 Parallel solution export for both managed and unmanaged packages
- 📦 Canvas App extraction and unpacking
- ⚙️ Multi-environment configuration with automatic version numbering
- 🚀 Integrated solution installation
- 🔌 Connection reference management between environments

## Prerequisites

- PowerShell 5.1+
- Power Platform CLI:

  ```powershell
  winget install Microsoft.PowerAppsCLI
  ```

## Installation

```powershell
# Add as submodule
git submodule add https://github.com/c-rw/PP-ALM.git tools/pp-alm
git submodule update --init --recursive
```

## Usage

1. Configure `config/config.json`:

```json
{
    "SolutionName": "YourSolutionName"
}
```

2. (Optional) Set up connection references in `Connections.json`:

```json
{
    "Prod": {
      "/providers/Microsoft.PowerApps/apis/shared_office365": "CONNECTION_ID_HERE",
      "..."
    },
    "Test": {
      "/providers/Microsoft.PowerApps/apis/shared_office365": "CONNECTION_ID_HERE",
      "..."
    }
}
```

3. Run script:

```powershell
# For ALM operations (export, unpack, generate settings)
.\tools\pp-alm\PP-ALM.ps1
```

```powershell
# For solution installation
.\tools\pp-alm\PP-ALM.ps1 -Install -EnvironmentUrl "https://yourenvironment.crm.dynamics.com"
```

## Script Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| -ConfigPath | Path to config.json | ./config/config.json |
| -ConnectionsPath | Path to Connections.json | ./tools/pp-alm/Connections.json |
| -EnvironmentUrl | Dynamics 365 environment URL | <https://org3babe93d.crm9.dynamics.com> |
| -Install | Switch to perform solution installation | False |

## Repository Structure

```plaintext
your-solution-repo/
├── Unmanaged/           # Solution files
├── CanvasAppSrc/        # Canvas app source code
├── config/              # Environment configs
│   ├── config.json      # Solution config
│   ├── dev.json         # Generated
│   ├── test.json        # Generated
│   └── prod.json        # Generated
├── tools/
│   └── pp-alm/         # PP-ALM submodule
│       ├── PP-ALM.ps1  # Main script
│       └── Connections.json # Connection references
├── Managed.zip         # Generated
├── Unmanaged.zip      # Generated
└── README.md
```

## Generated Files

| File/Folder | Description |
|------------|-------------|
| Managed.zip | Managed solution package |
| Unmanaged.zip | Unmanaged solution package |
| ./Unmanaged/ | Unpacked solution |
| ./CanvasAppSrc/ | Canvas App sources |
| ./config/*.json | Environment configs |

## Advanced Features

### Automatic Version Numbering

The script automatically generates solution versions in the format:
`3.YY.MMDD.HHMM` (e.g., 3.25.0311.1430)

### Parallel Export Processing

Solutions are exported in parallel processes to improve performance:

- Managed solution export
- Unmanaged solution export

### Connection Reference Management

Using Connections.json, the script automatically updates connection references in environment-specific configuration files for consistent deployment across environments.

## Troubleshooting

Common issues:

1. **Connection Issues**: Verify your authentication with `pac auth list` and create a new connection if needed with `pac auth create`
2. **Invalid Environment URL**: Ensure your environment URL follows the pattern `https://[org-name].crm.dynamics.com`
3. **Missing Configuration**: Verify config.json exists with the correct SolutionName property
4. **Export Failures**: Check your permissions to the solution and environment connection
5. **Path Issues**: Verify all paths are correctly set, especially when used outside the standard structure
