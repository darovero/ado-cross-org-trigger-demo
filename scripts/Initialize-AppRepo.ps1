[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://[^\s]+$')]
    [string]$RemoteUrl,

    [string]$WorkingDirectory = (Join-Path $PWD 'demo-app-trigger-work'),

    [SecureString]$Pat,

    [switch]$SkipPush
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments)][string[]]$GitArguments)

    & git @GitArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git falló con código $($LASTEXITCODE): git $($GitArguments -join ' ')"
    }
}

function Enable-TemporaryGitAuthentication {
    param([SecureString]$SecurePat)

    if (-not $SecurePat) { return }

    $plainPat = $null
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePat)
    try {
        $plainPat = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        $token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$plainPat"))
        $env:GIT_CONFIG_COUNT = '1'
        $env:GIT_CONFIG_KEY_0 = 'http.extraHeader'
        $env:GIT_CONFIG_VALUE_0 = "AUTHORIZATION: Basic $token"
    }
    finally {
        if ($plainPat) { $plainPat = $null }
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function Disable-TemporaryGitAuthentication {
    Remove-Item Env:GIT_CONFIG_COUNT -ErrorAction SilentlyContinue
    Remove-Item Env:GIT_CONFIG_KEY_0 -ErrorAction SilentlyContinue
    Remove-Item Env:GIT_CONFIG_VALUE_0 -ErrorAction SilentlyContinue
}

$templatePath = Join-Path $PSScriptRoot '..\source-repo-template'
if (-not (Test-Path $templatePath -PathType Container)) {
    throw "No se encontró la plantilla de la aplicación: $templatePath"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git no está instalado o no está disponible en PATH.'
}

if (Test-Path $WorkingDirectory) {
    $existing = Get-ChildItem -LiteralPath $WorkingDirectory -Force -ErrorAction SilentlyContinue
    if ($existing) {
        throw "El directorio de trabajo no está vacío: $WorkingDirectory"
    }
}
else {
    New-Item -ItemType Directory -Path $WorkingDirectory | Out-Null
}

Copy-Item -Path (Join-Path $templatePath '*') -Destination $WorkingDirectory -Recurse -Force
Copy-Item -Path (Join-Path $templatePath '.gitignore') -Destination $WorkingDirectory -Force

Push-Location $WorkingDirectory
try {
    Invoke-Git init
    Invoke-Git checkout -b main
    Invoke-Git config user.name 'Azure DevOps Demo'
    Invoke-Git config user.email 'demo@example.invalid'
    Invoke-Git add --all
    Invoke-Git commit -m 'feat: create .NET 10 demo API'
    Invoke-Git remote add origin $RemoteUrl

    Invoke-Git checkout -b develop
    $settingsPath = Join-Path $WorkingDirectory 'src\DemoApi\appsettings.json'
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $settings.Application.EnvironmentLabel = 'develop'
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8
    Invoke-Git add $settingsPath
    Invoke-Git commit -m 'chore: configure develop environment label'

    Invoke-Git checkout -b feature/demo-branch
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $settings.Application.EnvironmentLabel = 'feature/demo-branch'
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8
    $programPath = Join-Path $WorkingDirectory 'src\DemoApi\Program.cs'
    Add-Content -Path $programPath -Value "`n// Feature branch used by the dynamic branch-selection demo."
    Invoke-Git add $settingsPath $programPath
    Invoke-Git commit -m 'chore: add feature branch marker'
    Invoke-Git checkout main

    if (-not $SkipPush) {
        if ($PSCmdlet.ShouldProcess($RemoteUrl, 'Publicar main, develop y feature/demo-branch')) {
            Enable-TemporaryGitAuthentication -SecurePat $Pat
            try {
                Invoke-Git push --set-upstream origin main
                Invoke-Git push --set-upstream origin develop
                Invoke-Git push --set-upstream origin feature/demo-branch
            }
            finally {
                Disable-TemporaryGitAuthentication
            }
        }
    }

    Write-Host "Repositorio preparado en: $WorkingDirectory"
    Write-Host 'Ramas creadas: main, develop y feature/demo-branch'
}
finally {
    Disable-TemporaryGitAuthentication
    Pop-Location
}
