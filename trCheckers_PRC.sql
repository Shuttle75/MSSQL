if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByUgon]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByUgon]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByDNZ]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByDNZ]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByWantedDocs]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByWantedDocs]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByWantedCar]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByWantedCar]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByArrestedCar]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByArrestedCar]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByControledCar]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByControledCar]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByOrderCertificate]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByOrderCertificate]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByAssignmentDoc]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByAssignmentDoc]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByTransitDNZ]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByTransitDNZ]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByArmor]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByArmor]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByBreach]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByBreach]
GO
if exists (select 1 from sysobjects where [id] = OBJECT_ID(N'[dbo].[tr_CheckByQuery]') 
  and OBJECTPROPERTY([id], N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[tr_CheckByQuery]
GO

SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS ON 
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByUgon]'
GO
 /*-----------------------------------------------------------------------------  
  Model  : tr   
  Class  : transport   
  Author : Осадчий А.П., Миронов Р.А.  
  Desc   : Процедура выполнения проверок по базам угона  
  Note   : Нужно ограничить количество выдаваемых строк, чтобы не выйти за пределы varchar(8000)  
  Result : 0 - OK , -1 - Error   
  Last   : Миронов Р.А. / 2006-05-05
*/  
CREATE PROCEDURE [dbo].[tr_CheckByUgon]  
   @Mark        varchar(20)       -- Марка
  ,@EngineNo    varchar(20)       -- номер двигателя  
  ,@BodyNo      varchar(20)       -- номер кузова  
  ,@ChassisNo   varchar(20)       -- номер шасси  
  ,@ResultHTML  varchar(8000) out -- отчет о проверке  
  ,@CheckResult int           out -- код результата проверки  
AS BEGIN  

  declare  
     @CheckMark       varchar(20)
    ,@CheckEngineNo   varchar(20)
    ,@CheckChassisNo  varchar(20)
    ,@CheckBodyNo     varchar(20)
    ,@CheckRegion     varchar(19)
    ,@CheckRowResult  int
    ,@Pos             int
    ,@MarkHTML        varchar(255)
    ,@EngineNoHTML    varchar(255)
    ,@ChassisNoHTML   varchar(255)
    ,@BodyNoHTML      varchar(255)
    ,@RegionHTML      varchar(255)
    ,@AVGEqualQty     int
    ,@EngineEqualQty  int
    ,@ChassisEqualQty int
    ,@BodyEqualQty    int

  declare @Ugon TABLE (
     CheckRowResult int          -- Результат перевірки
    ,AVGEqualQty    int          -- Середня кількість співпадінь
    ,Mark           varchar(255) -- Марка
    ,EngineNo       varchar(255) -- номер двигателя  
    ,BodyNo         varchar(255) -- номер кузова  
    ,ChassisNo      varchar(255) -- номер шасси  
    ,Region         varchar(255) -- 
    )
  
  set @CheckResult = 720 --Успішна перевірка  
  -- Обрабатываем пустые строки в номерных агрегатах - приводим их к null, иначе будут ложные совпадения
  set @BodyNo      = REVERSE(case when LEN(@BodyNo)    < 5 then NULL else @BodyNo    end)
  set @EngineNo    = REVERSE(case when LEN(@EngineNo)  < 5 then NULL else @EngineNo  end)
  set @ChassisNo   = REVERSE(case when LEN(@ChassisNo) < 5 then NULL else @ChassisNo end)
  set @ResultHTML  = ''

  declare trUgonCursor cursor static for  
  select distinct
     Mark      = Steal.Mark
    ,EngineNo  = Steal.EngineNo
    ,ChassisNo = Steal.ChassisNo
    ,BodyNo    = Steal.BodyNo
    ,Region    = ISNULL(DeclarantCountry, 'СНГ')
  from trStealInterpol Steal
    left outer join trStealDeclarant Declarant on Declarant.DeclarantID = Steal.DeclareCode
  where OperationCode = 0
    and StripEngineNo = LEFT(@EngineNo, 5)
  union
  select distinct
     Mark      = Steal.Mark
    ,EngineNo  = Steal.EngineNo
    ,ChassisNo = Steal.ChassisNo
    ,BodyNo    = Steal.BodyNo
    ,Region    = ISNULL(DeclarantCountry, 'СНГ')
  from trStealInterpol Steal
    left outer join trStealDeclarant Declarant on Declarant.DeclarantID = Steal.DeclareCode
  where OperationCode = 0
    and StripChassisNo = LEFT(@ChassisNo, 5)
  union
  select distinct
     Mark      = Steal.Mark
    ,EngineNo  = Steal.EngineNo
    ,ChassisNo = Steal.ChassisNo
    ,BodyNo    = Steal.BodyNo
    ,Region    = ISNULL(DeclarantCountry, 'СНГ')
  from trStealInterpol Steal
    left outer join trStealDeclarant Declarant on Declarant.DeclarantID = Steal.DeclareCode
  where OperationCode = 0
    and StripBodyNo = LEFT(@BodyNo, 5)
  union
  select distinct
     Mark      = Steal.Mark
    ,EngineNo  = Steal.EngineNo
    ,ChassisNo = Steal.BodyNo
    ,BodyNo    = Steal.ChassisNo
    ,Region    = ISNULL(DeclarantCountry, 'СНГ') + '(шасі)'
  from trStealInterpol Steal
    left outer join trStealDeclarant Declarant on Declarant.DeclarantID = Steal.DeclareCode
  where OperationCode = 0
    and StripChassisNo = LEFT(@BodyNo, 5)
  union
  select distinct
     Mark      = Steal.Mark
    ,EngineNo  = Steal.EngineNo
    ,ChassisNo = Steal.BodyNo
    ,BodyNo    = Steal.ChassisNo
    ,Region    = ISNULL(DeclarantCountry, 'СНГ') + '(кузов)'
  from trStealInterpol Steal
    left outer join trStealDeclarant Declarant on Declarant.DeclarantID = Steal.DeclareCode
  where OperationCode = 0
    and StripBodyNo = LEFT(@ChassisNo, 5)
  union
  select distinct
     Mark      = Steal.Mark
    ,EngineNo  = Steal.EngineNo
    ,ChassisNo = Steal.ChassisNo
    ,BodyNo    = Steal.BodyNo
    ,Region    = (select top 1 RegionName from ldrRegion where RegionID = Steal.RegionID)
  from trStealVehicles Steal
  where OperationCode = 0
    and StripEngineNo = LEFT(@EngineNo, 5)
  union
  select distinct
     Mark      = Steal.Mark
    ,EngineNo  = Steal.EngineNo
    ,ChassisNo = Steal.ChassisNo
    ,BodyNo    = Steal.BodyNo
    ,Region    = (select top 1 RegionName from ldrRegion where RegionID = Steal.RegionID)
  from trStealVehicles Steal
  where OperationCode = 0
    and StripChassisNo = LEFT(@ChassisNo, 5)
  union
  select distinct
     Mark      = Steal.Mark
    ,EngineNo  = Steal.EngineNo
    ,ChassisNo = Steal.ChassisNo
    ,BodyNo    = Steal.BodyNo
    ,Region    = (select top 1 RegionName from ldrRegion where RegionID = Steal.RegionID)
  from trStealVehicles Steal
  where OperationCode = 0
    and StripBodyNo = LEFT(@BodyNo, 5)
  union
  select distinct
     Mark      = Steal.Mark
    ,EngineNo  = Steal.EngineNo
    ,ChassisNo = Steal.BodyNo
    ,BodyNo    = Steal.ChassisNo
    ,Region    = (select top 1 RegionName from ldrRegion where RegionID = Steal.RegionID) + '(шасі)'
  from trStealVehicles Steal
  where OperationCode = 0
    and StripChassisNo = LEFT(@BodyNo, 5)
  union
  select distinct
     Mark      = Steal.Mark
    ,EngineNo  = Steal.EngineNo
    ,ChassisNo = Steal.BodyNo
    ,BodyNo    = Steal.ChassisNo
    ,Region    = (select top 1 RegionName from ldrRegion where RegionID = Steal.RegionID) + '(кузов)'
  from trStealVehicles Steal
  where OperationCode = 0
    and StripBodyNo = LEFT(@ChassisNo, 5)

  open trUgonCursor
  
  fetch next from trUgonCursor into   
     @CheckMark
    ,@CheckEngineNo
    ,@CheckChassisNo
    ,@CheckBodyNo
    ,@CheckRegion
  
  if @@CURSOR_ROWS > 0
  begin
    while @@FETCH_STATUS = 0
    begin  
      if @CheckEngineNo = @EngineNo or @CheckChassisNo = @ChassisNo or @CheckBodyNo = @BodyNo
        set @CheckRowResult = 760 -- Операцію заборонено
      else
        set @CheckRowResult = 730 -- Потрібен візуальний контроль інспектора

      set @EngineNoHTML = ''
      set @EngineEqualQty = 0
      if @CheckEngineNo is NOT NULL
      begin
        set @Pos = 1
        while @Pos <= LEN(@CheckEngineNo)
        begin
          if SUBSTRING(@EngineNo, @Pos, 1) = SUBSTRING(@CheckEngineNo, @Pos, 1)
          begin
            set @EngineEqualQty = @EngineEqualQty + ABS(9 - @Pos)
            set @EngineNoHTML = '<b><u>' + SUBSTRING(@CheckEngineNo, @Pos, 1) + '</u></b>' + @EngineNoHTML
          end
          else
            set @EngineNoHTML = SUBSTRING(@CheckEngineNo, @Pos, 1) + @EngineNoHTML
          set @Pos = @Pos + 1
        end
        set @EngineNoHTML = REPLACE(@EngineNoHTML, '</u></b><b><u>', '')
      end
      else
        set @EngineNoHTML = '&nbsp'

      set @BodyNoHTML = ''
      set @BodyEqualQty = 0
      if @CheckBodyNo is NOT NULL
      begin
        set @Pos = 1
        while @Pos <= LEN(@CheckBodyNo)
        begin
          if SUBSTRING(@BodyNo, @Pos, 1) = SUBSTRING(@CheckBodyNo, @Pos, 1)
          begin
            set @BodyEqualQty = @BodyEqualQty + ABS(9 - @Pos)
            set @BodyNoHTML = '<b><u>' + SUBSTRING(@CheckBodyNo, @Pos, 1) + '</u></b>' + @BodyNoHTML
          end
          else
            set @BodyNoHTML = SUBSTRING(@CheckBodyNo, @Pos, 1) + @BodyNoHTML
          set @Pos = @Pos + 1
        end
        set @BodyNoHTML = REPLACE(@BodyNoHTML, '</u></b><b><u>', '')
      end
      else
        set @BodyNoHTML = '&nbsp'

      set @ChassisNoHTML = ''
      set @ChassisEqualQty = 0
      if @CheckChassisNo is NOT NULL
      begin
        set @Pos = 1
        while @Pos <= LEN(@CheckChassisNo)
        begin
          if SUBSTRING(@ChassisNo, @Pos, 1) = SUBSTRING(@CheckChassisNo, @Pos, 1)
          begin
            set @ChassisEqualQty = @ChassisEqualQty + ABS(9 - @Pos)
            set @ChassisNoHTML = '<b><u>' + SUBSTRING(@CheckChassisNo, @Pos, 1) + '</u></b>' + @ChassisNoHTML
          end
          else
            set @ChassisNoHTML = SUBSTRING(@CheckChassisNo, @Pos, 1) + @ChassisNoHTML
          set @Pos = @Pos + 1
        end
        set @ChassisNoHTML = REPLACE(@ChassisNoHTML, '</u></b><b><u>', '')
      end
      else
        set @ChassisNoHTML = '&nbsp'
   
      select @AVGEqualQty = MAX(EqualQty)
      from (select EqualQty = @ChassisEqualQty
            union 
            select EqualQty = @BodyEqualQty) ss

 
      insert into @Ugon (
         CheckRowResult
        ,AVGEqualQty
        ,Mark
        ,EngineNo
        ,BodyNo
        ,ChassisNo
        ,Region
        )
      values (
         @CheckRowResult
        ,@AVGEqualQty
        ,@CheckMark
        ,@EngineNoHTML
        ,@BodyNoHTML
        ,@ChassisNoHTML
        ,@CheckRegion    
        )

      fetch next from trUgonCursor into   
         @CheckMark
        ,@CheckEngineNo
        ,@CheckChassisNo
        ,@CheckBodyNo
        ,@CheckRegion
    end  
  end  

  deallocate trUgonCursor  

  declare trUgonCursor cursor static for  
  select top 20
     CheckRowResult
    ,Mark
    ,EngineNo
    ,BodyNo
    ,ChassisNo
    ,Region
  from @Ugon
  order by CheckRowResult desc, AVGEqualQty desc

  open trUgonCursor  

  fetch next from trUgonCursor into
     @CheckRowResult
    ,@MarkHTML
    ,@EngineNoHTML
    ,@ChassisNoHTML
    ,@BodyNoHTML
    ,@RegionHTML

  while @@FETCH_STATUS = 0
  begin  

    if @CheckResult < @CheckRowResult
      set @CheckResult = @CheckRowResult

    if @CheckRowResult = 760 -- Операцію заборонено
      set @ResultHTML = @ResultHTML + '<table border=1><tr>'
    else
      set @ResultHTML = @ResultHTML + '<table><tr>'

    set @ResultHTML = @ResultHTML
        + '<td>' + ISNULL(@MarkHTML, '') + '</td>'  
        + '<td>' + ISNULL(@EngineNoHTML, '') + '</td>'  
        + '<td>' + ISNULL(@ChassisNoHTML, '') + '</td>'  
        + '<td>' + ISNULL(@BodyNoHTML, '') + '</td>'  
        + '<td>' + ISNULL(@RegionHTML, '') + '</td></tr></table>'  

    fetch next from trUgonCursor into   
       @CheckRowResult
      ,@MarkHTML
      ,@EngineNoHTML
      ,@ChassisNoHTML
      ,@BodyNoHTML
      ,@RegionHTML
  end

  deallocate trUgonCursor  

  RETURN 0  
END  
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByDNZ]'
GO
 /*-----------------------------------------------------------------------------  
  Model  : tr   
  Class  : transport  
  Author : Осадчий А.П., Миронов Р.А.  
  Desc   : Процедура выполнения проверок по АИС "Номерной знак"  
  Result : 0 - OK , -1 - Error   
  Last   : Осадчий А.П. / 2006-05-03
*/  
CREATE  PROCEDURE [dbo].[tr_CheckByDNZ]  
   @DNZNumber   varchar(15)  
  ,@ResultHTML  varchar(8000) out  
  ,@CheckResult int out           -- Результат проверки  
