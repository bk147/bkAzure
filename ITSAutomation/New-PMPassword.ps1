#
# Prereq:
# - Setup the key for the Password Generator in the SMA [PasswordManager_PwdGeneratorKey]
# - Setup the URL for the Service API in the SMA [PasswordManager_ServiceDNS]
#
workflow New-PMPassword {
    param (
        # Which PasswordGeneratorId to use - default is 0
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=1)]
        [int]
        $PwdGeneratorId = 0,

        # Key for the PasswordGenerator - if omitted try getting from SMA credential store...
        [Parameter(Mandatory=$false)]
        [string]
        $PwdGenKey
    )

    try {
        # Get variables from SMA
        [string] $genpwdkey = Get-AutomationVariable -Name 'PasswordManager_PwdGeneratorKey'
        [string] $pwmgrApiURL = Get-AutomationVariable -Name 'PasswordManager_ServiceDNS'
    } catch {
        throw "Cannot get the variable for the 'PwdGeneratorKey' or the 'ServiceDNS'"
    }
    
    $uri = "https://$pwmgrApiURL/api/generatepassword/?PasswordGeneratorID=$PwdGeneratorId&apikey=$genpwdkey"
    #Hack to check if password contains at least one special character, as PwMgr seems to have a bug...
    $specialcharacterlist = "!@#$%^&*+/=_-"
    $nospecialchar = $true
    while ($nospecialchar -eq $true) {
        #Generate password from the pwdGeneratorId
        $pwgenRes = Invoke-RestMethod -Method Get -Uri $uri -ContentType 'application/json'
        $pwd = $pwgenRes[0].Password
        #Check password for special char
        for($i = 0 ; $i -lt $specialcharacterlist.Length ; $i++)  {
            if ($pwd.IndexOf($specialcharacterlist.Chars($i)) -ge 0) {
                $nospecialchar = $false
            }
        }
    }
    $pwd
}