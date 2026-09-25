        # SCRIPT RUN AS ADMIN
        If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
        {Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
        Exit}
        $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + " (Administrator)"
        $Host.UI.RawUI.BackgroundColor = "Black"
        $Host.PrivateData.ProgressBackgroundColor = "Black"
        $Host.PrivateData.ProgressForegroundColor = "White"
        Clear-Host

        # FUNCTION RUN AS TRUSTED INSTALLER
        function Run-Trusted([String]$command) {
        try {
    	Stop-Service -Name TrustedInstaller -Force -ErrorAction Stop -WarningAction Stop
  		}
  		catch {
    	taskkill /im trustedinstaller.exe /f >$null
  		}
        $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='TrustedInstaller'"
        $DefaultBinPath = $service.PathName
  		$trustedInstallerPath = "$env:SystemRoot\servicing\TrustedInstaller.exe"
  		if ($DefaultBinPath -ne $trustedInstallerPath) {
    	$DefaultBinPath = $trustedInstallerPath
  		}
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
        $base64Command = [Convert]::ToBase64String($bytes)
        sc.exe config TrustedInstaller binPath= "cmd.exe /c powershell.exe -encodedcommand $base64Command" | Out-Null
        sc.exe start TrustedInstaller | Out-Null
        sc.exe config TrustedInstaller binpath= "`"$DefaultBinPath`"" | Out-Null
        try {
    	Stop-Service -Name TrustedInstaller -Force -ErrorAction Stop -WarningAction Stop
  		}
  		catch {
    	taskkill /im trustedinstaller.exe /f >$null
  		}
        }
		
        # SCRIPT SILENT
        $progresspreference = 'silentlycontinue'

        Write-Host "REMOVE EDGE`n"
        ## c:\program files (x86)\microsoft
        ## powershell -NoExit -c "reg query 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages' | findstr 'Microsoft-Windows-Internet-Browser-Package' | findstr '~~'"

# stop edge running
$stop = "backgroundTaskHost", "Copilot", "CrossDeviceResume", "GameBar", "MicrosoftEdgeUpdate", "msedge", "msedgewebview2", "OneDrive", "OneDrive.Sync.Service", "OneDriveStandaloneUpdater", "Resume", "RuntimeBroker", "Search", "SearchHost", "Setup", "StoreDesktopExtension", "WidgetService", "Widgets"
$stop | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
Get-Process | Where-Object { $_.ProcessName -like "*edge*" } | Stop-Process -Force -ErrorAction SilentlyContinue

# find edgeupdate.exe
$edgeupdate = @(); "LocalApplicationData", "ProgramFilesX86", "ProgramFiles" | ForEach-Object {
$folder = [Environment]::GetFolderPath($_)
$edgeupdate += Get-ChildItem "$folder\Microsoft\EdgeUpdate\*.*.*.*\MicrosoftEdgeUpdate.exe" -rec -ea 0
}

# find edgeupdate & allow uninstall regedit
$global:REG = "HKCU:\SOFTWARE", "HKLM:\SOFTWARE", "HKCU:\SOFTWARE\Policies", "HKLM:\SOFTWARE\Policies", "HKCU:\SOFTWARE\WOW6432Node", "HKLM:\SOFTWARE\WOW6432Node", "HKCU:\SOFTWARE\WOW6432Node\Policies", "HKLM:\SOFTWARE\WOW6432Node\Policies"
foreach ($location in $REG) { Remove-Item "$location\Microsoft\EdgeUpdate" -recurse -force -ErrorAction SilentlyContinue }

# uninstall edgeupdate
foreach ($path in $edgeupdate) {
if (Test-Path $path) { Start-Process -Wait $path -Args "/unregsvc" | Out-Null }
do { Start-Sleep 3 } while ((Get-Process -Name "setup", "MicrosoftEdge*" -ErrorAction SilentlyContinue).Path -like "*\Microsoft\Edge*")
if (Test-Path $path) { Start-Process -Wait $path -Args "/uninstall" | Out-Null }
do { Start-Sleep 3 } while ((Get-Process -Name "setup", "MicrosoftEdge*" -ErrorAction SilentlyContinue).Path -like "*\Microsoft\Edge*")
}

# new folder to uninstall edge
New-Item -Path "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

# new file to uninstall edge
New-Item -Path "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" -ItemType File -Name "MicrosoftEdge.exe" -ErrorAction SilentlyContinue | Out-Null

# find edge uninstall string
$regview = [Microsoft.Win32.RegistryView]::Registry32
$microsoft = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regview).
OpenSubKey("SOFTWARE\Microsoft", $true)
$uninstallregkey = $microsoft.OpenSubKey("Windows\CurrentVersion\Uninstall\Microsoft Edge")
try {
$uninstallstring = $uninstallregkey.GetValue("UninstallString") + " --force-uninstall"
} catch {
}

# uninstall edge
Start-Process cmd.exe "/c $uninstallstring" -WindowStyle Hidden -Wait

# clean folder file
Remove-Item -Recurse -Force "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" -ErrorAction SilentlyContinue | Out-Null

# remove edgewebview uninstaller
cmd /c "reg delete `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView`" /f >nul 2>&1"

# remove edge uninstaller
$findmicrosoftedge = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
$microsoftedge = Get-ItemProperty $findmicrosoftedge -ErrorAction SilentlyContinue |
Where-Object { $_.DisplayName -like "*Microsoft Edge*" }
if ($microsoftedge) {
$guid = $microsoftedge.PSChildName
cmd /c "reg delete `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$guid`" /f >nul 2>&1"
}

# remove edge shortcut
Remove-Item -Recurse -Force "$env:SystemDrive\Windows\System32\config\systemprofile\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk" -ErrorAction SilentlyContinue | Out-Null
Remove-Item -Recurse -Force "$env:SystemDrive\Users\Public\Desktop\Microsoft Edge.lnk" -ErrorAction SilentlyContinue | Out-Null

# remove edge folders
Remove-Item -Recurse -Force "$env:SystemDrive\Program Files (x86)\Microsoft" -ErrorAction SilentlyContinue | Out-Null

# remove edge services
$services = Get-Service | Where-Object { $_.Name -match 'Edge' }
foreach ($service in $services) {
cmd /c "sc stop `"$($service.Name)`" >nul 2>&1"
cmd /c "sc delete `"$($service.Name)`" >nul 2>&1"
}

