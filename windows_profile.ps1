# Profiles are exectuted in a cascade. To prevent this, use `pwsh.exe` in your terminal emulator as follows:
# \windows\sdks\PowerShell-7.4.0-win-x64\pwsh.exe -NoProfile -noexit -c "Set-Executionpolicy remotesigned -Scope CurrentUser ; invoke-expression '. ''\windows\sdks\PowerShell-7.4.0-win-x64\profile.ps1''' "
# For reference, see https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.3#profile-types-and-locations

# What follows here is a setup of the specific tools needed.

# Initialising with an empty path to prevent interference from host system paths
$Env:Path = ""

# Adding Powershell to PATH
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\PowerShell-7.4.0-win-x64"

# Adding Git to PATH
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\git\bin"

# Adding Flutter and Dart to PATH
# Note that for the command to work, Git must be available on PATH and `git rev-parse HEAD` must not fail on the Flutter SDK repo.
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\flutter_windows\flutter\bin"
# (Fix from https://stackoverflow.com/a/75336553) to ensure that `flutter --version` and other misc commands work.
# ENSURE that `git` has been configured and setup before use
git config --global --add safe.directory "$DriveRoot/windows/sdks/flutter_windows/flutter"

# Adding an explicit pub cache folder
# Taken from https://dart.dev/tools/pub/environment-variables
$Env:PUB_CACHE = "$DriveRoot\windows\caches\pub"

# Adding `where.exe` to PATH. Extracted from `C:\Windows\system32` on a Win10 install.
# This allows `flutter doctor` and  command to work.
$Env:Path = $Env:Path + ";$DriveRoot\windows\sys32"

# Adding VS Code to PATH
# This allows `code .` to work in the terminal
$Env:Path = $Env:Path + ";$DriveRoot\windows\apps\VSCode\bin"

# Adding Sublime Merge to PATH
$Env:Path = $Env:Path + ";$DriveRoot\windows\apps\sublime_merge_build_2091_x64"

# Adding Sublime Text to PATH
$Env:Path = $Env:Path + ";$DriveRoot\windows\apps\sublime_text_build_4169_x64"

# Adding Python to PATH
# For this purpose, the (WinPython)[https://winpython.github.io/] distribtion is used
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\winpython\WPy64-31160\python-3.11.6.amd64"

# Also adding Python Scripts to PATH
# This allows tools like `jupyter` and `flask` to work
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\winpython\WPy64-31160\python-3.11.6.amd64\Scripts"

# Adding NodeJS (inc npm) to PATH
# This is reusing the NodeJS installed as a part of WinPython to save on space
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\winpython\WPy64-31160\n"

# Adding Java to PATH
# This is meant for Android development.
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\jdk-21.0.1+12\bin"

#Setting up JAVA_HOME
$Env:JAVA_HOME = "$DriveRoot\windows\sdks\jdk-21.0.1+12"

# Adding the Android SDK to PATH.
# This path must be the *parent* of the `cmdline-tools` folder.
# This allows Android development without needing Android Studio installed. This is necessary as the IDE is not portable.
# To install the rest needed to pass `flutter doctor` check, use `sdkmanager "platform-tools" "platforms;android-33" "build-tools;34.0.0"` after installing `sdkmanager`.
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\commandlinetools-win\cmdline-tools\latest\bin"
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\commandlinetools-win\cmdline-tools\latest"
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\commandlinetools-win\platform-tools\"

# Setting up ANDROID_HOME (SDK), ANDROID_USER_HOME (User Prefs), REPO_OS_OVERRIDE (os)
# Taken from https://developer.android.com/tools/variables
$Env:ANDROID_HOME = "$DriveRoot\windows\sdks\commandlinetools-win"
$Env:ANDROID_USER_HOME = "$DriveRoot\windows\sdks\commandlinetools-win\.android"
$Env:REPO_OS_OVERRIDE = "windows"

# Adding Android Studio to PATH
$Env:Path = $Env:Path + ";$DriveRoot\windows\apps\android-studio\bin"

# # Android Studio variables
# # $Env:STUDIO_VM_OPTIONS="$DriveRoot\common\config\studio.vmoptions"	# Sets the location of the studio.vmoptions file. This file contains settings that affect the performance characteristics of the Java HotSpot Virtual Machine. This file can also be accessed from within Android Studio. See Customize your VM options.
# $Env:STUDIO_PROPERTIES="$DriveRoot\common\config\studio.properties"	# Sets the location of the idea.properties file. This file lets you customize Android Studio IDE properties, such as the path to user installed plugins and the maximum file size supported by the IDE. See Customize your IDE properties.
# $Env:STUDIO_JDK=$Env:JAVA_HOME	                                    # Sets the location of the JDK that Android Studio runs in. When you launch the IDE, it checks the STUDIO_JDK, JDK_HOME, and JAVA_HOME environment variables, in that order.
# $Env:STUDIO_GRADLE_JDK=$Env:JAVA_HOME	                            # Sets the location of the JDK that Android Studio uses to start the Gradle daemon. When you launch the IDE, it first checks STUDIO_GRADLE_JDK. If STUDIO_GRADLE_JDK is not defined, the IDE uses the value set in the project structure settings.

# Adding .NET to PATH
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\dotnet-sdk-8.0.100-win-x64"

# Adding `just` to PATH
$Env:Path = $Env:Path + ";$DriveRoot\windows\apps\just"

# Adding SQLite CLI to PATH
$Env:Path = $Env:Path + ";$DriveRoot\windows\apps\sqlite-tools-win-x64-3450000"

# Adding 7z CLI to PATH
$Env:Path = $Env:Path + ";$DriveRoot\windows\apps\7z2301-extra"

# Adding w64devkit to PATH
# This allows for C(gcc)/C++(g++)/Fortran(gfortran) dev
$Env:Path = $Env:Path + ";$DriveRoot\windows\sdks\w64devkit\bin"

# Adding Vivaldi to PATH
$Env:Path = $Env:Path + ";$DriveRoot\windows\apps\Vivaldi\Application"

# Setting Local App Data folder
$Env:LOCALAPPDATA = "$DriveRoot\windows\appdata\local"

# Additional Flutter setup
flutter config --android-sdk "$DriveRoot\windows\sdks\commandlinetools-win" | Out-Null
flutter config --android-studio-dir "$DriveRoot\windows\apps\android-studio" | Out-Null

################################################################################

# Other Windows-specific settings


# This is the windows equivalent of `$HOME` so only use this if all else fails
# $Env:USERPROFILE="D:\windows\user"