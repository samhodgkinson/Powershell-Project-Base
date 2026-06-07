function Get-Example {
    <#
    .SYNOPSIS
        Returns a greeting message for the specified name.

    .DESCRIPTION
        Get-Example is the template public function for this module.
        It demonstrates the standard function layout used throughout:

        - [CmdletBinding()] for common parameters (-Verbose, -WhatIf, etc.)
        - [OutputType()] so callers and platyPS know what to expect
        - A Mandatory, pipeline-accepting parameter with validation
        - begin{} / process{} / end{} blocks for correct pipeline semantics
        - Comment-based help covering all sections

        Replace this function with your own cmdlets. Keep one function per
        file in Public/; the build auto-discovers and exports them.

    .PARAMETER Name
        The name to include in the greeting. Must not be null or empty.
        Accepts value from the pipeline and from a pipeline object's Name
        property.

    .EXAMPLE
        Get-Example -Name 'World'

        Hello, World!

        Passes a single name directly.

    .EXAMPLE
        'Alice', 'Bob' | Get-Example

        Hello, Alice!
        Hello, Bob!

        Pipes multiple strings; each produces one output string.

    .EXAMPLE
        [pscustomobject]@{ Name = 'Carol' } | Get-Example

        Hello, Carol!

        Pipes an object whose Name property binds via ValueFromPipelineByPropertyName.

    .INPUTS
        System.String
            You can pipe a string to the Name parameter.

    .OUTPUTS
        System.String
            A greeting string of the form "Hello, <Name>!".

    .NOTES
        Author : Your Name
        Version: 0.1.0

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

    begin {
        # One-time setup: open connections, validate cross-parameter constraints,
        # initialise accumulators for aggregation in end{}.
    }

    process {
        Invoke-ExampleHelper -Name $Name
    }

    end {
        # Post-pipeline cleanup: close connections, emit aggregated results.
    }
}
