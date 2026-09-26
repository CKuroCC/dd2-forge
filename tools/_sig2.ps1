$tsv = 'D:\dd2-forge\reference\dd2-types.tsv'
function Hunt($label, $pattern, $take) {
    Write-Output ("--------- {0} ---------" -f $label)
    $n = 0
    Select-String -Path $tsv -Pattern $pattern -CaseSensitive:$false |
      Select-Object -First $take | ForEach-Object { $n++; "  " + $_.Line.Trim() }
    if ($n -eq 0) { Write-Output '  (NO MATCH)' }
    Write-Output ''
}
Hunt 'PawnDataContext: full method+field list' '^app\.PawnDataContext\t' 40
Hunt 'Character: GenerateInfo / Human / ContextHolder' '^app\.Character\t(method|prop)\t(get_GenerateInfo|get_Human|get_CharaIDString|get_ContextHolder|get_CharaID)' 15
Hunt 'GenerateInfo -> Context' 'GenerateInfo\t(method|prop)\tget_Context|ContextHolder\tmethod\tget' 15
Hunt 'PawnManager: betrayal + party' '^app\.PawnManager\t(method|field)\t.*(Betrayal|MainPawn|PartyPawn)' 20
Hunt 'PossessionManager: changeEyeGlow signatures' '^app\.PossessionManager\t(method|field)\t(changeEyeGlow|get_EyeGlow|IsEnable|setup|adjustEyeGlow)' 15
