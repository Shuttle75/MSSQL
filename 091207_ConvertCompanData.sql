declare
  @NZA varchar(20), @DrvNumber varchar(20), @DrvGUID uniqueidentifier, @RecordID uniqueidentifier, @ErrMsg varchar(1000)
declare @Categories varchar(32), @i int, @Category int
declare
   @LastName varchar(50)
  ,@FirstName varchar(20)
  ,@MiddleName varchar(20)
  ,@Birthday datetime
  ,@PassNo varchar(20)
  ,@LicenseNumber varchar(15)
  ,@LicenseStoreID int
  ,@TicketNumber varchar(15)
  ,@TicketStoreID int
  ,@PrevDrvNumber varchar(20)
  ,@PrevLicenseNumber varchar(15)
  ,@PrevLicenseStoreID int
  ,@PrevTicketNumber varchar(15)
  ,@PrevTicketStoreID int
  ,@TOID int

create table dbo.Categories (
   ID int not null
  ,CategoryID int
  ,CategoryName varchar(32)
  ,CategoryValue int
  primary key (ID)
)
insert into dbo.Categories
select 1, NULL, 'ТРАКТОР', 0
union
select 2, NULL, 'САМОХІД. М', 0
union
select 3, NULL, 'БРАК', 0
union
select 4, NULL, 'ТРАМВАЙ', 128
union
select 5, NULL, 'ТРАМВ', 128
union
select 6, NULL, 'ТРОЛЕЙБУС', 64
union
select 7, NULL, 'ТРОЛЛЕЙБУС', 64
union
select 8, NULL, 'ТРОЛЕЙБ', 64
union
select 9, NULL, 'МОТОКОЛЯСКА', 2
union
select 10, 3, 'A', 2
union
select 11, 5, 'B', 4
union
select 12, 7, 'C', 8
union
select 13, 9, 'D', 16
union
select 14, 10, 'E', 32
union
--кирилица
select 15, 3, 'А', 2
union
select 16, 5, 'В', 4
union
select 17, 7, 'С', 8
union
select 18, 9, 'Д', 16
union
select 19, 10, 'Е', 32
union
select 20, NULL, '5', 0
union
select 21, NULL, '36', 0
union
select 22, NULL, '-', 0

--добавляем новый тип документа
if not exists(select 1 from trDocuments where (DocID = 99))
begin
  exec [dbo].[tr_InsDocuments]
     @DocID          = 99         -- ID документа
    ,@DocName        = 'Інший документ'  -- Название документа
    ,@DocCode        = '99'  -- Номер документа
    ,@CheckID        = NULL        -- ID проверки
    ,@grID           = NULL       -- ID группы
    ,@IsLinked       = 0       -- Добавить в группу
    ,@ShortName      = NULL  -- Сокращенное название
    ,@IsForSpecMarks = 0       -- Признак "Печатать в спец. отметках"
    ,@foID           = 266          -- ID папки прав
end
if not exists(select 1 from trDocuments where (DocID = 118))
begin
  exec [dbo].[tr_InsDocuments]
     @DocID          =  118        -- ID документа
    ,@DocName        = 'Довідка адмін. групи'  -- Название документа
    ,@DocCode        = '118'  -- Номер документа
    ,@CheckID        = NULL        -- ID проверки
    ,@grID           = 2132       -- ID группы
    ,@IsLinked       = 1       -- Добавить в группу
    ,@ShortName      = NULL  -- Сокращенное название
    ,@IsForSpecMarks = 0       -- Признак "Печатать в спец. отметках"
    ,@foID           = 266          -- ID папки прав
end
if not exists(select 1 from trDocuments where (DocID = 119))
begin
  exec [dbo].[tr_InsDocuments]
     @DocID          = 119         -- ID документа
    ,@DocName        = 'Дозвіл на здачу есктерном'  -- Название документа
    ,@DocCode        = '119'  -- Номер документа
    ,@CheckID        = NULL        -- ID проверки
    ,@grID           = 2132       -- ID группы
    ,@IsLinked       = 1       -- Добавить в группу
    ,@ShortName      = NULL  -- Сокращенное название
    ,@IsForSpecMarks = 0       -- Признак "Печатать в спец. отметках"
    ,@foID           = 266          -- ID папки прав
