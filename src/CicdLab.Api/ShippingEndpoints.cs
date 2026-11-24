namespace CicdLab.Api;

public static class ShippingEndpoints
{
    public static void MapShippingEndpoints(this WebApplication app)
    {
        app.MapGet("/api/shipping", (decimal orderAmount) =>
        {
            if (orderAmount <= 0)
            {
                return Results.BadRequest(new
                {
                    Error = "Order amount must be positive"
                });
            }

            decimal shippingCost;

            if (orderAmount >= 100)
            {
                shippingCost = 0;
            }
            else if (orderAmount >= 50)
            {
                shippingCost = 5;
            }
            else
            {
                shippingCost = 10;
            }

            return Results.Ok(new
            {
                OrderAmount = orderAmount,
                ShippingCost = shippingCost,
                TotalAmount = orderAmount + shippingCost
            });
        });
    }
}