AS BEGIN  
  if @DNZNumber is NOT NULL
  begin  
    if exists(select 1 from trStealVehicles where DNZNo = @DNZNumber and OperationCode in (0, 2)) begin  
      set @ResultHTML = '<font color="red">' + @DNZNumber + ' у розшуку <b>ЗНАЧИТЬСЯ !!!</b></font>'  
      set @CheckResult = 760 -- Операцію заборонено
    end  
    else
    begin  
      set @ResultHTML = NULL
      set @CheckResult = 720 --Успішна перевірка  
    end  
  end  
  RETURN 0  
END    
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByWantedDocs]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : Осадчий А.П., Миронов Р.А.
  Desc   : Процедура выполнения проверок по АИС "Документы в розыске"
  Result : 0 - OK , -1 - Error 
  Last   : Миронов Р.А. / 2006-04-04
*/
CREATE PROCEDURE [dbo].[tr_CheckByWantedDocs]
   @DocNumber   varchar(20)   -- Серия и номер документа
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out       -- Результат проверки
AS BEGIN
  if @DocNumber is NOT NULL
  begin
    if exists(select 1 
      from trStealDocuments StealDoc
      where StealDoc.DocNo = @DocNumber
        and StealDoc.OperationCode = 0)
    begin
      set @ResultHTML = '<font color="red">' + @DocNumber + ' у розшуку <B>ЗНАЧИТЬСЯ !!!</b></font>'
      set @CheckResult = 760 --Операцію заборонено
    end
    else
    begin
      set @ResultHTML = NULL
      set @CheckResult = 720 --Успішна перевірка
    end
  end
  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByWantedCar]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : Осадчий А.П.
  Desc   : Процедура выполнения проверок по базе "Розшук"
  Result : 0 - OK , -1 - Error 
  Last   : Осадчий А.П. / 2007-03-03
