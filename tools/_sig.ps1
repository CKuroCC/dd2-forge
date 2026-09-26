$tsv = 'D:\dd2-forge\reference\dd2-types.tsv'
if (-not (Test-Path $tsv)) { Write-Output 'TSV MISSING'; exit 1 }
$i = Get-Item $tsv
Write-Output ("=== {0}  {1:N0} bytes  built {2} ===" -f $i.Name, $i.Length, $i.LastWriteTime)
Write-Output ''

function Hunt($label, $pattern, $take) {
    Write-Output ("--------- {0} ---------" -f $label)
    $n = 0
    Select-String -Path $tsv -Pattern $pattern -CaseSensitive:$false |
      Select-Object -First $take | ForEach-Object { $n++; "  " + $_.Line.Trim() }
    if ($n -eq 0) { Write-Output '  (no match)' }
    Write-Output ''
}

Hunt 'PLAGUE: setPossessionLv + friends' 'setPossessionLv|judgPossession|PossessionProgressPoint|get_PawnCharacterList' 25
Hunt 'PLAGUE: PossessionManager methods' 'app\.PossessionManager' 25
Hunt 'AFFINITY: favorability setters' 'setFavorabilityRating|resetAccumulatedFavorability|FavorabilityRating|AccumulatedFavorability' 25
Hunt 'AFFINITY: sentiment methods' 'Sentiment.*\t.*(set|get|add|reset)|(set|get|add|reset).*Sentiment' 30
Hunt 'STAMINA: battle mode + stamina manager' 'get_IsBattleMode|recoverAll|get_ReducedMaxValue|get_RemainingAmount|get_StaminaManager|get_IsDrawedWeapon' 25
Hunt 'CHAIN: custom setting path' 'set_CustomSetting|copySetting|blendSetting|ChainCustomSetting' 20
