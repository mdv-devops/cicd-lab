// using System.Net;
// using System.Net.Http.Json;
// using Microsoft.AspNetCore.Mvc.Testing;
// using Xunit;

// namespace CicdLab.Api.Tests;

// public class OrderEndpointsTests : IClassFixture<WebApplicationFactory<Program>>
// {
//     private readonly HttpClient _client;

//     public OrderEndpointsTests(WebApplicationFactory<Program> factory)
//     {
//         _client = factory.CreateClient();
//     }

//     [Fact]
//     public async Task GetOrders_ReturnsOk()
//     {
//         var response = await _client.GetAsync("/api/orders/");

//         Assert.Equal(HttpStatusCode.OK, response.StatusCode);
//     }

//     [Fact]
//     public async Task GetOrder_WhenNotExists_ReturnsNotFound()
//     {
//         var response = await _client.GetAsync("/api/orders/999999");

//         Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
//     }

//     [Fact]
//     public async Task CreateOrder_WithInvalidProductId_ReturnsBadRequest()
//     {
//         var response = await _client.PostAsJsonAsync(
//             "/api/orders/",
//             new { ProductId = 0, Quantity = 2 });

//         Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
//     }

//     [Fact]
//     public async Task CreateOrder_WithInvalidQuantity_ReturnsBadRequest()
//     {
//         var response = await _client.PostAsJsonAsync(
//             "/api/orders/",
//             new { ProductId = 1, Quantity = 0 });

//         Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
//     }

//     [Fact]
//     public async Task CreateOrder_WhenProductNotExists_ReturnsNotFound()
//     {
//         var response = await _client.PostAsJsonAsync(
//             "/api/orders/",
//             new { ProductId = 999999, Quantity = 2 });

//         Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
//     }

//     [Fact]
//     public async Task CreateOrder_WithValidData_ReturnsCreated()
//     {
//         var productResponse = await _client.PostAsJsonAsync(
//             "/api/products/",
//             new { Name = "Order Test Product", Price = 100 });

//         Assert.Equal(HttpStatusCode.Created, productResponse.StatusCode);

//         var product = await productResponse.Content
//             .ReadFromJsonAsync<Product>();

//         Assert.NotNull(product);

//         var response = await _client.PostAsJsonAsync(
//             "/api/orders/",
//             new { ProductId = product.Id, Quantity = 3 });

//         Assert.Equal(HttpStatusCode.Created, response.StatusCode);

//         var order = await response.Content.ReadFromJsonAsync<Order>();

//         Assert.NotNull(order);
//         Assert.True(order.Id > 0);
//         Assert.Equal(product.Id, order.ProductId);
//         Assert.Equal(3, order.Quantity);
//         Assert.True(order.CreatedAt <= DateTime.UtcNow);
//         Assert.Equal($"/api/orders/{order.Id}", response.Headers.Location?.ToString());
//     }

//     [Fact]
//     public async Task GetOrder_WhenExists_ReturnsOrder()
//     {
//         var productResponse = await _client.PostAsJsonAsync(
//             "/api/products/",
//             new { Name = "Get Order Test Product", Price = 50 });

//         Assert.Equal(HttpStatusCode.Created, productResponse.StatusCode);

//         var product = await productResponse.Content
//             .ReadFromJsonAsync<Product>();

//         Assert.NotNull(product);

//         var createResponse = await _client.PostAsJsonAsync(
//             "/api/orders/",
//             new { ProductId = product.Id, Quantity = 5 });

//         Assert.Equal(HttpStatusCode.Created, createResponse.StatusCode);

//         var createdOrder = await createResponse.Content
//             .ReadFromJsonAsync<Order>();

//         Assert.NotNull(createdOrder);

//         var response = await _client.GetAsync(
//             $"/api/orders/{createdOrder.Id}");

//         Assert.Equal(HttpStatusCode.OK, response.StatusCode);

//         var order = await response.Content.ReadFromJsonAsync<Order>();

//         Assert.NotNull(order);
//         Assert.Equal(createdOrder.Id, order.Id);
//         Assert.Equal(product.Id, order.ProductId);
//         Assert.Equal(5, order.Quantity);
//     }
// }