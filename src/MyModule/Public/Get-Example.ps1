function Get-Example {
    <#
    .SYNOPSIS
        Returns a greeting message.
    .DESCRIPTION
        Returns a greeting string for the given name. This function demonstrates
        the standard layout used in this module template: CmdletBinding, OutputType,
        Mandatory parameter, pipeline support, and comment-based help.
    .PARAMETER Name
        The name to greet. Accepts pipeline input.
    .EXAMPLE
        Get-Example -Name 'World'
        Hello, World!
    .EXAMPLE
        'Alice', 'Bob' | Get-Example
        Hello, Alice!
        Hello, Bob!
    .OUTPUTS
        System.String
    .LINK
        https://github.com/samhodgkinson/powershell-project-base
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    process {
        Invoke-ExampleHelper -Name $Name
    }
}
