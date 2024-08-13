# Update Scripts

$Downloads = "$DriveRoot/common/downloads"
$FolderName = "temp"
if (-not (Test-Path -Path "$Downloads/$FolderName")) {
    New-Item -Path $Downloads -Name $FolderName -ItemType "directory"
}

$tmpFolder = "$Downloads/$FolderName"

# Most update procedures will require the use of a folder to download the files into.
# For this operation, we'll use $Downloads/$FolderName

class AppVersion:System.IComparable {
    [int]$MajorVersion;
    [int]$MinorVersion;
    [int]$PatchVersion;
    [string]$Extra;
    [string]$Metadata;

    Version() { $this.Init(@{}) }

    Version([hashtable]$Properties) { $this.Init($Properties) }

    Version([string]$versionText) {
        # TODO: Convert into proper parsing
        # For now, parsing assumes that the metadata exists alongside the prerelease
        $versionParts = $versionText.Split("-");
        $mainVersionParts = $versionParts[0].Split(".");
        $versionExtraParts = $null;
        if ($null -ne $versionParts[1]) {
            $versionExtraParts = $versionParts[1].Split("+");
        }
        
        $this.Init(@{
                MajorVersion = $mainVersionParts[0];
                MinorVersion = $mainVersionParts[1];
                PatchVersion = $mainVersionParts[2];
                Extra        = $versionExtraParts[0];
                Metadata     = $versionExtraParts[1];
            });

    }

    [boolean] isPrerelease() {
        if ("" -eq $this.Extra) {
            return $false;
        }
        else {
            return $true;
        }
    }

    [string] toShortString() {
        return "$($this.MajorVersion).$($this.MinorVersion).$($this.PatchVersion)"
    }

    [boolean] Equals($otherNumber) {
        if (($otherNumber -lt $this) -or ($otherNumber -gt $this)) {
            return $false;
        }
        else {
            return $true;
        }
    }
        
    # -1 if lesser, 0 if equal, 1 if greater
    # From https://stackoverflow.com/a/57063933
    [int] CompareTo($other) {
        if (-not($other -is [AppVersion])) {
            return $null;
        }
        # If any ofteh versions is pre but the other is not, short-circuit here
        if (($null -eq $other.Extra) -and ($null -ne $this.Extra)) {
            return 1;
        }
        elseif (($null -eq $this.Extra) -and ($null -ne $other.Extra)) {
            return -1;
        }
        # Comparing major version
        if ($other.MajorVersion -gt $this.MajorVersion) {
            return -1;
        }
        elseif ($other.MajorVersion -lt $this.MajorVersion) {
            return 1;
        }
        else {
            # Comapring minor version
            if ($other.MinorVersion -gt $this.MinorVersion) {
                return -1;
            }
            elseif ($other.MinorVersion -lt $this.MinorVersion) {
                return 1;
            }
            else {
                # Comapring patch version
                if ($other.PatchVersion -gt $this.PatchVersion) {
                    return -1;
                }
                elseif ($other.PatchVersion -lt $this.PatchVersion) {
                    return 1;
                }
                else {
                    # Comapring extra version info
                    if ($other.Extra -eq $this.Extra) {
                        return 0;
                    }
                    else {
                        # This portion is supposed to me a more detailled comapre
                        # For simplicity, we're comapring strings instead
                        # For practicality, we're prefering stable over pre-release versions
                        if ($null -eq $other.Extra) {
                            return 1;
                        }
                        elseif ($null -eq $this.Extra) {
                            return -1;
                        }
                        else {
                            # Both are prerelease, comapre strings instead
                            return $other.Extra.CompareTo($this.Extra);
                        }
                    }
                }
            }
        }
    }
}

function Format-VersionString {
    param (
        [string]$VersionString
    )
    # Write-Host $VersionString
    $versionParts = $versionString.Split("-");
    $mainVersionParts = $versionParts[0].Split(".");
    $versionExtra = $null;
    $versionMeta = $null;
    if ($null -ne $versionParts[1]) {
        $versionExtraParts = $versionParts[1].Split("+");
        $versionExtra = $versionExtraParts[0];
        $versionMeta = $versionExtraParts[1];
    }


    return [AppVersion](@{
            MajorVersion = $mainVersionParts[0];
            MinorVersion = $mainVersionParts[1];
            PatchVersion = $mainVersionParts[2];
            Extra        = $versionExtra;
            Metadata     = $versionMeta;
        })
}

