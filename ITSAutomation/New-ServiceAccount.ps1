workflow New-ServiceAccount {
    param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        [string] $ServiceName,

        #FQDN for the domain in which the service account should be created
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=1)]
        [string] $ServiceDomain,
        
        #UPN for the manager object (for now we only support User accounts - should be group at some point!)
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=2)]
        [string] $ManagerUPN,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=3)]
        [string] $SubService
    )

    # Get credential from SMA
    try {
        $cred = Get-AutomationPSCredential -Name SVC_SMAWorker_Writer
    } catch {
        throw "Error getting credentials from SMA variable (SVC_SMAWorker_Writer@srv.aau.dk)..."
    }

    $objDomain = Get-ADDomain -Identity $ServiceDomain
    $domainDN = $objDomain.DistinguishedName
    
    $managerDomain = $ManagerUPN.Split('@')[1]
    $objManager = InlineScript {
        try {
            Get-ADUser -Identity $($Using:ManagerUPN).Split('@')[0] -Server $Using:managerDomain -ErrorAction Stop
        } catch {
            $empty
        }
    }
    if ($objManager -eq $empty) { throw "$ManagerUPN not found!" }
    
    #######################
    #Create Service Account
    $ServiceAccountOU = "OU=Service Identities,OU=Admins,$domainDN"
    if (($SubService -eq "") -or ($SubService -eq $empty)) {
        $name = "SVC_$ServiceName"
        $desc = "Service account for the $ServiceName service"
    } else {
        $name = "SVC_${ServiceName}_$SubService"
        $desc = "Service account for the $ServiceName/$SubService service"
    }

    $upn = "$name@$ServiceDomain"
    $managerinfo = "Manager: '" + $managerUPN + "' [" + (Get-Date).ToString() + "]"

    $user = InlineScript {
        try {
            Get-ADUser -Identity $($Using:upn).Split('@')[0] -Server $Using:ServiceDomain -ErrorAction Stop
        } catch {
            $empty
        }
    }

    If ($user -eq $empty) {
        $pwdinfo = Add-PMAccountAndPassword -UserName $upn -PwdListName 'Services' -Title "Service Account $upn" -Description $desc
        $secpwd = ConvertTo-SecureString -String $pwdinfo.Password -AsPlainText -Force
    
        Write-Verbose -Message "Creating $upn..."
        New-ADUser -Name $name -AccountPassword $secpwd -Description $desc -DisplayName $name -PasswordNeverExpires $true -Path $ServiceAccountOU -UserPrincipalName $upn -Enabled $true -Server $ServiceDomain -Credential $cred

        $result = @{
            Result = 'Service created successfully.'
            ReturnCode = 0
            ServiceAccount = $upn
            PasswordLink = $pwdinfo.Permalink
        }
    } else {
        Write-Verbose -Message "'$upn' already exists..."
        $result = @{
            Result = "Service Account ($upn) already exist."
            ReturnCode = 0
        }
    }

    #Set the manager and info - has to be Inline as Manager cannot be set otherwise using Workflows...
    InlineScript {
        $managerinfo = "Manager: '" + $using:managerUPN + "' [" + (Get-Date).ToString() + "]"
        $managerinfo += "`r`nPasswordLink: " + ($Using:pwdinfo).Permalink
        $managerObj = Get-ADUser -Identity $($Using:ManagerUPN).Split('@')[0] -Server $Using:managerDomain -ErrorAction Stop

        $user = Get-ADUser -Identity $($Using:upn).Split('@')[0] -Server $Using:ServiceDomain -Properties info -ErrorAction Stop
        if ($user -ne $empty) {
            $info = $user.info + "`n" + $managerinfo
        } else {
            $info = $managerinfo
        }

        $user | Set-ADUser -Server $using:ServiceDomain -Manager $managerObj -Replace @{info=$info} -Credential $using:cred
    }
    $result += @{
        AdditionalInfo = "Manager set to $ManagerUPN and info added accordingly."
    }

    $result
}
