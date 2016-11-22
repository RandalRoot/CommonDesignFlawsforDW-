/**********************************************************************
In this script we look at of the most common 
Data Warehouse design flaws 
***********************************************************************/

-- First, let's make a new DB and some namespaces(schemas) to orgainize them...
USE [master];
Go
If Exists (Select name from SysDatabases Where Name = 'AW_Project01_DW_DB')
	Begin
		ALTER DATABASE [AW_Project01_DW_DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
		DROP DATABASE [AW_Project01_DW_DB];
	End
Go
Create Database [AW_Project01_DW_DB];
Go
USE AW_Project01_DW_DB
Go
Create Schema BadDesign1;
Go
Create Schema BadDesign2;
Go
Create Schema SimpleStarDesign;
Go
Create Schema SimpleSnowflakeDesign;
Go
Use [AW_Project01_OLTP_DB]; -- Source DB
Go


/* One common flawed design is know as the "Centipede"
"Some designers CREATE SEPARATE NORMALIZED DIMENSIONS FOR EACH LEVEL OF A MANY-TO-ONE HIERARCHY, 
such as a date dimension, month dimension, quarter dimension, and year dimension, and then include 
all these foreign keys in a fact table. THIS RESULTS IN A CENTIPEDE FACT TABLE WITH DOZENS OF 
HIERARCHICALLY RELATED DIMENSIONS. Centipede fact tables should be avoided."
(http://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/centipede-fact-table/)
*/

/************-- Bad Design 1 (Centipede design = Bad) --************/
SELECT        
  SalesOrderHeader.SalesOrderID
, SalesOrderDetail.SalesOrderDetailID
, SalesOrderHeader.OrderDate
, SalesOrderHeader.CustomerID
, SalesOrderDetail.ProductID
, ProductSubcategory.ProductSubcategoryID
, ProductCategory.ProductCategoryID
, SalesOrderDetail.OrderQty
, SalesOrderDetail.UnitPrice
INTO [AW_Project01_DW_DB].[BadDesign1].[FactSales] 
FROM  SalesOrderDetail
INNER JOIN SalesOrderHeader 
	ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
INNER JOIN Products 	
	ON SalesOrderDetail.ProductID = Products.ProductID	 
INNER JOIN ProductSubcategory
	ON ProductSubcategory.ProductSubcategoryID = Products.ProductSubcategoryID 
INNER JOIN ProductCategory 
	ON ProductSubcategory.ProductCategoryID = ProductCategory.ProductCategoryID; 
Go
SELECT
  ProductID
, Name AS ProductName
, ListPrice AS ProductListPrice
INTO [AW_Project01_DW_DB].[BadDesign1].[DimProducts]
FROM Products;
Go
SELECT
  ProductSubcategoryID
, Name AS ProductSubcategoryName
INTO [AW_Project01_DW_DB].[BadDesign1].[DimProductSubCategories]   
FROM ProductSubcategory;
Go
SELECT
  ProductCategoryID
, Name AS ProductCategoryName
INTO [AW_Project01_DW_DB].[BadDesign1].[DimProductCategories]   
FROM ProductCategory;
Go
/************-- Bad Design 1 (Centipede design) --************/

/* A second common flaw is flattening a many to many dimension
"Sometimes dimensions can take on multiple values for a single measurement event, 
such as the multiple diagnoses associated with a health care encounter or multiple 
customers with a bank account. In these cases, it’s UNREASONABLE TO RESOLVE THE 
MANY-VALUED DIMENSIONS DIRECTLY IN THE FACT TABLE, AS THIS WOULD VIOLATE THE NATURAL 
GRAIN OF THE MEASUREMENT EVENT. Thus, we use a many-to-many, dual-keyed bridge table 
in conjunction with the fact table."
http://www.kimballgroup.com/2009/05/the-10-essential-rules-of-dimensional-modeling/
*/
/************-- Bad Design 2 (Flattend Many to Many design = Bad) --************/
SELECT
  SalesOrderDetail.SalesOrderID
, SalesOrderDetail.SalesOrderDetailID
, SalesOrderHeader.OrderDate
, SalesOrderHeader.CustomerID
, SalesOrderDetail.ProductID
, SalesOrderDetail.OrderQty
, SalesOrderDetail.UnitPrice
INTO [AW_Project01_DW_DB].[BadDesign2].[FactSales]
FROM SalesOrderDetail 
INNER JOIN SalesOrderHeader 
	ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID

SELECT
  Customer.CustomerID
, Customer.AccountNumber
, Customer.PersonID
, Person.FirstName
, Person.LastName
, AddressType.Name AS AddressTypeName
, AddressType.AddressTypeID
, Address.AddressID
, Address.City
, StateProvince.StateProvinceCode
, StateProvince.Name AS StateProvanceName
, CountryRegion.CountryRegionCode 
, CountryRegion.Name AS CountryRegionName
INTO [AW_Project01_DW_DB].[BadDesign2].[DimCustomers]
FROM Customer 
INNER JOIN Person 
	ON Customer.PersonID = Person.BusinessEntityID 
INNER JOIN PersonAddress 
	ON Person.BusinessEntityID = PersonAddress.BusinessEntityID 
INNER JOIN AddressType 
	ON PersonAddress.AddressTypeID = AddressType.AddressTypeID 
INNER JOIN Address 
	ON PersonAddress.AddressID = Address.AddressID 
INNER JOIN StateProvince 
	ON Address.StateProvinceID = StateProvince.StateProvinceID 
INNER JOIN CountryRegion 
	ON StateProvince.CountryRegionCode = CountryRegion.CountryRegionCode

Select * 
Into [AW_Project01_DW_DB].[BadDesign2].[OriginalCustomer]
from Customer;

Select * 
Into [AW_Project01_DW_DB].[BadDesign2].[OriginalPerson]
from Person;

Select * 
Into [AW_Project01_DW_DB].[BadDesign2].[OriginalPersonAddress]
from PersonAddress;

Select * 
Into [AW_Project01_DW_DB].[BadDesign2].[OriginalAddress]
from Address;

Select * 
Into [AW_Project01_DW_DB].[BadDesign2].[OriginalStateProvince]
from StateProvince;

Select * 
Into [AW_Project01_DW_DB].[BadDesign2].[OriginalCountryRegion]
from CountryRegion;

/************-- Bad Design 2 (Flattend Many to Many design) --************/

/* Bridge Table Alternitives 
"Multivalued dimension attributes are a reality for many designers. The bridge table technique and the 
alternatives discussed in this Design Tip have their pluses and minuses."
http://www.kimballgroup.com/2014/05/design-tip-166-potential-bridge-table-detours/
*/

/* Typical star and snowflake designs
Now, let's setup a typical star and snowflake design, 
While neither on is Flawed, they do have some advatages and 
Disadvantages to be aware of...
"We generally encourage you to handle many-to-one hierarchical relationships in a single dimension table 
rather than snowflaking. Snowflakes may appear optimal to an experienced OLTP 
data modeler, but they’re suboptimal for DW/BI query performance."
http://www.kimballgroup.com/2008/09/design-tip-105-snowflakes-outriggers-and-bridges/ 


/************-- SimpleStarDesign (Simple Star design) --************/
SELECT
  SalesOrderDetail.SalesOrderID
, SalesOrderDetail.SalesOrderDetailID
, SalesOrderHeader.OrderDate
, SalesOrderHeader.CustomerID
, SalesOrderDetail.ProductID
, SalesOrderDetail.OrderQty
, SalesOrderDetail.UnitPrice
INTO [AW_Project01_DW_DB].[SimpleStarDesign].[FactSales]
FROM SalesOrderDetail 
INNER JOIN SalesOrderHeader 
	ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID


SELECT
  Products.ProductID
, Products.Name AS ProductName
, Products.ListPrice AS ProductListPrice
, ProductSubcategory.ProductSubcategoryID
, ProductSubcategory.Name AS ProductSubCategoryName
, ProductCategory.ProductCategoryID
, ProductCategory.Name AS ProductCategoryName
INTO [AW_Project01_DW_DB].[SimpleStarDesign].[DimProducts]
FROM Products 
INNER JOIN ProductSubcategory 
	ON Products.ProductSubcategoryID = ProductSubcategory.ProductSubcategoryID 
INNER JOIN ProductCategory 
	ON ProductSubcategory.ProductCategoryID = ProductCategory.ProductCategoryID
/************-- SimpleStarDesign (Simple Star design) --************/


/************-- SimpleSnowflakeDesign (Simple Snowflake design) --************/
SELECT
  SalesOrderDetail.SalesOrderID
, SalesOrderDetail.SalesOrderDetailID
, SalesOrderHeader.OrderDate
, SalesOrderHeader.CustomerID
, SalesOrderDetail.ProductID
, SalesOrderDetail.OrderQty
, SalesOrderDetail.UnitPrice
INTO [AW_Project01_DW_DB].[SimpleSnowflakeDesign].[FactSales]
FROM SalesOrderDetail 
INNER JOIN SalesOrderHeader 
	ON SalesOrderDetail.SalesOrderID = SalesOrderHeader.SalesOrderID
Go
SELECT
  ProductID
, Name AS ProductName
, ListPrice AS ProductListPrice
, ProductSubcategoryID
INTO [AW_Project01_DW_DB].[SimpleSnowflakeDesign].[DimProducts]
FROM Products;
Go
SELECT
  ProductSubcategoryID
, Name AS ProductSubcategoryName
, ProductCategoryID
INTO [AW_Project01_DW_DB].[SimpleSnowflakeDesign].[DimProductSubCategories]   
FROM ProductSubcategory;
Go
SELECT
  ProductCategoryID
, Name AS ProductCategoryName
INTO [AW_Project01_DW_DB].[SimpleSnowflakeDesign].[DimProductCategories]   
FROM ProductCategory;

/************-- SimpleSnowflakeDesign (Simple Snowflake design) --************/


/************-- Indexing  --************/
/Indexing can have a big impact on performance, 
so let's add some common idexes...
/*
Missing Index Details from BadDesigns.sql - (local).AW_Project01_DW_DB (NWTech-01\Randal (53))
The Query Processor estimates that implementing the following index could improve the query cost by 16.349%.
*/
/*
USE [AW_Project01_DW_DB]
GO
CREATE UNIQUE CLUSTERED INDEX [ciBadDimSnowflakeProductID]
ON [BadDesign1].[DimProducts]([ProductID])
GO

CREATE UNIQUE CLUSTERED INDEX [ciBadDimSubCategoryID]
ON [BadDesign1].[DimProductSubCategories]([ProductSubCategoryID])
GO

CREATE UNIQUE CLUSTERED INDEX [ciBadDimCategoryID]
ON [BadDesign1].[DimProductCategories]([ProductCategoryID])
GO


CREATE UNIQUE CLUSTERED INDEX [ciDimStarProductID]
ON [SimpleStarDesign].[DimProducts] ([ProductID])
GO

CREATE UNIQUE CLUSTERED INDEX [ciDimSnowflakeProductID]
ON [SimpleSnowflakeDesign].[DimProducts]([ProductID])
GO

CREATE UNIQUE CLUSTERED INDEX [ciDimSubCategoryID]
ON [SimpleSnowflakeDesign].[DimProductSubCategories]([ProductSubCategoryID])
GO

CREATE UNIQUE CLUSTERED INDEX [ciDimCategoryID]
ON [SimpleSnowflakeDesign].[DimProductCategories]([ProductCategoryID])
GO

CREATE NONCLUSTERED INDEX [nciFactSalesProductID]
ON [SimpleStarDesign].[FactSales] ([ProductID])
GO

CREATE NONCLUSTERED INDEX [nciStarFactSalesProductIDWithInclude]
ON [SimpleStarDesign].[FactSales] ([ProductID])
INCLUDE ([SalesOrderID],[SalesOrderDetailID],[OrderDate],[CustomerID],[OrderQty],[UnitPrice])

CREATE NONCLUSTERED INDEX [nciBadFactSalesProductIDWithInclude]
ON [BadDesign1].[FactSales] ([ProductID])
INCLUDE ([SalesOrderID],[SalesOrderDetailID],[OrderDate],[CustomerID],[ProductSubcategoryID],[ProductCategoryID],[OrderQty],[UnitPrice])

CREATE NONCLUSTERED INDEX [nciSnowflakeFactSalesProductIDWithInclude]
ON [SimpleSnowflakeDesign].[FactSales] ([ProductID])
INCLUDE ([SalesOrderID],[SalesOrderDetailID],[OrderDate],[CustomerID],[OrderQty],[UnitPrice])
*/
/************-- Indexing  --************/
 
/******* Performance Testing code *******/
Use [AW_Project01_DW_DB]; -- Data Warehouse DB
Go
-- Test Performance on Bad Design 1
-- Note, there is a large performance hit when you join the DimProducts and DimCategories 
-- since it has to evaluate all of the rows in the fact table to process the join!
Use [AW_Project01_DW_DB];
Go

Select '-- Star --'
Print  '-- Star --'
Set Statistics IO On
Set Statistics Time On
SELECT
  SimpleStarDesign.FactSales.SalesOrderID
, SimpleStarDesign.FactSales.SalesOrderDetailID
, SimpleStarDesign.FactSales.OrderDate
, SimpleStarDesign.FactSales.CustomerID
, SimpleStarDesign.DimProducts.ProductID
, SimpleStarDesign.DimProducts.ProductName
, SimpleStarDesign.DimProducts.ProductListPrice
, SimpleStarDesign.DimProducts.ProductSubcategoryID
, SimpleStarDesign.DimProducts.ProductSubCategoryName
, SimpleStarDesign.DimProducts.ProductCategoryID
, SimpleStarDesign.DimProducts.ProductCategoryName
, SimpleStarDesign.FactSales.OrderQty
, SimpleStarDesign.FactSales.UnitPrice
FROM SimpleStarDesign.DimProducts 
INNER JOIN SimpleStarDesign.FactSales 
	ON SimpleStarDesign.DimProducts.ProductID = SimpleStarDesign.FactSales.ProductID
ORDER BY
  SimpleStarDesign.FactSales.SalesOrderID
, SimpleStarDesign.FactSales.SalesOrderDetailID
, SimpleStarDesign.FactSales.OrderDate
, SimpleStarDesign.FactSales.CustomerID
, SimpleStarDesign.DimProducts.ProductID
, SimpleStarDesign.DimProducts.ProductName
, SimpleStarDesign.DimProducts.ProductListPrice
, SimpleStarDesign.DimProducts.ProductSubcategoryID
, SimpleStarDesign.DimProducts.ProductSubCategoryName
, SimpleStarDesign.DimProducts.ProductCategoryID
, SimpleStarDesign.DimProducts.ProductCategoryName
Print '-------------------------------------------'
Set Statistics IO Off
Set Statistics Time Off


Select '-- Snowflake --'
Print  '-- Snowflake --'
Set Statistics IO On
Set Statistics Time On
SELECT        
SimpleSnowflakeDesign.FactSales.SalesOrderID
, SimpleSnowflakeDesign.FactSales.SalesOrderDetailID
, SimpleSnowflakeDesign.FactSales.OrderDate
, SimpleSnowflakeDesign.FactSales.CustomerID
, SimpleSnowflakeDesign.FactSales.ProductID
, SimpleSnowflakeDesign.DimProducts.ProductName
, SimpleSnowflakeDesign.DimProducts.ProductListPrice
, SimpleSnowflakeDesign.DimProductSubCategories.ProductSubcategoryID
, SimpleSnowflakeDesign.DimProductSubCategories.ProductSubcategoryName
, SimpleSnowflakeDesign.DimProductCategories.ProductCategoryID
, SimpleSnowflakeDesign.DimProductCategories.ProductCategoryName
, SimpleSnowflakeDesign.FactSales.OrderQty
, SimpleSnowflakeDesign.FactSales.UnitPrice
FROM SimpleSnowflakeDesign.FactSales 
INNER JOIN SimpleSnowflakeDesign.DimProducts 
	ON SimpleSnowflakeDesign.FactSales.ProductID = SimpleSnowflakeDesign.DimProducts.ProductID 
INNER JOIN SimpleSnowflakeDesign.DimProductSubCategories 
	ON SimpleSnowflakeDesign.DimProducts.ProductSubcategoryID = SimpleSnowflakeDesign.DimProductSubCategories.ProductSubcategoryID 
INNER JOIN SimpleSnowflakeDesign.DimProductCategories 
	ON SimpleSnowflakeDesign.DimProductSubCategories.ProductCategoryID = SimpleSnowflakeDesign.DimProductCategories.ProductCategoryID
ORDER BY
  SimpleSnowflakeDesign.FactSales.SalesOrderID
, SimpleSnowflakeDesign.FactSales.SalesOrderDetailID
, SimpleSnowflakeDesign.FactSales.OrderDate
, SimpleSnowflakeDesign.FactSales.CustomerID
, SimpleSnowflakeDesign.DimProducts.ProductID
, SimpleSnowflakeDesign.DimProducts.ProductName
, SimpleSnowflakeDesign.DimProducts.ProductListPrice
, SimpleSnowflakeDesign.DimProductSubcategories.ProductSubcategoryID
, SimpleSnowflakeDesign.DimProductSubCategories.ProductSubCategoryName
, SimpleSnowflakeDesign.DimProductCategories.ProductCategoryID
, SimpleSnowflakeDesign.DimProductCategories.ProductCategoryName
Print '-------------------------------------------'
Set Statistics IO Off
Set Statistics Time Off

Select '-- Caterpillar --'
Print  '-- Caterpillar --'
Set Statistics IO On
Set Statistics Time On
SELECT        
  BadDesign1.FactSales.SalesOrderID
, BadDesign1.FactSales.SalesOrderDetailID
, BadDesign1.FactSales.OrderDate
, BadDesign1.FactSales.CustomerID
, BadDesign1.DimProducts.ProductID
, BadDesign1.DimProducts.ProductName
, BadDesign1.DimProducts.ProductListPrice
, BadDesign1.DimProductSubCategories.ProductSubcategoryID
, BadDesign1.DimProductSubCategories.ProductSubcategoryName
, BadDesign1.DimProductCategories.ProductCategoryID
, BadDesign1.DimProductCategories.ProductCategoryName
, BadDesign1.FactSales.OrderQty
, BadDesign1.FactSales.UnitPrice
FROM BadDesign1.FactSales 
INNER JOIN BadDesign1.DimProducts 
	ON BadDesign1.FactSales.ProductID = BadDesign1.DimProducts.ProductID 
INNER JOIN BadDesign1.DimProductSubCategories 
	ON BadDesign1.FactSales.ProductSubcategoryID = BadDesign1.DimProductSubCategories.ProductSubcategoryID 
INNER JOIN BadDesign1.DimProductCategories 
	ON BadDesign1.FactSales.ProductCategoryID = BadDesign1.DimProductCategories.ProductCategoryID
ORDER BY
  BadDesign1.FactSales.SalesOrderID
, BadDesign1.FactSales.SalesOrderDetailID
, BadDesign1.FactSales.OrderDate
, BadDesign1.FactSales.CustomerID
, BadDesign1.DimProducts.ProductID
, BadDesign1.DimProducts.ProductName
, BadDesign1.DimProducts.ProductListPrice
, BadDesign1.DimProductSubcategories.ProductSubcategoryID
, BadDesign1.DimProductSubCategories.ProductSubCategoryName
, BadDesign1.DimProductCategories.ProductCategoryID
, BadDesign1.DimProductCategories.ProductCategoryName
Go
Print '-------------------------------------------'
Set Statistics Time Off
Set Statistics IO OFF
/******* Testing code *******/


