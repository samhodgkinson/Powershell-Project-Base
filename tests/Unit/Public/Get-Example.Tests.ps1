BeforeAll {
    $modulePath = "$PSScriptRoot/../../../src/MyModule/MyModule.psd1"
    Import-Module -Name $modulePath -Force
}

AfterAll {
    Remove-Module -Name MyModule -Force -ErrorAction SilentlyContinue
}

Describe 'Get-Example' {
    Context 'When given a valid name' {
        It 'Returns a greeting string' {
            Get-Example -Name 'World' | Should -Be 'Hello, World!'
        }

        It 'Accepts pipeline input by value' {
            'Alice' | Get-Example | Should -Be 'Hello, Alice!'
        }

        It 'Processes multiple pipeline values' {
            $result = 'Alice', 'Bob' | Get-Example
            $result | Should -HaveCount 2
            $result[0] | Should -Be 'Hello, Alice!'
            $result[1] | Should -Be 'Hello, Bob!'
        }
    }

    Context 'When given invalid input' {
        It 'Throws on empty string' {
            { Get-Example -Name '' } | Should -Throw
        }

        It 'Throws when Name is not supplied' {
            { Get-Example } | Should -Throw
        }
    }
}
