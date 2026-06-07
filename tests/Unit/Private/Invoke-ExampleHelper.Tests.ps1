BeforeAll {
    . "$PSScriptRoot/../../../src/MyModule/Private/Invoke-ExampleHelper.ps1"
}

Describe 'Invoke-ExampleHelper' {
    It 'Returns a formatted greeting string' {
        Invoke-ExampleHelper -Name 'Bob' | Should -Be 'Hello, Bob!'
    }

    It 'Handles names with spaces' {
        Invoke-ExampleHelper -Name 'Jane Doe' | Should -Be 'Hello, Jane Doe!'
    }
}
