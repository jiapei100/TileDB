# PowerShell script for performing TileDB bootstrapping process on
# Windows.

<#
.SYNOPSIS
This is a Powershell script to bootstrap a TileDB build on Windows.

.DESCRIPTION
This script will check dependencies, and run the CMake build generator
to generate a Visual Studio solution file that can be used to build or
develop TileDB.

.PARAMETER Prefix
Installs files in tree rooted at PREFIX (defaults to TileDB\dist).

.PARAMETER Dependency
Semicolon separated list to binary dependencies.

.PARAMETER CMakeGenerator
Optionally specify the CMake generator string, e.g. "Visual Studio 15
2017". Check 'cmake --help' for a list of supported generators.

.PARAMETER EnableDebug
Enable Debug build.

.PARAMETER EnableCoverage
Enable build with code coverage support.

.PARAMETER EnableVerbose
Enable verbose status messages.

.PARAMETER EnableS3
Enables building with the S3 storage backend.

.PARAMETER BuildProcesses
Number of parallel compile jobs.

.LINK
https://github.com/TileDB-Inc/TileDB

.EXAMPLE
..\bootstrap.ps1 -Prefix "\path\to\install" -Dependency "\path\to\dep1;\path\to\dep2"

#>

# Note -Debug and -Verbose are included in the PowerShell
# CommonParameters list, so we don't duplicate them here.
# TODO: that means they don't appear in the -? usage message.
[CmdletBinding()]
Param(
    [string]$Prefix,
    [string]$Dependency,
    [string]$CMakeGenerator,
    [switch]$EnableDebug,
    [switch]$EnableCoverage,
    [switch]$EnableVerbose,
    [switch]$EnableS3,
    [Alias('J')]
    [int]
    $BuildProcesses = $env:NUMBER_OF_PROCESSORS
)

# Return the directory containing this script file.
function Get-ScriptDirectory {
    Split-Path -Parent $PSCommandPath
}

# Absolute path of TileDB directories.
$SourceDirectory = Get-ScriptDirectory
$BinaryDirectory = (Get-Item -Path ".\" -Verbose).FullName

# Choose the default install prefix.
$DefaultPrefix = Join-Path $SourceDirectory "dist"

# Choose the default dependency install prefix.
$DefaultDependency = $DefaultPrefix

# Set TileDB build type
$BuildType = "Release"
if ($EnableDebug.IsPresent) {
    $BuildType = "Debug"
}
if ($EnableCoverage.IsPresent) {
    $BuildType = "Coverage"
}

# Set TileDB verbosity
$Verbosity = "OFF"
if ($EnableVerbose.IsPresent) {
    $Verbosity = "ON"
}

# Set TileDB S3 flag
$UseS3 = "OFF"
if ($EnableS3.IsPresent) {
    $UseS3 = "ON"
}

# Set TileDB prefix
$InstallPrefix = $DefaultPrefix
if ($Prefix.IsPresent) {
    $InstallPrefix = $Prefix
}

# Set TileDB dependency directory string
$DependencyDir = $DefaultDependency
if ($Dependency.IsPresent) {
    $DependencyDir = $Dependency
}

# Set CMake generator type.
$GeneratorFlag = ""
if ($CMakeGenerator.IsPresent) {
    $GeneratorFlag = "-G ""$CMakeGenerator"""
}

# Enforce out-of-source build
if ($SourceDirectory -eq $BinaryDirectory) {
    Throw "Cannot build the project in the source directory! Out-of-source build is enforced!"
}

# Check cmake binary
if ((Get-Command "cmake.exe" -ErrorAction SilentlyContinue) -eq $null) {
    Throw "Unable to find cmake.exe in your PATH."
}
if ($CMakeGenerator -eq $null) {
    Throw "Could not identify a generator for CMake. Do you have Visual Studio installed?"
}

# Run CMake.
# We use Invoke-Expression so we can echo the command to the user.
$CommandString = "cmake -A x64 -DCMAKE_BUILD_TYPE=$BuildType -DCMAKE_INSTALL_PREFIX=""$InstallPrefix"" -DCMAKE_PREFIX_PATH=""$DependencyDir"" -DMSVC_MP_FLAG=""/MP$BuildProcesses"" -DTILEDB_VERBOSE=$Verbosity -DUSE_S3=$UseS3 $GeneratorFlag ""$SourceDirectory"""
Write-Host $CommandString
Write-Host
Invoke-Expression "$CommandString"

Write-Host "Bootstrap success. Run 'cmake --build .' to build and 'cmake --build . --target check --config $BuildType' to test."
