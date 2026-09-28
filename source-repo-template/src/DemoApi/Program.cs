var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();
var environmentLabel = builder.Configuration["Application:EnvironmentLabel"] ?? "unknown";

app.MapGet("/", () => Results.Ok(new
{
    application = "Demo API .NET 10",
    message = "Aplicación de prueba para Azure Pipelines cross-organization",
    sourceBranchLabel = environmentLabel
}));

app.MapGet("/api/status", () => Results.Ok(new
{
    status = "Healthy",
    framework = ".NET 10",
    sourceBranchLabel = environmentLabel,
    utcTimestamp = DateTimeOffset.UtcNow
}));

app.MapGet("/api/greeting/{name}", (string name) =>
    Results.Ok(new { message = $"Hola, {name}. La API funciona correctamente." }));

app.Run();

public partial class Program;