# windows 10 remove microsoft edge legacy package
$EdgeLegacyPackage = (Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages" -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -like "*Microsoft-Windows-Internet-Browser-Package*~~*" }).PSChildName
if ($EdgeLegacyPackage) {
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\$EdgeLegacyPackage"
cmd /c "reg add `"$($regPath.Replace('HKLM:\', 'HKLM\'))`" /v Visibility /t REG_DWORD /d 1 /f >nul 2>&1"
cmd /c "reg delete `"$($regPath.Replace('HKLM:\', 'HKLM\'))\Owners`" /va /f >nul 2>&1"
dism /online /Remove-Package /PackageName:$EdgeLegacyPackage /quiet /norestart 2>$null | Out-Null
}

        Write-Host "REMOVE UWP APPS`n"
        ## ms-settings:appsfeatures
        ## powershell -noexit -command "get-appxpackage | select name | format-table -autosize"

Get-AppXPackage -AllUsers | Where-Object {
# breaks file explorer
$_.Name -notlike '*CBS*' -and
$_.Name -notlike '*Microsoft.AV1VideoExtension*' -and
$_.Name -notlike '*Microsoft.AVCEncoderVideoExtension*' -and
$_.Name -notlike '*Microsoft.HEIFImageExtension*' -and
$_.Name -notlike '*Microsoft.HEVCVideoExtension*' -and
$_.Name -notlike '*Microsoft.MPEG2VideoExtension*' -and
$_.Name -notlike '*Microsoft.Paint*' -and
$_.Name -notlike '*Microsoft.RawImageExtension*' -and
# breaks windows server defender
$_.Name -notlike '*Microsoft.SecHealthUI*' -and
$_.Name -notlike '*Microsoft.VP9VideoExtensions*' -and
$_.Name -notlike '*Microsoft.WebMediaExtensions*' -and
$_.Name -notlike '*Microsoft.WebpImageExtension*' -and
$_.Name -notlike '*Microsoft.Windows.Photos*' -and
# breaks windows server task bar
$_.Name -notlike '*Microsoft.Windows.ShellExperienceHost*' -and
# breaks windows server start menu
$_.Name -notlike '*Microsoft.Windows.StartMenuExperienceHost*' -and
$_.Name -notlike '*Microsoft.WindowsNotepad*' -and
$_.Name -notlike '*Microsoft.WindowsStore*' -and
$_.Name -notlike '*NVIDIACorp.NVIDIAControlPanel*' -and
# breaks windows server immersive control panel
$_.Name -notlike '*windows.immersivecontrolpanel*'
} | Remove-AppxPackage -ErrorAction SilentlyContinue

        Write-Host "REMOVE UWP FEATURES`n"
        ## ms-settings:optionalfeatures
        ## powershell -noexit -command "dism /online /get-capabilities /format:table"

Get-WindowsCapability -Online | Where-Object {
$_.Name -notlike '*Microsoft.Windows.Ethernet*' -and
# windows 10
$_.Name -notlike '*Microsoft.Windows.MSPaint*' -and
# windows 10
$_.Name -notlike '*Microsoft.Windows.Notepad*' -and
$_.Name -notlike '*Microsoft.Windows.Notepad.System*' -and
$_.Name -notlike '*Microsoft.Windows.Wifi*' -and
$_.Name -notlike '*NetFX3*' -and
# windows 11 breaks msi installers if removed
$_.Name -notlike '*VBSCRIPT*' -and
# breaks monitoring programs
$_.Name -notlike '*WMIC*' -and
# windows 10 breaks uwp snippingtool if removed
$_.Name -notlike '*Windows.Client.ShellComponents*'
} | ForEach-Object {
try {
Remove-WindowsCapability -Online -Name $_.Name | Out-Null
} catch { }
}

        Write-Host "REMOVE LEGACY FEATURES`n"
        ## c:\windows\system32\optionalfeatures.exe
		## powershell -noexit -command "dism /online /get-features /format:table"

Get-WindowsOptionalFeature -Online | Where-Object {
$_.FeatureName -notlike '*DirectPlay*' -and
$_.FeatureName -notlike '*LegacyComponents*' -and
$_.FeatureName -notlike '*NetFx3*' -and
# breaks windows server turn windows features on or off
$_.FeatureName -notlike '*NetFx4*' -and
$_.FeatureName -notlike '*NetFx4-AdvSrvs*' -and
# breaks windows server turn windows features on or off
$_.FeatureName -notlike '*NetFx4ServerFeatures*' -and
# breaks search
$_.FeatureName -notlike '*SearchEngine-Client-Package*' -and
# breaks windows server desktop
$_.FeatureName -notlike '*Server-Shell*' -and
# breaks windows server defender
$_.FeatureName -notlike '*Windows-Defender*' -and
# breaks windows server internet
$_.FeatureName -notlike '*Server-Drivers-General*' -and
# breaks windows server internet
$_.FeatureName -notlike '*ServerCore-Drivers-General*' -and
# breaks windows server internet
$_.FeatureName -notlike '*ServerCore-Drivers-General-WOW64*' -and
# breaks windows server turn windows features on or off
$_.FeatureName -notlike '*Server-Gui-Mgmt*' -and
# breaks windows server nvidia app
$_.FeatureName -notlike '*WirelessNetworking*'
} | ForEach-Object {
try {
Disable-WindowsOptionalFeature -Online -FeatureName $_.FeatureName -NoRestart -WarningAction SilentlyContinue | Out-Null
} catch { }
}

		Write-Host "REMOVE LEGACY APPS`n"
		## appwiz.cpl

# uninstall brlapi
cmd /c "sc stop `"brlapi`" >nul 2>&1"
cmd /c "sc delete `"brlapi`" >nul 2>&1"
cmd /c "takeown /f `"$env:SystemRoot\brltty`" /r /d y >nul 2>&1"
cmd /c "icacls `"$env:SystemRoot\brltty`" /grant *S-1-5-32-544:F /t >nul 2>&1"
Remove-Item "$env:SystemRoot\brltty" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# uninstall microsoft gameinput
$findmicrosoftgameinput = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
$microsoftgameinput = Get-ItemProperty $findmicrosoftgameinput -ErrorAction SilentlyContinue |
Where-Object { $_.DisplayName -like "*Microsoft GameInput*" }
if ($microsoftgameinput) {
$guid = $microsoftgameinput.PSChildName
Start-Process "msiexec.exe" -ArgumentList "/x $guid /qn /norestart" -Wait -NoNewWindow
}

# stop onedrive running
Stop-Process -Force -Name OneDrive -ErrorAction SilentlyContinue | Out-Null

# uninstall onedrive
cmd /c "C:\Windows\System32\OneDriveSetup.exe -uninstall >nul 2>&1"
# uninstall office 365 onedrive
Get-ChildItem -Path "C:\Program Files*\Microsoft OneDrive", "$env:LOCALAPPDATA\Microsoft\OneDrive" -Filter "OneDriveSetup.exe" -Recurse -ErrorAction SilentlyContinue |
ForEach-Object { Start-Process -Wait $_.FullName -ArgumentList "/uninstall /allusers" -WindowStyle Hidden -ErrorAction SilentlyContinue }
# windows 10 uninstall onedrive
cmd /c "C:\Windows\SysWOW64\OneDriveSetup.exe -uninstall >nul 2>&1"
# windows 10 remove onedrive scheduled tasks
Get-ScheduledTask | Where-Object {$_.Taskname -match 'OneDrive'} | Unregister-ScheduledTask -Confirm:$false

# uninstall remote desktop connection
try {
Start-Process "mstsc" -ArgumentList "/Uninstall" -ErrorAction SilentlyContinue
} catch { }
# silent window for remote desktop connection
$processExists = Get-Process -Name mstsc -ErrorAction SilentlyContinue
if ($processExists) {
$running = $true
$timeout = 0
do {
$mstscProcess = Get-Process -Name mstsc -ErrorAction SilentlyContinue
if ($mstscProcess -and $mstscProcess.MainWindowHandle -ne 0) {
Stop-Process -Force -Name mstsc -ErrorAction SilentlyContinue | Out-Null
$running = $false
}
Start-Sleep -Milliseconds 100
$timeout++
if ($timeout -gt 100) {
Stop-Process -Name mstsc -Force -ErrorAction SilentlyContinue
$running = $false
}
} while ($running)
}
Start-Sleep -Seconds 1

# windows 10 uninstall old snipping tool
try {
Start-Process "C:\Windows\System32\SnippingTool.exe" -ArgumentList "/Uninstall" -ErrorAction SilentlyContinue
} catch { }
# silent window for uninstall old snipping tool
$processExists = Get-Process -Name SnippingTool -ErrorAction SilentlyContinue
if ($processExists) {
$running = $true
$timeout = 0
do {
$snipProcess = Get-Process -Name SnippingTool -ErrorAction SilentlyContinue
if ($snipProcess -and $snipProcess.MainWindowHandle -ne 0) {
Stop-Process -Force -Name SnippingTool -ErrorAction SilentlyContinue | Out-Null
$running = $false
}
Start-Sleep -Milliseconds 100
$timeout++
if ($timeout -gt 100) {
Stop-Process -Name SnippingTool -Force -ErrorAction SilentlyContinue
$running = $false
}
} while ($running)
}
Start-Sleep -Seconds 1

# windows 10 uninstall update for windows 10 for x64-based systems
$findupdateforwindows = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
$updateforwindows = Get-ItemProperty $findupdateforwindows -ErrorAction SilentlyContinue |
Where-Object { $_.DisplayName -like "*Update for x64-based Windows Systems*" }
if ($updateforwindows) {
$guid = $updateforwindows.PSChildName
Start-Process "msiexec.exe" -ArgumentList "/x $guid /qn /norestart" -Wait -NoNewWindow
}

# windows 10 uninstall microsoft update health tools
$findupdatehealthtools = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
$updatehealthtools = Get-ItemProperty $findupdatehealthtools -ErrorAction SilentlyContinue |
Where-Object { $_.DisplayName -like "*Microsoft Update Health Tools*" }
if ($updatehealthtools) {
$guid = $updatehealthtools.PSChildName
Start-Process "msiexec.exe" -ArgumentList "/x $guid /qn /norestart" -Wait -NoNewWindow
}
cmd /c "reg delete `"HKLM\SYSTEM\ControlSet001\Services\uhssvc`" /f >nul 2>&1"
Unregister-ScheduledTask -TaskName PLUGScheduler -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

# remove 3rd party startup apps
## taskmgr /0 /startup
## ms-settings:startupapps
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\RunNotification`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\RunNotification`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
cmd /c "reg delete `"HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg delete `"HKLM\Software\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\Software\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
cmd /c "reg delete `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce`" /f >nul 2>&1"
cmd /c "reg delete `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`" /f >nul 2>&1"
Remove-Item -Recurse -Force "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup" -ErrorAction SilentlyContinue | Out-Null
Remove-Item -Recurse -Force "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp" -ErrorAction SilentlyContinue | Out-Null
New-Item -Path "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
New-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

# remove 3rd party scheduled tasks
## taskschd.msc
## regedit HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree
## C:\Windows\System32\Tasks
$treePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree"
Get-ChildItem $treePath | Where-Object { $_.PSChildName -ne "Microsoft" } | ForEach-Object {
Run-Trusted "Remove-Item '$($_.PSPath)' -Recurse -Force"
}

$tasksPath = "$env:SystemRoot\System32\Tasks"
Get-ChildItem $tasksPath | Where-Object { $_.Name -ne "Microsoft" } | ForEach-Object {
Remove-Item $_.FullName -Recurse -Force
}

        Write-Host "STORE SETTINGS`n"
        ## ms-windows-store:settings

# open store settings page so disable personalized experiences on ms account sticks
try {
Start-Process "ms-windows-store:settings"
} catch { }
Start-Sleep -Seconds 5

# stop store running
$stop = "WinStore.App", "backgroundTaskHost", "StoreDesktopExtension"
$stop | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

# disable apps updates
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate`" /v `"AutoDownload`" /t REG_DWORD /d `"2`" /f >nul 2>&1"

# create reg file
$storesettings = @'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Settings\LocalState]
; disable video autoplay
"VideoAutoplay"=hex(5f5e10b):00,96,9d,69,8d,cd,93,dc,01
; disable notifications for app installations
"EnableAppInstallNotifications"=hex(5f5e10b):00,36,d0,88,8e,cd,93,dc,01

[HKEY_LOCAL_MACHINE\Settings\LocalState\PersistentSettings]
; disable personalized experiences
"PersonalizationEnabled"=hex(5f5e10b):00,0d,56,a1,8a,cd,93,dc,01
'@
Set-Content -Path "$env:SystemRoot\Temp\windowsstore.reg" -Value $storesettings -Force
$settingsdat = "$env:LocalAppData\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\Settings\settings.dat"
$regfilewindowsstore = "$env:SystemRoot\Temp\windowsstore.reg"

# load hive
reg load "HKLM\Settings" $settingsdat >$null 2>&1

# import reg file
if ($LASTEXITCODE -eq 0) {
reg import $regfilewindowsstore >$null 2>&1

# unload hive
[gc]::Collect()
Start-Sleep -Seconds 2
reg unload "HKLM\Settings" >$null 2>&1
}

		Write-Host "WINDOWS SETTINGS`n"
		## regedit
		## control
        ## ms-settings:
        ## ms-settings:privacy
		## ms-settings:backup
		
# fix 1 for turn off privacy & security app permissions
# stop cam service and remove the database
Stop-Service -Name 'camsvc' -Force -ErrorAction SilentlyContinue
$capabilityconsentstoragedb = "Remove-item `"$env:ProgramData\Microsoft\Windows\CapabilityAccessManager\CapabilityConsentStorage.db*`" -Force"
Run-Trusted -command $capabilityconsentstoragedb

# fix for disable windows backup
cmd /c "reg add `"HKLM\SYSTEM\ControlSet001\Services\CDPUserSvc`" /v `"Start`" /t REG_DWORD /d `"4`" /f >nul 2>&1"

# import steptwo reg file
Start-Process -Wait "regedit.exe" -ArgumentList "/S `"$env:SystemRoot\Temp\reg.reg`"" -WindowStyle Hidden

# disable gamebarpresencewriter.exe
Run-Trusted -command "reg add `"HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter`" /v `"ActivationType`" /t REG_DWORD /d `"0`" /f"

# fix 2 for turn off privacy & security app permissions
# stop cam service and remove the database
Stop-Service -Name 'camsvc' -Force -ErrorAction SilentlyContinue
$capabilityconsentstoragedb = "Remove-item `"$env:ProgramData\Microsoft\Windows\CapabilityAccessManager\CapabilityConsentStorage.db*`" -Force"
Run-Trusted -command $capabilityconsentstoragedb

# disable memorycompression
## powershell -noexit -command "get-mmagent"
Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null

# disable bitlocker
## control /name microsoft.bitlockerdriveencryption
try {
Get-BitLockerVolume |
Where-Object {
$_.ProtectionStatus -eq "On" -or $_.VolumeStatus -ne "FullyDecrypted"
} |
ForEach-Object {
Disable-BitLocker -MountPoint $_.MountPoint -ErrorAction SilentlyContinue | Out-Null
}
} catch { }

# smartscreen for microsoft edge - needs normal boot as admin
cmd /c "reg add `"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Edge\SmartScreenEnabled`" /ve /t REG_DWORD /d `"0`" /f >nul 2>&1"

# smartscreen for microsoft store apps - needs normal boot as admin
cmd /c "reg add `"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost`" /v `"EnableWebContentEvaluation`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# disable scheduled tasks - needs normal boot as admin
## powershell -noexit -command "get-scheduledtask | where-object {$_.taskname -like '*defender*' -or $_.taskname -like '*exploitguard*'} | format-table taskname, state -autosize"
schtasks /Change /TN "Microsoft\Windows\ExploitGuard\ExploitGuard MDM policy Refresh" /Disable 2>$null | Out-Null
schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance" /Disable 2>$null | Out-Null
schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Cleanup" /Disable 2>$null | Out-Null
schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan" /Disable 2>$null | Out-Null
schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Verification" /Disable 2>$null | Out-Null

# disable defragment and optimize your drives scheduled task
## powershell -noexit -command "get-scheduledtask -taskname "scheduleddefrag" | select-object taskname, state"
## dfrgui
Get-ScheduledTask | Where-Object {$_.TaskName -match 'ScheduledDefrag'} | Disable-ScheduledTask | Out-Null

# disable all network adapters except ipv4
## powershell -noexit -command "get-netadapterbinding | select-object name, displayname, componentid, enabled | format-table -autosize"
## ncpa.cpl
$adapterstodisable = @('ms_lldp', 'ms_lltdio', 'ms_implat', 'ms_rspndr', 'ms_tcpip6', 'ms_server', 'ms_msclient', 'ms_pacer')
foreach ($adapterbinding in $adapterstodisable) {
Disable-NetAdapterBinding -Name "*" -ComponentID $adapterbinding -ErrorAction SilentlyContinue
}

# pause updates
## ms-settings:windowsupdate
$pause = (Get-Date).AddDays(365)
$today = Get-Date
$today = $today.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ssZ" )
$pause = $pause.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ssZ" )
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseUpdatesExpiryTime" -Value $pause -Force >$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseFeatureUpdatesEndTime" -Value $pause -Force >$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseFeatureUpdatesStartTime" -Value $today -Force >$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseQualityUpdatesEndTime" -Value $pause -Force >$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseQualityUpdatesStartTime" -Value $today -Force >$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseUpdatesStartTime" -Value $today -Force >$null

# block all windows driver updates
## ms-settings:windowsupdate
reg add "HKLM\Software\Policies\Microsoft\Windows\Device Metadata" /v "PreventDeviceMetadataFromNetwork" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\DeviceInstall\Settings" /v "DisableSendGenericDriverNotFoundToWER" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\DeviceInstall\Settings" /v "DisableSendRequestAdditionalSoftwareToWER" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\DriverSearching" /v "SearchOrderConfig" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "SetAllowOptionalContent" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "AllowTemporaryEnterpriseFeatureControl" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "ExcludeWUDriversInQualityUpdate" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "IncludeRecommendedUpdates" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "EnableFeaturedSoftware" /t REG_DWORD /d 0 /f | Out-Null

# disable if you've been away, when should windows require you to sign in again?
## ms-settings:signinoptions
powercfg /setdcvalueindex scheme_current sub_none consolelock 0 2>$null
powercfg /setacvalueindex scheme_current sub_none consolelock 0 2>$null

# disable set priority notifications
## ms-settings:notifications

# create reg file
$disableprioritynotificationsregcontent = @"
Windows Registry Editor Version 5.00

; disable set priority notifications
"@
$disableprioritynotificationsguid = Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current" -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -match '^\{[a-f0-9-]+\}\$' } |
ForEach-Object { ($_.PSChildName -split '\$')[0] } |
Select-Object -Unique
foreach ($guid in $disableprioritynotificationsguid) {
$disableprioritynotificationsregcontent += "`n`n[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\$guid`$windows.data.donotdisturb.quiethoursprofile`$quiethoursprofilelist\windows.data.donotdisturb.quiethoursprofile`$microsoft.quiethoursprofile.priorityonly]`n"
$disableprioritynotificationsregcontent += '"Data"=hex(3):43,42,01,00,0A,02,01,00,2A,06,DF,B8,B4,CC,06,2A,2B,0E,D0,03,\' + "`n"
$disableprioritynotificationsregcontent += '  43,42,01,00,C2,0A,01,CD,14,06,02,05,00,00,01,01,02,00,03,01,04,00,CC,32,12,\' + "`n"
$disableprioritynotificationsregcontent += '  05,28,4D,00,69,00,63,00,72,00,6F,00,73,00,6F,00,66,00,74,00,2E,00,53,00,63,\' + "`n"
$disableprioritynotificationsregcontent += '  00,72,00,65,00,65,00,6E,00,53,00,6B,00,65,00,74,00,63,00,68,00,5F,00,38,00,\' + "`n"
$disableprioritynotificationsregcontent += '  77,00,65,00,6B,00,79,00,62,00,33,00,64,00,38,00,62,00,62,00,77,00,65,00,21,\' + "`n"
$disableprioritynotificationsregcontent += '  00,41,00,70,00,70,00,29,4D,00,69,00,63,00,72,00,6F,00,73,00,6F,00,66,00,74,\' + "`n"
$disableprioritynotificationsregcontent += '  00,2E,00,57,00,69,00,6E,00,64,00,6F,00,77,00,73,00,41,00,6C,00,61,00,72,00,\' + "`n"
$disableprioritynotificationsregcontent += '  6D,00,73,00,5F,00,38,00,77,00,65,00,6B,00,79,00,62,00,33,00,64,00,38,00,62,\' + "`n"
$disableprioritynotificationsregcontent += '  00,62,00,77,00,65,00,21,00,41,00,70,00,70,00,31,4D,00,69,00,63,00,72,00,6F,\' + "`n"
$disableprioritynotificationsregcontent += '  00,73,00,6F,00,66,00,74,00,2E,00,58,00,62,00,6F,00,78,00,41,00,70,00,70,00,\' + "`n"
$disableprioritynotificationsregcontent += '  5F,00,38,00,77,00,65,00,6B,00,79,00,62,00,33,00,64,00,38,00,62,00,62,00,77,\' + "`n"
$disableprioritynotificationsregcontent += '  00,65,00,21,00,4D,00,69,00,63,00,72,00,6F,00,73,00,6F,00,66,00,74,00,2E,00,\' + "`n"
$disableprioritynotificationsregcontent += '  58,00,62,00,6F,00,78,00,41,00,70,00,70,00,2D,4D,00,69,00,63,00,72,00,6F,00,\' + "`n"
$disableprioritynotificationsregcontent += '  73,00,6F,00,66,00,74,00,2E,00,58,00,62,00,6F,00,78,00,47,00,61,00,6D,00,69,\' + "`n"
$disableprioritynotificationsregcontent += '  00,6E,00,67,00,4F,00,76,00,65,00,72,00,6C,00,61,00,79,00,5F,00,38,00,77,00,\' + "`n"
$disableprioritynotificationsregcontent += '  65,00,6B,00,79,00,62,00,33,00,64,00,38,00,62,00,62,00,77,00,65,00,21,00,41,\' + "`n"
$disableprioritynotificationsregcontent += '  00,70,00,70,00,29,57,00,69,00,6E,00,64,00,6F,00,77,00,73,00,2E,00,53,00,79,\' + "`n"
$disableprioritynotificationsregcontent += '  00,73,00,74,00,65,00,6D,00,2E,00,4E,00,65,00,61,00,72,00,53,00,68,00,61,00,\' + "`n"
$disableprioritynotificationsregcontent += '  72,00,65,00,45,00,78,00,70,00,65,00,72,00,69,00,65,00,6E,00,63,00,65,00,52,\' + "`n"
$disableprioritynotificationsregcontent += '  00,65,00,63,00,65,00,69,00,76,00,65,00,00,00,00,00'
}
$disableprioritynotificationsregfile = "$env:SystemRoot\Temp\disablesetprioritynotifications.reg"
$disableprioritynotificationsregcontent | Out-File -FilePath $disableprioritynotificationsregfile -Encoding ASCII

# import reg file
Start-Process -Wait "regedit.exe" -ArgumentList "/S `"$disableprioritynotificationsregfile`"" -WindowStyle Hidden

# disable app actions
## ms-settings:appactions
# stop c:\windows\systemapps\microsoftwindows.client.cbs_cw5n1h2txyewy running
$stop = "AppActions", "CrossDeviceResume", "DesktopStickerEditorWin32Exe", "DiscoveryHubApp", "FESearchHost", "SearchHost", "SoftLandingTask", "TextInputHost", "VisualAssistExe", "WebExperienceHostApp", "WindowsBackupClient", "WindowsMigration"
$stop | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

# create reg file
$appactions = @'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Settings\LocalState\DisabledApps]
"Microsoft.Paint_8wekyb3d8bbwe"=hex(5f5e10b):01,61,ed,11,34,f7,9f,dc,01
"Microsoft.Windows.Photos_8wekyb3d8bbwe"=hex(5f5e10b):01,61,ed,11,34,f7,9f,dc,01
"MicrosoftWindows.Client.CBS_cw5n1h2txyewy"=hex(5f5e10b):01,61,ed,11,34,f7,9f,dc,01
'@
Set-Content -Path "$env:SystemRoot\Temp\appactions.reg" -Value $appactions -Force
$settingsdat = "$env:LOCALAPPDATA\Packages\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\Settings\settings.dat"
$regfileappactions = "$env:SystemRoot\Temp\appactions.reg"

# load hive
reg load "HKLM\Settings" $settingsdat >$null 2>&1

# import reg file
if ($LASTEXITCODE -eq 0) {
reg import $regfileappactions >$null 2>&1

# unload hive
[gc]::Collect()
Start-Sleep -Seconds 2
reg unload "HKLM\Settings" >$null 2>&1
}

# disable network adapter powersaving & wake on all connected devices
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) {
if ($key.PSChildName -match '^\d{4}$') {
$regPath = $key.Name
# disable adapter powersaving & wake
cmd /c "reg add `"$regPath`" /v `"PnPCapabilities`" /t REG_DWORD /d `"24`" /f >nul 2>&1"
# disable advanced energy efficient ethernet
cmd /c "reg add `"$regPath`" /v `"AdvancedEEE`" /t REG_SZ /d `"0`" /f >nul 2>&1"
# disable energy-efficient ethernet
cmd /c "reg add `"$regPath`" /v `"*EEE`" /t REG_SZ /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"EEELinkAdvertisement`" /t REG_SZ /d `"0`" /f >nul 2>&1"
# system idle power saver
cmd /c "reg add `"$regPath`" /v `"SipsEnabled`" /t REG_SZ /d `"0`" /f >nul 2>&1"
# ultra low power mode
cmd /c "reg add `"$regPath`" /v `"ULPMode`" /t REG_SZ /d `"0`" /f >nul 2>&1"
# disable gigabit lite
cmd /c "reg add `"$regPath`" /v `"GigaLite`" /t REG_SZ /d `"0`" /f >nul 2>&1"
# disable green ethernet
cmd /c "reg add `"$regPath`" /v `"EnableGreenEthernet`" /t REG_SZ /d `"0`" /f >nul 2>&1"
# disable power saving mode
cmd /c "reg add `"$regPath`" /v `"PowerSavingMode`" /t REG_SZ /d `"0`" /f >nul 2>&1"
# disable all wake
cmd /c "reg add `"$regPath`" /v `"S5WakeOnLan`" /t REG_SZ /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"*WakeOnMagicPacket`" /t REG_SZ /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"*ModernStandbyWoLMagicPacket`" /t REG_SZ /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"*WakeOnPattern`" /t REG_SZ /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"WakeOnLink`" /t REG_SZ /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"*ModernStandbyWoLMagicPacket`" /t REG_SZ /d `"0`" /f >nul 2>&1"
}
}

# disable acpi power savings on all connected devices
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\ACPI" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "Device Parameters" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"EnhancedPowerManagementEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"SelectiveSuspendEnabled`" /t REG_BINARY /d `"00`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"SelectiveSuspendOn`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\ACPI" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "WDF" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"IdleInWorkingState`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}

# disable hid power savings on all connected devices
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\HID" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "Device Parameters" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"EnhancedPowerManagementEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"SelectiveSuspendEnabled`" /t REG_BINARY /d `"00`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"SelectiveSuspendOn`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\HID" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "WDF" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"IdleInWorkingState`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}

# disable pci power savings on all connected devices
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\PCI" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "Device Parameters" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"EnhancedPowerManagementEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"SelectiveSuspendEnabled`" /t REG_BINARY /d `"00`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"SelectiveSuspendOn`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\PCI" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "WDF" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"IdleInWorkingState`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}

# disable usb power savings on all connected devices
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\USB" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "Device Parameters" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"EnhancedPowerManagementEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"SelectiveSuspendEnabled`" /t REG_BINARY /d `"00`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"SelectiveSuspendOn`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\USB" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "WDF" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"IdleInWorkingState`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}

# disable acpi wake on all connected devices
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\ACPI" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "Device Parameters" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"WaitWakeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}

# disable hid wake on all connected devices
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\HID" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "Device Parameters" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"WaitWakeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}

# disable pci wake on all connected devices
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\PCI" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "Device Parameters" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"WaitWakeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}

