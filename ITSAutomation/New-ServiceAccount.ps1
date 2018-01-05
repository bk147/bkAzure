workflow New-ServiceAccount {
    param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        [string] $ServiceName,

        #FQDN for the domain in which the service account should be created
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=1)]
        [string] $ServiceDomain,
        
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=2)]
        [string] $ManagerUPN,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=3)]
        [string] $SubService
    )

    $objDomain = Get-ADDomain -Identity $ServiceDomain
    $domainDN = $objDomain.DistinguishedName

    # Get variables from SMA
    try {
        $cred = Get-AutomationPSCredential -Name SVC_SMAWorker_Writer
    } catch {
        throw "Error getting credentials from SMA variable (SVC_SMAWorker_Writer)..."
    }

    $managerDomain = $ManagerUPN.Split('@')[1]
    $objManager = Get-ADUser -Filter {UserPrincipalName -eq $ManagerUPN} -Server $managerDomain -Credential $cred
    if ($objManager -eq $empty) { throw "$ManagerUPN not found!" }
    
    #######################
    #Create Service Account
    $ServiceAccountOU = "OU=Service Identities,OU=Admins,$domainDN"
    if (($SubService -eq "") -or ($SubService -eq $empty)) {
        $name = "SVC_$ServiceName"
        $desc = "Service account for $Service"
    } else {
        $name = "SVC_${ServiceName}_$SubService"
        $desc = "Service account for $Service/$SubService"
    }
    $upn = "$name@$ServiceDomain"

    $user = Get-ADUser -Filter {UserPrincipalName -eq $upn} -Server $ServiceDomain
    If ($user -eq $empty) {
        $pwdinfo = Add-PMAccountAndPassword -UserName $upn -PwdListName Services -Title "Service Account $upn" -Description $desc
        $secpwd = ConvertTo-SecureString -String $pwdinfo.Password -AsPlainText -Force
    
        Write-Verbose -Message "Creating $upn..." | Write-Host -Foreground Green
        New-ADUser -Name $name -AccountPassword $secpwd -Description $desc -DisplayName $name -PasswordNeverExpires $true -Path $ServiceAccountOU -UserPrincipalName $upn -Enabled $true -Manager $objManager -Server $ServiceDomain -Credential $cred

        @{
            Result = 'Service created successfully.'
            ErrorCode = 0
            ServiceAccount = $upn
            PasswordLink = $pwdinfo.Permalink
        }
    } else {
        Write-Verbose -Message "'$upn' already exists..."
        Set-ADUser -Identity $name -Manager $objManager -Credential $cred
        @{
            Result = 'Service Account ($upn) already exists - setting manager'
            ErrorCode = 0
        }
    }

    #Set manager info...
    $managerinfo = "Manager: '" + $managerUPN + "' [" + (Get-Date).ToString() + "]"
    Set-ADUser -Identity $name -Replace @{info=$managerinfo}
}