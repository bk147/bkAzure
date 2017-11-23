$info = 'Test from Azure runbook v2 '

$str = $info + '[' + [DateTime]::Now + ']'
$str
$str | Out-File -FilePath $env:system\_install\AzureRunbook.txt -Append
