#
# Get a new IP address from our IPAM master database
#
# WARNING: NO ERROR HANDLING IMPLEMENTED YET
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
    $serviceinfo = Get-AutomationVariable -Name 'IPam_ServiceInfo'
    
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

    #Setup basic variables
    $ip = $newip.ip
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