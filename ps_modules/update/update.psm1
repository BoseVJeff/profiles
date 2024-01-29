function Get-VSCodeVersion {
    $a=$(code --version)
    Write-Output ($a -Split "`n")[0]
}

function Get-7ZipVersion {
    $a=$(7za i)
    # Expected output on second line:
    # 7-Zip (a) 23.01 (x86) : Copyright (c) 1999-2023 Igor Pavlov : 2023-06-20
    Write-Output (($a -Split "`n")[1] -Split " ")[2]
}

function Get-AndroidStudioVersion {
    $a=$(studio.bat --version)
    Write-Output ($a -Split "`n")[-2]
}

function Get-JustVersion {
    $a=$(just --version)
    Write-Output $a
}

function Get-DotnetVersion {
    Write-Output "$(dotnet --version)"
}

function Get-SQLiteVersion {
    $a=$(sqlite3 --version)
    # Expected output:
    # 3.42.0 2023-05-16 12:36:15 831d0fb2836b71c9bc51067c49fee4b8f18047814f2ff22d817d25195cf350b0
    Write-Output ($a -Split " ")[0]
}

function Get-GccVersion {
    $a=$(gcc --version)
    # Expected output:
    # gcc.exe (GCC) 13.2.0
    # Copyright (C) 2023 Free Software Foundation, Inc.
    # This is free software; see the source for copying conditions.  There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    Write-Output (($a -Split "`n")[0] -Split " ")[2]
}

Export-ModuleMember -Function Get-VSCodeVersion, Get-7ZipVersion, Get-AndroidStudioVersion, Get-JustVersion, Get-DotnetVersion, Get-SQLiteVersion, Get-GccVersion