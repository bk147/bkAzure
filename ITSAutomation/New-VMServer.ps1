#
# vRO Certificate Should be installed on the runbook workers for this workflow to work!
#
workflow New-VMServer
{
    param(
        # Name of the new VM to create - use FQDN if possible
        [Parameter(Mandatory = $true)]
        [string]
        $Name,
    
        # This parameter specifies the name of the vlan to use - if omittet the Test vlan is used...
        [Parameter(Mandatory = $false)]
        [string]
        $VlanName,
    
        # Used if static ip addresses is used - the format is in IDR (ex: 172.11.12.13/25)
        [Parameter(Mandatory = $false)]
#        [ValidatePattern("\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}")] #Basic Validation...
        [string]
        $IPAddress,
    
        # Datacenter
        [Parameter(Mandatory = $false)]
#        [ValidateSet('dc2-old', 'dc2-new', 'slvd', 'hosting')]
        [string]
        $Datacenter = 'dc2-new',
    
        # Owner
        [Parameter(Mandatory = $false)]
        [string]
        $Owner,
    
        # Version of the Operating system to be installed
        [Parameter(Mandatory = $false)]
#        [ValidateSet('ws2012r2', 'ws2k16')]
        [string]
        $OSVersion = 'ws2k16',
    
        # Wait for the virtual machine to be fully created - times out after 60 minuts (valid values are: 'yes', 'no')
        [Parameter(Mandatory = $false)]
        [string] $WaitUntilFinished = "yes"
    )

#####################
#Main script...
#####################
    $vRoApiUrl = 'https://esx-vro01.srv.aau.dk:8281/vco/api'
#    $workflowname = 'New Windows Server'
    $workflowid = 'ea919d9a-3735-4ae4-b3f3-ef058ac00734'

#Problem with this Workflow
    $pwd = Add-PMAccountAndPassword -UserName Administrator -PwdListName VMServers -Title "$Name" -Description "Local Administrator for $Name"
    Write-Verbose -Message "Added password to PM"

    if ([string]::IsNullOrEmpty($Owner) -eq $true) { $Owner = "PowerShell" }

    #Using inlinescript to remove extra parameters such as PSComputerName,PSShowComputerName,PSSourceJobInstanceId
    $myjson = InlineScript {
        #####################
        #Network Helper functions...
        #####################
        function toBinary ($dottedDecimal) {
            $binary = $empty
            $dottedDecimal.split(".") | ForEach-Object { $binary=$binary + $([convert]::toString($_,2).padleft(8,"0")) }
            return $binary
        }
        function toDottedDecimal ($binary){
            $i = 0
            $dottedDecimal = $empty
            do {
                $dottedDecimal += "." + [string]$([convert]::toInt32($binary.substring($i,8),2)); $i+=8
            } while ($i -le 24)
            return $dottedDecimal.substring(1)
        }
        function GetGateway ($strIP, $length) {
            $ipBinary = toBinary $strIP
            toDottedDecimal $($ipBinary.Substring(0,$length).PadRight(31,"0") + 1)
        }
        function GetNetwork ($strIP, $length) {
            $ipBinary = toBinary $strIP
            toDottedDecimal $($ipBinary.Substring(0,$length).PadRight(32,"0"))
        }
        function GetSubnetMask($length) {
            $ipBinary = "".PadRight($length,'1').PadRight(32,'0')
            toDottedDecimal $ipBinary
        }

        #####################
        # Functions for generating the json for use with vRO
        #####################
        function CreateStringVar ([string] $name, [string] $value) {
            @{type='string';name=$name;scope='local';value=@{string=@{value=$value}}}
        }
        function CreateSecureStringVar ([string] $name, [string] $value) {
            @{type='securestring';name=$name;scope='local';value=@{string=@{value=$value}}}
        }
        function CreateBooleanVar ([string] $name, [bool] $value) {
            @{type='boolean';name=$name;scope='local';value=@{boolean=@{value=$value}}}
        }
        function CreateStringArrayVar ([string] $name, [string[]] $value) {
            $jarr = @()
            foreach($val in $value) {
                $jarr += @{string=@{value=$val}}
            }
            @{type='Array/String';name=$name;scope='local';value=@{array=@{elements=$jarr}}}
        }
        
        $parameterlist = @()
        $parameterlist += CreateStringVar -name 'vmName' -value $Using:Name
        $parameterlist += CreateStringVar -name 'vmTemplate' -value $Using:OSVersion
        $parameterlist += CreateStringVar -name 'vmDepartment' -value 'IFS' #Needs to be changed
        $parameterlist += CreateStringVar -name 'vmService' -value 'Unknown' #Needs to be changed
        $parameterlist += CreateStringVar -name 'vmOwner' -value $Using:Owner
        $parameterlist += CreateStringVar -name 'vmSysAdm' -value $Using:Owner #Needs to be changed
        $parameterlist += CreateStringVar -name 'vmAppAdm' -value $Using:Owner #Needs to be changed
        $parameterlist += CreateSecureStringVar -name 'vmPasswordSecure' -value $Using:pwd.password
        $parameterlist += CreateStringVar -name 'vmLocation' -value $Using:Datacenter
        $parameterlist += CreateBooleanVar -name 'startVM' -value $true
        
        if ([string]::IsNullOrEmpty($Using:IPAddress) -eq $true) {
            $parameterlist += CreateBooleanVar -name 'vmDHCP' -value $true
        } else {
            $ip = ($Using:IPAddress).Split('/')[0]
            $iplen = ($Using:IPAddress).Split('/')[1]
            $ipgw = GetGateway -strIP $ip -length $iplen
            $ipmask = GetSubnetMask -length $iplen
        
            $parameterlist += CreateBooleanVar -name 'vmDHCP' -value $false
            $parameterlist += CreateStringVar -name 'vmIP' -value $ip
            $parameterlist += CreateStringVar -name 'vmSubnet' -value $ipmask
            $parameterlist += CreateStringVar -name 'vmGateway' -value $ipgw
            $parameterlist += CreateStringArrayVar -name 'vmDNSServers' -value @("172.18.16.17")
        }
        
        if ([string]::IsNullOrEmpty($Using:VlanName) -eq $false) {
            $parameterlist += CreateStringVar -name 'vmNetworkName' -value $Using:VlanName
        }
    
        @{ parameters=$parameterlist } | ConvertTo-Json -Depth 10
    }

    #Run vRO Workflow
    try {
        $cred = Get-AutomationPSCredential -Name SVC_SMA_vRO_Access        
        if (($cred -eq "") -or ($cred -eq $empty)) {
            throw "Error getting credentials from SMA variable (SVC_SMA_vRO_Access)..."
        }
    } catch {
        throw "Error getting credentials..."
    }

    $apiendpoint = "$vRoApiUrl/workflows/$workflowid/executions"

    # The following returns important info in Headers.Location!
    $r = Invoke-WebRequest -Method Post -Uri $apiendpoint -Credential $cred -Body $myjson -ContentType "application/json" -UseBasicParsing
    $executionpath = $r.Headers.Location
    Write-Verbose -Message "Execution: $executionpath"

    #We create a checkpoint here to be able to resume if something goes wrong afterwards...
    Checkpoint-Workflow

    if ($WaitUntilFinished -ne "no") {
        $timoutInMinutes = 60
        $timeoutTime = [DateTime]::Now.AddMinutes($timoutInMinutes)
        $finished = $false
        while (($finished -eq $false) -and ([DateTime]::Now -le $timeoutTime)) {
            $res = Invoke-RestMethod -Uri $executionpath -Method Get -Credential $cred
            if ($res.state -eq 'failed') {
                $finished = $true
                @{
                    Status = 'Failed'
                    Message = "Failed vRO execution... [$executionpath]"
                }
            } elseif ($res.state -eq 'completed') {
                $finished = $true
                $ip = ($res.'output-parameters' | Where-Object Name -eq 'arg_out_IPaddress').value.string.value
                Write-Verbose -Message "Password available from $($pwd.Permalink) - please move the password to the correct password list!"
                Write-Verbose -Message "Finished creating server ($name)"
                #The following results in a: "Exception has been thrown by the target of an invocation. (An item with the same key has already been added.)" Error - dunno why!?
                #Write-Verbose -Message "Server got ip: <" + $ip + ">"
                Write-Verbose -Message "Server got ip: <$ip>"
                @{
                    Status = 'Completed'
                    Message = "Finished creating $name"
                    PasswordURL = $($pwd.Permalink)
                    Ip = $ip
                }
            } else {
                $t = [DateTime]::Now.ToLongTimeString()
                Write-Verbose -Message "Still waiting: [$($res.state)][$($res.'current-item-display-name')][$t]"
                Start-Sleep -Seconds 30
            }
    
            #We create a checkpoint here to be able to resume if something goes wrong afterwards...
            Checkpoint-Workflow
        }
        if ($finished -eq $false) {
            throw "Timedout [$timeOutTime] - now at: " + [DateTime]::Now
        }
    } else {
        Write-Verbose -Message "Password available from $($pwd.Permalink) - please move the password to the correct password list!"
        Write-Verbose -Message "Started vRO execution at [$executionpath]"
        @{
            Status = 'Running'
            Message = "Started creating $name"
            PasswordURL = $($pwd.Permalink)
            ExecutionPath = $executionpath
        }
    }
}