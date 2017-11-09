if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_GetProductionByPeriodReport]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_GetProductionByPeriodReport]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_GetProductionByPeriodReportGroup]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_GetProductionByPeriodReportGroup]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_GetProductionComingReport]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_GetProductionComingReport]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_GetProductionTransmitReport]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_GetProductionTransmitReport]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_GetProductionSellingReport]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_GetProductionSellingReport]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_GetProductionDefectReport]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_GetProductionDefectReport]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_GetProductionDestructionReport]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_GetProductionDestructionReport]
GO

SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS ON 
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_GetProductionByPeriodReport]'
GO
/*--------------------------------------------------------------------------------
  Model  : tr
  Class  : Transport Report
  Author : Герасевич А.Ю., Осадчий А.П.
  Desc   : Выводим отчет по типу продукции по МРЕВ за период
  Last   : Осадчий А.П. / 2007-06-06
  Result :
  Cursor :  
     [Nomenclature] varchar(10)  -- Номенклатура
    ,[ProdID]       int          -- Спец. продукция
    ,[ProdName]     varchar(255) -- Название спец. продукции
    ,[StartCount]   int          -- Остаток на начало периода
    ,[IncomeCount]  int          -- Приход за период
    ,[OutcomeCount] int          -- Расход за период
    ,[EndCount]     int          -- Остаток на конец
*/
CREATE PROCEDURE [dbo].[tr_GetProductionByPeriodReport]
   @DateFrom  datetime    -- Начальная дата
  ,@DateTo    datetime    -- Конечная дата
  ,@OVSCode   varchar(10) -- ОВС
  ,@ProdType  int         -- Тип спец. продукции (4001 - Нова, 4002 - Була у використанні)
  ,@ProdClass int         -- Класс спец. продукции (6001 - Бланк, 6002 - Номерний знак)
  ,@ProdID    int         -- ID спец продукции