# disable usb wake on all connected devices
$usbKeys = Get-ChildItem -Path "HKLM:\SYSTEM\ControlSet001\Enum\USB" -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.PSChildName -eq "Device Parameters" }
foreach ($key in $usbKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"WaitWakeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}

# turn off windows write-cache buffer flushing on the device on all connected scsi devices
$basePath = "HKLM:\SYSTEM\ControlSet001\Enum\SCSI"
Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq "Device Parameters" } | ForEach-Object {
$diskPath = Join-Path $_.PSPath "Disk"
cmd /c "reg add `"$(($diskPath -replace 'Microsoft.PowerShell.Core\\Registry::',''))`" /v `"CacheIsPowerProtected`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
}

# turn off windows write-cache buffer flushing on the device on all connected nvme devices
$basePath = "HKLM:\SYSTEM\ControlSet001\Enum\NVME"
Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq "Device Parameters" } | ForEach-Object {
$diskPath = Join-Path $_.PSPath "Disk"
cmd /c "reg add `"$(($diskPath -replace 'Microsoft.PowerShell.Core\\Registry::',''))`" /v `"CacheIsPowerProtected`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
}

# import notepad settings
## notepad
# stop notepad running
Stop-Process -Name "Notepad" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# create reg file
$NotepadSettings = @'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Settings\LocalState]
"OpenFile"=hex(5f5e104):01,00,00,00,d1,55,24,57,d1,84,db,01
"GhostFile"=hex(5f5e10b):00,42,60,f1,5a,d1,84,db,01
"RewriteEnabled"=hex(5f5e10b):00,12,4a,7f,5f,d1,84,db,01
'@
Set-Content -Path "$env:SystemRoot\Temp\notepadsettings.reg" -Value $NotepadSettings -Force
$SettingsDat = "$env:LocalAppData\Packages\Microsoft.WindowsNotepad_8wekyb3d8bbwe\Settings\settings.dat"
$RegFileNotepadSettings = "$env:SystemRoot\Temp\notepadsettings.reg"

