
using System.Collections.Concurrent;

namespace CicdLab.Api;

public record Product(int Id, string Name, decimal Price);

public record ProductRequest(string Name, decimal Price);

public record ProductPriceRequest(decimal Price);

public static class ProductEndpoints
{
    private const string ProductByIdRoute = "/{id:int}";

    private static readonly ConcurrentDictionary<int, Product> Products = new();
    private static int _nextId;

    public static void MapProductEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/products");

        group.MapGet("/", GetAllProducts);
        group.MapGet(ProductByIdRoute, GetProduct);
        group.MapPost("/", CreateProduct);
        group.MapPut(ProductByIdRoute, UpdateProduct);
        group.MapPatch(ProductByIdRoute, UpdateProductPrice);
        group.MapDelete(ProductByIdRoute, DeleteProduct);
    }

    private static IResult GetAllProducts()
    {
        return Results.Ok(Products.Values.OrderBy(p => p.Id));
    }

    private static IResult GetProduct(int id)
    {
        return Products.TryGetValue(id, out var product)
            ? Results.Ok(product)
            : Results.NotFound();
    }

    private static IResult CreateProduct(ProductRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name) ||
            request.Price < 0)
            return Results.BadRequest();

        var id = Interlocked.Increment(ref _nextId);

        var product = new Product(id, request.Name, request.Price);

        Products[id] = product;

        return Results.Created($"/api/products/{id}", product);
    }

    private static IResult UpdateProduct(int id, ProductRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name) ||
            request.Price < 0)
            return Results.BadRequest();

        while (Products.TryGetValue(id, out var existing))
        {
            var updated = new Product(id, request.Name, request.Price);

            if (Products.TryUpdate(id, updated, existing))
                return Results.NoContent();
        }

        return Results.NotFound();
    }

    private static IResult UpdateProductPrice(
        int id,
        ProductPriceRequest request)
    {
        if (request.Price < 0)
            return Results.BadRequest();

        while (Products.TryGetValue(id, out var existing))
        {
            var updated = existing with { Price = request.Price };

            if (Products.TryUpdate(id, updated, existing))
                return Results.NoContent();
        }

        return Results.NotFound();
    }

    private static IResult DeleteProduct(int id)
    {
        return Products.TryRemove(id, out _)
            ? Results.NoContent()
            : Results.NotFound();
    }
}
