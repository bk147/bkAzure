workflow bkUsingTest
{
    $DSCConfig01 = 'myConfig01'
    $computer = 'bkTestMOMS01.admt.aau.dk'
    [PSCredential]$cred = Get-AutomationPSCredential -Name 'DSC_Admt_Domain'

    InlineScript {
        "[[[InlineScript01]"
        #Using: is available in InlineScript blocks...
        $DSCConfig02 = 'myConfig02'
        "Stuff -01 <" + $DSCConfig01 + ">"
        "Stuff u01 <" + $Using:DSCConfig01 + ">"
        "Stuff -02 <" + $DSCConfig02 + ">"
        "Stuff u02 <" + $Using:DSCConfig02 + ">"

        #Invoke-Command cannot use 'Using:' passing variables as arguments...
        $argList = @{DSCConfig01=$using:DSCConfig01;DSCConfig02=$DSCConfig02}
        Invoke-Command -ComputerName $Using:computer -Credential $using:cred -ArgumentList $argList -ScriptBlock {
            $strHost = (hostname)
            "Host [" + $strHost + "] -01 (" + $DSCConfig01 + ")"
            "Host [" + $strHost + "] u01 (" + $Using:DSCConfig01 + ")"
            "Host [" + $strHost + "] -02 (" + $DSCConfig02 + ")"
            "Host [" + $strHost + "] u02 (" + $Using:DSCConfig02 + ")"
            "Host [" + $strHost + "] a01 (" + $args.DSCConfig01 + ")"
            "Host [" + $strHost + "] a02 (" + $args.DSCConfig02 + ")"
            "<<<<args:"
            $args
            ">>>>"
        }
        "]]]"
    }

    # Same as the Invoke-Command above, but we can use "Using:"
    InlineScript {
        "[[[InlineScript02]"
        (hostname)
        "<" + $DSCConfig01 + ">"
        "<" + $Using:DSCConfig01 + ">"
        "]]]"
    } -PSComputer $computer -PSCredential $cred

}