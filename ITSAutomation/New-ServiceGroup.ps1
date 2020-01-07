workflow New-ServiceGroup {
    param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        [string] $ServiceName,

        #FQDN for the domain in which the service account should be created
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=1)]
        [string] $ServiceDomain = 'srv.aau.dk',
        
        #UPN for the manager object (for now we only support User accounts - should be group at some point!)
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=2)]
        [string] $ManagerUPN,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=3)]
        [string] $SubService,

        # Don't add or use <service>_Admin group for access
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=4)]
        [switch]
        $DontUseAdminGroup
    )

    Write-Verbose "Script running on [$(hostname)]..."
    
    # Get credential from SMA
    try {
        $cred = Get-AutomationPSCredential -Name SVC_SMAWorker_Writer
    } catch {
        throw "Error getting credentials from SMA variable (SVC_SMAWorker_Writer@srv.aau.dk)..."
    }

    #Get domain info and pdc for AD work
    try {
        $oDomain = Get-ADDomain -Identity $ServiceDomain -ErrorAction Stop
        $pdc = $oDomain.PDCEmulator
        $ouPath = "OU=Application Access,OU=Groups," + $oDomain.DistinguishedName
    } catch {
        throw "Error connecting to ServiceDomain [$ServiceDomain] - Exiting..."
    }

    #Get the manager object
    $strManagerAccount = $ManagerUPN.Split('@')[0]
    $strManagerDomain = $ManagerUPN.Split('@')[1]
    $objManager = Get-ADUser -Identity $strManagerAccount -Server $strManagerDomain -ErrorAction Stop
    if ($objManager -eq $empty) {
        throw "Couldn't find manager [$ManagerUPN] to set on the Service Group - exitting."
    }

    if ($DontUseAdminGroup) {
        "We won't use the Service Admins group for managing this object..."
    } else {
        #Get the Admin group controlling the Service
        $strServiceAdminGroupName = "APP_" + $ServiceName + "_Admins"
        try {
            $objAdminGroup = Get-ADGroup -Identity $strServiceAdminGroupName -Server $pdc -ErrorAction Stop
        } catch {
            #Group doesn't exist Create it...
            #Create admins group as special case
            Write-Verbose -Message "Admins group [$strServiceAdminGroupName] doesn't exist - create it..."
            $desc = "Group with administrator rights for the entire service [$ServiceName] - used to give access to service accounts and other service groups."
            $objAdminGroup = New-ADGroup -Name $strServiceAdminGroupName -GroupScope Universal -Description $desc -Path $ouPath -Server $pdc -Credential $cred -PassThru -ErrorAction Stop

            #Set managedBy attribute and rights
            Set-ADGroup -Identity $objAdminGroup -ManagedBy $objAdminGroup -Server $pdc -Credential $cred -ErrorAction Stop
            $dsaclcmd = "dsacls """ + $objAdminGroup.DistinguishedName + """ /G """ + $objAdminGroup.DistinguishedName + ":WP;member"""
            $res = cmd /c $dsaclcmd
            if ($res[-1] -ne "The command completed successfully") { throw "Couldn't add rights to $strServiceAdminGroupName!" }
            
            #Add manager to the Admins group
            Add-ADGroupMember -Identity $strServiceAdminGroupName -Members $objManager -Server $pdc -Credential $cred -ErrorAction Stop
        }
    }

    #Create the new service group with _Admins rights...
    $strGroupName = "APP_" + $ServiceName + "_" + $SubService
    $desc = "Group used for giving '$SubService' access to the '$ServiceName' service."
    try {
        Write-Verbose -Message "Create service group [$strGroupName]..."
        if ($DontUseAdminGroup) {
            $managerDN = $objManager.DistinguishedName
        } else {
            $managerDN = $objAdminGroup.DistinguishedName
        }
        $objGroup = Get-ADGroup -Filter { samAccountName -eq $strGroupName } -Server $pdc -ErrorAction Stop
        if ($objGroup -eq $empty) {
            $objGroup = InlineScript {
                $strGroupName = $Using:strGroupName
                $desc = $Using:desc
                $managerDN = $Using:managerDN
                $ouPath = $Using:ouPath
                $pdc = $Using:pdc
                $cred = $Using:cred
                $objGroup = New-ADGroup -Name $strGroupName -GroupScope Universal -Description $desc -Path $ouPath -Server $pdc -Credential $cred -PassThru -ErrorAction Stop
                $objGroup | Set-ADGroup -Add @{ManagedBy=$managerDN}
                $objGroup
            }    
            "Created Group [$strGroupName][$($objGroup.DistinguishedName)]"
        } else {
            "Group [$strGroupName][$($objGroup.DistinguishedName)] already exists..."
        }

        #Setup Write Property member rights for manager
        $user = $cred.UserName
        $pwd = $cred.GetNetworkCredential().Password
        $dsaclcmd = "C:\Windows\system32\dsacls.exe """ + $objGroup.DistinguishedName + """ /G """ + $managerDN + ":WP;member"" /user:$user /passwd:""$pwd"""
        $res = cmd /c $dsaclcmd
        if ($res[-1] -ne "The command completed successfully") {
            "Error in dsacls command [$($res[-1])]"
            "<<<"
            $res
            ">>>"
            throw "Couldn't add rights to $strGroupName!"
        } else {
            "Finished setting rights on $strGroupName"
        }
    } catch {
        throw "Error in creating group [$_]"
    }
}