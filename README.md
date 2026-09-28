# Demo cross-organization con .NET 10 LTS y windows-latest

Este laboratorio valida dos escenarios:

1. Seleccionar dinámicamente una rama de `daroverodck/agony/demo-app-trigger` al ejecutar manualmente un pipeline cuyo YAML está en GitHub.
2. Ejecutar automáticamente el pipeline cuando Azure Repos notifica un `push` en `develop` mediante un Service Hook y una conexión `Incoming Webhook`.

Todos los jobs usan agentes Microsoft-hosted:

```yaml
pool:
  vmImage: windows-latest
```

## Estructura

```text
source-repo-template/             Aplicación ASP.NET Core .NET 10 y pruebas xUnit
pipelines/manual-branch.yml       Selección manual de main, develop o feature/demo-branch
pipelines/automatic-develop.yml   Ejecución por webhook para push en develop
scripts/Initialize-AppRepo.ps1    Inicializa y publica el Azure Repo origen
scripts/Test-WebHookPayload.ps1   Prueba aislada del Incoming Webhook
```

## 1. Preparar el Azure Repo origen

El repositorio vacío debe existir en:

```text
https://dev.azure.com/daroverodck/agony/_git/demo-app-trigger
```

Abra PowerShell 7 desde la carpeta `scripts`.

### Autenticación recomendada con Git Credential Manager

```powershell
.\Initialize-AppRepo.ps1 `
  -RemoteUrl 'https://dev.azure.com/daroverodck/agony/_git/demo-app-trigger'
```

Git solicitará autenticación si todavía no existe una sesión válida.

### Alternativa con PAT solicitado de forma segura

El PAT se crea en la organización `daroverodck` y requiere `Code: Read & Write` solo para inicializar el repositorio.

```powershell
$pat = Read-Host 'PAT de Azure DevOps' -AsSecureString
.\Initialize-AppRepo.ps1 `
  -RemoteUrl 'https://dev.azure.com/daroverodck/agony/_git/demo-app-trigger' `
  -Pat $pat
```

El PAT no se escribe en archivos, URLs ni historial de Git. Después de publicar las ramas puede revocarse.

## 2. Configurar el acceso cross-organization

En la organización destino cree una Service Connection de tipo `Azure Repos/Team Foundation Server` o `Azure DevOps` hacia `daroverodck`.

- Nombre usado por el YAML: `ado-source-daroverodck`
- Proyecto remoto: `agony`
- Repositorio remoto: `demo-app-trigger`
- Permiso requerido para ejecución: `Code: Read`

Si la conexión tiene otro nombre, actualice `endpoint` en ambos YAML.

## 3. Crear el pipeline manual

1. Publique este paquete en `darovero/ado-cross-org-trigger-demo` de GitHub.
2. Cree un pipeline en la organización destino apuntando a `pipelines/manual-branch.yml`.
3. Autorice ambas Service Connections cuando Azure DevOps lo solicite.
4. Use **Run pipeline** y seleccione `azureRepoRef`.

El pipeline restaura, compila, prueba y publica la aplicación .NET 10 desde la rama elegida.
El parámetro es de texto libre, por lo que también permite indicar ramas nuevas
sin actualizar el YAML, usando el formato `refs/heads/<nombre-rama>`.

## 4. Crear el pipeline automático para develop

1. En la organización destino cree una Service Connection **Incoming Webhook** con el nombre `ado-source-push-webhook`.
2. Cree otro pipeline apuntando a `pipelines/automatic-develop.yml`.
3. Ejecute el pipeline una vez manualmente para registrar la suscripción al webhook.
4. Copie la URL pública generada para el webhook.
5. En `daroverodck/agony`, cree un Service Hook de tipo **Web Hooks** para el evento **Code pushed**.
6. Limite el evento al repositorio `demo-app-trigger` y a la rama `develop`.
7. Configure la URL del webhook de la organización destino como destino del Service Hook.

El YAML también valida `eventType`, repositorio y rama dentro del payload.

> Para una PoC puede usarse una conexión Incoming Webhook sin secreto. En un entorno productivo se recomienda un intermediario controlado que valide el origen y firme la solicitud antes de invocar Azure Pipelines.

## 5. Pruebas

### Prueba A: rama manual

Ejecute el pipeline tres veces seleccionando:

- `refs/heads/main`
- `refs/heads/develop`
- `refs/heads/feature/demo-branch`

Confirme en el log de checkout la referencia usada y valide el artefacto `DemoApi-*`.

### Prueba B: trigger automático

Realice un commit en `develop` y publique el cambio:

```powershell
git checkout develop
Add-Content .\src\DemoApi\Program.cs '// Trigger validation'
git add .
git commit -m 'test: validate automatic pipeline trigger'
git push origin develop
```

El pipeline automático debe iniciar y generar el artefacto `DemoApi-develop`.

### Prueba aislada del webhook

```powershell
.\Test-WebHookPayload.ps1 -IncomingWebhookUrl '<URL-del-incoming-webhook>'
```

## Observaciones

- `ref` del repository resource se resuelve en tiempo de compilación; por eso el pipeline manual usa `${{ parameters.azureRepoRef }}` y no `$(azureRepoRef)`.
- El pipeline automático fija `refs/heads/develop`, porque ese es el evento que se desea validar.
- `windows-latest` es una imagen administrada por Microsoft y cambia con el tiempo. `UseDotNet@2` instala explícitamente .NET 10 para evitar depender del SDK preinstalado.
- La Service Connection de lectura no sirve para publicar el contenido inicial; la carga inicial requiere `Code: Read & Write` o una identidad con permisos equivalentes.