*/
CREATE PROCEDURE [dbo].[tr_CheckByWantedCar]
   @NZA         varchar(20)       -- NZA
  ,@BodyNo      varchar(20)       -- номер кузова
  ,@ChassisNo   varchar(20)       -- номер шасси
  ,@ResultHTML  varchar(8000) out -- Результат в HTML
  ,@CheckResult int out           -- Результат проверки
AS BEGIN

  declare 
     @ResolNumber      varchar(20)
    ,@ResolDate        varchar(10)
    ,@CardArrestNumber varchar(20)
    ,@CardArrestDate   varchar(10)
    ,@ResolOwnerName   varchar(255)
    ,@ResolDescription varchar(255)
    ,@ArrAppNumber     varchar(20)
    ,@ArrMark          varchar(100)
    ,@ArrModel         varchar(255)
    ,@ArrNZA           varchar(20)
    ,@ArrBodyNo        varchar(17)
    ,@ArrChassisNo     varchar(17)

  set @BodyNo    = case when LEN(@BodyNo)    < 5 then NULL else REVERSE(@BodyNo)    end
  set @ChassisNo = case when LEN(@ChassisNo) < 5 then NULL else REVERSE(@ChassisNo) end

  declare ArrCursor cursor static for  
  select top 10
     ResolNumber      = ISNULL(Arrest.ResolutionNumber, '')
    ,ResolDate        = ISNULL(CONVERT(varchar(10), Arrest.ResolutionDate, 104), '')
    ,CardArrestNumber = ISNULL(Arrest.CardArrestNumberIn, '')
    ,CardArrestDate   = ISNULL(CONVERT(varchar(10), Arrest.CardArrestDateIn, 104), '')
    ,ResolOwnerName   = ISNULL(Arrest.ResolutionOwnerName, '')
    ,ResolDescription = ISNULL(Arrest.ResolutionDescription, '')
    ,AppNumber        = ISNULL(App.AppNumber, '')
    ,Mark             = ISNULL(App.Mark, '')
    ,Model            = ISNULL(App.Model, '')
    ,NZA              = ISNULL(App.NZA, '')
    ,BodyNo           = ISNULL(App.BodyNo, '')
    ,ChassisNo        = ISNULL(App.ChassisNo, '')
  from trCardArrestsApplications Arr2App
   inner join (
      select 
         AppGUID
        ,AppNumber
        ,NZA
        ,Mark
        ,Model
        ,BodyNo = REVERSE(BodyNo)
        ,ChassisNo = REVERSE(ChassisNo)
      from trApplications (nolock)
      where NZA = @NZA 
      union 
      select
         AppGUID
        ,AppNumber
        ,NZA
        ,Mark
        ,Model
        ,BodyNo = REVERSE(BodyNo)
        ,ChassisNo = REVERSE(ChassisNo)
      from trApplications (nolock)
      where BodyNo = @BodyNo
      union 
      select
         AppGUID
        ,AppNumber
        ,NZA
        ,Mark
        ,Model
        ,BodyNo = REVERSE(BodyNo)
        ,ChassisNo = REVERSE(ChassisNo)
      from trApplications (nolock)
      where ChassisNo = @ChassisNo) App on App.AppGUID = Arr2App.AppGUID
    inner join trCardArrests Arrest on Arrest.CardArrestGUID = Arr2App.CardArrestGUID
  where Arr2App.CardUnarrestGUID is NULL 
    and Arrest.CardArrestTypeID = 2101 -- Постанова в розшук

  open ArrCursor  
  
  fetch next from ArrCursor into
     @ResolNumber
    ,@ResolDate
    ,@CardArrestNumber
    ,@CardArrestDate
    ,@ResolOwnerName
    ,@ResolDescription
    ,@ArrAppNumber
    ,@ArrMark
    ,@ArrModel
    ,@ArrNZA
    ,@ArrBodyNo
    ,@ArrChassisNo

  if @@CURSOR_ROWS > 0
  begin
    set @CheckResult = 745 -- Тільки АНУЛЮВАННЯ
    set @ResultHTML = '<font color="red"><b>ЗНАЧИТЬСЯ В РОЗШУКУ !!!</b>'

    while @@FETCH_STATUS = 0
    begin  
      set @ResultHTML = @ResultHTML
      + '<br>Постанова №' + @ResolNumber + ' ' + @ResolDate + ' Вхідний №' + @CardArrestNumber + ' ' + @CardArrestDate + '<br>'
      + '&nbsp&nbspПоставив: ' + @ResolOwnerName + ' Примітки: ' + @ResolDescription + '<br>'
      + '&nbsp&nbspАМТ: ' + @ArrMark + ' ' + @ArrModel + ' Картка №' + @ArrAppNumber + ' NZA:' + @ArrNZA 
        + ' Кузов:' + @ArrBodyNo + ' Шасі:' + @ArrChassisNo

    fetch next from ArrCursor into
       @ResolNumber
      ,@ResolDate
      ,@CardArrestNumber
      ,@CardArrestDate
      ,@ResolOwnerName
      ,@ResolDescription
      ,@ArrAppNumber
      ,@ArrMark
      ,@ArrModel
      ,@ArrNZA
      ,@ArrBodyNo
      ,@ArrChassisNo
    end

    set @ResultHTML = @ResultHTML + '</font>'
  end
  else 
  begin
    set @CheckResult = 720 --Успішна перевірка  
    set @ResultHTML = NULL
  end

  close ArrCursor
  deallocate ArrCursor

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByArrestedCar]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : Осадчий А.П., Миронов Р.А.
  Desc   : Процедура выполнения проверок по базам ареста
  Result : 0 - OK , -1 - Error 
  Last   : Миронов Р.А. / 2006-04-04
