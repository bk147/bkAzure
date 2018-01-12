workflow Set-ADObjectManager {
    param(
        # UPN for the Account to set manager on
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        [string]
        $AccountUPN,
        
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=1)]
        [string]
        $ManagerUPN
    )

    ($accountSam,$accountDomain) = $AccountUPN.Split('@')
    ($managerSam,$managerDomain) = $ManagerUPN.Split('@')

    # Get variables from SMA
    try {
        $cred = Get-AutomationPSCredential -Name SVC_SMAWorker_Writer
    } catch {
        throw "Error getting credentials from SMA variable (SVC_SMAWorker_Writer)..."
    }

    $managerObj = Get-ADUser -Identity $managerSam -Server $managerDomain
    if ($managerObj -eq $empty) { throw "$ManagerUPN not found!" }
    
    Set-ADUser -Identity $accountSam -Manager $managerObj -Server $accountDomain -Credential $cred
}