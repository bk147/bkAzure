#$myVar2 = "{'VMServers':{'id':38,'key':'457df632eac89b34fb383527e9cda685'},'Services':{'id':39,'key':'724f89d3c65be3afe36b8a275c349dfd'}}"

Login-AzureRmAccount -SubscriptionId '96b85154-ca89-47b0-9ab6-f4feace7d80d'

#New-AzureRmAutomationVariable -Name 'bkTestVar02' -Value $myVar -ResourceGroupName 'AutomationGroup' -AutomationAccountName 'bkAutomationTest01' -Encrypted:$true
#Set-AzureRmAutomationVariable -Name 'bkTestVar02' -Value $myVar -ResourceGroupName 'AutomationGroup' -AutomationAccountName 'bkAutomationTest01' -Encrypted:$true
#$res = Get-AzureRmAutomationVariable -Name 'bkTestVar02' -ResourceGroupName 'AutomationGroup' -AutomationAccountName 'bkAutomationTest01'

$resGroupName = 'AutomationGroup'
$autoAccount = 'bkAutomationTest01'
$autoAccountDev = 'bkAutomationTest01Dev'

$cred = Get-Credential -Message "Domain join account for admt" -UserName SVC_DSC_Domain@admt.aau.dk
New-AzureRmAutomationCredential -Name 'DSC_admt_Domain' -Value $cred -ResourceGroupName $resGroupName -AutomationAccountName $autoAccountDev

$cred = Get-Credential -Message "Service account used from SMA to access vRO workflows" -UserName SVC_SMA_vRO_Access@srv.aau.dk
New-AzureRmAutomationCredential -Name 'SVC_SMA_vRO_Access' -Value $cred -ResourceGroupName $resGroupName -AutomationAccountName $autoAccountDev

$params = @{
    Name = 'PasswordManager_PwdGeneratorKey'
    Value = 'fdc7483ae23b9654d7a23e36f85cb9ad'
    Encrypted = $true
    Description = 'Key for generating passwords in PasswordManager'
    ResourceGroupName = $resGroupName
    AutomationAccountName = $autoAccountDev
}
#New-AzureRmAutomationVariable @params
Set-AzureRmAutomationVariable @params
#-Name 'PasswordManager_PwdGeneratorKey' -Value 'fdc7483ae23b9654d7a23e36f85cb9ad' -ResourceGroupName $resGroupName -AutomationAccountName $autoAccountDev -Encrypted:$true

$params = @{
    Name = 'PasswordManager_ServiceDNS'
    Value = 'pwmgr.its.aau.dk'
    Encrypted = $false
    Description = 'DNS Name for the PasswordManager service.'
    ResourceGroupName = $resGroupName
    AutomationAccountName = $autoAccountDev
}
New-AzureRmAutomationVariable @params

$params = @{
    Name = 'DSC_InstallTopDirectory'
    Value = '\\srv.aau.dk\Fileshares\dsc-install'
    Encrypted = $false
    Description = 'Top directory for DSC install files'
    ResourceGroupName = $resGroupName
    AutomationAccountName = $autoAccountDev
}
New-AzureRmAutomationVariable @params

$pwmgrPasswordLists = @{
    VMServers = @{ id=38; key='457df632eac89b34fb383527e9cda685' }
    Services = @{ id=39; key='724f89d3c65be3afe36b8a275c349dfd' }
}
$params = @{
    Name = 'PasswordManager_PasswordLists'
    Value = $pwmgrPasswordLists
    Encrypted = $true
    Description = 'PasswordLists with ids and keys for use with PasswordManager'
    ResourceGroupName = $resGroupName
    AutomationAccountName = $autoAccountDev
}
New-AzureRmAutomationVariable @params

Exit

$q = Get-AzureRmAutomationRunbook -ResourceGroupName AutomationGroup -AutomationAccountName bkAutomationTest01Dev
$q | Format-Table Name,RunbookType
$w = Get-AzureRmAutomationRunbook -Name 'New-PMPassword' -ResourceGroupName AutomationGroup -AutomationAccountName bkAutomationTest01Dev
