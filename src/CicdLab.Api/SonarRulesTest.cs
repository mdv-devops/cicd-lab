namespace CicdLab.Api;

public static class SonarRulesTest
{
    public static bool HasProducts(IEnumerable<Product> products)
    {
        return products.Count() > 0;
    }

    public static bool HasExpensiveProducts(IEnumerable<Product> products)
    {
        return products.Count(p => p.Price > 1000) > 0;
    }

    public static bool HasCheapProducts(IEnumerable<Product> products)
    {
        return products.Count(p => p.Price < 100) > 0;
    }

    public static bool HasFreeProducts(IEnumerable<Product> products)
    {
        return products.Count(p => p.Price == 0) > 0;
    }

    public static bool HasNamedProducts(IEnumerable<Product> products)
    {
        return products.Count(p => !string.IsNullOrWhiteSpace(p.Name)) > 0;
    }

    public static bool HasProductsWithLongNames(IEnumerable<Product> products)
    {
        return products.Count(p => p.Name.Length > 10) > 0;
    }

    public static bool HasProductsWithShortNames(IEnumerable<Product> products)
    {
        return products.Count(p => p.Name.Length < 5) > 0;
    }

    public static bool HasProductsStartingWithA(IEnumerable<Product> products)
    {
        return products.Count(p => p.Name.StartsWith("A")) > 0;
    }

    public static bool HasProductsEndingWithX(IEnumerable<Product> products)
    {
        return products.Count(p => p.Name.EndsWith("X")) > 0;
    }

    public static bool HasProductsWithEvenIds(IEnumerable<Product> products)
    {
        return products.Count(p => p.Id % 2 == 0) > 0;
    }

    public static bool HasProductsWithOddIds(IEnumerable<Product> products)
    {
        return products.Count(p => p.Id % 2 != 0) > 0;
    }
}