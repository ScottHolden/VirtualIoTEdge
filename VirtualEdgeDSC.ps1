Configuration VirtualEdge {
    Import-DscResource -ModuleName PsDesiredStateConfiguration
    Node "localhost" {
        LocalConfigurationManager
        {
            RefreshMode = 'Push'
            RebootNodeIfNeeded = $true
        }
        WindowsFeature HyperV {
            Ensure = "Present"
            Name   = "Hyper-V"
        }
        WindowsFeature Containers {
            Ensure = "Present"
            Name   = "Containers"
        }
        Script HyperVOptionalFeature {
            GetScript = {            
                return @{            
                    Result = "Ok"          
                }            
            }
            TestScript = {            
                return (Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V").State -eq "Enabled"
            }
            SetScript = {
                Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V" -All

                $global:DSCMachineStatus = 1;
            }
        }
        File CheckpointDirectory {
            Type = 'Directory'
            DestinationPath = 'C:\DSC\Checkpoint'
            Ensure = "Present"
        }
        File TempDirectory {
            Type = 'Directory'
            DestinationPath = 'C:\DSC\Temp'
            Ensure = "Present"
        }
        Script VCRedist {
            GetScript = {            
                return @{            
                    Result = "Ok"          
                }            
            }
            TestScript = {            
                return Test-Path -Path 'C:\DSC\Checkpoint\vcredist.ok'    
            }
            SetScript = {
                $ProgressPreference = 'SilentlyContinue'
                $vcRedistPath = "C:\DSC\Temp\vc_redist.exe"

                if (Test-Path $vcRedistPath) {
                    Remove-Item -Path $vcRedistPath -Force -Confirm:$false
                }

                Invoke-WebRequest -useb "https://download.microsoft.com/download/0/6/4/064F84EA-D1DB-4EAA-9A5C-CC2F0FF6A638/vc_redist.x64.exe" -o $vcRedistPath
                Start-Process -FilePath $vcRedistPath -ArgumentList "/quiet /norestart" -Wait

                "Ok" | Out-File -FilePath "C:\DSC\Checkpoint\vcredist.ok"
            }
        }
        Script DockerForWindows {
            GetScript = {            
                return @{            
                    Result = "Ok"          
                }            
            }
            TestScript = {            
                return Test-Path -Path 'C:\DSC\Checkpoint\dockerforwindows.ok'    
            }
            SetScript = {
                $ProgressPreference = 'SilentlyContinue'
                $dockerForWindowsPath = "C:\DSC\Temp\dockerforwindows.exe"

                if (Test-Path $dockerForWindowsPath) {
                    Remove-Item -Path $dockerForWindowsPath -Force -Confirm:$false
                }

                Invoke-WebRequest -useb "https://download.docker.com/win/stable/19098/Docker%20for%20Windows%20Installer.exe" -o $dockerForWindowsPath
                Start-Process -FilePath $dockerForWindowsPath -ArgumentList "install --quiet" -Wait

                Get-LocalUser |? {$_.Enabled} | Add-LocalGroupMember -Group "docker-users"

                $global:DSCMachineStatus = 1;

                "Ok" | Out-File -FilePath "C:\DSC\Checkpoint\dockerforwindows.ok"
            }
        }
        Script DockerStartup {
            GetScript = {            
                return @{            
                    Result = "Ok"          
                }            
            }
            TestScript = {            
                return Test-Path -Path 'C:\DSC\Checkpoint\dockerstartup.ok'    
            }
            SetScript = {
                $ProgressPreference = 'SilentlyContinue'
                
                Start-Process -FilePath "C:\Program Files\Docker\Docker\DockerCli.exe" -ArgumentList "-SwitchLinuxEngine"

                Start-Sleep -Seconds 240

                "Ok" | Out-File -FilePath "C:\DSC\Checkpoint\dockerstartup.ok"
            }
        }
        Script IoTEdge {
            GetScript = {            
                return @{            
                    Result = "Ok"          
                }            
            }
            TestScript = {            
                return Test-Path -Path 'C:\DSC\Checkpoint\iotedge.ok'    
            }
            SetScript = {
                $ProgressPreference = 'SilentlyContinue'
                $iotEdgePath = "iotedged-windows.zip"

                if (Test-Path $iotEdgePath) {
                    Remove-Item -Path $iotEdgePath -Force -Confirm:$false
                }

                Invoke-WebRequest https://aka.ms/iotedged-windows-latest -o $iotEdgePath
                Expand-Archive $iotEdgePath C:\ProgramData\iotedge -f
                Move-Item c:\ProgramData\iotedge\iotedged-windows\* C:\ProgramData\iotedge\ -Force
                rmdir C:\ProgramData\iotedge\iotedged-windows

                "Ok" | Out-File -FilePath "C:\DSC\Checkpoint\iotedge.ok"
            }
        }
        Environment IoTEdgeCliPath {
            Name    = "Path"
            Ensure  = "Present"
            Path    = $true
            Value   = "C:\ProgramData\iotedge"
        }
        Registry IoTEdgeRegistryCustomSource
        {
            Ensure      = "Present"
            Key         = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\EventLog\Application\iotedged"
            ValueName   = "CustomSource"
            ValueData   = "1"
            ValueType   = "Dword"
        }
        Registry IoTEdgeRegistryTypesSupported
        {
            Ensure      = "Present"
            Key         = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\EventLog\Application\iotedged"
            ValueName   = "TypesSupported"
            ValueData   = "7"
            ValueType   = "Dword"
        }
        Registry IoTEdgeRegistryEventMessageFile
        {
            Ensure      = "Present"
            Key         = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\EventLog\Application\iotedged"
            ValueName   = "EventMessageFile"
            ValueData   = "C:\\ProgramData\\iotedge\\iotedged.exe"
            ValueType   = "String"
        }
        Script IoTEdgeFirewallRule {
            GetScript = {            
                return @{            
                    Result = "Ok"          
                }            
            }
            TestScript = {            
                return @(Get-NetFirewallRule |? {$_.Name -eq "iotedgedinbound"}).Length -gt 0   
            }
            SetScript = {
                $ProgressPreference = 'SilentlyContinue'
                New-NetFirewallRule -DisplayName "iotedged allow inbound 15580,15581" -Direction Inbound `
                                    -Action Allow -Protocol TCP -LocalPort 15580-15581 `
                                    -Program "C:\programdata\iotedge\iotedged.exe" -InterfaceType Any `
                                    -Name "iotedgedinbound"
            }
        }
        Script IoTEdgeConfig {
            GetScript = {            
                return @{            
                    Result = "Ok"          
                }            
            }
            TestScript = {            
                return Test-Path -Path 'C:\DSC\Checkpoint\iotedgeconfig.ok'    
            }
            SetScript = {
                $ProgressPreference = 'SilentlyContinue'

                $configFilePath = "C:\ProgramData\iotedge\config.yaml"

                $timeout = 30;
                while (@(Get-NetAdapter -Name *DockerNAT*).Length -lt 1) {
                    Start-Sleep -Seconds 10
                    $timeout -= 1;
                    if ($timeout -lt 1) {
                        throw "Timeout error!"
                    }
                }

                $ipAddress = @(Get-NetAdapter -Name *DockerNAT* | Get-NetIPAddress -AddressFamily IPv4)[0].IpAddress
                $hostname = $env:ComputerName

                [Environment]::SetEnvironmentVariable("IOTEDGE_HOST", "http://$($ipAddress):15580", [System.EnvironmentVariableTarget]::Machine)

                $config = Get-Content -Path $configFilePath -Raw
                $config = $config.Replace("<GATEWAY_ADDRESS>", $ipAddress)
                $config = $config.Replace("<ADD HOSTNAME HERE>", $hostname)
                $config = $config.Replace("#   network: `"nat`"", "  network: `"azure-iot-edge`"")
                Set-Content -Path $configFilePath -Value $config

                $WshShell = New-Object -comObject WScript.Shell
                $Shortcut = $WshShell.CreateShortcut("$env:Public\Desktop\IoT Edge Config.lnk")
                $Shortcut.TargetPath = $configFilePath
                $Shortcut.Save()

                "Ok" | Out-File -FilePath "C:\DSC\Checkpoint\iotedgeconfig.ok"
            }
        }
        Service IoTEdgeService
        {
            Name        = "iotedge"
            StartupType = "Manual"
            State       = "Stopped"
            Path        = "C:\ProgramData\iotedge\iotedged.exe -c C:\ProgramData\iotedge\config.yaml"
        }
    }
}
VirtualEdge