# load hive
reg load "HKLM\Settings" $SettingsDat >$null 2>&1

# import reg file
if ($LASTEXITCODE -eq 0) {
reg import $RegFileNotepadSettings >$null 2>&1

# unload hive
[gc]::Collect()
Start-Sleep -Seconds 2
reg unload "HKLM\Settings" >$null 2>&1
}

# unpin all taskbar items
cmd /c "reg delete HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband /f >nul 2>&1"
Remove-Item -Recurse -Force "$env:USERPROFILE\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch" -ErrorAction SilentlyContinue | Out-Null
	
# black signout & lockscreen
## ms-settings:lockscreen
# create image
Add-Type -AssemblyName System.Windows.Forms
$screenWidth = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
$screenHeight = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height
Add-Type -AssemblyName System.Drawing
$file = "C:\Windows\Black.jpg"
$edit = New-Object System.Drawing.Bitmap $screenWidth, $screenHeight
$color = [System.Drawing.Brushes]::Black
$graphics = [System.Drawing.Graphics]::FromImage($edit)
$graphics.FillRectangle($color, 0, 0, $edit.Width, $edit.Height)
$graphics.Dispose()
$edit.Save($file)
$edit.Dispose()

# set image
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP`" /v `"LockScreenImagePath`" /t REG_SZ /d `"C:\Windows\Black.jpg`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP`" /v `"LockScreenImageStatus`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# black wallpaper
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"Wallpaper`" /t REG_SZ /d `"C:\Windows\Black.jpg`" /f >nul 2>&1"
rundll32.exe user32.dll, UpdatePerUserSystemParameters

