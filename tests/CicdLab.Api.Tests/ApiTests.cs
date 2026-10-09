using System.Net;
using System.Net.Http.Json;
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

        var result = await response.Content.ReadFromJsonAsync<SumResponse>();

        Assert.NotNull(result);
        Assert.Equal(3, result.Result);
    }

    private record SumResponse(int A, int B, int Result);
}