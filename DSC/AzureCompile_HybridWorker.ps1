param(
    # Environment to implement
    [Parameter(Mandatory=$false)]
    [ValidateSet('Dev','Prod')]
    [string]
    $Environment = 'Dev'
)

#Basic parameters used in the environments
$Accounts = @{
    Dev = @{
        ResourceGroup = 'AutomationGroup'
        AutomationAccount = 'ifsAutomationDev'
        LocalDSCPath = 'C:\_Git\_GitHub\bkAzure\DSC'
        DSCFile = 'DSC_Admt_HybridWorker.ps1'
        ConfigFile = 'Config_admt_dev.psd1'
        Description = 'HybridWorker setup'
    }
    Prod = @{
        ResourceGroup = 'AutomationGroup'
#        AutomationAccount = 'ifsAutomationProd'
        AutomationAccount = 'ifsAutomationDev'     #We still have the Production Hybrid Workers in the Dev Account!!!
        LocalDSCPath = 'C:\_Git\_GitHub\bkAzure\DSC'
        DSCFile = 'DSC_Admt_HybridWorker.ps1'
        ConfigFile = 'Config_admt_prod.psd1'
        Description = 'HybridWorker setup'
    }
}

#Import the DSC Configuration into Azure
$params = @{
    ResourceGroupName = $Accounts[$Environment].ResourceGroup
    AutomationAccountName = $Accounts[$Environment].AutomationAccount
    SourcePath = $Accounts[$Environment].LocalDSCPath + "\" + $Accounts[$Environment].DSCFile
    Description = $Accounts[$Environment].Description
    Published = $true
    Force = $true
}
Import-AzureRmAutomationDscConfiguration @params

#Compile the DSC Configuration with the configuration definition
$configdata = Get-Content -Path $Accounts[$Environment].ConfigFile -Raw | Invoke-Expression
$params = @{
    ResourceGroupName = $Accounts[$Environment].ResourceGroup
    AutomationAccountName = $Accounts[$Environment].AutomationAccount
    ConfigurationName = $Accounts[$Environment].DSCFile.Split('.')[0]
    ConfigurationData = $configdata
}
Start-AzureRmAutomationDscCompilationJob @params
