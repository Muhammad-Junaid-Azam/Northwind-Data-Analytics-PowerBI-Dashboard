USE northwind;

-- Sales_Performance
SELECT 
    c.Country,
    c.City,
    cat.CategoryName,
    cat.Description AS CategoryDescription,
    p.ProductID,
    p.ProductName,
    SUM(od.Quantity * p.Price) AS TotalRevenue,
    COUNT(DISTINCT o.OrderID) AS TotalOrders,
    EXTRACT(YEAR FROM o.OrderDate) AS OrderYear,
    MONTHNAME(o.OrderDate) AS OrderMonth
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN OrderDetails od ON o.OrderID = od.OrderID
JOIN Products p ON p.ProductID = od.ProductID
JOIN Categories cat ON cat.CategoryID = p.CategoryID
GROUP BY 
    c.Country, c.City, cat.CategoryName, cat.Description, 
    p.ProductID, p.ProductName, 
    EXTRACT(YEAR FROM o.OrderDate), MONTHNAME(o.OrderDate)
ORDER BY TotalRevenue DESC;

-- Supplier_Shipper_Employee_Performance

SELECT
    s.SupplierID,
    s.SupplierName,
    sh.ShipperID,
    sh.ShipperName,
    e.EmployeeID,
    CONCAT(e.FirstName, ' ', e.LastName) AS EmployeeName,
    EXTRACT(YEAR FROM o.OrderDate) AS OrderYear,
    COUNT(DISTINCT o.OrderID) AS TotalOrders,
    SUM(od.Quantity) AS TotalQuantity,
    SUM(od.Quantity * p.Price) AS TotalRevenue,
    DENSE_RANK() OVER (PARTITION BY EXTRACT(YEAR FROM o.OrderDate) ORDER BY SUM(od.Quantity * p.Price) DESC) AS YearlyRank
FROM Orders o
LEFT JOIN OrderDetails od ON o.OrderID = od.OrderID
LEFT JOIN Products p ON p.ProductID = od.ProductID
LEFT JOIN Suppliers s ON s.SupplierID = p.SupplierID
LEFT JOIN Shippers sh ON sh.ShipperID = o.ShipperID
LEFT JOIN Employees e ON e.EmployeeID = o.EmployeeID
GROUP BY 
    s.SupplierID, s.SupplierName, 
    sh.ShipperID, sh.ShipperName, 
    e.EmployeeID, e.FirstName, e.LastName,
    EXTRACT(YEAR FROM o.OrderDate)
ORDER BY TotalRevenue DESC;

-- Top5_Loyal_Customers_RevenueWise

WITH CustomerRevenue AS (
    SELECT 
        cu.CustomerID,
        cu.ContactName AS CustomerName,
        cu.City,
        cu.Country,
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        SUM(od.Quantity * p.Price) AS TotalRevenue,
        MAX(o.OrderDate) AS LastOrderDate
    FROM Customers cu
    JOIN Orders o ON cu.CustomerID = o.CustomerID
    JOIN OrderDetails od ON o.OrderID = od.OrderID
    JOIN Products p ON p.ProductID = od.ProductID
    GROUP BY cu.CustomerID, cu.ContactName, cu.City, cu.Country
),
RankedCustomers AS (
    SELECT
        CustomerID,
        CustomerName,
        City,
        Country,
        TotalOrders,
        TotalRevenue,
        LastOrderDate,
        DENSE_RANK() OVER (ORDER BY TotalRevenue DESC) AS RevenueRank
    FROM CustomerRevenue
)
SELECT *
FROM RankedCustomers
WHERE RevenueRank <= 5
ORDER BY RevenueRank;

-- Customer Segmentation RFM_Analysis

WITH RFM AS (
    SELECT 
        c.CustomerID,
        c.ContactName AS CustomerName,
        c.City,
        c.Country,
        MAX(o.OrderDate) AS LastOrderDate,
        COUNT(DISTINCT o.OrderID) AS Frequency,
        SUM(od.Quantity * p.Price) AS Monetary
    FROM Customers c
    JOIN Orders o ON c.CustomerID = o.CustomerID
    JOIN OrderDetails od ON o.OrderID = od.OrderID
    JOIN Products p ON p.ProductID = od.ProductID
    GROUP BY c.CustomerID, c.ContactName, c.City, c.Country
),
RFM_Scored AS (
    SELECT 
        r.CustomerID,
        r.CustomerName,
        r.City,
        r.Country,
        DATEDIFF((SELECT MAX(OrderDate) FROM Orders), r.LastOrderDate) AS RecencyDays,
        r.Frequency,
        r.Monetary,
        NTILE(5) OVER (ORDER BY DATEDIFF((SELECT MAX(OrderDate) FROM Orders), r.LastOrderDate) ASC) AS R_Score,
        NTILE(5) OVER (ORDER BY r.Frequency DESC) AS F_Score,
        NTILE(5) OVER (ORDER BY r.Monetary DESC) AS M_Score
    FROM RFM r
)
SELECT 
    CustomerID,
    CustomerName,
    City,
    Country,
    RecencyDays AS Recency,
    Frequency,
    ROUND(Monetary, 2) AS Monetary,
    R_Score,
    F_Score,
    M_Score,
    (R_Score + F_Score + M_Score) AS TotalScore,
    CASE
        WHEN (R_Score + F_Score + M_Score) >= 13 THEN 'Best Customers'
        WHEN (R_Score + F_Score + M_Score) BETWEEN 10 AND 12 THEN 'Loyal Customers'
        WHEN (R_Score + F_Score + M_Score) BETWEEN 7 AND 9 THEN 'Potential Customers'
        WHEN (R_Score + F_Score + M_Score) BETWEEN 4 AND 6 THEN 'At Risk'
        ELSE 'Churned'
    END AS Segment
FROM RFM_Scored
ORDER BY TotalScore DESC;