function Format-ChromeVersionString {
    param (
        [string]$versionString
    )
    $parts = $versionString.Split(".");

    return [AppVersion](@{
            MajorVersion = $parts[0];
            MinorVersion = $parts[1];
            PatchVersion = $parts[2];
            Extra        = $parts[3];
        });
}

# # Returns true if the remote version is higher than the current version
# function Compare-UpgradeVersion {
#     param (
#         [hashtable] $currentVersion,
#         [hashtable]$remoteVersion
#     )
#     if ($remoteVersion["MajorVersion"] -gt $currentVersion["MajorVersion"]) {
#         Write-Output $true
#     } elseif (<#condition#>) {
#         <# Action when this condition is true #>
#     }
# }

function Get-VSCodeVersion {
    $a = $(code --version)
    Write-Output ($a -Split "`n")[0]
}

function Get-7ZipVersion {
    $a = $(7za i)
    # Expected output on second line:
    # 7-Zip (a) 23.01 (x86) : Copyright (c) 1999-2023 Igor Pavlov : 2023-06-20
    Write-Output (($a -Split "`n")[1] -Split " ")[2]
}

function Get-AndroidStudioVersion {
    $a = $(studio.bat --version)
    Write-Output ($a -Split "`n")[-2]
}

function Get-JustVersion {
    $a = $(just --version)
    Write-Output ($a.Split(" "))[1]
}

function Get-DotnetVersion {
    Write-Output "$(dotnet --version)"
}

function Get-SQLiteVersion {
    $a = $(sqlite3 --version)
    # Expected output:
    # 3.42.0 2023-05-16 12:36:15 831d0fb2836b71c9bc51067c49fee4b8f18047814f2ff22d817d25195cf350b0
    Write-Output ($a -Split " ")[0]
}

function Get-GccVersion {
    $a = $(gcc --version)
    # Expected output:
    # gcc.exe (GCC) 13.2.0
    # Copyright (C) 2023 Free Software Foundation, Inc.
    # This is free software; see the source for copying conditions.  There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    Write-Output (($a -Split "`n")[0] -Split " ")[2]
}

function Get-PowershellVersion {
    $a = $(pwsh --version)
    # Expected Output:
    # PowerShell 7.4.4
    Write-Output $($a -Split " ")[1]
}

function Get-ChromeTestingVersion {
    # `chrome --version` does not work on windows, so we use a more native, but unreliable scheme
    $versionObj = (Get-Item $Env:CHROME_EXECUTABLE).VersionInfo.FileVersionRaw;
    return $versionObj.ToString();
}

function Get-GitVersion {
    $a = $(git --version);
    return "$($a.Split(' ')[-1].Split('.')[0..2] -join ".")"
}

# Powershell
function Update-Powershell {

    $currentVersion = Format-VersionString "$(Get-PowershellVersion)"

    # Get list of all releases
    $latestVersion = Invoke-WebRequest -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases" | ConvertFrom-Json | Select-Object -Property tag_name | ForEach-Object { $_.tag_name.Split("v")[1] } | ForEach-Object { Format-VersionString $_ } | Where-Object { -not $_.isPrerelease() } | Sort-Object -Bottom 1

    # After the above process, the variable only has the highest pre-release version available.

    if ($currentVersion -eq $latestVersion) {
        Write-Host "Current version is the latest version!"
    }
    else {

        # TODO: Replace with actula logic for getting the latest release from github
        $powershellReleaseLink = "https://github.com/PowerShell/PowerShell/releases/download/$($latestVersion.toShortString())/PowerShell-$($latestVersion.toShortString())-win-x64.zip"
        
        Invoke-WebRequest -Uri $powershellReleaseLink -OutFile "$tmpFolder/powershell.zip"
        
        Expand-Archive -Path "$tmpFolder/powershell.zip" -DestinationPath "E:\windows\sdks\PowerShell-New" -Force

        Remove-Item -Path "$tmpFolder/powershell.zip"
    }
}