# remove context menu items
# restore the classic context menu
cmd /c "reg add `"HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32`" /ve /t REG_SZ /d `"`" /f >nul 2>&1"

# remove customize this folder
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer`" /v `"NoCustomizeThisFolder`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# remove pin to quick access
cmd /c "reg delete `"HKCR\Folder\shell\pintohome`" /f >nul 2>&1"

# remove add to favorites
cmd /c "reg delete `"HKCR\*\shell\pintohomefile`" /f >nul 2>&1"

# remove troubleshoot compatibility
cmd /c "reg delete `"HKCR\exefile\shellex\ContextMenuHandlers\Compatibility`" /f >nul 2>&1"

# remove open in terminal
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked`" /v `"{9F156763-7844-4DC4-B2B1-901F640F5155}`" /t REG_SZ /d `"`" /f >nul 2>&1"

# remove scan with defender
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked`" /v `"{09A47860-11B0-4DA5-AFA5-26D86198A780}`" /t REG_SZ /d `"`" /f >nul 2>&1"

# remove give access to
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked`" /v `"{f81e9010-6ea4-11ce-a7ff-00aa003ca9f6}`" /t REG_SZ /d `"`" /f >nul 2>&1"

# remove include in library
cmd /c "reg delete `"HKCR\Folder\ShellEx\ContextMenuHandlers\Library Location`" /f >nul 2>&1"

# remove share
cmd /c "reg delete `"HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\ModernSharing`" /f >nul 2>&1"

