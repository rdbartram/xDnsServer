$Global:DSCModuleName = 'xDnsServer'
$Global:DSCResourceName = 'MSFT_xDnsServerCFZone'

#region HEADER
[String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
if ( (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
    (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) ) {
    & git @('clone', 'https://github.com/PowerShell/DscResource.Tests.git', (Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'))
}
else {
    & git @('-C', (Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'), 'pull')
}
Import-Module (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Global:DSCModuleName `
    -DSCResourceName $Global:DSCResourceName `
    -TestType Unit 
#endregion

# Begin Testing
try {
    #region Pester Tests

    InModuleScope $Global:DSCResourceName {
        #region Pester Test Initialization
        $testZoneName = 'example.com';
        $testMasterServers = @('192.168.1.1');
        $testReplicationScope = 'Domain';
        $testDirectoryPartitionName = "DomainDnsZones.$testZoneName";
        $testParams = @{ Name = $testZoneName; MasterServers = $testMasterServers }

        $fakeDnsADZone = [PSCustomObject] @{
            ZoneName               = $testZoneName;
            MasterServers          = $testMasterServers;
            ReplicationScope       = $testReplicationScope;
            DirectoryPartitionName = $testDirectoryPartitionName;
        }

        $fakePresentTargetResource = @{
            Name                   = $testZoneName
            MasterServers          = $testMasterServers
            ReplicationScope       = $testReplicationScope;
            DirectoryPartitionName = $testDirectoryPartitionName;
            Ensure                 = 'Present'
            CimSession             = @{
                Id           = 1
                Name         = 'CimSession1'
                InstanceId   = 'a23d4d49-f588-407d-9b78-601cd74d8116'
                ComputerName = 'localhost'
                Protocol     = 'WSMAN'
            }
        }

        $fakeAbsentTargetResource = @{ Ensure = 'Absent' }
        #endregion

        #region Function Get-TargetResource
        Describe "$($Global:DSCResourceName)\Get-TargetResource" {
            function Get-DnsServerZone { 
            }

            Mock -CommandName 'Assert-Module' -MockWith { }

            It 'Returns a "System.Collections.Hashtable" object type with schema properties' {
                $targetResource = Get-TargetResource @testParams -ReplicationScope $testReplicationScope;
                $targetResource -is [System.Collections.Hashtable] | Should Be $true;

                $schemaFields = @('Name', 'MasterServers', 'ReplicationScope', 'DirectoryPartitionName', 'Ensure');
                ($Null -eq ($targetResource.Keys.GetEnumerator() | Where-Object -FilterScript { $schemaFields -notcontains $_ })) | Should Be $true;
            }

            It 'Returns "Present" when DNS zone exists and "Ensure" = "Present"' {
                Mock -CommandName Get-DnsServerZone -MockWith { return $fakeDnsADZone; }
                $targetResource = Get-TargetResource @testParams -ReplicationScope $testReplicationScope;
                $targetResource.Ensure | Should Be 'Present';
            }

            It 'Returns "Absent" when DNS zone does not exists and "Ensure" = "Present"' {
                Mock -CommandName Get-DnsServerZone -MockWith { }
                $targetResource = Get-TargetResource @testParams -ReplicationScope $testReplicationScope;
                $targetResource.Ensure | Should Be 'Absent';
            }

            It 'Returns "Present" when DNS zone exists and "Ensure" = "Absent"' {
                Mock -CommandName Get-DnsServerZone -MockWith { return $fakeDnsADZone; }
                $targetResource = Get-TargetResource @testParams -ReplicationScope $testReplicationScope -Ensure Absent;
                $targetResource.Ensure | Should Be 'Present';
            }

            It 'Returns "Absent" when DNS zone does not exist and "Ensure" = "Absent"' {
                Mock -CommandName Get-DnsServerZone -MockWith { }
                $targetResource = Get-TargetResource @testParams -ReplicationScope $testReplicationScope -Ensure Absent;
                $targetResource.Ensure | Should Be 'Absent';
            }
        }
        #endregion


        #region Function Test-TargetResource
        Describe "$($Global:DSCResourceName)\Test-TargetResource" {
            function Get-DnsServerZone { 
            }
            
            It 'Returns a "System.Boolean" object type' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                $targetResource = Test-TargetResource @testParams -ReplicationScope $testReplicationScope;
                $targetResource -is [System.Boolean] | Should Be $true;
            }

            It 'Passes when DNS zone exists and "Ensure" = "Present"' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope | Should Be $true;
            }

            It 'Passes when DNS zone does not exist and "Ensure" = "Absent"' {
                Mock -CommandName Get-TargetResource -MockWith {  }
                Test-TargetResource @testParams -Ensure Absent -ReplicationScope $testReplicationScope | Should Be $true;
            }

            It 'Passes when DNS zone "MasterServers" is correct' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope | Should Be $true;
            }

            It 'Passes when DNS zone "ReplicationScope" is correct' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope | Should Be $true;
            }

            It 'Passes when DNS zone "DirectoryPartitionName" is correct' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope -DirectoryPartitionName $testDirectoryPartitionName | Should Be $true;
            }

            It 'Fails when DNS zone exists and "Ensure" = "Absent"' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                Test-TargetResource @testParams -Ensure Absent -ReplicationScope $testReplicationScope | Should Be $false;
            }

            It 'Fails when DNS zone does not exist and "Ensure" = "Present"' {
                Mock -CommandName Get-TargetResource -MockWith { }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope | Should Be $false;
            }

            It 'Fails when DNS zone "MasterServers" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                $testParams1 = $testParams.Clone();
                $testParams1["MasterServers"] = @("10.10.10.1")
                Test-TargetResource @testParams1 -Ensure Present -ReplicationScope $testReplicationScope | Should Be $false;
            }

            It 'Fails when DNS zone "ReplicationScope" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope 'Forest' | Should Be $false;
            }

            It 'Fails when DNS zone "DirectoryPartitionName" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                Test-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope -DirectoryPartitionName 'IncorrectDirectoryPartitionName' | Should Be $false;
            }
        }
        #endregion


        #region Function Set-TargetResource
        Describe "$($Global:DSCResourceName)\Set-TargetResource" {
            function Get-DnsServerZone { 
            }
            function Add-DnsServerConditionalForwarderZone {
                param ( $Name ) 
            }
            function Set-DnsServerConditionalForwarderZone {
                [CmdletBinding()] param (
                    $Name,
                    $MasterServers,
                    $ReplicationScope,
                    $DirectoryPartitionName,
                    $CimSession ) 
            }
            function Remove-DnsServerZone { 
            }

            It 'Calls "Add-DnsServerConditionalForwarderZone" when DNS zone does not exist and "Ensure" = "Present"' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakeAbsentTargetResource }
                Mock -CommandName Add-DnsServerConditionalForwarderZone -ParameterFilter { $Name -eq $testZoneName } -MockWith { }
                Set-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope;
                Assert-MockCalled -CommandName Add-DnsServerConditionalForwarderZone -ParameterFilter { $Name -eq $testZoneName } -Scope It;
            }

            It 'Calls "Remove-DnsServerZone" when DNS zone does exist and "Ensure" = "Absent"' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                Mock -CommandName Remove-DnsServerZone -MockWith { }
                Set-TargetResource @testParams -Ensure Absent -ReplicationScope $testReplicationScope
                Assert-MockCalled -CommandName Remove-DnsServerZone -Scope It;
            }

            It 'Calls "Set-DnsServerConditionalForwarderZone" when DNS zone "MasterServers" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                Mock -CommandName Set-DnsServerConditionalForwarderZone -ParameterFilter { $MasterServers -eq @("10.10.10.1") } -MockWith { }
                $testParams1 = $testParams.Clone();
                $testParams1["MasterServers"] = @("10.10.10.1")
                Set-TargetResource @testParams1 -Ensure Present -ReplicationScope $testReplicationScope
                Assert-MockCalled -CommandName Set-DnsServerConditionalForwarderZone -ParameterFilter { $MasterServers -eq @("10.10.10.1") } -Scope It;
            }

            It 'Calls "Set-DnsServerConditionalForwarderZone" when DNS zone "ReplicationScope" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                Mock -CommandName Set-DnsServerConditionalForwarderZone -ParameterFilter { $ReplicationScope -eq 'Forest' } -MockWith { }
                Set-TargetResource @testParams -Ensure Present -ReplicationScope 'Forest';
                Assert-MockCalled -CommandName Set-DnsServerConditionalForwarderZone -ParameterFilter { $ReplicationScope -eq 'Forest' } -Scope It;
            }

            It 'Calls "Set-DnsServerConditionalForwarderZone" when DNS zone "DirectoryPartitionName" is incorrect' {
                Mock -CommandName Get-TargetResource -MockWith { return $fakePresentTargetResource; }
                Mock -CommandName Set-DnsServerConditionalForwarderZone -ParameterFilter { $DirectoryPartitionName -eq 'IncorrectDirectoryPartitionName' } -MockWith { }
                Set-TargetResource @testParams -Ensure Present -ReplicationScope $testReplicationScope -DirectoryPartitionName 'IncorrectDirectoryPartitionName';
                Assert-MockCalled -CommandName Set-DnsServerConditionalForwarderZone -ParameterFilter { $DirectoryPartitionName -eq 'IncorrectDirectoryPartitionName' } -Scope It;
            }
        }
        #endregion
    } #end InModuleScope
}
finally {
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