*/
CREATE PROCEDURE [dbo].[tr_CheckByArrestedCar]
   @NZA         varchar(20)       -- NZA
  ,@BodyNo      varchar(20)       -- номер кузова
  ,@ChassisNo   varchar(20)       -- номер шасси
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- Результат проверки
AS BEGIN

  declare 
     @ArrKind          varchar(100)
    ,@ResolNumber      varchar(20)
    ,@ResolDate        varchar(10)
    ,@CardArrestNumber varchar(20)
    ,@CardArrestDate   varchar(10)
    ,@ResolOwnerName   varchar(255)
    ,@ResolDescription varchar(255)
    ,@ArrAppNumber     varchar(20)
    ,@ArrMark          varchar(100)
    ,@ArrModel         varchar(255)
    ,@ArrNZA           varchar(20)
    ,@ArrBodyNo        varchar(17)
    ,@ArrChassisNo     varchar(17)

  set @BodyNo    = case when LEN(@BodyNo)    < 5 then NULL else REVERSE(@BodyNo)    end
  set @ChassisNo = case when LEN(@ChassisNo) < 5 then NULL else REVERSE(@ChassisNo) end

  declare ArrCursor cursor static for  
  select top 10
     ArrKind          = ISNULL(ArrKind.[Name], '')
    ,ResolNumber      = ISNULL(Arrest.ResolutionNumber, '')
    ,ResolDate        = ISNULL(CONVERT(varchar(10), Arrest.ResolutionDate, 104), '')
    ,CardArrestNumber = ISNULL(Arrest.CardArrestNumberIn, '')
    ,CardArrestDate   = ISNULL(CONVERT(varchar(10), Arrest.CardArrestDateIn, 104), '')
    ,ResolOwnerName   = ISNULL(Arrest.ResolutionOwnerName, '')
    ,ResolDescription = ISNULL(Arrest.ResolutionDescription, '')
    ,AppNumber        = ISNULL(App.AppNumber, '')
    ,Mark             = ISNULL(App.Mark, '')
    ,Model            = ISNULL(App.Model, '')
    ,NZA              = ISNULL(App.NZA, '')
    ,BodyNo           = ISNULL(App.BodyNo, '')
    ,ChassisNo        = ISNULL(App.ChassisNo, '')
  from trCardArrestsApplications Arr2App
   inner join (
      select 
         AppGUID
        ,AppNumber
        ,NZA
        ,Mark
        ,Model
        ,BodyNo = REVERSE(BodyNo)
        ,ChassisNo = REVERSE(ChassisNo)
      from trApplications (nolock)
      where NZA = @NZA 
      union 
      select
         AppGUID
        ,AppNumber
        ,NZA
        ,Mark
        ,Model
        ,BodyNo = REVERSE(BodyNo)
        ,ChassisNo = REVERSE(ChassisNo)
      from trApplications (nolock)
      where BodyNo = @BodyNo
      union 
      select
         AppGUID
        ,AppNumber
        ,NZA
        ,Mark
        ,Model
        ,BodyNo = REVERSE(BodyNo)
        ,ChassisNo = REVERSE(ChassisNo)
      from trApplications (nolock)
      where ChassisNo = @ChassisNo) App on App.AppGUID = Arr2App.AppGUID
    inner join trCardArrests Arrest on Arrest.CardArrestGUID = Arr2App.CardArrestGUID
    left outer join trEnumTypeValues ArrKind on ArrKind.tvID = Arrest.CardArrestKindID
  where Arr2App.CardUnarrestGUID is NULL 
    and Arrest.CardArrestTypeID = 1401 -- Постанова на арешт

  open ArrCursor  
  
  fetch next from ArrCursor into
     @ArrKind
    ,@ResolNumber
    ,@ResolDate
    ,@CardArrestNumber
    ,@CardArrestDate
    ,@ResolOwnerName
    ,@ResolDescription
    ,@ArrAppNumber
    ,@ArrMark
    ,@ArrModel
    ,@ArrNZA
    ,@ArrBodyNo
    ,@ArrChassisNo

  if @@CURSOR_ROWS > 0
  begin
    set @CheckResult = 740 -- Зняття з обліку заборонено
    set @ResultHTML = '<font color="red"><b>ЗНАЧИТЬСЯ В АРЕШТІ !!!</b>'

    while @@FETCH_STATUS = 0
    begin  
      set @ResultHTML = @ResultHTML + '<br>Тип "' + ISNULL(@ArrKind, '') + '" '
      + 'Постанова №' + @ResolNumber + ' ' + @ResolDate + ' Вхідний №' + @CardArrestNumber + ' ' + @CardArrestDate + '<br>'
      + '&nbsp&nbspПоставив: ' + @ResolOwnerName + ' Примітки: ' + @ResolDescription + '<br>'
      + '&nbsp&nbspАМТ: ' + @ArrMark + ' ' + @ArrModel + ' Картка №' + @ArrAppNumber + ' NZA:' + @ArrNZA 
        + ' Кузов:' + @ArrBodyNo + ' Шасі:' + @ArrChassisNo

    fetch next from ArrCursor into
       @ArrKind
      ,@ResolNumber
      ,@ResolDate
      ,@CardArrestNumber
      ,@CardArrestDate
      ,@ResolOwnerName
      ,@ResolDescription
      ,@ArrAppNumber
      ,@ArrMark
      ,@ArrModel
      ,@ArrNZA
      ,@ArrBodyNo
      ,@ArrChassisNo
    end

    set @ResultHTML = @ResultHTML + '</font>'
  end
  else 
  begin
    set @CheckResult = 720 --Успішна перевірка  
    set @ResultHTML = NULL
  end

  close ArrCursor
  deallocate ArrCursor

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByControledCar]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : Осадчий А.П., Миронов Р.А.
  Desc   : Процедура выполнения проверок по АИС "Контроль"
  Result : 0 - OK , -1 - Error 
  Last   : Осадчий А.П. / 2006-07-26