# Visual Studio Code
function Update-VSCode {
    $location = "\windows\apps\VSCode"

    $currentVersion = Format-VersionString "$(Get-VSCodeVersion)"

    # Get list of all releases
    $latestVersion = Invoke-WebRequest -Uri "https://api.github.com/repos/microsoft/vscode/releases" | ConvertFrom-Json | Select-Object -Property tag_name | ForEach-Object { Format-VersionString $_.tag_name } | Where-Object { -not $_.isPrerelease() } | Sort-Object -Bottom 1

    # After the above process, the variable only has the highest pre-release version available.

    if ($currentVersion -eq $latestVersion) {
        Write-Host "Current version is the latest version!"
    }
    else {
        Write-Host "Upgrading $($currentVersion.toShortString()) -> $($latestVersion.toShortString())"

        $powershellReleaseLink = "https://update.code.visualstudio.com/$($latestVersion.toShortString())/win32-x64-archive/stable"
        
        if (-not (Test-Path "$tmpFolder/vscode-$($latestVersion.toShortString()).zip")) {
            Invoke-WebRequest -Uri $powershellReleaseLink -OutFile "$tmpFolder/vscode-$($latestVersion.toShortString()).zip"
        }
        else {
            Write-Host "Found archive already downloaded, reusing..."
        }
        
        Expand-Archive -Path "$tmpFolder/vscode-$($latestVersion.toShortString()).zip" -DestinationPath $location -Force

        if (Format-VersionString "$(Get-VSCodeVersion)" -eq $latestVersion) {
            Write-Host "Upgraded to latest version. Removing downloaded archive..."
            Remove-Item -Path "$tmpFolder/vscode-$($latestVersion.toShortString()).zip"
        }
    }
}

# Visual Studio Code CLI
function Update-VSCodeCLI {
    $location = "\windows\sdks\VSCode"

    $currentVersion = Format-VersionString "$(Get-VSCodeVersion)"

    # Get list of all releases
    $latestVersion = Invoke-WebRequest -Uri "https://api.github.com/repos/microsoft/vscode/releases" | ConvertFrom-Json | Select-Object -Property tag_name | ForEach-Object { Format-VersionString $_.tag_name } | Where-Object { -not $_.isPrerelease() } | Sort-Object -Bottom 1

    # After the above process, the variable only has the highest pre-release version available.

    if ($currentVersion -eq $latestVersion) {
        Write-Host "Current version is the latest version!"
    }
    else {
        Write-Host "Upgrading $($currentVersion.toShortString()) -> $($latestVersion.toShortString())"

        $powershellReleaseLink = "https://update.code.visualstudio.com/$($latestVersion.toShortString())/cliwin32-x64/stable"

        $archivePath = "$tmpFolder/vscode-cli-$($latestVersion.toShortString()).zip"
        
        if (-not (Test-Path $archivePath)) {
            Invoke-WebRequest -Uri $powershellReleaseLink -OutFile $archivePath
        }
        else {
            Write-Host "Found archive already downloaded, reusing..."
        }
        
        Expand-Archive -Path $archivePath -DestinationPath $location -Force

        if (Format-VersionString "$(Get-VSCodeVersion)" -eq $latestVersion) {
            Write-Host "Upgraded to latest version. Removing downloaded archive..."
            Remove-Item -Path $archivePath
        }
    }
}

# Just
function Update-Just {
    $location = "\windows\apps\just"

    $currentVersion = Format-VersionString "$(Get-JustVersion)"

    # Get list of all releases
    $latestVersion = Invoke-WebRequest -Uri "https://api.github.com/repos/casey/just/releases" | ConvertFrom-Json | Select-Object -Property tag_name | ForEach-Object { Format-VersionString $_.tag_name } | Where-Object { -not $_.isPrerelease() } | Sort-Object -Bottom 1

    # After the above process, the variable only has the highest pre-release version available.

    if ($currentVersion -eq $latestVersion) {
        Write-Host "Current version is the latest version!"
    }
    else {
        Write-Host "Upgrading $($currentVersion.toShortString()) -> $($latestVersion.toShortString())"

        $powershellReleaseLink = "https://github.com/casey/just/releases/download/$($latestVersion.toShortString())/just-$($latestVersion.toShortString())-x86_64-pc-windows-msvc.zip"
        
        if (-not (Test-Path "$tmpFolder/just-$($latestVersion.toShortString()).zip")) {
            Invoke-WebRequest -Uri $powershellReleaseLink -OutFile "$tmpFolder/just-$($latestVersion.toShortString()).zip"
        }
        else {
            Write-Host "Found archive already downloaded at $tmpFolder/just-$($latestVersion.toShortString()).zip, reusing..."
        }
        
        Expand-Archive -Path "$tmpFolder/just-$($latestVersion.toShortString()).zip" -DestinationPath $location -Force

        if (Format-VersionString "$(Get-JustVersion)" -eq $latestVersion) {
            Write-Host "Upgraded to latest version. Removing downloaded archive..."
            Remove-Item -Path "$tmpFolder/just-$($latestVersion.toShortString()).zip"
        }
    }
}

