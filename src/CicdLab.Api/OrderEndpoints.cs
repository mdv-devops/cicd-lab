using System.Collections.Concurrent;

namespace CicdLab.Api;

public record Order(
    int Id,
    int ProductId,
    int Quantity,
    DateTime CreatedAt
);

public record OrderRequest(int ProductId, int Quantity);

public static class OrderEndpoints
{
    private const string OrderByIdRoute = "/{id:int}";

    private static readonly ConcurrentDictionary<int, Order> Orders = new();
    private static int _nextId;

    public static void MapOrderEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/orders");

        group.MapGet("/", GetAllOrders);
        group.MapGet(OrderByIdRoute, GetOrder);
        group.MapPost("/", CreateOrder);
    }

    private static IResult GetAllOrders()
    {
        return Results.Ok(Orders.Values.OrderBy(o => o.Id));
    }

    private static IResult GetOrder(int id)
    {
        return Orders.TryGetValue(id, out var order)
            ? Results.Ok(order)
            : Results.NotFound();
    }

    private static IResult CreateOrder(OrderRequest request)
    {
        if (request.ProductId <= 0 || request.Quantity <= 0)
            return Results.BadRequest();

        if (!ProductEndpoints.ProductExists(request.ProductId))
            return Results.NotFound();

        var id = Interlocked.Increment(ref _nextId);

        var order = new Order(
            id,
            request.ProductId,
            request.Quantity,
            DateTime.UtcNow
        );

        Orders[id] = order;

        return Results.Created($"/api/orders/{id}", order);
    }
}