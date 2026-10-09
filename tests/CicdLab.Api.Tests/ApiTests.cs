using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;

namespace CicdLab.Api.Tests;

public class ApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Health_ReturnsOk()
    {
        var response = await _client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Sum_ReturnsCorrectResult()
    {
        var response = await _client.GetAsync("/api/sum/10/20");

        response.EnsureSuccessStatusCode();

        var content = await response.Content.ReadAsStringAsync();

        Assert.Contains("\"result\":30", content);
    }
}