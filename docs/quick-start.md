# Backup Validation with PowerShell
This project is used to provide a framework for serial and parallel application testing against workloads that have been protected by Rubrik's Cloud Data Management platform.

## Abstract
As virtual machines running in a VMware environment are backed up and cataloged by Rubrik, each backup or "snapshot" can be Live Mounted for testing and development purposes. This allows for an instant clone to be created that is hosted on the Rubrik filesystem layer and executed on an available ESXi host. A Live Mount takes up minimal space on the Rubrik filesystem because only incoming writes to the guest filesystem need be tracked. Because of this, the Live Mount technology is the perfect solution for quickly bringing up one or more virtual machines for validating the protected applications and services can be restored in the event of a production failure, outage, or disaster.

## Prerequisites

* [PowerShell](https://aka.ms/getps6)
* [Rubrik PowerShell Module](https://www.powershellgallery.com/packages/Rubrik/)
* [Rubrik PowerShell Backup Validation Module](https://github.com/rubrikinc/rubrik-module-for-powershell-backup-validation)
* [VMware PowerCLI](https://www.powershellgallery.com/packages/VMware.PowerCLI/)
* [InvokeBuild](https://www.powershellgallery.com/packages/InvokeBuild/)

## Installation
Once you have PowerShell installed on your system you can install the required modules by executing the following PowerShell commands:

```
Install-Module -Name Rubrik -Scope CurrentUser
Install-Module -Name RubrikBackupValidation -Scope CurrentUser
Install-Module -Name VMware.PowerCLI -Scope CurrentUser
Install-Module -Name InvokeBuild -Scope CurrentUser
```
![alt text](/img/image1.png)
Sample output of Install-Module cmdlet

This will install the modules in the current user scope and will not require local administrative privileges. If you would like to install the modules to be used for all users on a system the following commands can be executed:

```
Install-Module -Name Rubrik -Scope AllUsers
Install-Module -Name RubrikBackupValidation -Scope AllUsers
Install-Module -Name VMware.PowerCLI -Scope AllUsers
Install-Module -Name InvokeBuild -Scope AllUsers
```

## Verify installation
The Rubrik PowerShell Backup Validation module, provides us with a function that can verify if we have all required modules properly installed, the `Test-PowerShellDependency` function:

```
Test-PowerShellDependency
```
![alt text](/img/image10.png)

Alternatively, we can use the `Get-Module` cmdlet to verify if all modules are successfully installed:

```
'Rubrik', 'VMware.PowerCLI', 'InvokeBuild' | ForEach-Object {
    if (Get-Module -ListAvailable -Name $_) {
        '{0} module is successfully installed' -f $_
    } else {
        '{0} module is not installed' -f $_
    }
}
```

![alt text](/img/image2.png)
The output shows that all modules are successfully installed on this system.

## Components
In order to get started with Backup Validation there are several components that you need to understand. The PowerShell Modules that are required to run and connect to both vCenter cluster and Rubrik cluster, and the InvokeBuild module that will execute the build tasks. 

Then we will move on the different configuration and credential files and how these files tie into the backup validation process.

Finally, we will look at the `.build.ps1` file, what it contains and how we can make additions to this.

### PowerShell Modules
This use case leverages several PowerShell modules, outlined in this section. 

#### Rubrik SDK for PowerShell
Rubrik’s API first architecture enables organizations to embrace and integrate Rubrik functionality into their existing automation processes. While Rubrik APIs can be consumed natively, companies are at various stages in their automation journey with different levels of automation knowledge on staff. The Rubrik SDK for PowerShell is a project that provides a Microsoft PowerShell module for managing and monitoring Rubrik's Cloud Data Management fabric by way of published RESTful APIs.

#### Rubrik PowerShell Backup Validation
This module has been created to help validate and verify the different components of a Backup Validation. It provides functions to generate the different Json files, allowing for this to be automated. Furthermore, it comes bundled with the `New-BuildConfiguration` function, that assists with the creation and validation of your backup validation scenario, by providing an interactive experience in which leads the administrator through the process of creating your first backup validation scenario.

#### VMware PowerCLI
VMware PowerCLI is a PowerShell module built by VMware. It provides a command-line and scripting tool with hundreds of cmdlets to manage and automate tasks using PowerShell. It is available in the PowerShell Gallery, which makes it easy to install and update.

#### InvokeBuild
Using the InvokeBuild framework, this project allows for an administrator to declare the topology of an application across one or more virtual machines. The entire collection of virtual machines is Live Mounted as a group and a battery of user-defined tests are applied. Upon the completion of the tests, the Live Mounts are removed, and a summary of results are displayed.

### Configuration
There are three main points of configuration that we will use for Backup Validation which we will go over in details and showcase the example configuration that we have made available.

* Environment JSON files
* Config JSON files
* Identity XML files

### Environment JSON Files
The `Environment` folder contains JSON files that describe the Rubrik Cluster and vCenter Server information. This specifies either the IP address or the FQDN of both the Rubrik cluster and the vCenter cluster. It also specifies the credentials that will be used to connect to either cluster.

A sample configuration looks like:

```
{
    "rubrikServer": "172.17.28.11",
    "rubrikCred": "rubrikCred.xml",
    "vmwareServer": "172.17.48.22",
    "vmwareCred": "vmwareCred.xml"
}
```

### Config JSON Files
The `Config` folder contains JSON files that describe the virtual machines being tested. A sample configuration looks like:

```
{
    "virtualMachines": [
        {
            "name": "SE-CWAHL-WIN",
            "mountName": "MOUNT-2TIER-APP",
            "guestCred": "guestCred.xml",
            "testIp": "172.17.50.121",
            "testNetwork": "VLAN50_Servers_Mount",
            "testGateway": "172.17.50.1",
            "tasks": ["Ping","Netlogon"]
        },
        {
            "name": "SE-CWAHL-WIN",
            "mountName": "MOUNT-2TIER-DB",
            "guestCred": "guestCred.xml",
            "testIp": "172.17.50.122",
            "testNetwork": "VLAN50_Servers_Mount",
            "testGateway": "172.17.50.1",
            "tasks": ["Ping","Netlogon"]
        }
    ]
}
```

#### Credentials
The `Credentials` folder is not included in this repository. It can be placed anywhere in your environment and should host secure XML files created with `Export-Clixml` containing the credentials needed to communicate with the Rubrik cluster, vCenter Server, and any guest operating systems involved in the application testing.

Use the [`generateCreds.ps1`](https://github.com/rubrikinc/PowerShell-Backup-Validation/blob/master/helper/generateCreds.ps1) file to create a starter set of credentials or see how the generation process works. The script takes a single argument for the Path parameter, which will determine where the files are stored for the three types of credentials will be stored.

```
param(
    $Path
)
 
$CredType = @("rubrikCreds.xml","vmwareCreds.xml","guestCreds.xml")
 
foreach ($Type in $CredType) {
    $Credential = Get-Credential -Message $Type
    $Credential | Export-Clixml -Path ($Path + "\" + $Type)
}
```

#### Note
Secure XML files can only be decrypted by the user account that created them, therefore they cannot be used by other users. Anyone that wants to run the build validation will have to generate their own set of credentials. In the following example I attempt to decrypt my credentials with a different user account, which fails as expected:

![alt text](/img/image3.png)

It is also important to note that these files can only be created on Windows systems. Both PowerShell and PowerShell Core support storing credentials on disk. This functionality is not available on other operating systems because `Export-Clixml` cannot be used to encrypt credentials as seen in the following screenshot running PowerShell Core on Ubuntu.

![alt text](/img/image4.png)

### Build Script
The Build script is a script specifically written to be used in combination with the InvokeBuild module. There are a few concepts that are used by this module.

#### Build Tasks
Tasks can be defined in the `.build.ps1` script, this is a specific alias to the `Add-BuildTask` function of the InvokeBuild Module. A task is like a PowerShell function, with some differences. Tasks can refer to multiple other tasks, but each of those tasks will only be invoked once.

An example of a simple task is the following which verifies the OS version by checking whether the OS is 32-bit or 64 bit:

```
task OSVersion {
    if ((wmic os get osarchitecture) -match '64-bit') {
        '64'
    } else {
        '32'
    }
}
```

These tasks can be referenced in either multiple other tasks or can be called at the end of the build script.

##### Task Code Examples
```
task GetConfig {
    $script:Environment = Get-Content -Path $EnvironmentFile | ConvertFrom-Json
    $script:Config = Get-Content -Path $ConfigFile | ConvertFrom-Json
    # If a trailing backslash is omitted, this will make sure it's added to correct for future path + filename activities
    if ($IdentityPath.Substring($IdentityPath.Length - 1) -ne '\') {
        $script:IdentityPath += '\'
    }
}
```

This task is used to load the different configuration files that will be used by the other build tasks that follow this command.

```
task ConnectVMware {
    $Credential = Import-Clixml -Path ($IdentityPath + $Environment.vmwareCred)
    $null = Connect-VIServer -Server $Environment.vmwareServer -Credential $Credential
    Write-Verbose -Message "VMware Status: Connected to $($global:DefaultVIServer.Name)" -Verbose
}
```

The `ConnectVMware` task is used to connect to the VMware cluster and will provide verbose information when successfully connected.

At the end of the script we will logically group together the different build tasks in 5 separate build tasks:

* 1_Init
* 2_Connect
* 3_LiveMount
* 4_LiveMountNetwork
* 5_Testing

```
task 1_Init `
GetConfig
 
task 2_Connect `
ConnectRubrik,
ConnectVMware
 
task 3_LiveMount `
CreateLiveMount,
ValidateLiveMount,
ValidateLiveMountTools
 
task 4_LiveMountNetwork `
MoveLiveMountNetwork,
MoveLiveMountNetworkAddress
 
task 5_Testing `
LiveMountTest
```

The last line of the build script specific the tasks to be executed, the dot indicates the default build task:

```
task . `
1_Init,
2_Connect,
3_LiveMount,
4_LiveMountNetwork,
5_Testing,
Cleanup
```

This will run the tasks in the order they are specific, starting with the initialization of the configuration files and cleaning any remaining live mounts at the end of the validation.

#### Tests
A `tests.ps1` file is also included in the package, this contains the tests that will be available during the build process. Every in the Config JSON files we specify which test will run against which VM.

An example of a test is the following ping test:

```
task Ping {
    assert (Test-Connection -ComputerName $Config.testIp -Quiet) "Unable to ping the server."
}
```

The `tests.ps1` file can be updated with additional tests, and once these tests have been created they can be added to the Config JSON files for the relevant systems.

## Validate Backup
Now that we have all components in place, we will create our own backup validation workflow. 

### Prepare the Environment
To get started we will download the Build Validation package and extract it to a folder named “Backup Validations”. The package is available in the [PowerShell-Backup-Validation](https://github.com/rubrikinc/Use-Case-PowerShell-Backup-Validation) repository. The zipped file is available for download [here](https://github.com/rubrikinc/PowerShell-Backup-Validation/archive/master.zip).

#### Configure Environment Files
In the Environment files make sure that the correct IP addresses or FQDNs are listed for both the Rubrik Cluster as well as the vCenter cluster.

When specify the credentials, just the filename is required as we will specify the specific path when running the `Invoke-Build` function.

#### Configure Config Files
In the Config files a number of configuration options are available:

* `Name` - the name of the VM
* `mountName` - the name of the live mount
* `guestCred` - the credentials file, only the filename is required, no path needs to be specified
* `testIp` - IP Address configured for Live Mounted VM
* `testNetwork` - virtual network used by the adapter of the Live Mount 
* `testGateway` - the gateway address of the network adapter
* `tasks` - which tasks will run against this specific VM

#### Create the Credential files
In order to save the credential files to disk, we will first create a `credentials` folder:

```
mkdir ..\credentials
```

![alt text](/img/image5.png)

After that we will use the `generateCreds.ps1` to generate the credential files required to connect to the different environments.

![alt text](/img/image6.png)

We can now verify that this command successfully created the files containing the encrypted credentials:

```
Get-ChildItem ..\credentials\
```
![alt text](/img/image7.png)

## Validate Backup with RubrikValidateBackup module

This chapter will discuss how the the Rubrik Validate Backup Module can be used to help automate the creation of a new Backup Validation workflow.

### Prepare environment

To get started we will download the Build Validation package and extract it to a folder named "Backup Validations". The package is available in the [Use-Case-PowerShell-Backup-Validation](https://github.com/rubrikinc/Use-Case-PowerShell-Backup-Validation) repository. The zipped file is available for download [here](https://github.com/rubrikinc/Use-Case-PowerShell-Backup-Validation/archive/master.zip).

### Interactive Configuration Generation

Because the sheer amount of options that need to be configured it can be overwhelming to generate the first configuration. To assist with this process the `New-BuildConfiguration` function has been created. This will provide an interactive experience in which the configuration will not only be generated, but also provides the possibility to validate and run the first backup validation job.

```
New-BuildConfiguration
```
![alt text](/img/image11.png)

By typing either yes or no we get the option to view the most recent version of Quick Start guide for Backup Validation.
![alt text](/img/image12.png)

The default browser will be used to open the website.

![alt text](/img/image13.png)

In the following step we are requested to enter in the credentials for the Rubrik cluster, vCenter and the Guest OS. Since we are running this on Windows the credentials will be stored in encrypted xml files. If we run this same command on macOS the credentials will be stored in keychain.

![alt text](/img/image14.png)

In the next step we will generate the `TestEnv.json` file, which contains the environment information, the IP address (or FQDN) of both the Rubrik Cluster and vCenter together with the corresponding credentials for authentication.

Afterwards we get prompted if we want to create an additional environment file, this is an optional step that can be used in case you would like to define multiple different environments to run your backup validation tests against.

![alt text](/img/image15.png)

Now we can define the configuration information for our VM, we are asked for several parameters to fill in. This information will be used to Live Mount the selected VM and configure and check the tasks that we select. Because Tasks is an array, it will continue prompting for more entries, it will take an empty entry as the end of the list.

![alt text](/img/image16.png)

Now that we have created the Environment and Config json files and securely stored our credentials, we are prompted to have our configuration validated.

![alt text](/img/image17.png)

The next prompt is to validate we have the required modules installed and available for backup validation to run. If you already validated this in an earlier step this can be skipped by answering no.

![alt text](/img/image18.png)

In the last step we are asked to specify which files we would like to use to start the backup validation. If everything has correctly been filled in, you will be able to follow the process of the Backup Validation from the console.

### New-ConfigJson

This function can be used to programmatically generate the config json files. The following parameters are used by this function:

![alt text](/img/image19.png)

An example of how this can be used it the following:

```
Get-RubrikVM | Get-Random | ForEach-Object {
    $Splat = [ordered]@{
        ConfigFilePath = "$($_.Name).json"
        Name = $_.Name
        MountName = 'LiveMnt-{0}' -f $_.Name
        GuestCred = 'GuestCred.xml'
        TestIp = '172.24.1.1'
        TestNetwork = 'ISOLATED_VLAN'
        TestGateway = '172.24.1.100'
        Tasks = 'Ping'
    }
    New-ConfigJson @Splat
}
```

This will select a random virtual machine and create a `config.json` which can then be used for backup validation. 

### Run `Invoke-Build`
Once the Environment, Config, and Identity requirements are met, use the `Invoke-Build` function to execute a build. Here is a sample command using a PowerShell technique called splatting to store the parameters and arguments and execute `Invoke-Build`.

```
$Splat = @{
    File            = '.\.build.ps1'
    EnvironmentFile = '.\environment\testhost.json'
    ConfigFile      = '.\config\TestConfiguration.json'
    IdentityPath    = '.\credentials'
    }
 
Invoke-Build @Splat -Result Result
```

![alt text](/img/image8.png)

When the build process is started we can see the Build Tasks are organized in the `1_Init/GetConfig` format, following the structure that was defined in `.build.ps1`.

![alt text](/img/image9.png)

Upon completion of all the build tests we can see that all our build tests have successfully been completed and no further action must be taken. Our backup validation process has been completed.

## Further Reading
This section contains links to sources of documentation and information that provide further information about the individual components.

### Rubrik SDK for PowerShell
[Rubrik SDK for PowerShell Documentation](http://rubrikinc.github.io/rubrik-sdk-for-powershell/)
[VIDEO: Getting Started with the Rubrik SDK for PowerShell](https://www.youtube.com/watch?v=tY6nQLNYRSE)
[Rubrik SDK for PowerShell](https://github.com/rubrikinc/rubrik-sdk-for-powershell)

### VMware PowerCLI
[VMware PowerCLI User Guide](https://vdc-download.vmware.com/vmwb-repository/dcr-public/2156d7ad-8f0f-4001-9de5-0cb95340873b/84fc3e8c-4755-4376-9917-18eb49a6bcdf/vmware-powercli-111-user-guide.pdf)

### `InvokeBuild`
[`Invoke-Build` Project Wiki](https://github.com/nightroman/Invoke-Build/wiki)