*/
CREATE PROCEDURE [dbo].[tr_CheckByControledCar]
   @BodyNo      varchar(20)       -- номер кузова
  ,@ChassisNo   varchar(20)       -- номер шасси
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out
AS BEGIN

  declare 
     @ResolNumber      varchar(20)
    ,@ResolDate        varchar(10)
    ,@CardArrestNumber varchar(20)
    ,@CardArrestDate   varchar(10)
    ,@ResolOwnerName   varchar(255)
    ,@ResolDescription varchar(255)
    ,@ArrMark          varchar(100)
    ,@ArrModel         varchar(255)
    ,@ArrBodyNo        varchar(17)
    ,@ArrChassisNo     varchar(17)

  set @BodyNo    = case when LEN(@BodyNo)    < 5 then NULL else @BodyNo    end
  set @ChassisNo = case when LEN(@ChassisNo) < 5 then NULL else @ChassisNo end

  declare ArrCursor cursor static for  
  select top 10
     ResolNumber      = ISNULL(Arrest.ResolutionNumber, '')
    ,ResolDate        = ISNULL(CONVERT(varchar(10), Arrest.ResolutionDate, 104), '')
    ,CardArrestNumber = ISNULL(Arrest.CardArrestNumberIn, '')
    ,CardArrestDate   = ISNULL(CONVERT(varchar(10), Arrest.CardArrestDateIn, 104), '')
    ,ResolOwnerName   = ISNULL(Arrest.ResolutionOwnerName, '')
    ,ResolDescription = ISNULL(Arrest.ResolutionDescription, '')
    ,Mark             = ISNULL(App.Mark, '')
    ,Model            = ISNULL(App.Model, '')
    ,BodyNo           = ISNULL(App.BodyNo, '')
    ,ChassisNo        = ISNULL(App.ChassisNo, '')
  from (
      select
         CardArrestGUID
        ,CardUnarrestGUID
        ,Mark
        ,Model
        ,BodyNo
        ,ChassisNo
      from trCardArrestsChecks
      where BodyNo = @BodyNo
      union
      select
         CardArrestGUID
        ,CardUnarrestGUID
        ,Mark
        ,Model
        ,BodyNo
        ,ChassisNo
      from trCardArrestsChecks
      where ChassisNo = @ChassisNo
      union
      select
         CardArrestGUID
        ,CardUnarrestGUID
        ,Mark
        ,Model
        ,BodyNo
        ,ChassisNo
      from trCardArrestsChecks
      where BodyNo = @ChassisNo
      union
      select
         CardArrestGUID
        ,CardUnarrestGUID
        ,Mark
        ,Model
        ,BodyNo
        ,ChassisNo
      from trCardArrestsChecks
      where ChassisNo = @BodyNo) App
    inner join trCardArrests Arrest on Arrest.CardArrestGUID = App.CardArrestGUID
  where App.CardUnarrestGUID is NULL

  open ArrCursor  
  
  fetch next from ArrCursor into
     @ResolNumber
    ,@ResolDate
    ,@CardArrestNumber
    ,@CardArrestDate
    ,@ResolOwnerName
    ,@ResolDescription
    ,@ArrMark
    ,@ArrModel
    ,@ArrBodyNo
    ,@ArrChassisNo

  if @@CURSOR_ROWS > 0
  begin
    set @CheckResult = 730 -- Потрібен візуальний контроль інспектора
    set @ResultHTML = '<font color="red"><b>ЗНАЧИТЬСЯ В КОНТРОЛІ !!!</b>'

    while @@FETCH_STATUS = 0
    begin  
      set @ResultHTML = @ResultHTML
      + '<br>Постанова №' + @ResolNumber + ' ' + @ResolDate + ' Вхідний №' + @CardArrestNumber + ' ' + @CardArrestDate + '<br>'
      + '&nbsp&nbspПоставив: ' + @ResolOwnerName + ' Примітки: ' + @ResolDescription + '<br>'
      + '&nbsp&nbspАМТ: ' + @ArrMark + ' ' + @ArrModel + ' Кузов:' + @ArrBodyNo + ' Шасі:' + @ArrChassisNo

    fetch next from ArrCursor into
       @ResolNumber
      ,@ResolDate
      ,@CardArrestNumber
      ,@CardArrestDate
      ,@ResolOwnerName
      ,@ResolDescription
      ,@ArrMark
      ,@ArrModel
      ,@ArrBodyNo
      ,@ArrChassisNo
    end

    set @ResultHTML = @ResultHTML + '</font>'
  end
  else 
  begin
    set @CheckResult = 720 --Успішна перевірка  
    set @ResultHTML = NULL
  end

  close ArrCursor
  deallocate ArrCursor

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByOrderCertificate]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : Осадчий А.П., Миронов Р.А.
  Desc   : Процедура выполнения проверок по АИС "Справка-счет"
  Result : 0 - OK , -1 - Error 
  Last   : Миронов Р.А. / 2006-04-04
