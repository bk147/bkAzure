configuration DSC_Admt_DomainJoin
{
    Import-DscResource -ModuleName xCertificate, xComputerManagement, xPSDesiredStateConfiguration, PSDesiredStateConfiguration

    $cred = Get-AutomationPSCredential -Name 'DSC_admt_Domain'
    $installPath = Get-AutomationVariable -Name 'DSC_InstallTopDirectory'

    Node $AllNodes.Where{$_.Role -eq 'Member'}.NodeName
    {
        xComputer AdmtJoin
        {
            Name = $Node.NodeName
            DomainName = $Node.Domain
            Credential = $cred
            JoinOU = $Node.OU
        }

        xGroup LocalAdministrators {
            Ensure = 'Present'
            GroupName = 'Administrators'
            MembersToInclude = 'IT CoreMgmt Admins@srv.aau.dk'
            Credential = $cred
            DependsOn = '[xComputer]AdmtJoin'
        }

        xWindowsFeature RSATADTools {
            Ensure = 'Present'
            Name = 'RSAT-AD-PowerShell'
        }

        xCertificateImport vRO01Certificate {
            Ensure = 'Present'
            Thumbprint = '61f224a03e50cf92ad57d594e34be16c1e2886c5'
            Path = $installPath + '\Certificates\esx-vro01.srv.aau.dk.cer'
            Location = 'LocalMachine'
            Store = 'Root'
            PsDscRunAsCredential = $cred
        }

        xCertificateImport vRO03Certificate {
            Ensure = 'Present'
            Thumbprint = '1467a0b4fc20aa41240e246d25a51c703e1250ce'
            Path = $installPath + '\Certificates\esx-vro03.srv.aau.dk.cer'
            Location = 'LocalMachine'
            Store = 'Root'
            PsDscRunAsCredential = $cred
        }
    }
}