@{
    AllNodes = @(
        @{
            NodeName ='*'
            Domain = 'admt.aau.dk'
            OU = "OU=Servers,DC=admt,DC=aau,DC=dk"
        },
        @{
            NodeName = "bkTestAuto03"
            Role = "Member"
        }
    )

    NonNodeData = @{
        SomeMessage = "I love Azure Automation DSC!"
    }
}
