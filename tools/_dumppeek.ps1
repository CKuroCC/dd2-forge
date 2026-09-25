$p = 'D:\SteamLibrary\steamapps\common\Dragons Dogma 2\il2cpp_dump.json'
Write-Output ("size: {0:N0} bytes" -f (Get-Item -LiteralPath $p).Length)
Write-Output '--- first 60 lines ---'
Get-Content -LiteralPath $p -TotalCount 60 | ForEach-Object { Write-Output $_ }
Write-Output '--- python available? ---'
foreach ($c in 'python', 'python3', 'py') {
    $g = Get-Command $c -ErrorAction SilentlyContinue
    if ($g) { Write-Output ("  {0} -> {1}" -f $c, $g.Source) }
}
