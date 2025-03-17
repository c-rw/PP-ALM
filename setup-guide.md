# Initial Setup

1. Clone PP-ALM repository:

```powershell
cd your-solution-repo
git clone https://github.com/c-rw/PP-ALM.git tools/pp-alm
```

2. Create configuration:

```powershell
# Create directory
New-Item -ItemType Directory -Path "config" -Force

# Create config.json
@{
    SolutionName = "YourSolutionName"
} | ConvertTo-Json | Set-Content "config/config.json"
```

## Script Usage

### ALM Operations (Export, Unpack, Generate Settings)

```powershell
.\tools\pp-alm\PP-ALM.ps1 -ConfigPath ./config/config.json
```

### Solution Installation

#### Unmanaged Solutions (Development/Test Environments)

```powershell
# Install to currently authenticated environment
.\tools\pp-alm\PP-ALM.ps1 -Install

# Install to specific environment
.\tools\pp-alm\PP-ALM.ps1 -Install -EnvironmentUrl "https://yourenv.crm.dynamics.com"
```

#### Managed Solutions (Production Environments)

```powershell
# Install to currently authenticated environment
.\tools\pp-alm\PP-ALM.ps1 -Install -Managed

# Install to specific environment
.\tools\pp-alm\PP-ALM.ps1 -Install -Managed -EnvironmentUrl "https://yourenv.crm.dynamics.com"
```

### Connection Reference Management

To manage connection references between environments:

1. Configure `Connections.json` with appropriate connection IDs
2. Run the script to update environment-specific configurations:

```powershell
.\tools\pp-alm\PP-ALM.ps1
```

### Logging Example

Output example:

```powershell
[2025-03-17 12:34:56] Processing started...
[2025-03-17 12:35:01] Exporting managed solution...
[2025-03-17 12:35:10] Successfully imported Managed solution
```

### Authentication

```powershell
# List authenticated environments
pac auth list

# Create new authentication
pac auth create -env example-environment-id

# Select active environment
pac auth select -env example-environment-id
```

## Additional Troubleshooting

1. **Configuration Path Issues:**
   - Verify the `$ConfigPath` parameter points to the correct location
   - Check that config.json contains the correct SolutionName property

2. **Installation Failures:**
   - Verify you're authenticated to the correct environment
   - Check that the solution package exists or try running without `-Install` first
   - For managed installation, ensure the managed package was properly exported

3. **Environment URL Format:**
   - Ensure URLs follow the pattern `https://[org-name].crm.dynamics.com`

4. **Logging Details:**
   - Review log messages for specific errors
   - The script provides real-time progress updates during export operations

---
