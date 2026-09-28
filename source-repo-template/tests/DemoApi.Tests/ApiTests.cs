using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace DemoApi.Tests;

public sealed class ApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Root_ReturnsSuccess()
    {
        var response = await _client.GetAsync("/");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Status_ReturnsHealthy()
    {
        var payload = await _client.GetFromJsonAsync<StatusResponse>("/api/status");
        Assert.NotNull(payload);
        Assert.Equal("Healthy", payload.Status);
        Assert.Equal(".NET 10", payload.Framework);
    }

    private sealed record StatusResponse(string Status, string Framework, DateTimeOffset UtcTimestamp);
}
