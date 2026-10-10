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
        Assert.Equal(30, result.Result);
    }

    private record SumResponse(int A, int B, int Result);

    [Fact]
    public async Task Multiply_ReturnsCorrectResult()
    {
        var response = await _client.GetAsync("/api/multiply?a=6&b=7");

        response.EnsureSuccessStatusCode();

        var result = await response.Content.ReadFromJsonAsync<MultiplyResponse>();

        Assert.NotNull(result);
        Assert.Equal(42, result.Result);
    }

    [Fact]
    public async Task Divide_ReturnsCorrectResult()
    {
        var response = await _client.GetAsync("/api/divide/7/2");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var result = await response.Content
            .ReadFromJsonAsync<DivideResponse>();

        Assert.NotNull(result);
        Assert.Equal(3.5, result.Result);
    }

    [Fact]
    public async Task Divide_ByZero_ReturnsBadRequest()
    {
        var response = await _client.GetAsync("/api/divide/10/0");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var result = await response.Content
            .ReadFromJsonAsync<ErrorResponse>();

        Assert.NotNull(result);
        Assert.Equal(
            "Division by zero is not allowed",
            result.Error
        );
    }

    private record DivideResponse(double Result);
    private record ErrorResponse(string Error);
    private record MultiplyResponse(int Result);
}