# remove restore previous versions
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer`" /v `"NoPreviousVersionsPage`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# remove send to
cmd /c "reg delete `"HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\SendTo`" /f >nul 2>&1"
cmd /c "reg delete `"HKCR\UserLibraryFolder\shellex\ContextMenuHandlers\SendTo`" /f >nul 2>&1"

# windows 10 import start menu
# delete startmenulayout.xml
Remove-Item -Recurse -Force "$env:SystemDrive\Windows\StartMenuLayout.xml" -ErrorAction SilentlyContinue | Out-Null

# create startmenulayout.xml
$MultilineComment = @'
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
    <LayoutOptions StartTileGroupCellWidth="6" />
    <DefaultLayoutOverride>
        <StartLayoutCollection>
            <defaultlayout:StartLayout GroupCellWidth="6" />
        </StartLayoutCollection>
    </DefaultLayoutOverride>
</LayoutModificationTemplate>
'@
Set-Content -Path "C:\Windows\StartMenuLayout.xml" -Value $MultilineComment -Force -Encoding ASCII

# assign startmenulayout.xml registry
$layoutFile="C:\Windows\StartMenuLayout.xml"
$regAliases = @("HKLM", "HKCU")
foreach ($regAlias in $regAliases){
$basePath = $regAlias + ":\SOFTWARE\Policies\Microsoft\Windows"
$keyPath = $basePath + "\Explorer"
IF(!(Test-Path -Path $keyPath)) {
New-Item -Path $basePath -Name "Explorer" | Out-Null
}
Set-ItemProperty -Path $keyPath -Name "LockedStartLayout" -Value 1 | Out-Null
Set-ItemProperty -Path $keyPath -Name "StartLayoutFile" -Value $layoutFile | Out-Null
}

# restart explorer
Stop-Process -Force -Name explorer -ErrorAction SilentlyContinue | Out-Null
Start-Sleep -Seconds 5

# disable lockedstartlayout registry
foreach ($regAlias in $regAliases){
$basePath = $regAlias + ":\SOFTWARE\Policies\Microsoft\Windows"
$keyPath = $basePath + "\Explorer"
Set-ItemProperty -Path $keyPath -Name "LockedStartLayout" -Value 0
}

# delete startmenulayout.xml
Remove-Item -Recurse -Force "$env:SystemDrive\Windows\StartMenuLayout.xml" -ErrorAction SilentlyContinue | Out-Null

# windows 11 import start menu
# remove start2 bin
Remove-Item -Recurse -Force "$env:USERPROFILE\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin" -ErrorAction SilentlyContinue | Out-Null

# decode start2 txt
certutil.exe -decode "$env:SystemRoot\Temp\start2.txt" "$env:SystemRoot\Temp\start2.bin" >$null

# install start2 bin
Copy-Item "$env:SystemRoot\Temp\start2.bin" -Destination "$env:USERPROFILE\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState" -Force -ErrorAction SilentlyContinue | Out-Null

# set start menu apps view to list
cmd /c "reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\Start`" /v `"AllAppsViewMode`" /t REG_DWORD /d `"2`" /f >nul 2>&1"

# restart explorer
Stop-Process -Force -Name explorer -ErrorAction SilentlyContinue | Out-Null

# create start menu & startup shortcuts
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Start Menu Shortcuts 1.lnk")
$Shortcut.TargetPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
$Shortcut.Save()
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Start Menu Shortcuts 2.lnk")
$Shortcut.TargetPath = "$env:AppData\Microsoft\Windows\Start Menu\Programs"
$Shortcut.Save()
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup Programs 1.lnk")
$Shortcut.TargetPath = "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup"
$Shortcut.Save()
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup Programs 2.lnk")
$Shortcut.TargetPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
$Shortcut.Save()

# create recycle bin shortcut
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Recycle Bin.lnk")
$Shortcut.TargetPath = '::{645ff040-5081-101b-9f08-00aa002f954e}'
$Shortcut.Save()

# hide accessibility accessories folders and all contents from start menu
$folders = @(
"$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Accessibility",
"$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Accessibility",
"$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Accessories"
)
foreach ($folder in $folders) {
if (Test-Path $folder) {
cmd /c "attrib +h `"$folder`" >nul 2>&1"
cmd /c "attrib +h `"$folder\*.*`" /s /d >nul 2>&1"
}
}

# set start menu apps view to list
cmd /c "reg add `"HKCU\Software\Microsoft\Windows\CurrentVersion\Start`" /v `"AllAppsViewMode`" /t REG_DWORD /d `"2`" /f >nul 2>&1"

# show all hidden taskbar icons
## ms-settings:taskbar
$notifyiconsettings = Get-ChildItem -Path 'registry::HKEY_CURRENT_USER\Control Panel\NotifyIconSettings' -Recurse -Force
foreach ($setreg in $notifyiconsettings) {
if ((Get-ItemProperty -Path "registry::$setreg").IsPromoted -eq 0) {
}
else {
Set-ItemProperty -Path "registry::$setreg" -Name 'IsPromoted' -Value 1 -Force
}
}

# restart explorer
Stop-Process -Force -Name explorer -ErrorAction SilentlyContinue | Out-Null
Start-Sleep -Seconds 10

        Write-Host "POWER PLAN`n"
        ## powercfg.cpl