end
update trDocGroups set foID = 266 where (grID = 2132 and DocID in (118, 119))
create table #t_DriverCards (
   DrvNumber  varchar(20) not null
  ,DrvGUID    uniqueidentifier NOT NULL
  primary key clustered (DrvNumber)
)
--только номера карточек
insert into #t_DriverCards
select --top 50000
  DrvNumber, DrvGUID
from dbo.DriverCards
where Processed is NULL
order by DrvNumber
--обрабатываем каждую карточку отдельно
declare get_driver cursor local static for
  select
    DrvNumber, DrvGUID
  from #t_DriverCards;
open get_driver;
fetch next from get_driver into @DrvNumber, @DrvGUID;
while (@@FETCH_STATUS = 0)
begin
  begin transaction;
  begin try
    --инициализация переменных
    set @i = 1
    set @Category = 0
    set @NZA = NULL
    set @RecordID = NULL
    select
       @LastName = LastName
      ,@FirstName = FirstName
      ,@MiddleName = MiddleName
      ,@Birthday = Birthday
      ,@PassNo = PassNo
      ,@Categories = Categories
      ,@PrevDrvNumber = PrevDrvNumber
      ,@TOID = TOID
      ,@LicenseNumber = LicenseNumber
      ,@TicketNumber = TicketNumber
      ,@PrevLicenseNumber = PrevLicenseNumber
      ,@PrevTicketNumber = PrevTicketNumber
    from dbo.DriverCards
    where (DrvNumber = @DrvNumber)
    --добавляем информацию о персоне
    select top 1
      @RecordID = RecordGUID
    from ctPersons
    where (PassNo = @PassNo and @PassNo is NOT NULL)
      or ((LastName = @LastName and Birthday = @Birthday) and (@PassNo is NULL and @Birthday is not NULL and @LastName is not NULL))
      or ((LastName = @LastName and FirstName = @FirstName and MiddleName = @MiddleName) and (@PassNo is NULL and @Birthday is NULL and @LastName is not NULL and @FirstName is NOT NULL and @MiddleName is NOT NULL))
    if (@RecordID is NULL)
    begin
      set @RecordID = NEWID()
      insert into ctPersons (
         LastName
        ,FirstName
        ,MiddleName
        ,INN
        ,Birthday
        ,PassNo
        ,PassFrom
        ,LatinLastName
        ,LatinFirstName
        ,WorkPlace
        ,PostName
        ,PhoneNo
        ,RecordGUID
        ,PersonGUID
        ,CreatedAt
        ,PassDate
        ,HomePhoneNo
        ,WorkPosition
        ,BirthState
        ,BirthTown
        ,Nationality
        ,Sex
        ,Education
        ,Occupation
        ,Notes
        ,StreetName
        ,HouseNo
        ,BuildingNo
        ,FlatNo
        ,RegionID
        ,MobilPhoneNo
        ,BirthPlace
        ,RegisteredAt
        ,RussianLastName
        ,RussianFirstName
        ,RussianMiddleName
      )
      select
         LastName
        ,FirstName
        ,MiddleName
        ,INN
        ,Birthday
        ,ISNULL(PassNo, '')
        ,PassBody
        ,LatinLastName
        ,LatinFirstName
        ,WorkPlace
        ,PostName
        ,PhoneNo
        ,@RecordID
        ,NEWID()
        ,GETDATE()
        ,PassDate
        ,HomePhoneNo
        ,NULL
        ,NULL
        ,Town
        ,NULL
        ,0
        ,NULL
        ,NULL
        ,NULL
        ,StreetName
        ,HouseNo
        ,BuildingNo
        ,FlatNo
        ,RegionID
        ,MobilPhoneNo
        ,BirthPlace
        ,NULL
        ,RussianLastName
        ,RussianFirstName
        ,RussianMiddleName
      from dbo.DriverCards
      where (DrvNumber = @DrvNumber)
    end
    --добавляем карточку водителя
    --устанавливаем категорию
    while (@i < 23)
    begin
      if (select PATINDEX ('%'+CategoryName+'%' , @Categories)
      from dbo.Categories
      where (ID = @i)) > 0
      begin
        select
           @Categories = REPLACE(@Categories, CategoryName, '')
          ,@Category = @Category + CategoryValue
        from dbo.Categories
        where (ID = @i)
      end
      set @i = @i+1
    end
    
    --устанавливаем тип склада продукции
    if (@PrevDrvNumber is NULL)
    begin
      if (@LicenseNumber is not NULL)
        set @LicenseStoreID = 106
      else set @LicenseStoreID = NULL
      if (@TicketNumber is not NULL)
        set @TicketStoreID = 106
      else set @TicketStoreID = NULL
      select
         @PrevLicenseStoreID = NULL
        ,@PrevTicketStoreID = NULL
    end
    else
    begin
      if (@LicenseNumber is not NULL)
        set @LicenseStoreID = 106
      else set @LicenseStoreID = NULL
      if (@TicketNumber is not NULL)
        set @TicketStoreID = 106
      if (@PrevLicenseNumber is not NULL)
        set @PrevLicenseStoreID = 
        case
          when @TOID in (152,156,158,159,160,168,169, 170,171,172,175,176) then 111
          when @TOID in (165,167) then 104
          when @TOID in (178) then 103
          else 111
        end
      else set @PrevLicenseStoreID = NULL
      if (@PrevTicketNumber is not NULL)
        set @PrevTicketStoreID = 
        case
          when @TOID in (152,156,158,159,160,168,169, 170,171,172,175,176) then 111
          when @TOID in (165,167) then 104
          when @TOID in (178) then 103
          else 111
        end
      else set @PrevTicketNumber = NULL
    end
    --находим NZA
    select
      @NZA = NZA
    from dbo.ddDriverCards
    where (DrvNumber = @PrevDrvNumber)
       or (PrevDrvNumber = @DrvNumber)
    if @NZA is NULL
      set @NZA = @DrvNumber
    --добавляем карточку
    insert into dbo.ddDriverCards (
       DrvGUID
      ,NZA
      ,DrvNumber
      ,TOID
      ,StateID
      ,OVSCode
      ,DrvDate
      ,DateTo
      ,SpecialMarks
      ,[Description]
      ,PersonGUID
      ,LicenseTypeID
      ,LicenseNumber
      ,LicenseStoreID
      ,TicketTypeID
      ,TicketNumber
      ,TicketStoreID
      ,Categories
      ,Examinations
      ,PrevDrvNumber
      ,PrevDrvDate
      ,PrevOvsCode
      ,PrevLicenseTypeID
      ,PrevLicenseNumber
      ,PrevLicenseStoreID
      ,PrevTicketTypeID
      ,PrevTicketNumber
      ,PrevTicketStoreID
      ,PrevCategories
      ,Envelope
      ,IsLast
      ,IsActive
    )
    select
       DrvGUID
      ,@NZA
      ,@DrvNumber
      ,TOID
      ,206 --закрыто
      ,case OVSCode
        when '12302' then '1330M2'
        when '123010' then '1330MA'
        else OVSCode
      end
      ,DrvDate
      ,DateTo
      ,SpecialMarks
      ,NULL
      ,@RecordID
      ,LicenseTypeID
      ,LicenseNumber
      ,@LicenseStoreID
      ,TicketTypeID
      ,TicketNumber
      ,@TicketStoreID
      ,@Category
      ,NULL
      ,PrevDrvNumber
      ,PrevDrvDate
      ,case PrevOvsCode
        when '12302' then '1330M2'
        when '123010' then '1330MA'
        else PrevOvsCode
      end
      ,PrevLicenseTypeID
      ,PrevLicenseNumber
      ,@PrevLicenseStoreID
      ,PrevTicketTypeID
      ,PrevTicketNumber
      ,@PrevTicketStoreID
      ,NULL
      ,NULL
      ,NULL
      ,NULL
    from dbo.DriverCards
    where (DrvNumber = @DrvNumber)
    --добавляем документы
    insert into dbo.ddDrvDocuments(
       DrvDocGUID
      ,DrvGUID
      ,DocID
      ,DocNo
      ,DocDate
      ,OrgName
      ,Categories
      ,RequirementID
    )
    select
       DrvDocGUID
      ,@DrvGUID
      ,case DocType
        when 204 then 104
        when 208 then 118
        when 237 then 106
        when 214 then 102
        when 216 then 99 --Інший документ
        when 215 then 105
        when 206 then 119
        when 27 then 116
        when 228 then 99 --Інший документ
        when 19 then 99 --Інший документ
        when 203 then 100 --мед. справка
        when 224 then 111
        when 202 then 101
        when 13 then 103
        when 103 then 117
        else 99
      end
      ,ISNULL(DocNo, 0)
      ,DocDate
      ,OrgName
      ,NULL
      ,NULL
    from dbo.Documents
    where (DrvNumber = @DrvNumber)
      and (DocType not in (16, 200, 201, 220, 221))
    --добавляем результаты экзаменов
    insert into dbo.ddDrvExaminations (
       ExamGUID
      ,DrvGUID
      ,CategoryID
      ,ExamDate
      ,ExamResult
      ,ExaminerID
      ,SpecMark
      ,CreatedBy
      ,CreatedAt
      ,EditedBy
      ,EditedAt
    )
    select
       ExamGUID
      ,@DrvGUID
      ,case
        when LEN(Categories) = 1 
          then (select ISNULL(c.CategoryID, 1) from dbo.Categories c where (c.CategoryName = Categories))
        when Categories = 'ПДР' then 1
        else 1 --ПДР
      end
      ,ExamDate
      ,ExamResult
      ,(select ugID from usUsers u where (u.isActive = 1) and (
          UPPER(SUBSTRING(LTRIM(ExaminerFIO), 1, COALESCE(NULLIF(CHARINDEX(' ', LTRIM(ExaminerFIO)), 0), LEN(LTRIM(ExaminerFIO))))+
          case when CHARINDEX('.', LTRIM(ExaminerFIO)) > 0 then SUBSTRING(LTRIM(ExaminerFIO), CHARINDEX('.', LTRIM(ExaminerFIO))-1, 1)+SPACE(1) else '' end)
          = UPPER(SUBSTRING(LTRIM(u.ugName), 1, case when CHARINDEX(' ', LTRIM(u.ugName)) > 0 then CHARINDEX(' ', LTRIM(u.ugName))+1 else LEN(LTRIM(u.ugName)) end))
      ))
      ,SpecialMark
      ,dbo.us_GetUserIDByLogin()
      ,GETDATE()
      ,NULL
      ,NULL
    from dbo.Examinations
    where (DrvNumber = @DrvNumber)
  end try
  begin catch
    if (@@TRANCOUNT > 0)
      rollback transaction
    update dbo.DriverCards set Processed = 0 where DrvNumber = @DrvNumber
    set @ErrMsg = 'Line:'+CONVERT(varchar(12), error_line())+SPACE(1)+'ErrorNumber:'+CONVERT(varchar(12), error_number())+SPACE(1)+'Text:'+error_message();
    RAISERROR('DrvNumber:%s, Ошибка: %s', 16, 10, @DrvNumber, @ErrMsg);
  end catch;
  if (@@TRANCOUNT > 0)
  begin
    update dbo.DriverCards set Processed = 1 where DrvNumber = @DrvNumber
    commit transaction
  end
  fetch next from get_driver into @DrvNumber, @DrvGUID;
end;
close get_driver;
deallocate get_driver;
drop table #t_DriverCards;
drop table dbo.Categories;