WITH RECOMPILE AS BEGIN

  SET NOCOUNT ON

  if @DateFrom is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата з') WITH SETERROR
    RETURN -1
  end
  if @DateTo is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата по') WITH SETERROR
    RETURN -1
  end
  set @DateTo = DATEADD(day, 1, CONVERT(datetime, CONVERT(varchar(10), @DateTo, 121), 121))
  if @DateTo < @DateFrom
  begin
    RAISERROR('"Дата по" повинна бути більшою ніж "Дата з"', 16, 10) WITH SETERROR
    RETURN -1
  end
  if @OVSCode is NULL
  begin
    RAISERROR(60002, 16, 10, 'МРЕВ') WITH SETERROR
    RETURN -1
  end
  if @ProdType is NULL
  begin
    RAISERROR(60002, 16, 10, 'Тип спец. продукції') WITH SETERROR
    RETURN -1
  end
  --
  select ProdID
  into #SeekProd
  from stProduction
  where (ProdID = @ProdID or @ProdID is NULL)
    and ((@ProdClass = 6001 and ProdClassID in (402, 404)) -- Документ
      or (@ProdClass = 6002 and ProdClassID in (401))      -- ДНЗ
      or @ProdClass is NULL)
  --
  CREATE UNIQUE INDEX IX_#SeekProd_Cluster ON #SeekProd (ProdID)
  --
  select StoreGUID
  into #SeekStores
  from stStores Stores
    inner join stStoreTypes StoreType on StoreType.StoreTypeID = Stores.StoreTypeID
  where Stores.OVSCode = @OVSCode
    and ((@ProdType = 4001 and StoreType.Options & 0x0010 <> 0)  -- Нова
      or (@ProdType = 4002 and StoreType.Options & 0x0020 <> 0)) -- Б/У
  --
  CREATE UNIQUE INDEX IX_#SeekStores_Cluster ON #SeekStores (StoreGUID)
  --
  CREATE TABLE #RemainsAtBegin (
     ProdID int
    ,Qty    int
    )
  CREATE TABLE #RemainsAtEnd (
     ProdID int
    ,Qty    int
    )
  --  
  if @ProdID is NULL
  begin
    -- Остаток на начало
    insert into #RemainsAtBegin
    select
       ProdID = Items.ProdID
      ,Qty    = COUNT(*)
    from stStoreDocs Doc
      inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
      inner join (
        select
           ItemNumber = ItemNumber
          ,ProdID     = ProdID
          ,DocDate    = MAX(DocDate)
        from stStoreDocItems
        where DocDate < @DateFrom
        group by ProdID, ItemNumber
      ) MaxItems on MaxItems.ProdID = Items.ProdID and MaxItems.ItemNumber = Items.ItemNumber and MaxItems.DocDate = Items.DocDate
    where Doc.StoreToGUID in (select StoreGUID from #SeekStores)
      and Items.ProdID in (select ProdID from #SeekProd)
      and Items.OnOVS = 0x1
    group by Items.ProdID
    -- Остаток на конец
    insert into #RemainsAtEnd
    select
       ProdID = Items.ProdID
      ,Qty    = COUNT(*)
    from stStoreDocs Doc
      inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
      inner join (
        select
           ItemNumber = ItemNumber
          ,ProdID     = ProdID
          ,DocDate    = MAX(DocDate)
        from stStoreDocItems
        where DocDate < @DateTo
        group by ProdID, ItemNumber
      ) MaxItems on MaxItems.ProdID = Items.ProdID and MaxItems.ItemNumber = Items.ItemNumber and MaxItems.DocDate = Items.DocDate
    where Doc.StoreToGUID in (select StoreGUID from #SeekStores)
      and Items.ProdID in (select ProdID from #SeekProd)
      and Items.OnOVS = 0x1
    group by Items.ProdID
  end
  else
  begin
    -- Остаток на начало
   insert into #RemainsAtBegin
    select
       ProdID = Items.ProdID
      ,Qty    = COUNT(*)
    from stStoreDocs Doc
      inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
      inner join (
        select
           ItemNumber = ItemNumber
          ,ProdID     = ProdID
          ,DocDate    = MAX(DocDate)
        from stStoreDocItems
        where DocDate < @DateFrom
        group by ProdID, ItemNumber
      ) MaxItems on MaxItems.ProdID = Items.ProdID and MaxItems.ItemNumber = Items.ItemNumber and MaxItems.DocDate = Items.DocDate
    where Doc.StoreToGUID in (select StoreGUID from #SeekStores)
      and Items.ProdID = @ProdID
      and Items.OnOVS = 0x1
    group by Items.ProdID
    -- Остаток на конец
    insert into #RemainsAtEnd
    select
       ProdID = Items.ProdID
      ,Qty    = COUNT(*)
    from stStoreDocs Doc
      inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
      inner join (
        select
           ItemNumber = ItemNumber
          ,ProdID     = ProdID
          ,DocDate    = MAX(DocDate)
        from stStoreDocItems
        where DocDate < @DateTo
        group by ProdID, ItemNumber
      ) MaxItems on MaxItems.ProdID = Items.ProdID and MaxItems.ItemNumber = Items.ItemNumber and MaxItems.DocDate = Items.DocDate
    where Doc.StoreToGUID in (select StoreGUID from #SeekStores)
      and Items.ProdID = @ProdID
      and Items.OnOVS = 0x1
    group by Items.ProdID
  end

 -- Приходы -------------------------------------------
    select
       ProdID = Items.ProdID
      ,Qty    = COUNT(*)
    into #Income
    from stStoreDocs Doc
      inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
      left outer join stStores StoreFrom on StoreFrom.StoreGUID = Doc.StoreFromGUID
      left outer join stStoreTypes TypeFrom on TypeFrom.StoreTypeID = StoreFrom.StoreTypeID
    where Doc.StoreToGUID in (select StoreGUID from #SeekStores)
      and Items.ProdID in (select ProdID from #SeekProd)
      and (StoreFrom.OVSCode <> @OVSCode
        or StoreFrom.OVSCode is NULL
        or StoreFrom.StoreGUID is NULL
        or (@ProdType = 4001 and TypeFrom.Options & 0x0010 = 0)  -- Нова
        or (@ProdType = 4002 and TypeFrom.Options & 0x0020 = 0)) -- Б/У
      and Doc.DocDate >= @DateFrom
      and Doc.DocDate < @DateTo
      and Items.DocDate >= @DateFrom
      and Items.DocDate < @DateTo
    group by Items.ProdID

 -- Расходы -------------------------------------------
    select
       ProdID = Items.ProdID
      ,Qty    = COUNT(*)
    into #Outcome
    from stStoreDocs Doc
      inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
      inner join stStores StoreTo on StoreTo.StoreGUID = Doc.StoreToGUID
      inner join stStoreTypes StoreTypeTo on StoreTypeTo.StoreTypeID = StoreTo.StoreTypeID
    where Doc.StoreFromGUID in (select StoreGUID from #SeekStores)
      and Items.ProdID in (select ProdID from #SeekProd)
      and (StoreTo.OVSCode <> @OVSCode
        or StoreTo.OVSCode is NULL
        or (@ProdType = 4001 and StoreTypeTo.Options & 0x0010 = 0)  -- Нова
        or (@ProdType = 4002 and StoreTypeTo.Options & 0x0020 = 0)) -- Б/У
      and Doc.DocDate >= @DateFrom
      and Doc.DocDate < @DateTo
      and Items.DocDate >= @DateFrom
      and Items.DocDate < @DateTo
    group by Items.ProdID
  --
  SET NOCOUNT OFF
  -- OUT
  select
     Nomenclature = Prod.BuhNomencl
    ,ProdID       = COALESCE(#RemainsAtBegin.ProdID, #RemainsAtEnd.ProdID, #Income.ProdID, #Outcome.ProdID)
    ,ProdName     = CONVERT(varchar(255), ISNULL(Prod.VisualCode, '') + '-' + Prod.ProdName)
    ,StartCount   = ISNULL(#RemainsAtBegin.Qty, 0)
    ,IncomeCount  = ISNULL(#Income.Qty, 0)
    ,OutcomeCount = ISNULL(#Outcome.Qty, 0)
    ,EndCount     = ISNULL(#RemainsAtEnd.Qty, 0)
  from #RemainsAtBegin
    full outer join #RemainsAtEnd on #RemainsAtEnd.ProdID = #RemainsAtBegin.ProdID
    full outer join #Income on #Income.ProdID = COALESCE(#RemainsAtBegin.ProdID, #RemainsAtEnd.ProdID)
    full outer join #Outcome on #Outcome.ProdID = COALESCE(#RemainsAtBegin.ProdID, #RemainsAtEnd.ProdID, #Income.ProdID)
    inner join stProduction Prod on Prod.ProdID = COALESCE(#RemainsAtBegin.ProdID, #RemainsAtEnd.ProdID, #Income.ProdID, #Outcome.ProdID)
  where ((@ProdClass = 6001 and Prod.ProdClassID in (402, 404)) -- Документ
      or (@ProdClass = 6002 and Prod.ProdClassID in (401))      -- ДНЗ
      or @ProdClass is NULL)
  --
  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_GetProductionByPeriodReportGroup]'
GO
/*--------------------------------------------------------------------------------
  Model  : tr
  Class  : Transport Report
  Author : Герасевич А.Ю., Осадчий А.П.
  Desc   : Выводим отчет по типу продукции по МРЕВ за период в ГРУППИРОВАНОМ ВИДЕ
  Last   : Осадчий А.П. / 2007-06-06
  Result :
  Cursor :  
    ProdID       int          -- ID спец. продукции
    StartName    varchar(255) -- Номер и серия на начало
    StartCount   int          -- Кол-во на начало
    IncomeName   varchar(255) -- Номер и серия в приходе
    IncomeCount  int          -- Кол-во в приходе
    OutcomeName  varchar(255) -- Номер и серия в расходе
    OutcomeCount int          -- Кол-во в расходе
    EndName      varchar(255) -- Номер и серия на конец периода
    EndCount     int          -- Кол-во на конец периода
*/
CREATE PROCEDURE [dbo].[tr_GetProductionByPeriodReportGroup]
   @DateFrom  datetime    -- Начальная дата
  ,@DateTo    datetime    -- Конечная дата
  ,@OVSCode   varchar(10) -- ОВС
  ,@ProdType  int         -- Тип спец. продукции (4001 - Нова, 4002 - Була у використанні)
  ,@ProdClass int         -- Класс спец. продукции (6001 - Бланк, 6002 - Номерний знак)
  ,@ProdID    int         -- ID спец продукции
WITH RECOMPILE AS BEGIN
  SET NOCOUNT ON
  if @DateFrom is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата з') WITH SETERROR
    RETURN -1
  end
  if @DateTo is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата по') WITH SETERROR
    RETURN -1
  end
  set @DateTo = DATEADD(day, 1, CONVERT(datetime, CONVERT(varchar(10), @DateTo, 121), 121))
  if @DateTo < @DateFrom
  begin
    RAISERROR('"Дата по" повинна бути більшою ніж "Дата з"', 16, 10) WITH SETERROR
    RETURN -1
  end
  if @OVSCode is NULL
  begin
    RAISERROR(60002, 16, 10, 'МРЕВ') WITH SETERROR
    RETURN -1
  end
  if @ProdType is NULL
  begin
    RAISERROR(60002, 16, 10, 'Тип спец. продукції') WITH SETERROR
    RETURN -1
  end
  --
  select ProdID
  into #SeekProd
  from stProduction
  where (ProdID = @ProdID or @ProdID is NULL)
    and ((@ProdClass = 6001 and ProdClassID in (402, 404)) -- Документ
      or (@ProdClass = 6002 and ProdClassID in (401))      -- ДНЗ
      or @ProdClass is NULL)
  --
  CREATE UNIQUE INDEX IX_#SeekProd_Cluster ON #SeekProd (ProdID)
  --
  select StoreGUID
  into #SeekStores
  from stStores Stores
    inner join stStoreTypes StoreType on StoreType.StoreTypeID = Stores.StoreTypeID
  where Stores.OVSCode = @OVSCode
    and ((@ProdType = 4001 and StoreType.Options & 0x0010 <> 0)  -- Нова
      or (@ProdType = 4002 and StoreType.Options & 0x0020 <> 0)) -- Б/У
  --
  CREATE UNIQUE INDEX IX_#SeekStores_Cluster ON #SeekStores (StoreGUID)
  --
  CREATE TABLE #RemainsAtBegin (
     ProdID  int
    ,Number  varchar(15)
    ,ProdNum varchar(50)
    ,Qty     int
    )
  CREATE TABLE #RemainsAtEnd (
     ProdID  int
    ,Number  varchar(15)
    ,ProdNum varchar(50)
    ,Qty     int
    )
  --  
  CREATE TABLE #ProdMovement (
     [ProdID]       int         NULL
    ,[Pattern]      varchar(20) NULL
    ,[Number]       bigint      NULL 
    ,[StartCount]   int         NULL
    ,[IncomeCount]  int         NULL
    ,[OutcomeCount] int         NULL
    ,[EndCount]     int         NULL
  )
  CREATE INDEX #ProdMovement_All ON #ProdMovement(ProdID, Pattern, Number)

  CREATE TABLE #SortBegin (
     [ProdID]       int         NULL
    ,[Pattern]      varchar(20) NULL
    ,[Number]       bigint      NULL 
    ,[StartCount]   int         NULL
    ,[IncomeCount]  int         NULL
    ,[OutcomeCount] int         NULL
    ,[EndCount]     int         NULL
  )
  CREATE INDEX #SortBegin_All ON #SortBegin(ProdID, Pattern, Number)

  CREATE TABLE #SortEnd (
     [ProdID]       int         NULL
    ,[Pattern]      varchar(20) NULL
    ,[Number]       bigint      NULL 
    ,[StartCount]   int         NULL
    ,[IncomeCount]  int         NULL
    ,[OutcomeCount] int         NULL
    ,[EndCount]     int         NULL
  )
  CREATE INDEX #SortEnd_All ON #SortEnd(ProdID, Pattern, Number)

  if @ProdID is NULL
  begin
    -- Остаток на начало ------------------------------------
    insert into #RemainsAtBegin
    select distinct
       ProdID  = Items.ProdID
      ,Number  = Items.ItemNumber
      ,ProdNum = CONVERT(varchar(10), Items.ProdID) + '-' + Items.ItemNumber
      ,Qty     = COUNT(*)
    from stStoreDocs Doc
      inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
      inner join (
        select
           ItemNumber = ItemNumber
          ,ProdID     = ProdID
          ,DocDate    = MAX(DocDate)
        from stStoreDocItems
        where DocDate < @DateFrom
        group by ProdID, ItemNumber
      ) MaxItems on MaxItems.ProdID = Items.ProdID and MaxItems.ItemNumber = Items.ItemNumber and MaxItems.DocDate = Items.DocDate
    where Doc.StoreToGUID in (select StoreGUID from #SeekStores)
      and Items.ProdID in (select ProdID from #SeekProd)
      and Items.OnOVS = 0x1
    group by Items.ProdID, Items.ItemNumber
    -- Остаток на конец ------------------------------
    insert into #RemainsAtEnd
    select distinct
       ProdID  = Items.ProdID
      ,Number  = Items.ItemNumber
      ,ProdNum = CONVERT(varchar(10), Items.ProdID) + '-' + Items.ItemNumber
      ,Qty     = COUNT(*)
    from stStoreDocs Doc
      inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
      inner join (
        select
           ItemNumber = ItemNumber
          ,ProdID     = ProdID
          ,DocDate    = MAX(DocDate)
        from stStoreDocItems
        where DocDate < @DateTo
        group by ProdID, ItemNumber
      ) MaxItems on MaxItems.ProdID = Items.ProdID and MaxItems.ItemNumber = Items.ItemNumber and MaxItems.DocDate = Items.DocDate
    where Doc.StoreToGUID in (select StoreGUID from #SeekStores)
      and Items.ProdID in (select ProdID from #SeekProd)
      and Items.OnOVS = 0x1
    group by Items.ProdID, Items.ItemNumber
  end
  else
  begin
    -- Остаток на начало ------------------------------------
    insert into #RemainsAtBegin
    select distinct
       ProdID  = Items.ProdID
      ,Number  = Items.ItemNumber
      ,ProdNum = CONVERT(varchar(10), Items.ProdID) + '-' + Items.ItemNumber
      ,Qty     = COUNT(*)
    from stStoreDocs Doc
      inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
      inner join (
        select
           ItemNumber = ItemNumber
          ,ProdID     = ProdID
          ,DocDate    = MAX(DocDate)
        from stStoreDocItems
        where DocDate < @DateFrom
        group by ProdID, ItemNumber
      ) MaxItems on MaxItems.ProdID = Items.ProdID and MaxItems.ItemNumber = Items.ItemNumber and MaxItems.DocDate = Items.DocDate
    where Doc.StoreToGUID in (select StoreGUID from #SeekStores)
      and Items.ProdID = @ProdID
      and Items.OnOVS = 0x1
    group by Items.ProdID, Items.ItemNumber
    -- Остаток на конец ------------------------------
    insert into #RemainsAtEnd
    select distinct
       ProdID  = Items.ProdID
      ,Number  = Items.ItemNumber
      ,ProdNum = CONVERT(varchar(10), Items.ProdID) + '-' + Items.ItemNumber
      ,Qty     = COUNT(*)
    from stStoreDocs Doc
      inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
      inner join (
        select
           ItemNumber = ItemNumber
          ,ProdID     = ProdID
          ,DocDate    = MAX(DocDate)
        from stStoreDocItems
        where DocDate < @DateTo
        group by ProdID, ItemNumber
      ) MaxItems on MaxItems.ProdID = Items.ProdID and MaxItems.ItemNumber = Items.ItemNumber and MaxItems.DocDate = Items.DocDate
    where Doc.StoreToGUID in (select StoreGUID from #SeekStores)
      and Items.ProdID = @ProdID
      and Items.OnOVS = 0x1
    group by Items.ProdID, Items.ItemNumber
  end
  -- Приходы -------------------------------------------
  select
     ProdID  = Items.ProdID
    ,Number  = Items.ItemNumber
    ,ProdNum = CONVERT(varchar(10), Items.ProdID) + '-' + Items.ItemNumber
    ,Qty     = COUNT(*)
  into #Income
  from stStoreDocs Doc
    inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
    left outer join stStores StoreFrom on StoreFrom.StoreGUID = Doc.StoreFromGUID
    left outer join stStoreTypes TypeFrom on TypeFrom.StoreTypeID = StoreFrom.StoreTypeID
  where Doc.StoreToGUID in (select StoreGUID from #SeekStores)
    and Items.ProdID in (select ProdID from #SeekProd)
    and (StoreFrom.OVSCode <> @OVSCode or StoreFrom.OVSCode is NULL
      or (@ProdType = 4001 and TypeFrom.Options & 0x0010 = 0)  -- Нова
      or (@ProdType = 4002 and TypeFrom.Options & 0x0020 = 0)) -- Б/У
    and Doc.DocDate >= @DateFrom
    and Doc.DocDate < @DateTo
    and Items.DocDate >= @DateFrom
    and Items.DocDate < @DateTo
  group by Items.ProdID, Items.ItemNumber
 -- Расходы -------------------------------------------
  select
     ProdID  = Items.ProdID
    ,Number  = Items.ItemNumber
    ,ProdNum = CONVERT(varchar(10), Items.ProdID) + '-' + Items.ItemNumber
    ,Qty     = COUNT(*)
  into #Outcome
  from stStoreDocs Doc
    inner join stStoreDocItems Items on Items.DocGUID = Doc.DocGUID
    inner join stProduction Prod on Prod.ProdID = Items.ProdID
    inner join stStores StoreTo on StoreTo.StoreGUID = Doc.StoreToGUID
    inner join stStoreTypes StoreTypeTo on StoreTypeTo.StoreTypeID = StoreTo.StoreTypeID
  where Doc.StoreFromGUID in (select StoreGUID from #SeekStores)
    and Items.ProdID in (select ProdID from #SeekProd)
    and (StoreTo.OVSCode <> @OVSCode or StoreTo.OVSCode is NULL
      or (@ProdType = 4001 and StoreTypeTo.Options & 0x0010 = 0)  -- Нова
      or (@ProdType = 4002 and StoreTypeTo.Options & 0x0020 = 0)) -- Б/У
    and Doc.DocDate >= @DateFrom
    and Doc.DocDate < @DateTo
    and Items.DocDate >= @DateFrom
    and Items.DocDate < @DateTo
  group by Items.ProdID, Items.ItemNumber
  --
  insert into #ProdMovement (
     ProdID
    ,Pattern
    ,Number
    ,StartCount
    ,IncomeCount
    ,OutcomeCount
    ,EndCount
    )
  select
     ProdID       = COALESCE(#RemainsAtBegin.ProdID, #RemainsAtEnd.ProdID, #Income.ProdID, #Outcome.ProdID)
    ,Pattern      = dbo.ic_GetPatternFromString(COALESCE(#RemainsAtBegin.Number, #RemainsAtEnd.Number, #Income.Number, #Outcome.Number))
    ,Number       = CONVERT(bigint, dbo.ic_GetIntFromString(COALESCE(#RemainsAtBegin.Number, #RemainsAtEnd.Number, #Income.Number, #Outcome.Number)))
    ,StartCount   = ISNULL(#RemainsAtBegin.Qty, 0)
    ,IncomeCount  = ISNULL(#Income.Qty, 0)
    ,OutcomeCount = ISNULL(#Outcome.Qty, 0)
    ,EndCount     = ISNULL(#RemainsAtEnd.Qty, 0)
  from #RemainsAtBegin
    full outer join #RemainsAtEnd on #RemainsAtEnd.ProdNum = #RemainsAtBegin.ProdNum
    full outer join #Income on #Income.ProdNum = COALESCE(#RemainsAtBegin.ProdNum, #RemainsAtEnd.ProdNum)
    full outer join #Outcome on #Outcome.ProdNum = COALESCE(#RemainsAtBegin.ProdNum, #RemainsAtEnd.ProdNum, #Income.ProdNum)
  --
  insert into #SortBegin (
     ProdID
    ,Pattern
    ,Number
    ,StartCount
    ,IncomeCount
    ,OutcomeCount
    ,EndCount
    )
  select
     ProdID       = s.ProdID
    ,Pattern      = s.Pattern
    ,Number       = s.Number
    ,StartCount   = MAX(s.StartCount)
    ,IncomeCount  = MAX(s.IncomeCount)
    ,OutcomeCount = MAX(s.OutcomeCount)
    ,EndCount     = MAX(s.EndCount)
  from (
    select
       [ProdID]       = s.ProdID
      ,[Pattern]      = s.Pattern
      ,[Number]       = s.Number
      ,[StartCount]   = s.StartCount
      ,[IncomeCount]  = CONVERT(int, NULL)
      ,[OutcomeCount] = CONVERT(int, NULL)
      ,[EndCount]     = CONVERT(int, NULL)
    from #ProdMovement s
    where s.StartCount > 0
      and not exists (
          select 1 from #ProdMovement
          where ProdID = s.ProdID 
            and Pattern = s.Pattern
            and Number + 1 = s.Number
            and StartCount = s.StartCount
            and IncomeCount = s.IncomeCount
            and OutcomeCount = s.OutcomeCount
            and EndCount = s.EndCount
          )
    union all
    select
       [ProdID]       = s.ProdID
      ,[Pattern]      = s.Pattern
      ,[Number]       = s.Number
      ,[StartCount]   = CONVERT(int, NULL)
      ,[IncomeCount]  = s.IncomeCount
      ,[OutcomeCount] = CONVERT(int, NULL)
      ,[EndCount]     = CONVERT(int, NULL)
    from #ProdMovement s
    where s.IncomeCount > 0
      and not exists (
          select 1 from #ProdMovement
          where ProdID = s.ProdID 
            and Pattern = s.Pattern
            and Number + 1 = s.Number
            and IncomeCount = s.IncomeCount
            and OutcomeCount = s.OutcomeCount
            and StartCount = s.StartCount
            and EndCount = s.EndCount
          )
    union all
    select
       [ProdID]       = s.ProdID
      ,[Pattern]      = s.Pattern
      ,[Number]       = s.Number
      ,[StartCount]   = CONVERT(int, NULL)
      ,[IncomeCount]  = CONVERT(int, NULL)
      ,[OutcomeCount] = s.OutcomeCount
      ,[EndCount]     = CONVERT(int, NULL)
    from #ProdMovement s
    where s.OutcomeCount > 0
      and not exists (
          select 1 from #ProdMovement
          where ProdID = s.ProdID 
            and Pattern = s.Pattern
            and Number + 1 = s.Number
            and OutcomeCount = s.OutcomeCount
            and StartCount = s.StartCount
            and IncomeCount = s.IncomeCount
            and EndCount = s.EndCount
          )
    union all
    select
       [ProdID]       = s.ProdID
      ,[Pattern]      = s.Pattern
      ,[Number]       = s.Number
      ,[StartCount]   = CONVERT(int, NULL)
      ,[IncomeCount]  = CONVERT(int, NULL)
      ,[OutcomeCount] = CONVERT(int, NULL)
      ,[EndCount]     = s.EndCount
    from #ProdMovement s
    where s.EndCount > 0
      and not exists (
          select 1 from #ProdMovement
          where ProdID = s.ProdID 
            and Pattern = s.Pattern
            and Number + 1 = s.Number
            and EndCount = s.EndCount
            and StartCount = s.StartCount
            and IncomeCount = s.IncomeCount
            and OutcomeCount = s.OutcomeCount
          )
       ) s
  group by s.ProdID, s.Pattern, s.Number
  --
  insert into #SortEnd (
     [ProdID]
    ,[Pattern]
    ,[Number]
    ,[StartCount]
    ,[IncomeCount]
    ,[OutcomeCount]
    ,[EndCount]
    )
  select
     [ProdID]       = s.ProdID
    ,[Pattern]      = s.Pattern
    ,[Number]       = s.Number
    ,[StartCount]   = MAX(s.StartCount)
    ,[IncomeCount]  = MAX(s.IncomeCount)
    ,[OutcomeCount] = MAX(s.OutcomeCount)
    ,[EndCount]     = MAX(s.EndCount)
  from (
    select 
       [ProdID]       = s.ProdID
      ,[Pattern]      = s.Pattern
      ,[Number]       = s.Number
      ,[StartCount]   = s.StartCount
      ,[IncomeCount]  = CONVERT(int, NULL)
      ,[OutcomeCount] = CONVERT(int, NULL)
      ,[EndCount]     = CONVERT(int, NULL)
    from #ProdMovement s
    where s.StartCount > 0
      and not exists (
          select 1 from #ProdMovement
          where ProdID = s.ProdID 
            and Pattern = s.Pattern
            and Number - 1 = s.Number
            and StartCount = s.StartCount
            and IncomeCount = s.IncomeCount
            and OutcomeCount = s.OutcomeCount
            and EndCount = s.EndCount
          )
    union all
    select
       [ProdID]       = s.ProdID
      ,[Pattern]      = s.Pattern
      ,[Number]       = s.Number
      ,[StartCount]   = CONVERT(int, NULL)
      ,[IncomeCount]  = s.IncomeCount
      ,[OutcomeCount] = CONVERT(int, NULL)
      ,[EndCount]     = CONVERT(int, NULL)
    from #ProdMovement s
    where s.IncomeCount > 0
      and not exists (
          select 1 from #ProdMovement
          where ProdID = s.ProdID 
            and Pattern = s.Pattern
            and Number - 1 = s.Number
            and IncomeCount = s.IncomeCount
            and StartCount = s.StartCount
            and OutcomeCount = s.OutcomeCount
            and EndCount = s.EndCount
          )
    union all
    select
       [ProdID]       = s.ProdID
      ,[Pattern]      = s.Pattern
      ,[Number]       = s.Number
      ,[StartCount]   = CONVERT(int, NULL)
      ,[IncomeCount]  = CONVERT(int, NULL)
      ,[OutcomeCount] = s.OutcomeCount
      ,[EndCount]     = CONVERT(int, NULL)
    from #ProdMovement s
    where s.OutcomeCount > 0
      and not exists (
          select 1 from #ProdMovement
          where ProdID = s.ProdID 
            and Pattern = s.Pattern
            and Number - 1 = s.Number
            and OutcomeCount = s.OutcomeCount
            and OutcomeCount = s.OutcomeCount
            and StartCount = s.StartCount
            and IncomeCount = s.IncomeCount
            and EndCount = s.EndCount
          )
    union all
    select
       [ProdID]       = s.ProdID
      ,[Pattern]      = s.Pattern
      ,[Number]       = s.Number
      ,[StartCount]   = CONVERT(int, NULL)
      ,[IncomeCount]  = CONVERT(int, NULL)
      ,[OutcomeCount] = CONVERT(int, NULL)
      ,[EndCount]     = s.EndCount
    from #ProdMovement s
    where s.EndCount > 0
      and not exists (
          select 1 from #ProdMovement
          where ProdID = s.ProdID 
            and Pattern = s.Pattern
            and Number - 1 = s.Number
            and EndCount = s.EndCount
            and StartCount = s.StartCount
            and IncomeCount = s.IncomeCount
            and OutcomeCount = s.OutcomeCount
          )
       ) s
  group by s.ProdID, s.Pattern, s.Number
  --
  SET NOCOUNT OFF
  -- OUT
  select
     [ProdID]       = SortBegin.ProdID
    ,[StartName]    = StartQry.Numbers
    ,[StartCount]   = StartQry.Qty
    ,[IncomeName]   = IncomeQry.Numbers
    ,[IncomeCount]  = IncomeQry.Qty
    ,[OutcomeName]  = OutcomeQry.Numbers
    ,[OutcomeCount] = OutcomeQry.Qty
    ,[EndName]      = EndQry.Numbers
    ,[EndCount]     = EndQry.Qty
  from #SortBegin SortBegin
    left outer join
       (select
           [ProdID]    = s.ProdID
          ,[Pattern]   = s.Pattern
          ,[NumberMin] = s.NumberMin
          ,[Numbers]   = CONVERT(varchar(255),
                         case
                           when s.NumberMin = s.NumberMax 
                             then dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin)
                           else dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin) + '-' + dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMax)
                          end)
          ,[Qty]       = CONVERT(int, (s.NumberMax - s.NumberMin + 1) * QtyBy1)
        from (select
                 [ProdID]    = s.ProdID
                ,[Pattern]   = s.Pattern
                ,[NumberMin] = s.Number
                ,[NumberMax] = MIN(sMax.Number)
                ,[QtyBy1]    = s.StartCount
              from #SortBegin s
                inner join #SortEnd sMax on sMax.ProdID = s.ProdID
                                        and sMax.Pattern = s.Pattern
                                        and sMax.Number >= s.Number
                                        and sMax.StartCount = s.StartCount
              group by s.ProdID
                      ,s.Pattern
                      ,s.Number
                      ,s.StartCount) s
          inner join #ProdMovement sMax on sMax.Pattern = s.Pattern and sMax.Number = s.NumberMax and sMax.ProdID = s.ProdID
    ) StartQry on StartQry.ProdID = SortBegin.ProdID and StartQry.Pattern = SortBegin.Pattern and StartQry.NumberMin = SortBegin.Number
    left outer join
       (select
           [ProdID]    = s.ProdID
          ,[Pattern]   = s.Pattern
          ,[NumberMin] = s.NumberMin
          ,[Numbers]   = CONVERT(varchar(255), case 
                           when s.NumberMin = s.NumberMax 
                             then dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin)
                           else dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin) + '-' + dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMax)
                         end)
          ,[Qty]       = CONVERT(int, (s.NumberMax - s.NumberMin + 1) * QtyBy1)
        from (select
                 [ProdID]    = s.ProdID
                ,[Pattern]   = s.Pattern
                ,[NumberMin] = s.Number
                ,[NumberMax] = MIN(sMax.Number)
                ,[QtyBy1]    = s.IncomeCount
              from #SortBegin s
                inner join #SortEnd sMax on sMax.ProdID = s.ProdID 
                                        and sMax.Pattern = s.Pattern
                                        and sMax.Number >= s.Number
                                        and sMax.IncomeCount = s.IncomeCount
              group by s.ProdID 
                      ,s.Pattern
                      ,s.Number
                      ,s.IncomeCount) s
          inner join #ProdMovement sMax on sMax.Pattern = s.Pattern and sMax.Number = s.NumberMax and sMax.ProdID = s.ProdID
    ) IncomeQry on IncomeQry.ProdID = SortBegin.ProdID and IncomeQry.Pattern = SortBegin.Pattern and IncomeQry.NumberMin = SortBegin.Number
    left outer join
       (select
           [ProdID]    = s.ProdID
          ,[Pattern]   = s.Pattern
          ,[NumberMin] = s.NumberMin
          ,[Numbers]   = CONVERT(varchar(255), case 
                           when s.NumberMin = s.NumberMax 
                             then dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin)
                           else dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin) + '-' + dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMax)
                         end)
          ,[Qty]       = CONVERT(int, (s.NumberMax - s.NumberMin + 1) * QtyBy1)
        from (select
                 [ProdID]    = s.ProdID
                ,[Number]    = s.Number
                ,[Pattern]   = s.Pattern
                ,[NumberMin] = s.Number
                ,[NumberMax] = MIN(sMax.Number)
                ,[QtyBy1]        = s.OutcomeCount
              from #SortBegin s
                inner join #SortEnd sMax on sMax.ProdID = s.ProdID 
                                        and sMax.Pattern = s.Pattern
                                        and sMax.Number >= s.Number
                                        and sMax.OutcomeCount = s.OutcomeCount
              group by s.ProdID 
                      ,s.Pattern
                      ,s.Number
                      ,s.OutcomeCount) s
          inner join #ProdMovement sMax on sMax.Pattern = s.Pattern and sMax.Number = s.NumberMax and sMax.ProdID = s.ProdID
    ) OutcomeQry on OutcomeQry.ProdID = SortBegin.ProdID and OutcomeQry.Pattern = SortBegin.Pattern and OutcomeQry.NumberMin = SortBegin.Number
    left outer join
       (select
           [ProdID]    = s.ProdID
          ,[Pattern]   = s.Pattern
          ,[NumberMin] = s.NumberMin
          ,[Numbers]   = CONVERT(varchar(255), case 
                           when s.NumberMin = s.NumberMax 
                             then dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin)
                           else dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin) + '-' + dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMax)
                         end)
          ,[Qty]       = CONVERT(int, (s.NumberMax - s.NumberMin + 1) * QtyBy1)
        from (select
                 [ProdID]    = s.ProdID
                ,[Pattern]   = s.Pattern
                ,[NumberMin] = s.Number
                ,[NumberMax] = MIN(sMax.Number)
                ,[QtyBy1]    = s.EndCount
              from #SortBegin s
                inner join #SortEnd sMax on sMax.ProdID = s.ProdID
                                        and sMax.Pattern = s.Pattern
                                        and sMax.Number >= s.Number
                                        and sMax.EndCount = s.EndCount
              group by s.ProdID
                      ,s.Pattern
                      ,s.Number
                      ,s.EndCount) s
          inner join #ProdMovement sMax on sMax.Pattern = s.Pattern and sMax.Number = s.NumberMax and sMax.ProdID = s.ProdID
  ) EndQry on EndQry.ProdID = SortBegin.ProdID and EndQry.Pattern = SortBegin.Pattern and EndQry.NumberMin = SortBegin.Number
  order by SortBegin.ProdID, SortBegin.Pattern, SortBegin.Number

  RETURN 0
END -- procedure
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_GetProductionComingReport]'
GO
/*--------------------------------------------------------------------------------
  Model  : tr
  Class  : Transport Report
  Author : Герасевич А.Ю., Осадчий А.П.
  Desc   : Выводим отчет по ПОСТУПЛЕНИЮ по типу продукции по МРЕВ за период
  Last   : Осадчий А.П. / 2007-06-06
  Result :
     [ProdID]       int         -- Спец. продукция
    ,[DocDate]      datetime    -- Дата
    ,[ParentDoc]    varchar(20) -- Номер накладной
    ,[Supplier]     varchar(50) -- Откуда пришло
    ,[Nomenclature] varchar(10) -- Номенклатура
    ,[Items]        varchar(31) -- Номер и серия спец. продукции
    ,[Quantity]     int         -- Количество
*/
CREATE PROCEDURE [dbo].[tr_GetProductionComingReport]
   @DateFrom  datetime    -- Начальная дата
  ,@DateTo    datetime    -- Конечная дата
  ,@OVSCode   varchar(10) -- ОВС
  ,@ProdType  int         -- Тип спец. продукции (4001 - Нова, 4002 - Була у використанні)
  ,@ProdClass int         -- Класс спец. продукции (6001 - Бланк, 6002 - Номерний знак)
  ,@ProdID    int         -- ID спец продукции
AS BEGIN
  SET NOCOUNT ON
  if @DateFrom is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата з') WITH SETERROR
    RETURN -1
  end
  if @DateTo is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата по') WITH SETERROR
    RETURN -1
  end
  set @DateTo = DATEADD(day, 1, CONVERT(datetime, CONVERT(varchar(10), @DateTo, 121), 121))
  if @DateTo < @DateFrom
  begin
    RAISERROR('"Дата по" повинна бути більшою ніж "Дата з"', 16, 10) WITH SETERROR
    RETURN -1
  end
  if @OVSCode is NULL
  begin
    RAISERROR(60002, 16, 10, 'МРЕВ') WITH SETERROR
    RETURN -1
  end
  if @ProdType is NULL
  begin
    RAISERROR(60002, 16, 10, 'Тип спец. продукції') WITH SETERROR
    RETURN -1
  end
  --
  select ProdID
  into #SeekProd
  from stProduction
  where (ProdID = @ProdID or @ProdID is NULL)
    and ((@ProdClass = 6001 and ProdClassID in (402, 404)) -- Документ
      or (@ProdClass = 6002 and ProdClassID in (401))      -- ДНЗ
      or @ProdClass is NULL)
  --
  CREATE UNIQUE INDEX IX_#SeekProd_Cluster ON #SeekProd (ProdID)
  --
  select StoreGUID
  into #SeekStores
  from stStores Stores
    inner join stStoreTypes StoreType on StoreType.StoreTypeID = Stores.StoreTypeID
  where Stores.OVSCode = @OVSCode
    and ((@ProdType = 4001 and StoreType.Options & 0x0010 <> 0)  -- Нова
      or (@ProdType = 4002 and StoreType.Options & 0x0020 <> 0)) -- Б/У
  --
  CREATE UNIQUE INDEX IX_#SeekStores_Cluster ON #SeekStores (StoreGUID)
  --
  CREATE TABLE #Remains (
     [ProdID]    int         NULL
    ,[DocDate]   datetime    NULL
    ,[ParentDoc] varchar(20) NULL
    ,[Supplier]  varchar(50) NULL
    ,[Pattern]   varchar(20) NULL
    ,[Number]    bigint      NULL
  )
  --
  CREATE TABLE #SortBegin (
     [ProdID]    int         NULL
    ,[DocDate]   datetime    NULL
    ,[ParentDoc] varchar(20) NULL
    ,[Supplier]  varchar(50) NULL
    ,[Pattern]   varchar(20) NULL
    ,[Number]    bigint      NULL
  )
  --
  CREATE TABLE #SortEnd (
     [ProdID]    int         NULL
    ,[DocDate]   datetime    NULL
    ,[ParentDoc] varchar(20) NULL
    ,[Supplier]  varchar(50) NULL
    ,[Pattern]   varchar(20) NULL
    ,[Number]    bigint      NULL
  )
  --
  insert into #Remains (
     [ProdID]
    ,[DocDate]
    ,[ParentDoc]
    ,[Supplier]
    ,[Pattern]
    ,[Number]
  )
  select
     [ProdID]    = Items.ProdID
    ,[DocDate]   = CONVERT(datetime, CONVERT(varchar(10), Doc.DocDate, 121), 121)
    ,[ParentDoc] = CONVERT(varchar(20), ISNULL(Doc.ParentDoc, ''))
    ,[Supplier]  = CONVERT(varchar(50), ISNULL(OVS.OvsName, '') + ' ' + ISNULL(StoreFrom.StoreName, ''))
    ,[Pattern]   = dbo.ic_GetPatternFromString(Items.ItemNumber)
    ,[Number]    = CONVERT(bigint, dbo.ic_GetIntFromString(Items.ItemNumber))
  from stStoreDocs Doc (nolock)
    inner join stStoreDocItems Items (nolock) on Items.DocGUID = Doc.DocGUID
    left outer join stStores StoreFrom on StoreFrom.StoreGUID = Doc.StoreFromGUID
    left outer join stStoreTypes TypeFrom on TypeFrom.StoreTypeID = StoreFrom.StoreTypeID
    left outer join trOVS OVS on OVS.OVSCode = StoreFrom.OVSCode
  where Doc.StoreToGUID in (select StoreGUID from #SeekStores)
    and Items.ProdID in (select ProdID from #SeekProd)
    and (StoreFrom.OVSCode <> @OVSCode
      or StoreFrom.OVSCode is NULL
      or (@ProdType = 4001 and TypeFrom.Options & 0x0010 = 0)  -- Нова
      or (@ProdType = 4002 and TypeFrom.Options & 0x0020 = 0)) -- Б/У
    and Doc.DocDate >= @DateFrom
    and Doc.DocDate < @DateTo
    and Items.DocDate >= @DateFrom
    and Items.DocDate < @DateTo
  --
  insert into #SortBegin (
     ProdID
    ,DocDate
    ,ParentDoc
    ,Supplier
    ,Pattern
    ,Number
  )
  select
     ProdID
    ,DocDate
    ,ParentDoc
    ,Supplier
    ,Pattern
    ,Number
  from #Remains s
  where not exists (
        select 1 from #Remains
        where ProdID = s.ProdID 
          and DocDate = s.DocDate
          and ParentDoc = s.ParentDoc
          and Supplier = s.Supplier
          and Pattern = s.Pattern
          and Number + 1 = s.Number)
  --
  insert into #SortEnd (
     ProdID
    ,DocDate
    ,ParentDoc
    ,Supplier
    ,Pattern
    ,Number
  )
  select
     ProdID
    ,DocDate
    ,ParentDoc
    ,Supplier
    ,Pattern
    ,Number
  from #Remains s
  where not exists (
        select 1 from #Remains
        where ProdID = s.ProdID 
          and DocDate = s.DocDate
          and ParentDoc = s.ParentDoc
          and Supplier = s.Supplier
          and Pattern = s.Pattern
          and Number - 1 = s.Number)
  --
  SET NOCOUNT OFF
  -- OUT
  select
     [ProdID]       = s.ProdID
    ,[DocDate]      = s.DocDate
    ,[ParentDoc]    = s.ParentDoc
    ,[Supplier]     = s.Supplier
    ,[Nomenclature] = p.BuhNomencl
    ,[Items]        = CONVERT(varchar(31),
                        case
                          when s.NumberMin = s.NumberMax 
                            then dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin)
                          else dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin) + '-' + dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMax)
                        end)
    ,[Quantity]     = CONVERT(int, s.NumberMax - s.NumberMin + 1)
  from (select
           [ProdID]    = s.ProdID
          ,[DocDate]   = s.DocDate
          ,[ParentDoc] = s.ParentDoc
          ,[Supplier]  = s.Supplier
          ,[Pattern]   = s.Pattern
          ,[NumberMin] = s.Number
          ,[NumberMax] = MIN(sMax.Number)
        from #SortBegin s
          inner join #SortEnd sMax on sMax.ProdID = s.ProdID
                                  and sMax.DocDate = s.DocDate
                                  and sMax.ParentDoc = s.ParentDoc
                                  and sMax.Supplier = s.Supplier
                                  and sMax.Pattern = s.Pattern
                                  and sMax.Number >= s.Number
        group by s.ProdID
                ,s.DocDate
                ,s.ParentDoc
                ,s.Supplier
                ,s.Pattern
                ,s.Number) s
    left outer join stProduction p on p.ProdID = s.ProdID
  order by DocDate, Items

  RETURN 0
END -- procedure
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_GetProductionTransmitReport]'
GO
/*--------------------------------------------------------------------------------
  Model  : tr
  Class  : Transport Report
  Author : Герасевич А.Ю., Осадчий А.П.
  Desc   : Выводим отчет по ПЕРЕДАЧЕ В ДРУГИЕ ПОДРАЗДЕЛЕНИЯ по типу продукции по МРЕВ за период
  Last   : Осадчий А.П. / 2007-06-06
  Result :
  Cursor :
     [ProdID]       int         -- Спец. продукция
    ,[DocDate]      datetime    -- Дата
    ,[ParentDoc]    varchar(20) -- Номер накладной
    ,[Recipient]    varchar(50) -- Куда передали
    ,[Nomenclature] varchar(10) -- Номенклатура
    ,[Items]        varchar(31) -- Номер и серия спец. продукции
    ,[Quantity]     int         -- Количество
*/
CREATE PROCEDURE [dbo].[tr_GetProductionTransmitReport]
   @DateFrom  datetime    -- Начальная дата
  ,@DateTo    datetime    -- Конечная дата
  ,@OVSCode   varchar(10) -- ОВС
  ,@ProdType  int         -- Тип спец. продукции (4001 - Нова, 4002 - Була у використанні)
  ,@ProdClass int         -- Класс спец. продукции (6001 - Бланк, 6002 - Номерний знак)
  ,@ProdID    int         -- ID спец продукции
AS BEGIN
  if @DateFrom is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата з') WITH SETERROR
    RETURN -1
  end
  if @DateTo is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата по') WITH SETERROR
    RETURN -1
  end
  set @DateTo = DATEADD(day, 1, CONVERT(datetime, CONVERT(varchar(10), @DateTo, 121), 121))
  if @DateTo < @DateFrom
  begin
    RAISERROR('"Дата по" повинна бути більшою ніж "Дата з"', 16, 10) WITH SETERROR
    RETURN -1
  end
  if @OVSCode is NULL
  begin
    RAISERROR(60002, 16, 10, 'МРЕВ') WITH SETERROR
    RETURN -1
  end
  if @ProdType is NULL
  begin
    RAISERROR(60002, 16, 10, 'Тип спец. продукції') WITH SETERROR
    RETURN -1
  end
  --
  select ProdID
  into #SeekProd
  from stProduction
  where (ProdID = @ProdID or @ProdID is NULL)
    and ((@ProdClass = 6001 and ProdClassID in (402, 404)) -- Документ
      or (@ProdClass = 6002 and ProdClassID in (401))      -- ДНЗ
      or @ProdClass is NULL)
  --
  CREATE UNIQUE INDEX IX_#SeekProd_Cluster ON #SeekProd (ProdID)
  --
  select StoreGUID
  into #SeekStores
  from stStores Stores
    inner join stStoreTypes StoreType on StoreType.StoreTypeID = Stores.StoreTypeID
  where Stores.OVSCode = @OVSCode
    and ((@ProdType = 4001 and StoreType.Options & 0x0010 <> 0)  -- Нова
      or (@ProdType = 4002 and StoreType.Options & 0x0020 <> 0)) -- Б/У
  --
  CREATE UNIQUE INDEX IX_#SeekStores_Cluster ON #SeekStores (StoreGUID)
  --
  CREATE TABLE #Remains (
     [ProdID]    int         NULL
    ,[DocDate]   datetime    NULL
    ,[ParentDoc] varchar(20) NULL
    ,[Recipient] varchar(50) NULL
    ,[Pattern]   varchar(20) NULL
    ,[Number]    bigint      NULL
    )
  --
  CREATE TABLE #SortBegin (
     [ProdID]    int         NULL
    ,[DocDate]   datetime    NULL
    ,[ParentDoc] varchar(20) NULL
    ,[Recipient] varchar(50) NULL
    ,[Pattern]   varchar(20) NULL
    ,[Number]    bigint      NULL
    )
  --
  CREATE TABLE #SortEnd (
     [ProdID]    int         NULL
    ,[DocDate]   datetime    NULL
    ,[ParentDoc] varchar(20) NULL
    ,[Recipient] varchar(50) NULL
    ,[Pattern]   varchar(20) NULL
    ,[Number]    bigint      NULL
    )
  --
  insert into #Remains (
     ProdID
    ,DocDate
    ,ParentDoc
    ,Recipient
    ,Pattern
    ,Number
    )
  select
     ProdID    = Items.ProdID
    ,DocDate   = CONVERT(datetime, CONVERT(varchar(10), Doc.DocDate, 121), 121)
    ,ParentDoc = CONVERT(varchar(20), ISNULL(Doc.ParentDoc, ''))
    ,Recipient = CONVERT(varchar(50), ISNULL(OVS.OvsName, '') + ' ' + ISNULL(StoreTo.StoreName, ''))
    ,Pattern   = dbo.ic_GetPatternFromString(Items.ItemNumber)
    ,Number    = CONVERT(bigint, dbo.ic_GetIntFromString(Items.ItemNumber))
  from stStores StoreFrom
    inner join stStoreTypes TypeFrom on TypeFrom.StoreTypeID = StoreFrom.StoreTypeID
    inner join stStoreDocs Doc (nolock) on Doc.StoreFromGUID = StoreFrom.StoreGUID
    inner join stStoreDocItems Items (nolock) on Items.DocGUID = Doc.DocGUID
    inner join stStores StoreTo on StoreTo.StoreGUID = Doc.StoreToGUID
    inner join stStoreTypes StoreTypeTo on StoreTypeTo.StoreTypeID = StoreTo.StoreTypeID
    left outer join trOVS OVS on OVS.OVSCode = StoreTo.OVSCode
  where Doc.StoreFromGUID in (select StoreGUID from #SeekStores)
    and Items.ProdID in (select ProdID from #SeekProd)
    and (StoreTo.OVSCode <> @OVSCode or StoreFrom.OVSCode is NULL -- Склад или ОВС
      or (@ProdType = 4001 and StoreTypeTo.Options & 0x0010 = 0)  -- Не Нова
      or (@ProdType = 4002 and StoreTypeTo.Options & 0x0020 = 0))  -- Не Б/У
    and StoreTo.StoreTypeID not in (106, 109, 110) -- not in Власники, Знищення, Брак
    and Doc.DocDate >= @DateFrom
    and Doc.DocDate < @DateTo
    and Items.DocDate >= @DateFrom
    and Items.DocDate < @DateTo
  --
  insert into #SortBegin (
     ProdID
    ,DocDate
    ,ParentDoc
    ,Recipient
    ,Pattern
    ,Number
  )
  select
     ProdID
    ,DocDate
    ,ParentDoc
    ,Recipient
    ,Pattern
    ,Number
  from #Remains s
  where not exists (
      select 1 from #Remains
      where ProdID = s.ProdID 
        and DocDate = s.DocDate
        and ParentDoc = s.ParentDoc
        and Recipient = s.Recipient
        and Pattern = s.Pattern
        and Number + 1 = s.Number)
  --
  insert into #SortEnd (
     ProdID
    ,DocDate
    ,ParentDoc
    ,Recipient
    ,Pattern
    ,Number
  )
  select
     ProdID
    ,DocDate
    ,ParentDoc
    ,Recipient
    ,Pattern
    ,Number
  from #Remains s
  where not exists (
      select 1 from #Remains
      where ProdID = s.ProdID 
        and DocDate = s.DocDate
        and ParentDoc = s.ParentDoc
        and Recipient = s.Recipient
        and Pattern = s.Pattern
        and Number - 1 = s.Number)
  --
  SET NOCOUNT OFF
  -- OUT
  select
     [ProdID]       = s.ProdID
    ,[DocDate]      = s.DocDate
    ,[ParentDoc]    = s.ParentDoc
    ,[Recipient]    = s.Recipient
    ,[Nomenclature] = p.BuhNomencl
    ,[Items]        = CONVERT(varchar(31),
                        case
                          when s.NumberMin = s.NumberMax 
                            then dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin)
                          else dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin) + '-' + dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMax)
                        end)
    ,[Quantity]     = CONVERT(int, s.NumberMax - s.NumberMin + 1)
  from (select
           ProdID    = s.ProdID
          ,DocDate   = s.DocDate
          ,ParentDoc = s.ParentDoc
          ,Recipient = s.Recipient
          ,Pattern   = s.Pattern
          ,NumberMin = s.Number
          ,NumberMax = MIN(sMax.Number)
        from #SortBegin s
          inner join #SortEnd sMax on sMax.ProdID = s.ProdID
                                  and sMax.DocDate = s.DocDate
                                  and sMax.ParentDoc = s.ParentDoc
                                  and sMax.Recipient = s.Recipient
                                  and sMax.Pattern = s.Pattern
                                  and sMax.Number >= s.Number
        group by s.ProdID
                ,s.DocDate
                ,s.ParentDoc
                ,s.Recipient
                ,s.Pattern
                ,s.Number) s
    left outer join stProduction p on p.ProdID = s.ProdID
  order by DocDate, Items

  RETURN 0