# import ultimate power plan
cmd /c "powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 99999999-9999-9999-9999-999999999999 >nul 2>&1"

# set ultimate power plan active
cmd /c "powercfg /SETACTIVE 99999999-9999-9999-9999-999999999999 >nul 2>&1"

# get all powerplans
$output = powercfg /L
$powerPlans = @()
foreach ($line in $output) {

# extract guid manually to avoid language issues
if ($line -match ':') {
$parse = $line -split ':'
$index = $parse[1].Trim().indexof('(')
$guid = $parse[1].Trim().Substring(0, $index)
$powerPlans += $guid
}
}

# delete all powerplans
foreach ($plan in $powerPlans) {
cmd /c "powercfg /delete $plan 2>nul" | Out-Null
}

# disable hibernate
powercfg /hibernate off
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Control\Power`" /v `"HibernateEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Control\Power`" /v `"HibernateEnabledDefault`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# disable lock
cmd /c "reg add `"HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings`" /v `"ShowLockOption`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# disable sleep
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings`" /v `"ShowSleepOption`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# disable fast boot
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power`" /v `"HiberbootEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# disable power throttling
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling`" /v `"PowerThrottlingOff`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# modify desktop & laptop settings
# hard disk turn off hard disk after 0%
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0x00000000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0x00000000 2>$null

# desktop background settings slide show paused
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 0d7dbae2-4294-402a-ba8e-26777e8488cd 309dce9b-bef4-4119-9921-a851fb12f0f4 001 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 0d7dbae2-4294-402a-ba8e-26777e8488cd 309dce9b-bef4-4119-9921-a851fb12f0f4 001 2>$null

# wireless adapter settings power saving mode maximum performance
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 000 2>$null

# sleep
# sleep after 0%
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 238c9fa8-0aad-41ed-83f4-97be242c8f20 29f6c1db-86da-48c5-9fdb-f2b67b1f44da 0x00000000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 238c9fa8-0aad-41ed-83f4-97be242c8f20 29f6c1db-86da-48c5-9fdb-f2b67b1f44da 0x00000000 2>$null

# allow hybrid sleep off
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 238c9fa8-0aad-41ed-83f4-97be242c8f20 94ac6d29-73ce-41a6-809f-6363ba21b47e 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 238c9fa8-0aad-41ed-83f4-97be242c8f20 94ac6d29-73ce-41a6-809f-6363ba21b47e 000 2>$null

# hibernate after
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 238c9fa8-0aad-41ed-83f4-97be242c8f20 9d7815a6-7ee4-497e-8888-515a05f02364 0x00000000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 238c9fa8-0aad-41ed-83f4-97be242c8f20 9d7815a6-7ee4-497e-8888-515a05f02364 0x00000000 2>$null

# allow wake timers disable
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 238c9fa8-0aad-41ed-83f4-97be242c8f20 bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 238c9fa8-0aad-41ed-83f4-97be242c8f20 bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d 000 2>$null

# usb settings
# unhide hub selective suspend timeout
cmd /c "reg add `"HKLM\System\ControlSet001\Control\Power\PowerSettings\2a737441-1930-4402-8d77-b2bebba308a3\0853a681-27c8-4100-a2fd-82013e970683`" /v `"Attributes`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# hub selective suspend timeout 0
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 2a737441-1930-4402-8d77-b2bebba308a3 0853a681-27c8-4100-a2fd-82013e970683 0x00000000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 2a737441-1930-4402-8d77-b2bebba308a3 0853a681-27c8-4100-a2fd-82013e970683 0x00000000 2>$null

# usb selective suspend setting disabled
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 000 2>$null

# unhide usb 3 link power management
cmd /c "reg add `"HKLM\System\ControlSet001\Control\Power\PowerSettings\2a737441-1930-4402-8d77-b2bebba308a3\d4e98f31-5ffe-4ce1-be31-1b38b384c009`" /v `"Attributes`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# usb 3 link power management - off
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 000 2>$null

# power buttons and lid start menu power button shut down
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 4f971e89-eebd-4455-a8de-9e59040e7347 a7066653-8d6c-40a8-910e-a1f54b84c7e5 002 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 4f971e89-eebd-4455-a8de-9e59040e7347 a7066653-8d6c-40a8-910e-a1f54b84c7e5 002 2>$null

# pci express link state power management off
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 000 2>$null

# processor power management
# minimum processor state 100%
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 0x00000064 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 0x00000064 2>$null

# system cooling policy active
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 54533251-82be-4824-96c1-47b60b740d00 94d3a615-a899-4ac5-ae2b-e4d8f634367f 001 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 54533251-82be-4824-96c1-47b60b740d00 94d3a615-a899-4ac5-ae2b-e4d8f634367f 001 2>$null

# maximum processor state 100%
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 0x00000064 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 0x00000064 2>$null

# unhide processor performance core parking min cores
cmd /c "reg add `"HKLM\System\ControlSet001\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583`" /v `"Attributes`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# unpark cpu cores
# processor performance core parking min cores 100%
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0x00000064 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0x00000064 2>$null

# unhide processor performance core parking max cores
cmd /c "reg add `"HKLM\System\ControlSet001\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\ea062031-0e34-4ff1-9b6d-eb1059334028`" /v `"Attributes`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# unpark cpu cores
# processor performance core parking max cores 100%
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb1059334028 0x00000064 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb1059334028 0x00000064 2>$null

# display
# turn off display after 10 min - oled protection
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 600 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 600 2>$null
powercfg /requestsoverride PROCESS "chrome.exe" DISPLAY SYSTEM AWAYMODE 2>$null
powercfg /requestsoverride PROCESS "Discord.exe" DISPLAY SYSTEM AWAYMODE 2>$null

# display brightness 100%
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 7516b95f-f776-4464-8c53-06167f40cc99 aded5e82-b909-4619-9949-f5d71dac0bcb 0x00000064 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 7516b95f-f776-4464-8c53-06167f40cc99 aded5e82-b909-4619-9949-f5d71dac0bcb 0x00000064 2>$null

# dimmed display brightness 100%
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 7516b95f-f776-4464-8c53-06167f40cc99 f1fbfde2-a960-4165-9f88-50667911ce96 0x00000064 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 7516b95f-f776-4464-8c53-06167f40cc99 f1fbfde2-a960-4165-9f88-50667911ce96 0x00000064 2>$null

# enable adaptive brightness off
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 7516b95f-f776-4464-8c53-06167f40cc99 fbd9aa66-9553-4097-ba44-ed6e9d65eab8 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 7516b95f-f776-4464-8c53-06167f40cc99 fbd9aa66-9553-4097-ba44-ed6e9d65eab8 000 2>$null

