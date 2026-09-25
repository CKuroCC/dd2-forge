# Can the folded index answer the questions that actually cost this project
# time? If any of these come back empty, the 1.12 GB source must NOT be deleted.
$tsv = 'D:\dd2-forge\reference\dd2-types.tsv'
$checks = @(
    @{ q = 'getItem on ItemManager';        p = '^app\.ItemManager\tmethod\tgetItem\t' },
    @{ q = 'MaxMoneyCount';                 p = '^app\.ItemManager\tfield\tMaxMoneyCount\t' },
    @{ q = 'getNPCData';                    p = '^app\.NPCManager\tmethod\tgetNPCData\t' },
    @{ q = 'getAllCharacters';              p = '^app\.CharacterListHolder\tmethod\tgetAllCharacters\t' },
    @{ q = 'HumanPreventFallController';    p = '^app\.HumanPreventFallController\t' },
    @{ q = 'FallPreventer height field';    p = '^app\.FallPreventer\tfield\t.*HeightPreventFall' },
    @{ q = 'Chain EnabledDynamicScaling';   p = '^via\.motion\.Chain\t.*EnabledDynamicScaling' },
    @{ q = 'getKeyLocationNode';            p = '^app\.AIAreaManager\tmethod\tgetKeyLocationNode\t' },
    @{ q = 'getJointByName';                p = '^via\.Transform\tmethod\tgetJointByName\t' }
)
foreach ($c in $checks) {
    $hits = @(Select-String -LiteralPath $tsv -Pattern $c.p)
    $tag = if ($hits.Count -gt 0) { 'OK  ' } else { 'MISS' }
    Write-Output ("{0} {1,-32} {2} hit(s)" -f $tag, $c.q, $hits.Count)
    $hits | Select-Object -First 3 | ForEach-Object { Write-Output ("       " + $_.Line) }
}
