using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using System.Text.Json;

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

    [Theory]
    [InlineData(10, 5, 15, 5, 50, 10, 5, 7.5)]
    [InlineData(3, 8, 11, -5, 24, 8, 3, 5.5)]
    [InlineData(-4, -2, -6, -2, 8, -2, -4, -3.0)]
    public async Task Statistics_ReturnsCorrectResults(
        int a,
        int b,
        int sum,
        int difference,
        int product,
        int maximum,
        int minimum,
        double average)
    {
        var response = await _client.GetAsync($"/api/statistics/{a}/{b}");

        response.EnsureSuccessStatusCode();

        var result = await response.Content
            .ReadFromJsonAsync<StatisticsResponse>();

        Assert.NotNull(result);
        Assert.Equal(sum, result.Sum);
        Assert.Equal(difference, result.Difference);
        Assert.Equal(product, result.Product);
        Assert.Equal(maximum, result.Maximum);
        Assert.Equal(minimum, result.Minimum);
        Assert.Equal(average, result.Average);
    }

    private record StatisticsResponse(
        int Sum,
        int Difference,
        int Product,
        int Maximum,
        int Minimum,
        double Average);

    [Theory]
    [InlineData(150, "High value")]
    [InlineData(50, "Low value")]
    public async Task Check_ReturnsCorrectMessage(int value, string expected)
    {
        var response = await _client.GetAsync($"/api/check/{value}");

        response.EnsureSuccessStatusCode();

        using var json = JsonDocument.Parse(
            await response.Content.ReadAsStringAsync()
        );

        Assert.Equal(
            expected,
            json.RootElement.GetProperty("message").GetString()
        );
    }

    [Fact]
    public async Task Subtract_ReturnsCorrectResult()
    {
        var response = await _client.GetAsync("/api/subtract/10/3");

        response.EnsureSuccessStatusCode();

        using var json = JsonDocument.Parse(
            await response.Content.ReadAsStringAsync()
        );

        Assert.Equal(
            7,
            json.RootElement.GetProperty("result").GetInt32()
        );
    }

    private record DivideResponse(double Result);
    private record ErrorResponse(string Error);
    private record MultiplyResponse(int Result);
}