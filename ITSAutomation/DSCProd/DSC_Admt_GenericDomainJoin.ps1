configuration DSC_admt_GenericDomainJoin
{
    Import-DscResource -ModuleName xCertificate, xComputerManagement, xPSDesiredStateConfiguration, PSDesiredStateConfiguration

    $cred = Get-AutomationPSCredential -Name 'DSC_admt_Domain'
    $installPath = Get-AutomationVariable -Name 'DSC_InstallTopDirectory'

    Node localhost
    {
        xComputer DomainJoin
        {
            Name = 'localhost'
            DomainName = 'admt.aau.dk'
            Credential = $cred
            JoinOU = 'OU=Servers,DC=admt,DC=aau,DC=dk'
        }

        xGroup LocalAdministrators {
            Ensure = 'Present'
            GroupName = 'Administrators'
            MembersToInclude = 'IT CoreMgmt Admins@srv.aau.dk'
            Credential = $cred
            DependsOn = '[xComputer]DomainJoin'
        }

        xWindowsFeature RSATADTools {
            Ensure = 'Present'
            Name = 'RSAT-AD-PowerShell'
        }

        xCertificateImport vROCertificate {
            Ensure = 'Present'
            Thumbprint = '61f224a03e50cf92ad57d594e34be16c1e2886c5'
            Path = $installPath + '\Certificates\esx-vro01.srv.aau.dk.cer'
            Location = 'LocalMachine'
            Store = 'Root'
            PsDscRunAsCredential = $cred
        }

#        xCertReq HostCertificate {
#            Subject = 'test.admt.aau.dk'
#            CertificateTemplate = 'Machine'
#            DependsOn = '[xComputer]DomainJoin'
#        }
    }
}

#DSC_Admt_DomainJoin -ConfigurationData .\Config_admt.psd1