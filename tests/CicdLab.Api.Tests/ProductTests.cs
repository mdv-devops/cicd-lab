using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;
namespace CicdLab.Api;

public class ProductTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ProductTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    private async Task<int> CreateProduct(
        string name = "Laptop",
        decimal price = 1200)
    {
        var response = await _client.PostAsJsonAsync(
            "/api/products",
            new { Name = name, Price = price });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        using var json = JsonDocument.Parse(
            await response.Content.ReadAsStringAsync());

        return json.RootElement.GetProperty("id").GetInt32();
    }

    [Fact]
    public async Task GetAllProducts_ReturnsOk()
    {
        await CreateProduct();

        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task GetProduct_ReturnsProduct()
    {
        var id = await CreateProduct();

        var response = await _client.GetAsync($"/api/products/{id}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using var json = JsonDocument.Parse(
            await response.Content.ReadAsStringAsync());

        Assert.Equal(
            "Laptop",
            json.RootElement.GetProperty("name").GetString());
    }

    [Fact]
    public async Task GetProduct_NotFound()
    {
        var response = await _client.GetAsync(
            "/api/products/2147483647");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task PostProduct_ReturnsCreated()
    {
        var id = await CreateProduct("Monitor", 500);

        var response = await _client.GetAsync($"/api/products/{id}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [InlineData("", 100)]
    [InlineData("Laptop", -100)]
    public async Task PostProduct_InvalidData_ReturnsBadRequest(
        string name, decimal price)
    {
        var response = await _client.PostAsJsonAsync(
            "/api/products",
            new { Name = name, Price = price });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PutProduct_UpdatesProduct()
    {
        var id = await CreateProduct();

        var response = await _client.PutAsJsonAsync(
            $"/api/products/{id}",
            new { Name = "Gaming Laptop", Price = 1500 });

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        var product = await _client.GetFromJsonAsync<Product>(
            $"/api/products/{id}");

        Assert.NotNull(product);
        Assert.Equal("Gaming Laptop", product.Name);
        Assert.Equal(1500, product.Price);
    }

    [Fact]
    public async Task PutProduct_NotFound()
    {
        var response = await _client.PutAsJsonAsync(
            "/api/products/2147483647",
            new { Name = "Laptop", Price = 100 });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Theory]
    [InlineData("", 100)]
    [InlineData("Laptop", -100)]
    public async Task PutProduct_InvalidData_ReturnsBadRequest(
        string name, decimal price)
    {
        var id = await CreateProduct();

        var response = await _client.PutAsJsonAsync(
            $"/api/products/{id}",
            new { Name = name, Price = price });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PatchProduct_UpdatesPrice()
    {
        var id = await CreateProduct();

        var request = new HttpRequestMessage(
            HttpMethod.Patch,
            $"/api/products/{id}")
        {
            Content = JsonContent.Create(new { Price = 1350 })
        };

        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        var product = await _client.GetFromJsonAsync<Product>(
            $"/api/products/{id}");

        Assert.NotNull(product);
        Assert.Equal("Laptop", product.Name);
        Assert.Equal(1350, product.Price);
    }

    [Fact]
    public async Task PatchProduct_NotFound()
    {
        var request = new HttpRequestMessage(
            HttpMethod.Patch,
            "/api/products/2147483647")
        {
            Content = JsonContent.Create(new { Price = 100 })
        };

        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task PatchProduct_InvalidPrice_ReturnsBadRequest()
    {
        var id = await CreateProduct();

        var request = new HttpRequestMessage(
            HttpMethod.Patch,
            $"/api/products/{id}")
        {
            Content = JsonContent.Create(new { Price = -100 })
        };

        var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteProduct_RemovesProduct()
    {
        var id = await CreateProduct();

        var response = await _client.DeleteAsync(
            $"/api/products/{id}");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        var getResponse = await _client.GetAsync(
            $"/api/products/{id}");

        Assert.Equal(HttpStatusCode.NotFound, getResponse.StatusCode);
    }

    [Fact]
    public async Task DeleteProduct_NotFound()
    {
        var response = await _client.DeleteAsync(
            "/api/products/2147483647");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}