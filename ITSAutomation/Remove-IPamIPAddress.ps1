#
# Delete an IP address from our IPAM master database
#
# WARNING: NO ERROR HANDLING IMPLEMENTED YET
#
# Adding to Azure Dev:
# Import-AzureRmAutomationRunbook -ResourceGroupName 'AutomationGroup' -AutomationAccountName 'ifsAutomationDev' -Path .\ITSAutomation\Remove-IPamIPAddress.ps1 -Description 'Removing an IP Address from IPAM' -Name Remove-IPamIPAddress -Type PowerShellWorkflow -Published -Force
#
workflow Remove-IPamIPAddress {
    param (
        #IPv4 address to delete
        [string] $IPAddress
    )

    #Static variables - should probably be set as a hashtable in an AutomationVariable...
    $serviceinfo = @{
        AppID = 'winnsx'
        Url = 'https://ipam.srv.aau.dk'
    }

    #Get Token for further calls to the API
    $cred = Get-AutomationPSCredential -Name 'SVC_IPAM_WinSMA'
    $res = Invoke-RestMethod -Method Post -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/user/" -Credential $cred
    $token = $res.data.token

    $address = (Invoke-RestMethod -Method Get -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/addresses/search/$IPAddress/" -Headers @{ token=$token } -Credential $cred).data

    $res = Invoke-RestMethod -Method Delete -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/addresses/$($address.id)/" -Headers @{ token=$token } -Credential $cred

    if ($res.success -eq 'True') { $Result = 'Success' } else { $Result = 'Error' }
    @{
        Result = $Result
        IP = $IPAddress
        ResultInfo = $res.message
    }
}