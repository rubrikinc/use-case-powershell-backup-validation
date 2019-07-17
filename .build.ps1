param (
    # Path to the environment JSON file used to identify the vCenter and Rubrik servers
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]$EnvironmentFile,
    # Path to the configuration JSON file used to describe the applications being tested
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]$ConfigFile,
    # Path to the folder that contains XML credential files for this build
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [String]$IdentityPath
)

# Synopsis: Pull configuration details from the root config.json file
task GetConfig {
    $script:Environment = Get-Content -Path $EnvironmentFile | ConvertFrom-Json
    $script:Config = Get-Content -Path $ConfigFile | ConvertFrom-Json
    # If a trailing backslash is omitted, this will make sure it's added to correct for future path + filename activities
    if ($IdentityPath.Substring($IdentityPath.Length - 1) -ne '\') {
        $script:IdentityPath += '\'
    }
}

# Synopsis: Establish connectivity to a Rubrik Cluster
task ConnectRubrik {
    Write-Verbose -Message "Importing Credential file: $($IdentityPath + $Environment.rubrikCred)"
    $Credential = Import-Clixml -Path ($IdentityPath + $Environment.rubrikCred)
    $null = Connect-Rubrik -Server $Environment.rubrikServer -Credential $Credential
    Write-Verbose -Message "Rubrik Status: Connected to $($rubrikConnection.server)" -Verbose
}

# Synopsis: Establish connectivity to a VMware vCenter Server
task ConnectVMware {
    Write-Verbose -Message "Importing Credential file: $($IdentityPath + $Environment.vmwareCred)"
    $Credential = Import-Clixml -Path ($IdentityPath + $Environment.vmwareCred)
    $null = Connect-VIServer -Server $Environment.vmwareServer -Credential $Credential
    Write-Verbose -Message "VMware Status: Connected to $($global:DefaultVIServer.Name)" -Verbose
}

# Synopsis: Create a Live Mount of the intended virtual machine(s)
task CreateLiveMount {
    $i = 0
    # Uses a null array of Mount IDs that will be used to track the request process
    [Array]$Script:MountArray = $null
    foreach ($VM in $Config.virtualMachines) {
        # Check if there is already an existing live mount with the same name
        if ( ( $MountTest = (Get-RubrikMount).mountedVmId | Where-Object {$_.total -ne 0} ) ) {
            if ($MountTest |
                ForEach-Object {
                    (Get-RubrikVM -ID $_ -EA 0).name
                } | Select-String -Pattern "^$($VM.mountName)$" ) {
                throw "The live mount $($VM.mountName) already exists. Please remove manually."
            }
        }
        # The resulting Live Mount has the network interface disabled         
        $MountRequest = Get-RubrikVM $VM.name |
            Get-RubrikSnapshot -Date (Get-Date) | Where-Object {$_.id} | ForEach-Object {
                New-RubrikMount -Id $_.id -MountName $VM.mountName -PowerOn:$true -DisableNetwork:$true -Confirm:$false
            }
        Write-Verbose -Message "$($Config.virtualMachines[$i].mountName) Request Created: $($MountRequest.id)" -Verbose
        $Script:MountArray += $MountRequest
        $i++
    }
}

# Synopsis: Validate the health of the Live Mount request and power state
task ValidateLiveMount {
    $i = 0
    foreach ($Mount in $MountArray) {
        while ($true) {
            $ValidateRequest = (Get-RubrikRequest -id $Mount.id -Type vmware/vm).status
            $ValidatePowerOn = (Get-VM -Name $Config.virtualMachines[$i].mountName -ErrorAction:SilentlyContinue).PowerState
            Write-Verbose -Message "$($Config.virtualMachines[$i].mountName) Status: Request is $ValidateRequest, PowerState is $ValidatePowerOn" -Verbose
            if ($ValidateRequest -in @('RUNNING','ACQUIRING','QUEUED','FINISHING')) {                
                Start-Sleep 5
            } elseif ($ValidateRequest -eq 'SUCCEEDED' -and $ValidatePowerOn -eq 'PoweredOn') {
                break
            } else {
                throw "$($Config.virtualMachines[$i].mountName) mount failed, exiting Build script. Previously live mounted VMs will continue running"
            }
        }
        $i++
    }
}