END -- procedure
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_GetProductionSellingReport]'
GO
/*--------------------------------------------------------------------------------
  Model  : tr
  Class  : Transport Report
  Author : Герасевич А.Ю., Осадчий А.П.
  Desc   : Выводим отчет по РЕАЛИЗАЦИИ по типу продукции по МРЕВ за период
  Last   : Осадчий А.П. / 2007-06-06
  Result :
  Cursor :  
     [ProdID]       int         -- ID cпец. продукции
    ,[DocDate]      datetime    -- Дата
    ,[Nomenclature] varchar(10) -- Номенклатура
    ,[Items]        varchar(31) -- Серия и номер спец. продукции
    ,[Quantity]     int         -- Кол-во
*/
CREATE PROCEDURE [dbo].[tr_GetProductionSellingReport]
   @DateFrom  datetime    -- Начальная дата
  ,@DateTo    datetime    -- Конечная дата
  ,@OVSCode   varchar(10) -- ОВС
  ,@ProdType  int         -- Тип спец. продукции (4001 - Нова, 4002 - Була у використанні)
  ,@ProdClass int         -- Класс спец. продукции (6001 - Бланк, 6002 - Номерний знак)
  ,@ProdID    int         -- ID спец продукции
AS BEGIN

  SET NOCOUNT ON

  if @DateFrom is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата з') WITH SETERROR
    RETURN -1
  end
  if @DateTo is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата по') WITH SETERROR
    RETURN -1
  end
  set @DateTo = DATEADD(day, 1, CONVERT(datetime, CONVERT(varchar(10), @DateTo, 121), 121))
  if @DateTo < @DateFrom
  begin
    RAISERROR('"Дата по" повинна бути більшою ніж "Дата з"', 16, 10) WITH SETERROR
    RETURN -1
  end
  if @OVSCode is NULL
  begin
    RAISERROR(60002, 16, 10, 'МРЕВ') WITH SETERROR
    RETURN -1
  end
  if @ProdType is NULL
  begin
    RAISERROR(60002, 16, 10, 'Тип спец. продукції') WITH SETERROR
    RETURN -1
  end
  --
  select ProdID
  into #SeekProd
  from stProduction
  where (ProdID = @ProdID or @ProdID is NULL)
    and ((@ProdClass = 6001 and ProdClassID in (402, 404)) -- Документ
      or (@ProdClass = 6002 and ProdClassID in (401))      -- ДНЗ
      or @ProdClass is NULL)
  --
  CREATE UNIQUE INDEX IX_#SeekProd_Cluster ON #SeekProd (ProdID)
  --
  select StoreGUID
  into #SeekStores
  from stStores Stores
    inner join stStoreTypes StoreType on StoreType.StoreTypeID = Stores.StoreTypeID
  where Stores.OVSCode = @OVSCode
    and ((@ProdType = 4001 and StoreType.Options & 0x0010 <> 0)  -- Нова
      or (@ProdType = 4002 and StoreType.Options & 0x0020 <> 0)) -- Б/У
  --
  CREATE UNIQUE INDEX IX_#SeekStores_Cluster ON #SeekStores (StoreGUID)
  --
  CREATE TABLE #Remains (
     [ProdID]  int         NULL
    ,[DocDate] datetime    NULL
    ,[Pattern] varchar(20) NULL
    ,[Number]  bigint      NULL
  )
  --
  CREATE TABLE #SortBegin (
     [ProdID]  int         NULL
    ,[DocDate] datetime    NULL
    ,[Pattern] varchar(20) NULL
    ,[Number]  bigint      NULL
  )
  --
  CREATE TABLE #SortEnd (
     [ProdID]  int         NULL
    ,[DocDate] datetime    NULL
    ,[Pattern] varchar(20) NULL
    ,[Number]  bigint      NULL
  )
  --
  insert into #Remains (
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  )
  select
     ProdID  = Items.ProdID
    ,DocDate = CONVERT(datetime, CONVERT(varchar(10), Doc.DocDate, 121), 121)
    ,Pattern = dbo.ic_GetPatternFromString(Items.ItemNumber)
    ,Number  = CONVERT(bigint, dbo.ic_GetIntFromString(Items.ItemNumber))
  from stStoreDocs Doc (nolock)
    inner join stStoreDocItems Items (nolock) on Items.DocGUID = Doc.DocGUID
    inner join stStores StoreTo on StoreTo.StoreGUID = Doc.StoreToGUID
  where Doc.StoreFromGUID in (select StoreGUID from #SeekStores)
    and Items.ProdID in (select ProdID from #SeekProd)
    and StoreTo.StoreTypeID = 106 -- Власники
    and Doc.DocDate >= @DateFrom
    and Doc.DocDate < @DateTo
    and Items.DocDate >= @DateFrom
    and Items.DocDate < @DateTo
  --
  insert into #SortBegin (
     ProdID
    ,DocDate
    ,Pattern
    ,Number
    )
  select
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  from #Remains s
  where not exists (
    select 1 from #Remains
    where ProdID = s.ProdID 
      and DocDate = s.DocDate
      and Pattern = s.Pattern
      and Number + 1 = s.Number)
  --
  insert into #SortEnd (
     ProdID
    ,DocDate
    ,Pattern
    ,Number
    )
  select
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  from #Remains s
  where not exists (
    select 1 from #Remains
    where ProdID = s.ProdID 
      and DocDate = s.DocDate
      and Pattern = s.Pattern
      and Number - 1 = s.Number)
  --
  SET NOCOUNT OFF
  -- OUT
  select
     ProdID       = s.ProdID
    ,DocDate      = s.DocDate
    ,Nomenclature = p.BuhNomencl
    ,Items        = CONVERT(varchar(31),
                        case
                          when s.NumberMin = s.NumberMax 
                            then dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin)
                          else dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin) + '-' + dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMax)
                        end)
    ,Quantity     = CONVERT(int, s.NumberMax - s.NumberMin + 1)
  from (select
           ProdID    = s.ProdID
          ,DocDate   = s.DocDate
          ,Pattern   = s.Pattern
          ,NumberMin = s.Number
          ,NumberMax = MIN(sMax.Number)
        from #SortBegin s
          inner join #SortEnd sMax on sMax.ProdID = s.ProdID
                                  and sMax.DocDate = s.DocDate
                                  and sMax.Pattern = s.Pattern
                                  and sMax.Number >= s.Number
        group by s.ProdID
                ,s.DocDate
                ,s.Pattern
                ,s.Number) s
    left outer join stProduction p on p.ProdID = s.ProdID
  order by DocDate, Items

  RETURN 0
