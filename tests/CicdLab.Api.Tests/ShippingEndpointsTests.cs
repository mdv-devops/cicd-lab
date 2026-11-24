using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace CicdLab.Api.Tests;

public class ShippingEndpointsTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ShippingEndpointsTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Theory]
    [InlineData(-10)]
    [InlineData(0)]
    public async Task Shipping_InvalidOrderAmount_ReturnsBadRequest(int orderAmount)
    {
        var response = await _client.GetAsync(
            $"/api/shipping?orderAmount={orderAmount}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData(30, 10)]
    [InlineData(49, 10)]
    [InlineData(50, 5)]
    [InlineData(75, 5)]
    [InlineData(99, 5)]
    [InlineData(100, 0)]
    [InlineData(150, 0)]
    public async Task Shipping_ValidOrderAmount_ReturnsCorrectCost(
        int orderAmount, int expectedShippingCost)
    {
        var response = await _client.GetAsync(
            $"/api/shipping?orderAmount={orderAmount}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadAsStringAsync();

        using var json = JsonDocument.Parse(content);

        var root = json.RootElement;

        Assert.Equal((decimal)orderAmount,
            root.GetProperty("orderAmount").GetDecimal());

        Assert.Equal((decimal)expectedShippingCost,
            root.GetProperty("shippingCost").GetDecimal());

        Assert.Equal((decimal)(orderAmount + expectedShippingCost),
            root.GetProperty("totalAmount").GetDecimal());
    }
}