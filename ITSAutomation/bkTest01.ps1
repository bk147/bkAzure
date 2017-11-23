$info = 'Test from Azure runbook v2 '

$str = $info + '[' + [DateTime]::Now + ']'
$str
'Running on: ' + (hostname)

$str | Out-File -FilePath $env:system\_install\AzureRunbook.txt -Append

"Finished writing " + '[' + [DateTime]::Now + ']'