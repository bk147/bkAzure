workflow Set-ADObjectManager
{
        param(
        # UPN for the Account to set manager on
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        [string]
        $AccountUPN,
        
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=1)]
        [string]
        $ManagerUPN
    )

    # Get variables from SMA
    try {
        $cred = Get-AutomationPSCredential -Name SVC_SMAWorker_Writer
    } catch {
        throw "Error getting credentials from SMA variable (SVC_SMAWorker_Writer)..."
    }

    InlineScript {
        $accountSam = $($using:AccountUPN).Split('@')[0]
        $accountDomain = $($using:AccountUPN).Split('@')[1]
        $managerSam = $($using:ManagerUPN).Split('@')[0]
        $managerDomain = $($using:ManagerUPN).Split('@')[1]

        $managerObj = Get-ADUser -Identity $managerSam -Server $managerDomain
        if ($managerObj -eq $empty) { throw "$using:ManagerUPN not found!" }
        
        Set-ADUser -Identity $accountSam -Manager $managerObj -Server $accountDomain -Credential $using:cred
    }
}