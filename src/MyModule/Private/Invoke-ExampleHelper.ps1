function Invoke-ExampleHelper {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    "Hello, $Name!"
}
