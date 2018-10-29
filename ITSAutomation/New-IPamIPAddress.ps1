#
# Get a new IP address from our IPAM master database
#
# WARNING: NO ERROR HANDLING IMPLEMENTED YET
#
#
workflow New-IPamIPAddress {
    param (
        #Subnet in CIDR format
        [string] $CIDRSubnet = '172.18.128.0/22',

        #Owner should be in UPN format
        [string] $Owner = 'OwnerPlaceholder',

        #Hostname should be FQDN
        [string] $Hostname = 'HostnamePlaceholder',

        [string] $Description = 'DescriptionPlaceholder'
    )

    #Static variables - should probably be set as a hashtable in an AutomationVariable...
#    $serviceinfo = Get-AutomationVariable -Name IpamInfo
    $serviceinfo = @{
        AppID = 'winnsx'
        Url = 'http://ipam02.srv.aau.dk'
        User = 'bk@its.aau.dk:nopassword'
    }

    #Get Token for further calls to the API
    #Maybe the user/password should be stored as Base64 in the above Automation Variable instead of doint the convertion here !?
    $base64Token = [convert]::ToBase64String([char[]]$serviceinfo.user)
    $res = Invoke-RestMethod -Method Post -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/user/" -Headers @{ Authorization="Basic $base64Token" }
    $token = $res.data.token

    #Get subnet info from a CIDR
    $subnet = (Invoke-RestMethod -Method Get -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/subnets/cidr/$CIDRSubnet/" -Headers @{token=$token}).data

    #Prepare the body as json - We have to use InlineScript to remove extra attributes after doing a ConvertTo-Json (PSComputerName,PSShowComputerName,PSSourceJobInstanceId)
    $body = InlineScript {
        @{
        hostname = $Using:Hostname
        owner = $Using:Owner
        description = $Using:Description
        } | ConvertTo-Json
    }
    $newip = Invoke-RestMethod -Method Post -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/addresses/first_free/$($subnet.id)/" -Headers @{token=$token ; 'Content-Type'='application/json'} -Body $body

    @{
        Result = 'Success'
        IPAddress = $newip.ip
    }
}