# video playback quality bias video playback performance bias
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 9596fb26-9850-41fd-ac3e-f7c3c00afd4b 10778347-1370-4ee0-8bbd-33bdacaade49 001 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 9596fb26-9850-41fd-ac3e-f7c3c00afd4b 10778347-1370-4ee0-8bbd-33bdacaade49 001 2>$null

# when playing video optimize video quality
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 9596fb26-9850-41fd-ac3e-f7c3c00afd4b 34c7b99f-9a6d-4b3c-8dc7-b6693b78cef4 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 9596fb26-9850-41fd-ac3e-f7c3c00afd4b 34c7b99f-9a6d-4b3c-8dc7-b6693b78cef4 000 2>$null

# modify laptop settings
# intel(r) graphics settings intel(r) graphics power plan maximum performance
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 44f3beca-a7c0-460e-9df2-bb8b99e0cba6 3619c3f2-afb2-4afc-b0e9-e7fef372de36 002 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 44f3beca-a7c0-460e-9df2-bb8b99e0cba6 3619c3f2-afb2-4afc-b0e9-e7fef372de36 002 2>$null

# amd power slider overlay best performance
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 c763b4ec-0e50-4b6b-9bed-2b92a6ee884e 7ec1751b-60ed-4588-afb5-9819d3d77d90 003 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 c763b4ec-0e50-4b6b-9bed-2b92a6ee884e 7ec1751b-60ed-4588-afb5-9819d3d77d90 003 2>$null

# ati graphics power settings ati powerplay settings maximize performance
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 f693fb01-e858-4f00-b20f-f30e12ac06d6 191f65b5-d45c-4a4f-8aae-1ab8bfd980e6 001 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 f693fb01-e858-4f00-b20f-f30e12ac06d6 191f65b5-d45c-4a4f-8aae-1ab8bfd980e6 001 2>$null

# switchable dynamic graphics global settings maximize performance
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 e276e160-7cb0-43c6-b20b-73f5dce39954 a1662ab2-9d34-4e53-ba8b-2639b9e20857 003 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 e276e160-7cb0-43c6-b20b-73f5dce39954 a1662ab2-9d34-4e53-ba8b-2639b9e20857 003 2>$null

# battery
# critical battery notification off
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f 5dbb7c9f-38e9-40d2-9749-4f8a0e9f640f 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f 5dbb7c9f-38e9-40d2-9749-4f8a0e9f640f 000 2>$null

# critical battery action do nothing
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f 637ea02f-bbcb-4015-8e2c-a1c7b9c0b546 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f 637ea02f-bbcb-4015-8e2c-a1c7b9c0b546 000 2>$null

# low battery level 0%
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f 8183ba9a-e910-48da-8769-14ae6dc1170a 0x00000000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f 8183ba9a-e910-48da-8769-14ae6dc1170a 0x00000000 2>$null

# critical battery level 0%
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f 9a66d8d7-4ff7-4ef9-b5a2-5a326ca2a469 0x00000000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f 9a66d8d7-4ff7-4ef9-b5a2-5a326ca2a469 0x00000000 2>$null

# low battery notification off
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f bcded951-187b-4d05-bccc-f7e51960c258 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f bcded951-187b-4d05-bccc-f7e51960c258 000 2>$null

# low battery action do nothing
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f d8742dcb-3e6a-4b3c-b3fe-374623cdcf06 000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f d8742dcb-3e6a-4b3c-b3fe-374623cdcf06 000 2>$null

# reserve battery level 0%
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f f3c5027d-cd16-4930-aa6b-90db844a8f00 0x00000000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 e73a048d-bf27-4f12-9731-8b2076e8891f f3c5027d-cd16-4930-aa6b-90db844a8f00 0x00000000 2>$null

# immersive control panel
# low screen brightness when using battery saver disable
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 de830923-a562-41af-a086-e3a2c6bad2da 13d09884-f74e-474a-a852-b6bde8ad03a8 0x00000064 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 de830923-a562-41af-a086-e3a2c6bad2da 13d09884-f74e-474a-a852-b6bde8ad03a8 0x00000064 2>$null

# turn battery saver on automatically at never
powercfg /setacvalueindex 99999999-9999-9999-9999-999999999999 de830923-a562-41af-a086-e3a2c6bad2da e69653ca-cf7f-4f05-aa73-cb833fa90ad4 0x00000000 2>$null
powercfg /setdcvalueindex 99999999-9999-9999-9999-999999999999 de830923-a562-41af-a086-e3a2c6bad2da e69653ca-cf7f-4f05-aa73-cb833fa90ad4 0x00000000 2>$null

        Write-Host "TIMER RESOLUTION`n"
        ## services.msc

# compile and create service
Start-Process -Wait "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" -ArgumentList "-out:C:\Windows\SetTimerResolutionService.exe C:\Windows\Temp\settimerresolutionservice.cs" -WindowStyle Hidden

# remove old service if exists
if (Get-Service -Name "Set Timer Resolution Service" -ErrorAction SilentlyContinue) {
    sc.exe delete "Set Timer Resolution Service" | Out-Null
    Start-Sleep -Seconds 2
}

# install and start service
New-Service -Name "Set Timer Resolution Service" -BinaryPathName "$env:SystemDrive\Windows\SetTimerResolutionService.exe" -ErrorAction SilentlyContinue | Out-Null
Set-Service -Name "Set Timer Resolution Service" -StartupType Auto -ErrorAction SilentlyContinue | Out-Null
Set-Service -Name "Set Timer Resolution Service" -Status Running -ErrorAction SilentlyContinue | Out-Null

# enable global timer resolution requests
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel`" /v `"GlobalTimerResolutionRequests`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# rebuild performance counters
## perfmon.msc
cmd /c "cd /d %systemroot%\system32 && lodctr /R >nul 2>&1"
cmd /c "cd /d %systemroot%\sysWOW64 && lodctr /R >nul 2>&1"

# remove uwp apps pesky on ms account
## ms-settings:appsfeatures
## powershell -noexit -command "get-appxpackage | select name | format-table -autosize"
Get-AppxPackage -allusers *MSTeams* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage -allusers *Microsoft.OutlookForWindows* | Remove-AppxPackage -ErrorAction SilentlyContinue

		Write-Host "DISK CLEANUP`n"
		## cleanmgr.exe
		## %temp%
		## temp

# clear %temp% folder
Remove-Item -Path "$env:USERPROFILE\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# clear temp folder
Remove-Item -Path "$env:SystemDrive\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# delete folders & files
Remove-Item "$env:SystemDrive\DumpStack.log" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemDrive\Output.txt" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemDrive\PerfLogs" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemDrive\Windows.old" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemDrive\XboxGames" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemDrive\inetpub" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# clear windows updates cache folder
cmd /c "sc stop `"wuauserv`" >nul 2>&1"
Remove-Item "$env:SystemDrive\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# run disk cleanup
cleanmgr.exe /autoclean /d C:

        Write-Host "RESTORE POINT`n"
        ## c:\windows\system32\control.exe sysdm.cpl ,4
        ## rstrui

try {
# allow multiple restore points
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore`" /v `"SystemRestorePointCreationFrequency`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# enable restore point
Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue | Out-Null

# create restore point
Checkpoint-Computer -Description "backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue | Out-Null
} catch { }

        Write-Host "RESTARTING`n" -ForegroundColor Red

# restart
Start-Sleep -Seconds 5
shutdown -r -t 00