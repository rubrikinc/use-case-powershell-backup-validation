param(
    $Path
)

$CredType = @("rubrikCreds.xml","vmwareCreds.xml","guestCreds.xml")

foreach ($Type in $CredType) {
    $Credential = Get-Credential -Message $Type
    $Credential | Export-Clixml -Path ($Path + "\" + $Type)
}