-- --------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------
--
--   Drop and Create Database (XOutputTable)
--
-- --------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------
DROP DATABASE IF EXISTS XOutputTable
GO
CREATE DATABASE XOutputTable
GO


-- --------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------
--
--   Create the tables (MainTable, AddTable, DeleteTable, Links, Objects)
--
-- --------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------
USE XOutputTable
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-- ------------------------------------------------------------
-- MainTable
--   database table corresponding to the Simio table "Table"
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dbo.MainTable
GO
CREATE TABLE dbo.MainTable (
	IntPK            INTEGER     NOT NULL PRIMARY KEY
	,RealState       REAL        NULL
	,IntegerState    INTEGER     NULL
	,BooleanState    BIT         NULL
	,DateTimeState   DATETIME    NULL
	,StringState     VARCHAR(50) NULL
	,ObjectRefState  VARCHAR(50) NULL
	,SourceIntPK     INTEGER     NULL
	)
GO


-- ------------------------------------------------------------
-- AddTable
--   tuples (sans IntPK) to add to the Simio "Table"
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dbo.AddTable
GO
CREATE TABLE dbo.AddTable (
	DBIntPK          INTEGER     NOT NULL IDENTITY(1,1)  PRIMARY KEY
	,RealState       REAL        NULL
	,IntegerState    INTEGER     NULL
	,BooleanState    BIT         NULL
	,DateTimeState   DATETIME    NULL
	,StringState     VARCHAR(50) NULL
	,ObjectRefState  VARCHAR(50) NULL
	,SourceIntPK     INTEGER     NULL
	)
GO

-- ------------------------------------------------------------
-- DeleteTable
--   IntPK of rows to delete from the Simio "Table"
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dbo.DeleteTable
GO
CREATE TABLE dbo.DeleteTable (
	IntPK  INTEGER  NOT NULL PRIMARY KEY
	)
GO

-- ------------------------------------------------------------
-- Links
--   Simio Links
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dbo.Links
GO
CREATE TABLE dbo.Links (
	Name         VARCHAR(50) NOT NULL
	,Type        VARCHAR(20) NOT NULL
	,Origin      VARCHAR(20) NOT NULL
	,Destination VARCHAR(20) NOT NULL
	)
GO
INSERT INTO dbo.Links (Name, Type, Origin, Destination)
VALUES
	 ('L01','Path','DropQueue',   'Input@DC01')
	,('L02','Path','DropQueue',   'Input@DC02')
	,('L03','Path','DropQueue',   'Input@DC03')
	,('L04','Path','DropQueue',   'Input@DC04')
	,('X01','Path','Output@DC01', 'Input@Sink1')
	,('X02','Path','Output@DC02', 'Input@Sink1')
	,('X03','Path','Output@DC03', 'Input@Sink1')
	,('X04','Path','Output@DC04', 'Input@Sink1')

-- ------------------------------------------------------------
-- Objects
--   Simio Objects
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dbo.Objects
GO
CREATE TABLE dbo.Objects (
	Name   VARCHAR(50) NOT NULL
	,Type  VARCHAR(20) NOT NULL
	,xLoc  INTEGER     NULL
	,zLoc  INTEGER     NULL
	)
GO
INSERT INTO dbo.Objects (Name, Type, xLoc, zLoc)
VALUES
	 ('DC01','Server',  0,   -4.5  )
	,('DC02','Server',  0,   -1.5  )
	,('DC03','Server',  0,    1.5  )
	,('DC04','Server',  0,    4.5  )
GO

-- --------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------
--
--   Create the SPROCS for TESTING the table synchronizing
--
-- --------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------

-- --------------------------------------------------------------------------------
-- InitializeTables
--   Execute once at the start of the run
-- --------------------------------------------------------------------------------
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[InitializeTables]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[InitializeTables]
GO
CREATE PROCEDURE [dbo].[InitializeTables]
AS
BEGIN
	SET NOCOUNT ON;
	TRUNCATE TABLE dbo.AddTable;
	TRUNCATE TABLE dbo.DeleteTable;
	TRUNCATE TABLE dbo.MainTable;
END
GO

-- --------------------------------------------------------------------------------
-- Raptomize (Random "Optimizer")
--   Execute periodically after DbWrite and before (DbRead + AddRow + DeleteRow)
--   Creates random Adds, Changes, and Deletes to exercise sample
-- --------------------------------------------------------------------------------
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Raptomize]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[Raptomize]
GO
CREATE PROCEDURE [dbo].[Raptomize]
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IntPK INT;
	DECLARE MainCursor CURSOR FAST_FORWARD FOR
		SELECT IntPK
		FROM   dbo.MainTable
		WHERE  ISNULL(MainTable.ObjectRefState, '') = ''
 
	OPEN MainCursor
	FETCH NEXT FROM MainCursor INTO @IntPK
 
	WHILE @@FETCH_STATUS = 0
	BEGIN
		UPDATE dbo.MainTable 
		SET ObjectRefState = (SELECT TOP 1 Name FROM dbo.Objects ORDER BY NEWID())
		WHERE IntPK = @IntPK;

		FETCH NEXT FROM MainCursor INTO @IntPK
	END
	CLOSE MainCursor
	DEALLOCATE MainCursor
	;

	IF ((SELECT COUNT(*) FROM dbo.MainTable) > 4) BEGIN
		INSERT INTO dbo.DeleteTable(
			IntPK
			)
		SELECT TOP 2
			IntPK
		FROM
			dbo.MainTable
		ORDER BY
			newid()

		INSERT INTO dbo.AddTable(
			RealState
			,IntegerState
			,BooleanState
			,DateTimeState
			,StringState
			,ObjectRefState
			,SourceIntPK
			)
		SELECT TOP 2
			RealState
			,IntegerState * RAND(CONVERT(VARBINARY, NEWID()))
			,BooleanState
			,GETDATE()
			,StringState
			,ObjectRefState
			,IntPK
		FROM
			dbo.MainTable
		WHERE
			IntPK NOT IN (SELECT IntPK FROM dbo.DeleteTable)
		ORDER BY
			NEWID()
		;
		END
	;


	UPDATE
		dbo.MainTable
	SET
		IntegerState = m.IntegerState - a.IntegerState
		,ObjectRefState = (SELECT TOP 1 Name FROM dbo.Objects ORDER BY NEWID())
	FROM
		dbo.MainTable AS m
		INNER JOIN dbo.AddTable AS a ON m.IntPK = a.SourceIntPK
	;

END
GO
