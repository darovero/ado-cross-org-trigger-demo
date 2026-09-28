[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://dev\.azure\.com/')]
    [string]$IncomingWebhookUrl
)

$ErrorActionPreference = 'Stop'

$payload = @{
    eventType = 'git.push'
    resource = @{
        repository = @{ name = 'demo-app-trigger' }
        refUpdates = @(@{ name = 'refs/heads/develop' })
    }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Method Post -Uri $IncomingWebhookUrl -ContentType 'application/json' -Body $payload
Write-Host 'Payload enviado. Valide que se haya iniciado el pipeline automático.'
