Import-Module DscBuildHelpers
$Error.Clear()
Write-Host ------------------------------------------------------------
$env:PSModulePath -split ';' | Write-Host
Write-Host ------------------------------------------------------------
Get-DscResource -Module CommonTasks | Out-String | Write-Host
Get-DscResource -Module SQLServerDscConfig | Out-String | Write-Host
Write-Host ------------------------------------------------------------

if (-not ($buildVersion = $env:BHBuildVersion)) {
    $buildVersion = '0.0.0'
}
if (-not ($environment = $node.Environment)) {
    $environment = 'NA'
}

configuration "RootConfiguration"
{
    #Import-DscResource -ModuleName PSDscResources
    Import-DscResource -ModuleName CommonTasks
    Import-DscResource -ModuleName SQLServerDscConfig

    $module = Get-Module -Name PSDesiredStateConfiguration
    & $module {
        param(
            [string]$BuildVersion,
            [string]$Environment
        ) 
        $Script:PSTopConfigurationName = "MOF_$($Environment)_$($BuildVersion)"
    } $buildVersion, $environment

    node $ConfigurationData.AllNodes.NodeName {
        Write-Host "`r`n$('-'*75)`r`n$($Node.Name) : $($Node.NodeName) : $(&$module { $Script:PSTopConfigurationName })" -ForegroundColor Yellow
        foreach ($configurationName in (Resolve-NodeProperty -PropertyPath 'Configurations')) {
            Write-Debug "`tLooking up params for $configurationName"
            $properties = Resolve-NodeProperty -PropertyPath $configurationName -DefaultValue @{}
            $dscError = [System.Collections.ArrayList]::new()
            (Get-DscSplattedResource -ResourceName $configurationName -ExecutionName $configurationName -Properties $properties -NoInvoke).Invoke($properties)
            if($Error[0] -and $lastError -ne $Error[0]) {
                $lastIndex = [Math]::Max(($Error.LastIndexOf($lastError) -1), -1)
                if($lastIndex -gt 0) {
                    $Error[0..$lastIndex].Foreach{
                        if($message = Get-DscErrorMessage -Exception $_.Exception) {
                            $null = $dscError.Add($message)
                        }
                    }
                }
                else {
                    if($message = Get-DscErrorMessage -Exception $Error[0].Exception) {
                        $null = $dscError.Add($message)
                    }
                }
                $lastError = $Error[0]
            }

            if($dscError.Count -gt 0) {
                $warningMessage = "    $($Node.Name) : $($Node.Role) ::> $_ "
                $n = [System.Math]::Max(1, 120 - $warningMessage.Length)
                Write-Host "$warningMessage$('.' * $n)FAILED" -ForeGroundColor Yellow
                $dscError.Foreach{
                    Write-Host "`t$message" -ForeGroundColor Yellow
                }
            }
            else {
                $okMessage = "    $($Node.Name) : $($Node.Role) ::> $_ "
                $n = [System.Math]::Max(1, 120 - $okMessage.Length)
                Write-Host "$okMessage$('.' * $n)OK" -ForeGroundColor Green
            }
            $lastCount = $Error.Count
        }
    }
}

$cd = @{}
$cd.Datum = $ConfigurationData.Datum

foreach ($n in $configurationData.AllNodes)
{
    $cd.AllNodes = @($ConfigurationData.AllNodes | Where-Object NodeName -eq $n.NodeName)
    try
    {
        RootConfiguration -ConfigurationData $cd -OutputPath (Join-Path -Path $BuildOutput -ChildPath MOF)
    }
    catch
    {
        Write-Host "Error occured during compilation of node '$($n.NodeName)' : $($_.Exception.Message)" -ForegroundColor Red
        $relevantErrors = $Error | Where-Object Exception -isnot [System.Management.Automation.ItemNotFoundException]
        Write-Host ($relevantErrors[0..2] | Out-String) -ForegroundColor Red
    }
}