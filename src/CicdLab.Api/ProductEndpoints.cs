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

        group.MapGet("/", () =>
            Results.Ok(Products.Values.OrderBy(p => p.Id)));

        group.MapGet(ProductByIdRoute, (int id) =>
            Products.TryGetValue(id, out var product)
                ? Results.Ok(product)
                : Results.NotFound());

        group.MapPost("/", (ProductRequest request) =>
        {
            if (string.IsNullOrWhiteSpace(request.Name) ||
                request.Price < 0)
                return Results.BadRequest();

            var id = Interlocked.Increment(ref _nextId);

            var product = new Product(id, request.Name, request.Price);

            Products[id] = product;

            return Results.Created($"/api/products/{id}", product);
        });

        group.MapPut(ProductByIdRoute, (int id, ProductRequest request) =>
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
        });

        group.MapPatch(ProductByIdRoute, (int id, ProductPriceRequest request) =>
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
        });

        group.MapDelete(ProductByIdRoute, (int id) =>
            Products.TryRemove(id, out _)
                ? Results.NoContent()
                : Results.NotFound());
    }
}