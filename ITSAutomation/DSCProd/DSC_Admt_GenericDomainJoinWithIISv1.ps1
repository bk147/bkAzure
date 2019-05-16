#
# $dscconf = Import-AzureRmAutomationDscConfiguration -ResourceGroupName 'AutomationGroup' -AutomationAccountName 'ifsAutomationDev' -SourcePath 'C:\_Git\_GitHub\bkAzure\ITSAutomation\DSCProd\DSC_Admt_GenericDomainJoinWithIISv1.ps1' -Published -Force
# $dscconf | Start-AzureRmAutomationDscCompilationJob
#
# $dscconfname = 'DSC_Admt_GenericDomainJoinWithIISv1'
# $dscconf = Import-AzureRmAutomationDscConfiguration -ResourceGroupName 'AutomationGroup' -AutomationAccountName 'ifsAutomationDev' -SourcePath "C:\_Git\_GitHub\bkAzure\ITSAutomation\DSCProd\$dscconfname.ps1" -Published -Force
# Start-AzureRmAutomationDscCompilationJob -ResourceGroupName 'AutomationGroup' -AutomationAccountName 'ifsAutomationDev' -ConfigurationName $dscconfname
#
configuration DSC_admt_GenericDomainJoinWithIISv1
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName @{ModuleName = 'CertificateDsc'; ModuleVersion = '4.5.0.0'}
    Import-DscResource -ModuleName @{ModuleName = 'xComputerManagement'; ModuleVersion = '4.1.0.0'}
    Import-DscResource -ModuleName @{ModuleName = 'xPSDesiredStateConfiguration'; ModuleVersion = '8.5.0.0'}
    Import-DscResource -ModuleName @{ModuleName = 'xWebAdministration'; ModuleVersion = '2.5.0.0'}
    Import-DscResource -ModuleName @{ModuleName = 'xDnsServer' ; ModuleVersion = '1.11.0.0'}

    $cred = Get-AutomationPSCredential -Name 'DSC_admt_Domain'
    $QVCred = Get-AutomationPSCredential -Name 'SVC_QV_OAFakturaSMA'
    
    Node localhost
    {
        xComputer DomainJoin
        {
            Name = 'localhost'
            DomainName = 'admt.aau.dk'
            Credential = $cred
            JoinOU = 'OU=Servers,DC=admt,DC=aau,DC=dk'
        }

        WindowsFeature WebServer
        {
            Ensure  = 'Present'
            Name    = 'Web-Server'
        }

        WindowsFeature WebWindowsAuth
        {
            Ensure  = 'Present'
            Name    = 'Web-Windows-Auth'
        }

        WindowsFeature WebServerManagement
        {
            Ensure  = 'Present'
            Name    = 'Web-Mgmt-Console'
        }

        WindowsFeature RSAT-DNS
        {
            Ensure  = 'Present'
            Name    = 'RSAT-DNS-Server'
        }
   
        xWebSite DefaultSite
        {
            Ensure          = 'Present'
            Name            = 'Default Web Site'
            State           = 'Stopped'
            PhysicalPath    = 'C:\inetpub\wwwroot'
            DependsOn       = '[WindowsFeature]WebServer'
        }
        
        # IIS Site Default Values
        xWebSiteDefaults SiteDefaults
        {
            ApplyTo                 = 'Machine'
            LogFormat               = 'IIS'
            LogDirectory            = 'C:\inetpub\logs\LogFiles'
            TraceLogDirectory       = 'C:\inetpub\logs\FailedReqLogFiles'
            DefaultApplicationPool  = 'DefaultAppPool'
            AllowSubDirConfig       = 'true'
            DependsOn               = '[WindowsFeature]WebServer'
        }
    
        #IIS App Pool Default Values
        xWebAppPoolDefaults PoolDefaults
        {
            ApplyTo                 = 'Machine'
            ManagedRuntimeVersion   = 'v4.0'
            IdentityType            = 'ApplicationPoolIdentity'
            DependsOn               = '[WindowsFeature]WebServer'
        }
        
        xWebAppPool QVFakturaAppPool
        {
            Name = 'QVFakturaPool'
            identityType = 'SpecificUser'
            Credential = $QVCred
        }

        xDnsRecord WebServiceRecord
        {
            Ensure = 'Present'
            Name = 'testSvc'
            Zone = 'admt.aau.dk'
            Target = 'bkTest31.admt.aau.dk'
            Type = 'CName'
            DnsServer = 'admt.aau.dk'
            PsDscRunAsCredential = $cred   #Er denne nødvendig - RSAT for DNS ER nødvendig...
            DependsOn = '[WindowsFeature]RSAT-DNS'
        }

        File WebSiteFolder {
            Ensure = 'Present'
            Type = 'Directory'
            DestinationPath = 'C:\inetpub\bkTestWebSite'
        }

        Script CreateSymLinkToQVFakturaShare {
            GetScript = {
                $path = 'C:\inetpub\bkTestWebSite\QVFaktura'
                $item = Get-Item -Path $path -ErrorAction SilentlyContinue
                if ($item -eq $empty -or $item.Target -ne '\\srv.aau.dk\Fileshares\QVFaktura') {
                    $res = $empty
                } else {
                    $res = $item.Target
                }
                @{ Result = $res }
            }
            SetScript = {
                New-Item -Type SymbolicLink -Path 'C:\inetpub\bkTestWebSite\QVFaktura' -Value '\\srv.aau.dk\Fileshares\QVFaktura'
            }
            TestScript = { 
                $sympath = [scriptblock]::Create($GetScript).Invoke()
                if ($sympath -eq '\\srv.aau.dk\Fileshares\QVFaktura') {
                    Write-Verbose -Message "SymLink is correct [$sympath]"
                    return $true
                } else {
                    Write-Verbose -Message "SymLink not correct [$sympath]"
                    return $false
                }
            }
            DependsOn = '[xComputer]DomainJoin','[File]WebSiteFolder'
        }

        xWebsite NewWebsite
        {
            Ensure          = "Present"
            Name            = 'bkTestWebSite'
            State           = "Started"
            PhysicalPath    = "C:\inetpub\bkTestWebSite"
            ApplicationPool = 'QVFakturaPool'
            BindingInfo     = MSFT_xWebBindingInformation
            {
                Protocol              = 'https'
                Port                  = '443'
                CertificateSubject = 'testSvc01.admt.aau.dk'
                HostName              = 'testSvc.admt.aau.dk'
                IPAddress             = '*'
                SSLFlags              = '1'
            }
            AuthenticationInfo =  MSFT_xWebAuthenticationInformation  
            {
                Anonymous = $false
                Basic = $false
                Windows = $true
                Digest = $false
            }
            DependsOn       = "[CertReq]WebServerCertificate","[WindowsFeature]WebServer"
        }

        xWebVirtualDirectory NewVirtualDirectory
        {
            Ensure          = 'Present'
            Website         = "bkTestWebSite"
            WebApplication  = ''
            Name            = 'kredit'
            PhysicalPath    = '\\srv.aau.dk\Fileshares\QVFaktura\kredit'
            PsDscRunAsCredential    = $QVCred
            DependsOn       = '[xWebSite]NewWebsite'

        }

# #        xGroup LocalAdministrators {
# #            Ensure = 'Present'
# #            GroupName = 'Administrators'
# #            MembersToInclude = 'IT CoreMgmt Admins@srv.aau.dk'
# #            Credential = $cred
# #            DependsOn = '[xComputer]DomainJoin'
# #        }

        Script AddCoreMgmtAdminsToLocalAdministrators {
            GetScript = {
                $res = (Get-LocalgroupMember -Group Administrators).Name -contains 'SRV\IT CoreMgmt Admins'
                @{ Result = $res }
            }
            SetScript = { Add-LocalGroupMember -Group Administrators -Member 'SRV\IT CoreMgmt Admins' }
            TestScript = { [bool] ((Get-LocalGroupMember -Group Administrators).Name -eq ('SRV\IT CoreMgmt Admins'))}
            DependsOn = '[xComputer]DomainJoin'
        }

        xWindowsFeature RSATADTools {
            Ensure = 'Present'
            Name = 'RSAT-AD-PowerShell'
        }

        CertReq WebServerCertificate {
            Subject = 'testSvc01.admt.aau.dk'
            CertificateTemplate = 'AAUWebServer'
            CAServerFQDN = 'ad-ca01.aau.dk'
            CARootName = 'AAU Issuing Certification Authority 01'
            FriendlyName = 'testSvc01 Web Certificate'
            SubjectAltName = 'dns=testSvc01.admt.aau.dk&dns=testSvc.admt.aau.dk'
        }
    }
}