# Chrome for Testing
function Update-ChromeTesting {
    # Pointing to the parent as the zip file has a top-level `chrome-win64` directory
    $location = "\windows\apps"

    $currentVersion = Format-ChromeVersionString "$(Get-ChromeTestingVersion)";

    $res = Invoke-WebRequest -Uri "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json" | ConvertFrom-Json;

    $stableVersionObject = $res.channels.Stable;

    $latestVersion = Format-ChromeVersionString $stableVersionObject.version;

    if ($currentVersion -eq $latestVersion) {
        Write-Output "Current version is the latest version!";
    }
    else {
        $downloadLink = ($stableVersionObject.downloads.chrome | Where-Object { $_.platform -eq "win64" }).url

        $archivePath = "$tmpFolder/chrome-$($latestVersion.toShortString()).zip";

        if (Test-Path $archivePath) {
            Write-Host "Archive allready exists. Reusing...";
        }
        else {
            Invoke-WebRequest -Uri $downloadLink -OutFile $archivePath;
        }

        Expand-Archive -Path $archivePath -DestinationPath $location -Force;

        if (Format-ChromeVersionString "$(Get-ChromeTestingVersion)" -eq $latestVersion) {
            Write-Host "Upgraded to latest version. Removing downloaded archive...";
            Remove-Item -Path $archivePath;
        }
    }
}

# Git Portable for Windows

function Update-Git {
    $location = "/windows/sdks/git"

    $currentVersion = Format-VersionString "$(Get-GitVersion)";
    
    $latestVersion = Invoke-WebRequest -Uri "https://api.github.com/repos/git/git/tags" | ConvertFrom-Json | Select-Object -Property name | ForEach-Object { $_.name.Split("v")[1] } | ForEach-Object { Format-VersionString $_ } | Where-Object { -not $_.isPrerelease() } | Sort-Object -Bottom 1

    if ($currentVersion -eq $latestVersion) {
        Write-Host "Current version is the latest version ($currentVersion)"
    }
    else {
        Write-Host "Performing upgrade: $($currentVersion.toShortString()) -> $($latestVersion.toShortString())";
        
        $downloadLink = "https://github.com/git-for-windows/git/releases/download/v$($latestVersion.toShortString()).windows.1/PortableGit-$($latestVersion.toShortString())-64-bit.7z.exe";
        
        $archivePath = "$tmpFolder/git-$($latestVersion.toShortString()).7z.exe"
        
        if (Test-Path $archivePath) {
            Write-Host "Found existing archive. Reusing...";
        }
        else {
            Write-Host "Downloading from $downloadLink to $archivePath";
            Invoke-WebRequest -Uri $downloadLink -OutFile $archivePath
        }
        
        & $archivePath -oE:/windows/sdks/git -y -aoa
        
        $currentVersion = Format-VersionString "$(Get-GitVersion)";
        if ($currentVersion -eq $latestVersion) {
            Write-Host "Upgraded to latest version. Removing downloaded archive...";
            Remove-Item -Path $archivePath;
        }
    }
}

Export-ModuleMember -Function Get-VSCodeVersion, Get-7ZipVersion, Get-AndroidStudioVersion, Get-JustVersion, Get-DotnetVersion, Get-SQLiteVersion, Get-GccVersion, Get-PowershellVersion, Get-ChromeTestingVersion, Get-GitVersion, Update-Powershell, Update-VSCode, Update-VSCodeCLI, Update-Just, Update-ChromeTesting, Update-Git, Format-VersionString, Format-ChromeVersionString

# Check url status:
# $req = [system.Net.WebRequest]::Create($url)

# Default true, causes redirects to be followed. That case is not really useful.
# $req.AllowAutoRedirect=$false

# try {
#     $res = $req.GetResponse()
# } 
# catch [System.Net.WebException] {
#     $res = $_.Exception.Response
# }

# $res.StatusCode string representation, cast to [int] to get numeric value.