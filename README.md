# PP-ALM (Power Platform ALM Automation)

## Overview

PP-ALM automates Power Platform solution management, deployment, and installation across environments.

## Features

- 🔄 Parallel solution export for both managed and unmanaged packages
- 📦 Canvas App extraction and unpacking
- ⚙️ Multi-environment configuration with automatic version numbering
- 🚀 Integrated solution installation (both managed and unmanaged)
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
# For unmanaged solution installation (using the authenticated environment)
.\tools\pp-alm\PP-ALM.ps1 -Install

# For unmanaged solution installation (specifying an environment URL)
.\tools\pp-alm\PP-ALM.ps1 -Install -EnvironmentUrl "https://yourenvironment.crm.dynamics.com"

# For managed solution installation (using the authenticated environment)
.\tools\pp-alm\PP-ALM.ps1 -Install -Managed

# For managed solution installation (specifying an environment URL)
.\tools\pp-alm\PP-ALM.ps1 -Install -Managed -EnvironmentUrl "https://yourenvironment.crm.dynamics.com"
```

## Script Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| -ConfigPath | Path to config.json | ./config/config.json |
| -ConnectionsPath | Path to Connections.json | ./tools/pp-alm/Connections.json |
| -EnvironmentUrl | Dynamics 365 environment URL (optional, uses currently authenticated environment if not specified) | None |
| -Install | Switch to perform solution installation | False |
| -Managed | When used with -Install, installs the managed solution package | False |

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

### Managed vs Unmanaged Installation

- **Unmanaged Installation**: Default mode when using `-Install`. Installs solutions that remain editable in the target environment. Ideal for development and test environments.
- **Managed Installation**: Used with `-Install -Managed`. Installs solutions that cannot be edited in the target environment. Recommended for production environments.

## Troubleshooting

Common issues:

1. **Connection Issues**: Verify your authentication with `pac auth list` and create a new connection if needed with `pac auth create`
2. **Invalid Environment URL**: Ensure your environment URL follows the pattern `https://[org-name].crm.dynamics.com`
3. **Missing Configuration**: Verify config.json exists with the correct SolutionName property
4. **Export Failures**: Check your permissions to the solution and environment connection
5. **Path Issues**: Verify all paths are correctly set, especially when used outside the standard structure
