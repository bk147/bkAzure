#
# Delete an IP address from our IPAM master database
#
# WARNING: NO ERROR HANDLING IMPLEMENTED YET
#
workflow Remove-IPamIPAddress {
    param (
        #IPv4 address to delete
        [string] $IPAddress
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
    $headers=@{ Authorization="Basic $base64Token" }
    $res = Invoke-RestMethod -Method Post -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/user/" -Headers $headers
    $token = $res.data.token

    $address = (Invoke-RestMethod -Method Get -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/addresses/search/$IPAddress/" -Headers @{ token=$token }).data

    $res = Invoke-RestMethod -Method Delete -Uri "$($serviceinfo.Url)/api/$($serviceinfo.AppID)/addresses/$($address.id)/" -Headers @{ token=$token }

    @{
        Result = 'Success'
        ResultInfo = $res.data
    }
}