# Synopsis: Validate the health of the Live Mount VMware Tools
task ValidateLiveMountTools {
    $i = 0
    foreach ($Mount in $MountArray) {
        while ($true) {
            $ValidateTools = (Get-VM -Name $Config.virtualMachines[$i].mountName).ExtensionData.Guest.ToolsRunningStatus
            Write-Verbose -Message "$($Config.virtualMachines[$i].mountName) VMware Tools Status: $ValidateTools" -Verbose
            if ($ValidateTools -ne 'guestToolsRunning') {
                Start-Sleep 5
            } else {
                break
            }
        }
        $i++
    }
}

task ValidateRemoteScriptExecution {
    $i = 0
    foreach ($Mount in $MountArray) {
        $LoopCount = 1
        while ($true) {
            Write-Verbose -Message "Testing script execution on '$($Config.virtualMachines[$i].mountName)', attempt '$LoopCount'..." -Verbose
            $splat = @{
                ScriptText      = 'hostname'
                ScriptType      = 'PowerShell'
                VM              = $Config.virtualMachines[$i].mountName
                GuestCredential = $GuestCredential
            }
            try {
                $VMScript_return = Invoke-VMScript @splat -ErrorAction Stop
                Write-Verbose -Message "ValidateRemoteScriptExecution returned '$VMScript_return'"
                break
            } catch { }
            
            $LoopCount++
            Sleep -Seconds 5
            
            if ($LoopCount -gt 5) {
                throw "Could not execute script on: $($Config.virtualMachines[$i].mountName)..."
            }
        }
        $i++
    }
}

# Synopsis: Move a Live Mount to a test network
task MoveLiveMountNetwork {
    $i = 0
    foreach ($Mount in $MountArray) {
        $SplatNetAdapter = @{
            NetworkName  = $Config.virtualMachines[$i].testNetwork
            Connected    = $true
            Confirm      = $false
        }
        $ValidateNetwork = Get-NetworkAdapter -VM $Config.virtualMachines[$i].mountName |
            Set-NetworkAdapter @SplatNetAdapter
        Write-Verbose -Message "$($Config.virtualMachines[$i].mountName) Network Status: $($ValidateNetwork.NetworkName) is $($ValidateNetwork.ConnectionState)" -Verbose
        $i++
    }
}