END -- procedure
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_GetProductionDefectReport]'
GO
/*--------------------------------------------------------------------------------
  Model  : tr
  Class  : Transport Report
  Author : Герасевич А.Ю., Осадчий А.П.
  Desc   : Выводим отчет по ОТПРАВКЕ НА БРАК по типу продукции по МРЕВ за период
  Last   : Осадчий А.П. / 2007-06-06
  Result :
  Cursor :
     [ProdID]       int         -- ID cпец. продукции
    ,[DocDate]      datetime    -- Дата
    ,[Nomenclature] varchar(10) -- Номенклатура
    ,[Items]        varchar(31) -- Серия и номер спец. продукции
    ,[Quantity]     int         -- Кол-во
*/
CREATE PROCEDURE [dbo].[tr_GetProductionDefectReport]
   @DateFrom  datetime    -- Начальная дата
  ,@DateTo    datetime    -- Конечная дата
  ,@OVSCode   varchar(10) -- ОВС
  ,@ProdType  int         -- Тип спец. продукции (4001 - Нова, 4002 - Була у використанні)
  ,@ProdClass int         -- Класс спец. продукции (6001 - Бланк, 6002 - Номерний знак)
  ,@ProdID    int         -- ID спец продукции
AS BEGIN
  SET NOCOUNT ON
  if @DateFrom is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата з') WITH SETERROR
    RETURN -1
  end
  if @DateTo is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата по') WITH SETERROR
    RETURN -1
  end
  set @DateTo = DATEADD(day, 1, CONVERT(datetime, CONVERT(varchar(10), @DateTo, 121), 121))
  if @DateTo < @DateFrom
  begin
    RAISERROR('"Дата по" повинна бути більшою ніж "Дата з"', 16, 10) WITH SETERROR
    RETURN -1
  end
  if @OVSCode is NULL
  begin
    RAISERROR(60002, 16, 10, 'МРЕВ') WITH SETERROR
    RETURN -1
  end
  if @ProdType is NULL
  begin
    RAISERROR(60002, 16, 10, 'Тип спец. продукції') WITH SETERROR
    RETURN -1
  end
  --
  select ProdID
  into #SeekProd
  from stProduction
  where (ProdID = @ProdID or @ProdID is NULL)
    and ((@ProdClass = 6001 and ProdClassID in (402, 404)) -- Документ
      or (@ProdClass = 6002 and ProdClassID in (401))      -- ДНЗ
      or @ProdClass is NULL)
  --
  CREATE UNIQUE INDEX IX_#SeekProd_Cluster ON #SeekProd (ProdID)
  --
  select StoreGUID
  into #SeekStores
  from stStores Stores
    inner join stStoreTypes StoreType on StoreType.StoreTypeID = Stores.StoreTypeID
  where Stores.OVSCode = @OVSCode
    and ((@ProdType = 4001 and StoreType.Options & 0x0010 <> 0)  -- Нова
      or (@ProdType = 4002 and StoreType.Options & 0x0020 <> 0)) -- Б/У
  --
  CREATE UNIQUE INDEX IX_#SeekStores_Cluster ON #SeekStores (StoreGUID)
  --
  CREATE TABLE #Remains (
     [ProdID]   int          NULL
    ,[DocDate]  datetime     NULL
    ,[Pattern]  varchar(20)  NULL
    ,[Number]   bigint       NULL
  )
  --
  CREATE TABLE #SortBegin (
     [ProdID]   int          NULL
    ,[DocDate]  datetime     NULL
    ,[Pattern]  varchar(20)  NULL
    ,[Number]   bigint       NULL
  )
  --
  CREATE TABLE #SortEnd (
     [ProdID]   int          NULL
    ,[DocDate]  datetime     NULL
    ,[Pattern]  varchar(20)  NULL
    ,[Number]   bigint       NULL
  )
  --
  insert into #Remains (
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  )
  select
     ProdID  = Items.ProdID
    ,DocDate = CONVERT(datetime, CONVERT(varchar(10), Doc.DocDate, 121), 121)
    ,Pattern = dbo.ic_GetPatternFromString(Items.ItemNumber)
    ,Number  = CONVERT(bigint, dbo.ic_GetIntFromString(Items.ItemNumber))
  from stStores StoreFrom
    inner join stStoreTypes TypeFrom on TypeFrom.StoreTypeID = StoreFrom.StoreTypeID
    inner join stStoreDocs Doc (nolock) on Doc.StoreFromGUID = StoreFrom.StoreGUID
    inner join stStoreDocItems Items (nolock) on Items.DocGUID = Doc.DocGUID
    inner join stStores StoreTo on StoreTo.StoreGUID = Doc.StoreToGUID
    left outer join trOVS OVS on OVS.OVSCode = StoreFrom.OVSCode
  where Doc.StoreFromGUID in (select StoreGUID from #SeekStores)
    and Items.ProdID in (select ProdID from #SeekProd)
    and StoreTo.StoreTypeID = 110 -- Брак
    and Doc.DocDate >= @DateFrom
    and Doc.DocDate < @DateTo
    and Items.DocDate >= @DateFrom
    and Items.DocDate < @DateTo
  --
  insert into #SortBegin (
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  )
  select
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  from #Remains s
  where not exists (
        select 1 from #Remains
        where ProdID = s.ProdID 
          and DocDate = s.DocDate
          and Pattern = s.Pattern
          and Number + 1 = s.Number)
  --
  insert into #SortEnd (
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  )
  select
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  from #Remains s
  where not exists (
        select 1 from #Remains
        where ProdID = s.ProdID 
          and DocDate = s.DocDate
          and Pattern = s.Pattern
          and Number - 1 = s.Number)
  --
  SET NOCOUNT OFF
  -- OUT
  select
     [ProdID]       = s.ProdID
    ,[DocDate]      = s.DocDate
    ,[Nomenclature] = p.BuhNomencl
    ,[Items]        = CONVERT(varchar(31),
                        case
                          when s.NumberMin = s.NumberMax 
                            then dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin)
                          else dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin) + '-' + dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMax)
                        end)
    ,[Quantity]     = CONVERT(int, s.NumberMax - s.NumberMin + 1)
  from (select
           [ProdID]    = s.ProdID
          ,[DocDate]   = s.DocDate
          ,[Pattern]   = s.Pattern
          ,[NumberMin] = s.Number
          ,[NumberMax] = MIN(sMax.Number)
        from #SortBegin s
          inner join #SortEnd sMax on sMax.ProdID = s.ProdID
                                  and sMax.DocDate = s.DocDate
                                  and sMax.Pattern = s.Pattern
                                  and sMax.Number >= s.Number
        group by s.ProdID
                ,s.DocDate
                ,s.Pattern
                ,s.Number) s
    left outer join stProduction p on p.ProdID = s.ProdID
  order by DocDate, Items

  RETURN 0
