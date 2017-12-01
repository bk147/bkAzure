workflow Add-PMAccountAndPassword {
    param(
        #The username for the password - try to use the UPN form (uname@domain)
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        [string] $UserName,

        #Password list to create the password in (currently 'Services' or 'VMServers')
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=1)]
        # Cannot use "advanced parameter validation in nested workflows!!!"
        #        [ValidateSet('Services','VMServers')]
        [string] $PwdListName = 'VMServers',

        #Title of the password
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=2)]
        [string] $Title,

        #Description for the password
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=3)]
        [string] $Description,

        #Creator is the user creating the password - use UPN form (ex. bk@its.aau.dk)
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=4)]
        [string] $Creator
    )
    
    # Get variables from SMA
    try {
        [string] $pwmgrURL = Get-AutomationVariable -Name 'PasswordManager_ServiceDNS'
        $PasswordLists = Get-AutomationVariable -Name 'PasswordManager_PasswordLists'
    } catch {
        throw "Cannot get the variable for the 'ServiceDNS' or the 'PasswordLists'"
    }
    
    #Find the Password Generator ID for the list and generate a password from this
    $pwdList = Invoke-RestMethod -Method Get -Uri "https://$pwmgrURL/api/passwordlists/$($PasswordLists.$PwdListName.id)?apikey=$($PasswordLists.$PwdListName.key)"
    $password = New-PMPassword -PwdGeneratorId $pwdList.PasswordGeneratorID
    
    #Register Password in Password Manager
    if (($Creator -eq "") -or ($Creator -eq $empty)) { $Creator = (whoami) }
    if (($Description -eq "") -or ($Description -eq $empty)) { $Description = "No description" }
    if (($Title -eq "") -or ($Title -eq $empty)) { $Title = "No title" }

    #Hotfix for '\' giving API Route problems in PasswordManager
    $Creator = $Creator.Replace('\','#')

    $jsonPassword = "
    {
        'PasswordListID':'$($PasswordLists.$PwdListName.id)',
        'Title':'$Title',
        'UserName':'$UserName',
        'Description':'$Description',
        'Password':'$password',
        'APIKey':'$($PasswordLists.$PwdListName.key)',
        'GenericField1':'$Creator'
    }
    "
    $result = Invoke-Restmethod -Method Post -Uri "https://$pwmgrURL/api/passwords" -ContentType "application/json" -Body $jsonPassword -UseBasicParsing
    $PwdID = $result.PasswordID
    
    #Return a hashtable with relevant info...
    @{
        password = $password
        PwdID = $pwdID
        Permalink = "https://$pwmgrURL/pid=$pwdID"
    }
}