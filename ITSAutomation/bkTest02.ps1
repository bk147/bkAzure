param (
    [string] $Name,
    [bool] $IsAdmin
)

If ($IsAdmin -eq $true) {
    "$Name is Admin"
} else {
    "$Name is NOT Admin"
}