# Synopsis: Move a Live Mount to a test address
task MoveLiveMountNetworkAddress {
    $i = 0
    foreach ($Mount in $MountArray) {
        # Keeping the guest credential value local since it may only apply to the individual virtual machine in some cases
        # Try per vm guest credentials first
        if ( Get-Variable -Name "$Config.virtualMachines[$i].guestCred" -ErrorAction SilentlyContinue ) {
            Write-Verbose -Message "Importing Credential file: $($IdentityPath + $($Config.virtualMachines[$i].guestCred))"
            $GuestCredential = Import-Clixml -Path ($IdentityPath + $($Config.virtualMachines[$i].guestCred))
        }
        # Use global guest credentials
        else {
            Write-Verbose -Message "Importing Credential file: $($IdentityPath + "guestCred.XML")"
            $GuestCredential = Import-Clixml -Path ($IdentityPath + "guestCred.XML")
        }
        # Find the first network interface's MAC 
        $TestInterfaceMAC = ((Get-NetworkAdapter -VM $Config.virtualMachines[$i].mountName | Select-Object -first 1).MacAddress).ToLower() -replace ":","-"
        $splat = @{
            ScriptText      = 'Get-NetAdapter | where {($_.MacAddress).ToLower() -eq "' + $TestInterfaceMAC + '"} | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue;`
                               Get-NetAdapter | where {($_.MacAddress).ToLower() -eq "' + $TestInterfaceMAC + '"} | Get-NetIPAddress | Remove-NetIPAddress -confirm:$false;`
                               Get-NetAdapter | where {($_.MacAddress).ToLower() -eq "' + $TestInterfaceMAC + '"} | `
                               New-NetIPAddress -IPAddress ' + $Config.virtualMachines[$i].testIp + ' -PrefixLength ' + $Config.virtualMachines[$i].testSubnet + `
                               ' -DefaultGateway ' + $Config.virtualMachines[$i].testGateway
            ScriptType      = 'PowerShell'
            VM              = $Config.virtualMachines[$i].mountName
            GuestCredential = $GuestCredential
        }
        Write-Verbose "Remote script:`n$($splat['ScriptText'])" -Verbose
        $output = Invoke-VMScript @splat -ErrorAction Stop
        Write-Verbose "Remote script output:`n$($output.ScriptOutput)" -Verbose
        $splat = @{
            ScriptText      = '(Get-NetAdapter| where {($_.MacAddress).ToLower() -eq "' + $TestInterfaceMAC + '"} | Get-NetIPAddress -AddressFamily IPv4).IPAddress'
            ScriptType      = 'PowerShell'
            VM              = $Config.virtualMachines[$i].mountName
            GuestCredential = $GuestCredential
        }
        Write-Verbose "Remote script:`n$($splat['ScriptText'])" -Verbose
        $output = Invoke-VMScript @splat -ErrorAction Stop
        Write-Verbose "Remote script output:`n$($output.ScriptOutput)" -Verbose
        $new_ip = $output.ScriptOutput -replace "`r`n", ""
        if ( $new_ip -eq $Config.virtualMachines[$i].testIp ) {
            Write-Verbose -Message "$($Config.virtualMachines[$i].mountName) Network Address Status: Assigned to $($new_ip)"
        }
        else {
            throw "$($Config.virtualMachines[$i].mountName) changing ip to $($Config.virtualMachines[$i].testIp) failed, exiting Build script.  Previously live mounted VMs will continue running"
        }
        $i++
    }
}

# Synopsis: Validate the Live Mount against one or more tests to verify the backup copy is operational
task LiveMountTest {
    $i = 0
    foreach ($Mount in $MountArray) {
        Write-Verbose -Message "$($Config.virtualMachines[$i].mountName) Test Status: Loading the following tests - $($Config.virtualMachines[$i].tasks)" -Verbose
        # Keeping the guest credential value local since it may only apply to the individual virtual machine in some cases
        # Not all tests will need a guest credential, but it's there in case required
        $GuestCredential = Import-Clixml -Path ($IdentityPath + $($Config.virtualMachines[$i].guestCred))
        Invoke-Build -File .\tests.ps1 -Task $Config.virtualMachines[$i].tasks -Config $Config.virtualMachines[$i] -GuestCredential $GuestCredential
        Write-Verbose -Message "$($Config.virtualMachines[$i].mountName) Test Status: Testing complete" -Verbose
        $i++
    }
}

# Synopsis: Remove any remaining Live Mount artifacts
task Cleanup {
    $i = 0
    foreach ($Mount in $MountArray) {
        # The request may take a few seconds to complete, but it's not worth holding up the build waiting for the task
        $UnmountRequest = Get-RubrikMount -id (Get-RubrikRequest -id $Mount.id -Type vmware/vm).links.href[0].split('/')[-1] | Remove-RubrikMount -Force -Confirm:$false
        Write-Verbose -Message "$($Config.virtualMachines[$i].mountName) Removal Status: $($UnmountRequest.id) is $($UnmountRequest.status)" -Verbose        
        $i++
    }
}

task 1_Init `
GetConfig

task 2_Connect `
ConnectRubrik,
ConnectVMware

task 3_LiveMount `
CreateLiveMount,
ValidateLiveMount,
ValidateLiveMountTools
#ValidateRemoteScriptExecution

task 4_LiveMountNetwork `
MoveLiveMountNetworkAddress,
MoveLiveMountNetwork

task 5_Testing `
LiveMountTest

task . `
1_Init,
2_Connect,
3_LiveMount,
4_LiveMountNetwork,
5_Testing,
Cleanup