*/
CREATE PROCEDURE [dbo].[tr_CheckByOrderCertificate]
   @DocNo       varchar(20)   -- Серия и номер документа
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out       -- Результат проверки
AS BEGIN
  declare 
    @OrgName  varchar(255)
   ,@Comments varchar(255)
   ,@Ser      varchar(20)
   ,@Num      varchar(20)

  set @Ser = CONVERT(varchar(15), REPLACE(dbo.ic_GetLetterFromString(@DocNo), '|', ''))
  set @Num = CONVERT(int, REPLACE(dbo.ic_GetNumberFromString(@DocNo), '|', ''))

  declare OrderCertCursor cursor static for  
  select
     OrgName
    ,Comments
  from trCertOrder 
  where Series = @Ser
    and @Num >= FromNo
    and @Num <= ToNo
  --
  open OrderCertCursor  
  --
  fetch next from OrderCertCursor into
    @OrgName
   ,@Comments
  --
  if @@CURSOR_ROWS > 0
  begin
    while @@FETCH_STATUS = 0
    begin  
      set @ResultHTML = ISNULL(@ResultHTML + '<br>', '') + @DocNo + ' видана <b>' + ISNULL(@OrgName, '') + '</b>'
                      + ISNULL(', <i>' + LOWER(@Comments) + '</i>', '')

      fetch next from OrderCertCursor into
        @OrgName
       ,@Comments
    end
    set @CheckResult = 720 --Успішна перевірка
  end
  else
  begin
    set @ResultHTML = '<font color="red">' + @DocNo + ' в базі ДДАІ <b>НЕ ЗНАЙДЕНА !!!</b></font>'
    set @CheckResult = 735 --Постійний облік заборонено
  end
  --
  close OrderCertCursor
  deallocate OrderCertCursor

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByAssignmentDoc]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : Осадчий А.П., Миронов Р.А.
  Desc   : Процедура выполнения проверок по АИС "Акт приема-передачи"
  Result : 0 - OK , -1 - Error 
  Last   : Миронов Р.А. / 2006-04-04
*/
CREATE PROCEDURE [dbo].[tr_CheckByAssignmentDoc]
   @DocNo       varchar(20)   -- Серия и номер документа
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- Результат проверки
AS BEGIN

  declare 
    @OrgName  varchar(255)
   ,@Comments varchar(255)
   ,@Ser      varchar(20)
   ,@Num      varchar(20)

  set @Ser = CONVERT(varchar(15), REPLACE(dbo.ic_GetLetterFromString(@DocNo), '|', ''))
  set @Num = CONVERT(int, REPLACE(dbo.ic_GetNumberFromString(@DocNo), '|', ''))

  declare ActTransmitCursor cursor static for  
  select
     OrgName
    ,Comments
  from trActTransmit 
  where Series = @Ser
    and @Num >= FromNo
    and @Num <= ToNo
  --
  open ActTransmitCursor  
  --
  fetch next from ActTransmitCursor into
    @OrgName
   ,@Comments
  --
  if @@CURSOR_ROWS > 0
  begin
    while @@FETCH_STATUS = 0
    begin  
      set @ResultHTML = ISNULL(@ResultHTML + '<br>', '') + @DocNo + ' видана <b>' + ISNULL(@OrgName, '') + '</b>'
                      + ISNULL(', <i>' + LOWER(@Comments) + '</i>', '')

      fetch next from ActTransmitCursor into
        @OrgName
       ,@Comments
    end
    set @CheckResult = 720 --Успішна перевірка
  end
  else
  begin
    set @ResultHTML = '<font color="red">' + @DocNo + ' в базі ДДАІ <b>НЕ ЗНАЙДЕНА !!!</b></font>'
    set @CheckResult = 730 -- Потрібен візуальний контроль інспектора
  end
  --
  close ActTransmitCursor
  deallocate ActTransmitCursor

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByTransitDNZ]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : Осадчий А.П., Миронов Р.А.
  Desc   : Процедура выполнения проверок по АИС "Транзитні ДНЗ"
  Result : 0 - OK , -1 - Error 
  Last   : Миронов Р.А. / 2006-04-04
