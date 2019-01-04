# PowerShell Backup Validation

This project is used to provide a framework for serial and parallel application testing against workloads that have been protected by Rubrik's Cloud Data Management platform.

## Abstract

As virtual machines running in a VMware environment are backed up and cataloged by Rubrik, each backup or "snapshot" can be Live Mounted for testing and development purposes. This allows for an instant clone to be created that is hosted on the Rubrik filesystem layer and executed on an available ESXi host. A Live Mount takes up minimal space on the Rubrik filesystem because only incoming writes to the guest filesystem need be tracked. Because of this, the Live Mount technology is the perfect solution for quickly bringing up one or more virtual machines for validating the protected applications and services can be restored in the event of a production failure, outage, or disaster.

Using the `Invoke-Build framework`, this project allows for an administrator to declare the topology of an application across one or more virtual machines. The entire collection of virtual machines are Live Mounted as a group and a battery of user-defined tests are applied. Upon the completion of the tests, the Live Mounts are removed and a summary of results are displayed.

## Prerequisites

* [Rubrik PowerShell Module](https://www.powershellgallery.com/packages/Rubrik/)
* [VMware PowerCLI](https://www.powershellgallery.com/packages/VMware.PowerCLI/)
* [InvokeBuild](https://www.powershellgallery.com/packages/InvokeBuild/)

## Installation

This folder can be dropped anywhere on your workstation that has network connectivity to a Rubrik cluster and related vCenter Server.

## Configuration

There are three main points of configuration: Environment JSON files, Config JSON files, and Identity XML files.

### Environment JSON Files

The `Environment` folder contains JSON files that describe the Rubrik Cluster and vCenter Server information. A sample configuration looks like:

```PowerShell
{
    "rubrikServer": "172.17.28.11",
    "rubrikCred": "rubrikCred.xml",
    "vmwareServer": "172.17.48.22",
    "vmwareCred": "vmwareCred.xml"
}
```

### Config JSON Files

The `Config` folder contains JSON files that describe the virtual machines being tested. A sample configuration looks like:

```PowerShell
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

### Identity

The `Identity` folder is not included in this repository. It can be placed anywhere in your environment and should host secure XML files created with `Export-Clixml` containing the credentials needed to communicate with the Rubrik cluster, vCenter Server, and any guest operating systems involved in the application testing.

Use the [generateCreds.ps1](https://github.com/rubrikinc/PowerShell-Backup-Validation/blob/master/helper/generateCreds.ps1) file to create a starter set of credentials or see how the generation process works.

_Note: Secure XML files can only be decrypted by the user account that created them._

## Usage

Once the Environment, Config, and Identity requirements are met, use the `Invoke-Build` function to execute a build. Here is a sample command using a splat.

```PowerShell
$Splat = @{
    File            = '..\.build.ps1'
    EnvironmentFile = '.\environment\se-2.json'
    ConfigFile      = '.\config\1-tier-app.json'
    IdentityPath    = '.\credential\laptop'
    }

Invoke-Build @Splat -Result Result
```
