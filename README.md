# PP-ALM (Power Platform ALM Automation)

## Overview

PP-ALM automates Power Platform solution management, deployment, and installation across environments.

## Features

- 🔄 Solution export and import automation
- 📦 Canvas App extraction
- ⚙️ Multi-environment configuration
- 🚀 Integrated solution installation

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

2. Run script:

```powershell
# For ALM operations
.\tools\pp-alm\PP-ALM.ps1
```

```powershell
# For solution installation
.\tools\pp-alm\PP-ALM.ps1 -Install
```

## Repository Structure

```plaintext
your-solution-repo/
├── Unmanaged/           # Solution files
├── config/              # Environment configs
│   ├── config.json      # Solution config
│   ├── dev.json         # Generated
│   ├── test.json        # Generated
│   └── prod.json        # Generated
├── tools/
│   └── pp-alm/         # PP-ALM submodule
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

Common issues:

1. Verify solution name and permissions
2. Check environment connectivity
3. Ensure proper file paths
4. Review authentication status