*/
CREATE PROCEDURE [dbo].[tr_CheckByTransitDNZ]
   @DNZNo       varchar(15)       -- ДНЗ
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- Результат проверки
AS BEGIN

  declare 
    @OrgName  varchar(255)
   ,@Comments varchar(255)
   ,@Ser      varchar(20)
   ,@Num      varchar(20)

  set @Ser = CONVERT(varchar(15), REPLACE(dbo.ic_GetLetterFromString(@DNZNo), '|', ''))
  set @Num = CONVERT(int, REPLACE(dbo.ic_GetNumberFromString(@DNZNo), '|', ''))

  declare TransitDNZCursor cursor static for  
  select
     OrgName
    ,Comments
  from trTransitDNZ 
  where Series = @Ser
    and @Num >= FromNo
    and @Num <= ToNo
  --
  open TransitDNZCursor  
  --
  fetch next from TransitDNZCursor into
    @OrgName
   ,@Comments
  --
  if @@CURSOR_ROWS > 0
  begin
    while @@FETCH_STATUS = 0
    begin  
      set @ResultHTML = ISNULL(@ResultHTML + '<br>', '') + @DNZNo + ' виданий <b>' + ISNULL(@OrgName, '') + '</b>'
                      + ISNULL(', <i>' + LOWER(@Comments) + '</i>', '')

      fetch next from TransitDNZCursor into
        @OrgName
       ,@Comments
    end
    set @CheckResult = 720 --Успішна перевірка
  end
  else
  begin
    set @ResultHTML = '<font color="red">' + @DNZNo + ' в базі ДДАІ <b>НЕ ЗНАЙДЕНА !!!</b></font>'
    set @CheckResult = 730 -- Потрібен візуальний контроль інспектора
  end
  --
  close TransitDNZCursor
  deallocate TransitDNZCursor

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByArmor]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : Осадчий А.П.
  Desc   : Процедура выполнения проверок по АИС "Армор"
  Result : 0 - OK , -1 - Error 
  Test   : ПОПОВСЬКИЙ ПОПОВСКИЙ МАКСИМ АЛЕКСАНДРОВИЧ 11.03.1968
  Last   : Осадчий А.П. / 2010-06-03
*/
CREATE PROCEDURE [dbo].[tr_CheckByArmor]
   @LastName    varchar(50)
  ,@FirstName   varchar(20)
  ,@MiddleName  varchar(20)
  ,@Birthday    datetime
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out       -- Результат проверки
AS BEGIN
  --
  declare
     @ArmorBirthday  datetime
    ,@ArmorLastName  varchar(50)
    ,@BirthdayDiff   int
    ,@CheckRowResult int
    ,@ArmorDB        varchar(10)
  --
  set @ResultHTML  = NULL
  set @CheckResult = 720 --Успішна перевірка
  set @Birthday    = CONVERT(datetime, CONVERT(varchar(10), @Birthday, 121), 121)
  set @LastName    = REPLACE(@LastName, 'Ё', '_')
  set @LastName    = REPLACE(@LastName, 'Э', '_')
  set @LastName    = REPLACE(@LastName, 'Ы', '_')
  set @LastName    = REPLACE(@LastName, 'О', '_')
  set @LastName    = REPLACE(@LastName, 'А', '_')
  set @LastName    = REPLACE(@LastName, 'Е', '_')
  set @LastName    = REPLACE(@LastName, 'И', '_')
  set @LastName    = REPLACE(@LastName, 'У', '_')
  set @LastName    = REPLACE(@LastName, 'Ъ', '_')
  set @LastName    = REPLACE(@LastName, 'ЬО', '_')
  --
  declare ArmorCursor cursor static for  
    select distinct top 10
       ArmorLastName = PERS.FM
      ,ArmorBirthday = CONVERT(datetime, PERS.DR, 121)
      ,BirthdayDiff  = ABS(DATEDIFF(dd, @Birthday, CONVERT(datetime, PERS.DR, 121)))
      ,ArmorDB       = 'Україна'
    from armorPERS PERS
      inner join armorRZ RZ on RZ.PERS = PERS.[ID]
    where PERS.FM like LEFT(@LastName, 6) + '%'
      and PERS.IM = @FirstName
      and PERS.OT = @MiddleName
      and LEFT(PERS.DR, 4) = CONVERT(varchar(4), @Birthday, 121)
      and RZ.UDLN is NULL
      and (RZ.DPREK is NULL or (RZ.KAT in ('310', '396') and RZ.PPREK in ('198', '199') and RZ.PSNT is NULL))
    union
    select distinct top 10 
       ArmorLastName = PERS.FM
      ,ArmorBirthday = CONVERT(datetime, PERS.DR, 121)
      ,BirthdayDiff  = ABS(DATEDIFF(dd, @Birthday, CONVERT(datetime, PERS.DR, 121)))
      ,ArmorDB       = 'СНГ'
    from armorPERS PERS
      inner join armorRZSNG RZSNG on RZSNG.PERS = PERS.[ID]
    where PERS.FM like LEFT(@LastName, 6) + '%'
      and PERS.IM = @FirstName
      and PERS.OT = @MiddleName
      and LEFT(PERS.DR, 4) = CONVERT(varchar(4), @Birthday, 121)
      and RZSNG.UDLN is NULL
      and RZSNG.DZU is NULL
      and RZSNG.PRCIR is NULL
    order by BirthdayDiff

  open ArmorCursor  
  --
  if @@CURSOR_ROWS > 0
  begin
    --
    fetch next from ArmorCursor into
       @ArmorLastName
      ,@ArmorBirthday
      ,@BirthdayDiff
      ,@ArmorDB
    --
    set @ResultHTML = '<table>' 
    --
    while @@FETCH_STATUS = 0
    begin  
      if @BirthdayDiff = 0
      begin
        set @CheckRowResult = 760 -- Операцію заборонено
        set @ResultHTML = @ResultHTML + '<tr style="color:red">'
                 + '<td style="width:40%">' + @ArmorLastName + ' ' + @FirstName + ISNULL(' ' + @MiddleName, '') + '</td>'
                 + '<td>' + ISNULL(CONVERT(varchar(10), @ArmorBirthday, 104), '') + '</td>'
                 + '<td>Повний збіг</td>'
                 + '<td>Розшук ' + @ArmorDB + '</td></tr>'
      end
      else
      begin
        set @CheckRowResult = 730 -- Потрібен візуальний контроль інспектора
        set @ResultHTML = @ResultHTML + '<tr>'
                 + '<td style="width:40%">' + @ArmorLastName + ' ' + @FirstName + ISNULL(' ' + @MiddleName, '') + '</td>'
                 + '<td>' + ISNULL(CONVERT(varchar(10), @ArmorBirthday, 104), '') + '</td>'
                 + '<td>Не повний збіг</td>'
                 + '<td>Розшук ' + @ArmorDB + '</td></tr>'
      end
      --
      fetch next from ArmorCursor into
         @ArmorLastName
        ,@ArmorBirthday
        ,@BirthdayDiff
        ,@ArmorDB
    end
    set @ResultHTML = @ResultHTML + '</table>'
    if @CheckRowResult > @CheckResult
      set @CheckResult = @CheckRowResult
  end
  --
  close ArmorCursor
  deallocate ArmorCursor  
  --
  RETURN 0
