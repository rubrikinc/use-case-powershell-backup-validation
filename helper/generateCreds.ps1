param(
    $Path
)

$CredType = @("rubrikCred.xml","vmwareCred.xml","guestCred.xml")

foreach ($Type in $CredType) {
    $Credential = Get-Credential -Message $Type
    $Credential | Export-Clixml -Path ($Path + "\" + $Type)
}