END -- procedure
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_GetProductionDestructionReport]'
GO
/*--------------------------------------------------------------------------------
  Model  : tr
  Class  : Transport Report
  Author : Герасевич А.Ю., Осадчий А.П.
  Desc   : Выводим отчет по ЗНИЩЕННЮ по типу продукции по МРЕВ за период
  Last   : Осадчий А.П. / 2007-06-06
  Result :
  Cursor :
     [ProdID]       int         -- ID cпец. продукции
    ,[DocDate]      datetime    -- Дата
    ,[Nomenclature] varchar(10) -- Номенклатура
    ,[Items]        varchar(31) -- Серия и номер спец. продукции
    ,[Quantity]     int         -- Кол-во
*/
CREATE PROCEDURE [dbo].[tr_GetProductionDestructionReport]
   @DateFrom  datetime    -- Начальная дата
  ,@DateTo    datetime    -- Конечная дата
  ,@OVSCode   varchar(10) -- ОВС
  ,@ProdType  int         -- Тип спец. продукции (4001 - Нова, 4002 - Була у використанні)
  ,@ProdClass int         -- Класс спец. продукции (6001 - Бланк, 6002 - Номерний знак)
  ,@ProdID    int         -- ID спец продукции
AS BEGIN
  SET NOCOUNT ON
  if @DateFrom is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата з') WITH SETERROR
    RETURN -1
  end
  if @DateTo is NULL
  begin
    RAISERROR(60002, 16, 10, 'Дата по') WITH SETERROR
    RETURN -1
  end
  set @DateTo = DATEADD(day, 1, CONVERT(datetime, CONVERT(varchar(10), @DateTo, 121), 121))
  if @DateTo < @DateFrom
  begin
    RAISERROR('"Дата по" повинна бути більшою ніж "Дата з"', 16, 10) WITH SETERROR
    RETURN -1
  end
  if @OVSCode is NULL
  begin
    RAISERROR(60002, 16, 10, 'МРЕВ') WITH SETERROR
    RETURN -1
  end
  if @ProdType is NULL
  begin
    RAISERROR(60002, 16, 10, 'Тип спец. продукції') WITH SETERROR
    RETURN -1
  end
  --
  select ProdID
  into #SeekProd
  from stProduction
  where (ProdID = @ProdID or @ProdID is NULL)
    and ((@ProdClass = 6001 and ProdClassID in (402, 404)) -- Документ
      or (@ProdClass = 6002 and ProdClassID in (401))      -- ДНЗ
      or @ProdClass is NULL)
  --
  CREATE UNIQUE INDEX IX_#SeekProd_Cluster ON #SeekProd (ProdID)
  --
  select StoreGUID
  into #SeekStores
  from stStores Stores
    inner join stStoreTypes StoreType on StoreType.StoreTypeID = Stores.StoreTypeID
  where Stores.OVSCode = @OVSCode
    and ((@ProdType = 4001 and StoreType.Options & 0x0010 <> 0)  -- Нова
      or (@ProdType = 4002 and StoreType.Options & 0x0020 <> 0)) -- Б/У
  --
  CREATE UNIQUE INDEX IX_#SeekStores_Cluster ON #SeekStores (StoreGUID)
  --
  CREATE TABLE #Remains (
     [ProdID]   int          NULL
    ,[DocDate]  datetime     NULL
    ,[Pattern]  varchar(20)  NULL
    ,[Number]   bigint       NULL
  )
  --
  CREATE TABLE #SortBegin (
     [ProdID]   int          NULL
    ,[DocDate]  datetime     NULL
    ,[Pattern]  varchar(20)  NULL
    ,[Number]   bigint       NULL
  )
  --
  CREATE TABLE #SortEnd (
     [ProdID]   int          NULL
    ,[DocDate]  datetime     NULL
    ,[Pattern]  varchar(20)  NULL
    ,[Number]   bigint       NULL
  )
  --
  insert into #Remains (
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  )
  select
     ProdID   = Items.ProdID
    ,DocDate  = CONVERT(datetime, CONVERT(varchar(10), Doc.DocDate, 121), 121)
    ,Pattern  = dbo.ic_GetPatternFromString(Items.ItemNumber)
    ,Number   = CONVERT(bigint, dbo.ic_GetIntFromString(Items.ItemNumber))
  from stStores StoreFrom
    inner join stStoreTypes TypeFrom on TypeFrom.StoreTypeID = StoreFrom.StoreTypeID
    inner join stStoreDocs Doc (nolock) on Doc.StoreFromGUID = StoreFrom.StoreGUID
    inner join stStoreDocItems Items (nolock) on Items.DocGUID = Doc.DocGUID
    inner join stStores StoreTo on StoreTo.StoreGUID = Doc.StoreToGUID
    left outer join trOVS OVS on OVS.OVSCode = StoreFrom.OVSCode
  where StoreFrom.OVSCode = @OVSCode
    and ((@ProdType = 4001 and TypeFrom.Options & 0x0010 <> 0)  -- Нова
      or (@ProdType = 4002 and TypeFrom.Options & 0x0020 <> 0)) -- Б/У
    and StoreTo.StoreTypeID = 109 -- Знищення 
    and Doc.DocDate >= @DateFrom
    and Doc.DocDate < @DateTo
    and (Items.ProdID = @ProdID or @ProdID is NULL)
  --
  insert into #SortBegin (
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  )
  select
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  from #Remains s
  where not exists (
        select 1 from #Remains
        where ProdID = s.ProdID 
          and DocDate = s.DocDate
          and Pattern = s.Pattern
          and Number + 1 = s.Number)
  --
  insert into #SortEnd (
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  )
  select
     ProdID
    ,DocDate
    ,Pattern
    ,Number
  from #Remains s
  where not exists (
        select 1 from #Remains
        where ProdID = s.ProdID 
          and DocDate = s.DocDate
          and Pattern = s.Pattern
          and Number - 1 = s.Number)
  --
  SET NOCOUNT OFF
  -- OUT
  select
     [ProdID]       = s.ProdID
    ,[DocDate]      = s.DocDate
    ,[Nomenclature] = p.BuhNomencl
    ,[Items]        = CONVERT(varchar(31),
                        case
                          when s.NumberMin = s.NumberMax 
                            then dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin)
                          else dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMin) + '-' + dbo.ic_GetPatternVSNumber(s.Pattern, s.NumberMax)
                        end)
    ,[Quantity]     = CONVERT(int, s.NumberMax - s.NumberMin + 1)
  from (select
           [ProdID]    = s.ProdID
          ,[DocDate]   = s.DocDate
          ,[Pattern]   = s.Pattern
          ,[NumberMin] = s.Number
          ,[NumberMax] = MIN(sMax.Number)
        from #SortBegin s
          inner join #SortEnd sMax on sMax.ProdID = s.ProdID
                                  and sMax.DocDate = s.DocDate
                                  and sMax.Pattern = s.Pattern
                                  and sMax.Number >= s.Number
        group by s.ProdID
                ,s.DocDate
                ,s.Pattern
                ,s.Number) s
    left outer join stProduction p on p.ProdID = s.ProdID
  order by DocDate, Items

  RETURN 0
END -- procedure
GO

GRANT EXEC ON [dbo].[tr_GetProductionByPeriodReport] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_GetProductionByPeriodReportGroup] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_GetProductionComingReport] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_GetProductionTransmitReport] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_GetProductionSellingReport] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_GetProductionDefectReport] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_GetProductionDestructionReport] TO [gn_DBO]
GO
