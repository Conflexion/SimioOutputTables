USE XOutputTable
GO

/*
SELECT * FROM Links;
SELECT * FROM Objects;
*/

SELECT * FROM dbo.MainTable   ORDER BY IntPK
SELECT * FROM dbo.DeleteTable ORDER BY IntPK
SELECT * FROM dbo.AddTable    ORDER BY SourceIntPK
