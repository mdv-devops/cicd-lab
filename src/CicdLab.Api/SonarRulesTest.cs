namespace CicdLab.Api;

public static class SonarRulesTest
{
    public static bool HasProducts(IEnumerable<Product> products)
    {
        return products.Count() > 0;
    }
    public static bool HasExpensiveProducts(IEnumerable<Product> products)
    {
        return products.Where(p => p.Price > 1000).Count() > 0;
    }

    public static bool HasCheapProducts(IEnumerable<Product> products)
    {
        return products.Where(p => p.Price < 100).Count() > 0;
    }

    public static bool HasFreeProducts(IEnumerable<Product> products)
    {
        return products.Where(p => p.Price == 0).Count() > 0;
    }

    public static bool HasNamedProducts(IEnumerable<Product> products)
    {
        return products.Where(p => !string.IsNullOrWhiteSpace(p.Name)).Count() > 0;
    }

    public static bool HasProductsWithLongNames(IEnumerable<Product> products)
    {
        return products.Where(p => p.Name.Length > 10).Count() > 0;
    }

    public static bool HasProductsWithShortNames(IEnumerable<Product> products)
    {
        return products.Where(p => p.Name.Length < 5).Count() > 0;
    }

    public static bool HasProductsStartingWithA(IEnumerable<Product> products)
    {
        return products.Where(p => p.Name.StartsWith("A")).Count() > 0;
    }

    public static bool HasProductsEndingWithX(IEnumerable<Product> products)
    {
        return products.Where(p => p.Name.EndsWith("X")).Count() > 0;
    }

    public static bool HasProductsWithEvenIds(IEnumerable<Product> products)
    {
        return products.Where(p => p.Id % 2 == 0).Count() > 0;
    }

    public static bool HasProductsWithOddIds(IEnumerable<Product> products)
    {
        return products.Where(p => p.Id % 2 != 0).Count() > 0;
    }
}

