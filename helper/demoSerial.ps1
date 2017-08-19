param (
    [ValidateSet('Home1','Home2','Laptop')]    
    $Demo
)

switch ($Demo) {
    # Demo on home workstation
    'Home1' {
        $Splat = @{
            File            = '..\.build.ps1'
            EnvironmentFile = '.\environment\se-2.json'
            ConfigFile      = '.\config\1-tier-app.json'
            IdentityPath    = '.\credential\home'
        }
    }
    'Home2' {
        $Splat = @{
            File            = '..\.build.ps1'
            EnvironmentFile = '.\environment\se-2.json'
            ConfigFile      = '.\config\3-tier-app.json'
            IdentityPath    = '.\credential\home'
        }
    }    
    # Demo on laptop
    'Laptop' {
        $Splat = @{
            File            = '..\.build.ps1'
            EnvironmentFile = '.\environment\se-2.json'
            ConfigFile      = '.\config\1-tier-app.json'
            IdentityPath    = '.\credential\laptop'
        }
    }
}

Invoke-Build @Splat -Result Result

return $Result.Tasks | Format-Table Elapsed, Name, Error -AutoSize