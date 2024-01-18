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

Export-ModuleMember -Function Get-VSCodeVersion, Get-7ZipVersion