END
GO


PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByBreach]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : Осадчий А.П.
  Desc   : Процедура вызова проверок по АІС "Адмінпрактика"
  Result : 0 - OK , -1 - Error 
  Last   : Осадчий А.П. / 2007-08-07
*/
CREATE PROCEDURE [dbo].[tr_CheckByBreach]
   @LastName    varchar(50)
  ,@FirstName   varchar(20)
  ,@MiddleName  varchar(20)
  ,@Birthday    datetime
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out       -- Результат проверки
AS BEGIN

  declare 
     @BreachNumber   varchar(15)
    ,@BreachDate     datetime
    ,@BreachBirthday datetime
    ,@ArticleNumber  varchar(15)
    ,@Fulfillment    varchar(15)
    ,@MaxCheckResult int
    ,@Address        varchar(100)

  set @ResultHTML = NULL
  set @CheckResult = 720 --Успішна перевірка

  declare BreachCursor cursor static for  
  select top 10
     BreachNumber  = ISNULL(Breach.DocBreachNumber, '')
    ,BreachDate    = Breach.BreachDate
    ,Birthday      = Person.Birthday
    ,Address       = Person.LivingStreet + ISNULL(' ' + LivingHouse, '')
    ,ArticleNumber = ISNULL(Article.ArticleNumber, '')
    ,Fulfillment   = ISNULL(CONVERT(varchar(15), CONVERT(int, Verdict.MeasuresAmount)) + ' грн.', CONVERT(varchar(15), Verdict.MeasuresPeriod) + ' міс.')
    ,CheckResult   = 760 -- Операцію заборонено
  from apBreach Breach
    inner join apBreachPerson Person on Person.BreachGUID = Breach.BreachGUID
    inner join apBreachArticle Article on Article.ArticleID = Breach.Article1ID
    left outer join apVerdict Verdict on Verdict.BreachGUID = Breach.BreachGUID and Verdict.IsLast = 1
  where Breach.BreachDate <= DATEADD(mm, -3, GETDATE()) 
    and Breach.BreachDate > DATEADD(yy, -3, GETDATE())
    and Verdict.FulfillmentDate is NULL
    and Person.LastName = @LastName
    and Person.FirstName = @FirstName
    and ISNULL(Person.MiddleName, '') = @MiddleName
    and ABS(DATEDIFF(dd, Person.Birthday, @Birthday)) < 1200
  order by FulfillmentDate, BreachDate desc
  --
  open BreachCursor  
  --
  if @@CURSOR_ROWS > 0
  begin
    --
    fetch next from BreachCursor into
       @BreachNumber
      ,@BreachDate
      ,@BreachBirthday
      ,@Address
      ,@ArticleNumber
      ,@Fulfillment
      ,@CheckResult

    set @ResultHTML = '<table>' 
    while @@FETCH_STATUS = 0
    begin  
      set @ResultHTML = @ResultHTML + '<tr style="color:red">'
             + '<td style="width:70%">' + @LastName + ' ' + @FirstName + ISNULL(' ' + @MiddleName, '')
                + ' ' + ISNULL(CONVERT(varchar(10), @BreachBirthday, 104), '')
                + ' ' + ISNULL(@Address, '') + '</td>'  
             + '<td>' + ISNULL(CONVERT(varchar(10), @BreachDate, 104), '') + ' ' + ISNULL(@ArticleNumber, '') + '</td>'
             + '<td style="width:10%">' + ISNULL(' ' + @Fulfillment, '') + '</td></tr>'
      --
      fetch next from BreachCursor into
         @BreachNumber
        ,@BreachDate
        ,@BreachBirthday
        ,@Address
        ,@ArticleNumber
        ,@Fulfillment
        ,@CheckResult
    end
    set @ResultHTML = @ResultHTML + '</table>'
    if @MaxCheckResult < @CheckResult
      set @MaxCheckResult = @CheckResult
  end
  --
  close BreachCursor
  deallocate BreachCursor  
  --
  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckByQuery]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : Осадчий А.П.
  Desc   : Процедура вызова проверок по АІС "Запити"
  Result : 0 - OK , -1 - Error 
  Last   : Осадчий А.П. / 2007-08-07
*/
CREATE PROCEDURE [dbo].[tr_CheckByQuery]
   @AppNumber   varchar(20)       -- Регистрация АМТ
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out
AS BEGIN

  set @CheckResult = 735 -- Постійний облік заборонено
  set @ResultHTML = '<font color="red">Підтверджених запитів <b>НЕ знайдено</b></font>'
  --
  select top 1
    @ResultHTML = '<b>Підтверджено</b>, '
        + 'Відповідь №' + ISNULL(Query.ReplyNumber, '') + ' '
        + ISNULL(CONVERT(varchar(10), Query.ReplyDate , 104), '') + ' '
        + ISNULL(Query.ReplyComment, '')
        + ISNULL(Performer.ugName, '')
    ,@CheckResult = 720 --Успішна перевірка 
  from trCardQuerys Query
    inner join usUsers Performer on Performer.ugID = Query.PerformerID
  where Query.NewAppNumber = @AppNumber
    and Query.IsConfirmed = 1 -- Підтверджено

  RETURN 0
END
GO
