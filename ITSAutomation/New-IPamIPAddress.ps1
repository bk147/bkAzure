#
# Get a new IP address from our IPAM master database
#
# WARNING: NO ERROR HANDLING IMPLEMENTED YET
#
# BUG: If Description is too long (<=64 chars) we get the following exception back:
# {"code":500,"success":0,"message":"Error: SQLSTATE[22001]: String data, right truncated: 1406 Data too long for column 'description' at row 1","time":0.04} (The remote server returned an error: (500) Internal Server Error.)
# Further there might be a problem using certain characters. Initial Description:
# 'Server used for presenting debit/kredit files in the QlikView system. ØA has an application where certain users can see their files by clicking on a link.'
# after problems did:
# 'Server used for presenting debitkredit files in the QlikView system. OEA has an application where certain users can see their files by clicking on a link.'
# Working: 'Server used for getting debit/kredit files in QlikView.'
#
#
# MISSING:
# 1) We should get some basic info back from IPAM (subnet info, gateway) - gateway is not simple, DNS should also be returned
# 2) We should be able to use a CIDR to get the necessary subnet OR a subnet NAME.
#
# Result example:
#@{
#    UseNet =        App
#    CatNet =        Prod
#    Subnet =        172.18.128.0
#    Gateway =       172.18.128.1
#    Description =   LS-a-win
#    NatNet =        ClientType
#    Result =        Success
#    Mask =          22
#    SecLayer =      Ring1
#    IPAddress =     172.18.128.108
#    DNS =           172.18.16.17
#}
#
# Adding to Azure Dev:
# Import-AzureRmAutomationRunbook -ResourceGroupName 'AutomationGroup' -AutomationAccountName 'ifsAutomationDev' -Path .\ITSAutomation\New-IPamIPAddress.ps1 -Description 'Getting and reserving an IPAddress from IPAM' -Name New-IPamIPAddress -Type PowerShellWorkflow -Published -Force -LogVerbose $true
#
workflow New-IPamIPAddress {
    param (
        #Subnet in CIDR format
        [string] $CIDRSubnet = '192.38.49.0/24',

        #Owner should be in UPN format
        [string] $Owner = 'OwnerPlaceholder',

        #Hostname should be FQDN
        [string] $Hostname = 'HostnamePlaceholder',

        [string] $Description = 'DescriptionPlaceholder'
    )

    #Static variable - should probably be set as a hashtable in an AutomationVariable...
    $serviceinfo = @{
        AppID = 'winnsx'
        Url = 'https://ipam.srv.aau.dk'
    }
    
    #Get Token for further calls to the API
    $cred = Get-AutomationPSCredential -Name 'SVC_IPAM_WinSMA'
    $res = Invoke-RestMethod -Method Post -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/user/" -Credential $cred
    $token = $res.data.token

    #Get subnet info from a CIDR
    $subnet = (Invoke-RestMethod -Method Get -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/subnets/cidr/$CIDRSubnet/" -Headers @{token=$token} -Credential $cred).data

    if ($Description.Length -gt 64) {
        #The IPAM module supports up to 64 characters - do a truncation
        $Description = $Description.Substring(0,64-3) + "..."
    }

    #Prepare the body as json - We have to use InlineScript to remove extra attributes after doing a ConvertTo-Json (PSComputerName,PSShowComputerName,PSSourceJobInstanceId)
    $body = InlineScript {
        @{
        hostname = $Using:Hostname
        owner = $Using:Owner
        description = $Using:Description
        } | ConvertTo-Json
    }
    Write-Verbose -Message "JSON: [$body]"
    $newip = Invoke-RestMethod -Method Post -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/addresses/first_free/$($subnet.id)/" -Headers @{token=$token} -ContentType "application/json; charset=utf-8" -Body $body -Credential $cred

    #Setup basic variables
    $ip = $newip.data
    $length = $subnet.mask

    #The following should be stored in IPAM pr. subnet - but for now they are hardcoded
    $dns = '172.18.16.17'

    #Calculate GW IP - has to do it in an inlinescript as method invocation is not supported in Workflow...
    $gw = InlineScript {
        $ip = $Using:ip
        $length = $Using:length
        $binary = $empty
        $ip.split(".") | ForEach-Object { $binary=$binary + $([convert]::toString($_,2).padleft(8,"0")) }
        $gwbinary = $empty
        $gwbinary = $($binary.Substring(0,$length).PadRight(31,"0") + 1)
        $i = 0
        $dottedDecimal = $empty
        do { $dottedDecimal += "." + [string]$([convert]::toInt32($gwbinary.substring($i,8),2)); $i += 8 } while ($i -le 24)
        $dottedDecimal.Substring(1)    
    }

    @{
        Result = 'Success'
        IPAddress = $ip
        Subnet = $subnet.subnet
        Mask = $length
        Gateway = $gw
        DNS = $dns
        Description = $subnet.description
        SecLayer = $subnet.SecLayer
        UseNet = $subnet.UseNet
        CatNet = $subnet.CatNet
        NatNet = $subnet.NatNet
    }
}
