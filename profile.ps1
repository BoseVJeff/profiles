# Preloads

# Setting the PROFILE variable to this script
# Taken from https://stackoverflow.com/a/15402335
$PROFILE = $PSCommandPath

# Storing the root directory as a variable
# This allows all paths to work even if one navigates outside of this drive
$DriveRoot = Split-Path -Qualifier $PROFILE

# Setting the path to load all PS Modules from
# Splitting code into PS Modules allows seperation of concerns and lets the code be modular and understandable.
$Env:PSModulePath = "$DriveRoot\common\profiles\ps_modules"

# Setting paths to `.gitconfig`s
# Remember to point to the file and not to the folder
$Env:GIT_CONFIG_GLOBAL="$DriveRoot\common\git\.gitconfig"
# $Env:GIT_CONFIG_SYSTEM="$DriveRoot\common\system\git"

# Add this profiles directory to the `git` safe list
git config --global --add safe.directory "$DriveRoot/common/profiles"

# Setting a location to store all command history in.
# This avoids both - interference from/with host, and loss of history when switching systems.
# See https://learn.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption?view=powershell-7.4#-historysavepath for official docs.
Set-PSReadLineOption -HistorySavePath $DriveRoot\windows\sys32\$($Host.Name)_history.txt

################################################################################

If ($IsWindows) {
	# Windows specific utils!

	# Loading the windows-specific profile
	# Execution method taken from https://superuser.com/a/1524149
	$script = $PSScriptRoot + "\windows_profile.ps1"
	. $script

}
ElseIf ($IsLinux) {
	Write-Output "Running on some Linux!"
}
ElseIf ($IsMacOs) {
	Write-Output "Running on MacOS!"
}
ElseIf ($PSVersionTable.Platform -eq "Unix") {
	Write-Output "Running some unknown variant of Unix!"
}
Else {
	Write-Output "Running some unknown OS!"
}

################################################################################

# Post Loads

# Utility Functions

# From search/search.psm1
Set-Alias -Name search -Value Search-InBrowser

Set-Alias -Name ai -Value AskGemini-Single

# PING
Set-Alias -Name ping -Value Test-Connection

# Get executable location
function which {
	param (
		[String]$execName
	)
	# TODO: Wrap this in a try..catch
	(Get-Command $execName @args).Source
}

# Modifying the system prompt
function prompt {
	# The start of the prompt.
	# This is the string `PPS` to stand for `Portable PowerShell`.
	# This also seperates it from the regular `PS` prompt of the system Powershell.
	$prompt = "PPS"

	# Adding an indicator for the current directory that the shell is in.
	$prompt = "$prompt $(Get-Location)"

	# Prepending an `!` if the last command returned an error or a non-zero exit code.
	if ($? -Eq $false) { $prompt = "! $prompt" }

	# Adding `1+context_dpeth` `>` to the start of the prompt.
	# This is on a new line as the path itself can be long.
	$prompt = "$prompt`n$('>'*($NestedPromptLevel + 1)) "
	Write-Output "$prompt"
}