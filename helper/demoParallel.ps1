param (
    [ValidateSet('Home', 'Laptop')]    
    $Demo
)

switch ($Demo) {
    # Demo on home workstation
    'Home' {
        Invoke-Builds -Result Result @(
            @{
                File            = '..\.build.ps1';
                EnvironmentFile = '.\environment\se-2.json';
                ConfigFile      = '.\config\2-tier-app.json';
                IdentityPath    = '.\credential\home'
            }
            @{
                File            = '..\.build.ps1';
                EnvironmentFile = '.\environment\se-2.json';
                ConfigFile      = '.\config\3-tier-app.json';
                IdentityPath    = '.\credential\home'
            }
        )
    }
    # Demo on laptop
    'Laptop' {
        Invoke-Builds -Result Result @(
            @{
                File            = '..\.build.ps1';
                EnvironmentFile = '.\environment\se-2.json';
                ConfigFile      = '.\config\1-tier-app.json';
                IdentityPath    = '.\credential\laptop'
            }
            @{
                File            = '..\.build.ps1';
                EnvironmentFile = '.\environment\se-2.json';
                ConfigFile      = '.\config\2-tier-app.json';
                IdentityPath    = '.\credential\laptop'
            }
        )
    }
}

return $Result.Tasks | Format-Table Elapsed, Name, Error -AutoSize