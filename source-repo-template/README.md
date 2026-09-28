# Demo API .NET 10

Aplicación mínima ASP.NET Core usada para validar un pipeline alojado en GitHub que consume código desde Azure Repos en otra organización.

## Ejecución local

```powershell
dotnet restore .\DemoApp.sln
dotnet build .\DemoApp.sln --configuration Release
dotnet test .\DemoApp.sln --configuration Release --no-build
dotnet run --project .\src\DemoApi\DemoApi.csproj
```

Endpoints:

- `GET /`
- `GET /api/status`
- `GET /api/greeting/{name}`
