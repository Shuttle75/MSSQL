if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByUgon]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByUgon]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByDNZ]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByDNZ]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByWantedDocs]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByWantedDocs]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByWantedCar]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByWantedCar]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByArrestedCar]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByArrestedCar]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByPerson]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByPerson]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByControledCar]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByControledCar]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByOrderCertificate]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByOrderCertificate]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByAssignmentDoc]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByAssignmentDoc]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByTransitDNZ]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByTransitDNZ]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByArmor]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByArmor]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByBreach]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByBreach]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_InvokeCheckByQuery]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_InvokeCheckByQuery]
GO

SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS ON 
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByUgon]'
GO

/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport 
  Author : ������� �.�., ������� �.�., ������ �.�.
  Desc   : ��������� ������ �������� �� ����� �����
  Note   : ����� ���������� ���������� ���������� �����, ����� �� ����� �� ������� varchar(8000)
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2006-11-24
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByUgon]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out -- ����� � ��������
  ,@CheckResult int           out -- ��� ���������� ��������
AS BEGIN
  declare 
     @BodyNo    varchar(20) -- ����� ������
    ,@EngineNo  varchar(20) -- ����� ���������
    ,@ChassisNo varchar(20) -- ����� �����
    ,@Mark      varchar(20) -- �������� �����

  select 
     @BodyNo    = case when LEN(BodyNo)    < 5 then NULL else REVERSE(BodyNo)    end
    ,@EngineNo  = case when LEN(EngineNo)  < 5 then NULL else REVERSE(EngineNo)  end
    ,@ChassisNo = case when LEN(ChassisNo) < 5 then NULL else REVERSE(ChassisNo) end
    ,@Mark      = Mark + ISNULL(' ' + Model, '')
  from trApplications
  where AppGUID = @AppGUID

  exec DAISRV2.RTZ.dbo.tr_CheckByUgon
     @Mark        = @Mark
    ,@EngineNo    = @EngineNo
    ,@BodyNo      = @BodyNo
    ,@ChassisNo   = @ChassisNo
    ,@ResultHTML  = @ResultHTML out
    ,@CheckResult = @CheckResult out

  if @BodyNo is NOT NULL or @EngineNo is NOT NULL or @ChassisNo is NOT NULL
  begin
    set @ResultHTML = '����²�������:<br>'
       + '<table>'  
         + '<tr>'
           + '<td>����� � ������</td>'  
           + '<td>� �������</td>'
           + '<td>� ������</td>'
           + '<td>� ���</td>'
           + '<td>�������</td></tr>'
       + '</table>'
       + '<table>'  
         + '<tr>'
           + '<td><b><u>' + ISNULL(@Mark, '') + '</u></b></td>'  
           + '<td><b><u>' + ISNULL(@EngineNo, '') + '</u></b></td>'
           + '<td><b><u>' + ISNULL(@BodyNo, '') + '</u></b></td>'
           + '<td><b><u>' + ISNULL(@ChassisNo, '') + '</u></b></td>'
           + '<td></td>' + 
         + '</tr>'
       + '</table>'
       + '���������:<br>' + @ResultHTML
  end
  else
  begin
    set @ResultHTML = '<font color="red">��� �������� �� �������� ����� ������ ��� ����� ��� ��� ����� �������</font>'  
    set @CheckResult = 760 -- ����������
  end

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByDNZ]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�., ��������� �.�.
  Desc   : ��������� ������ �������� �� ��� "�������� ����"
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2006-11-24
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByDNZ]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN
  declare @DNZNumber varchar(20)

  select
     @DNZNumber = ISNULL(DNZNumber, PrevDNZNumber)
  from trApplications
  where AppGUID = @AppGUID

  if @DNZNumber is NOT NULL begin
    exec DAISRV2.RTZ.dbo.tr_CheckByDNZ
       @DNZNumber   = @DNZNumber
      ,@ResultHTML  = @ResultHTML out
      ,@CheckResult = @CheckResult out
  end
  else begin
    set @ResultHTML = '�������� �� �����������'
    set @CheckResult = 710 -- �������� �� �����������  
  end

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByWantedDocs]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�., ��������� �.�.
  Desc   : ��������� ������ �������� �� ��� "��������� � �������"
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2006-11-24
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByWantedDocs]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN
  declare @DocNumber varchar(20) -- ����� ���. �������������

  select @DocNumber = ISNULL(DocNumber, PrevDocNumber)
  from trApplications
  where AppGUID = @AppGUID

  if @DocNumber is NOT NULL
  begin
    exec DAISRV2.RTZ.dbo.tr_CheckByWantedDocs
       @DocNumber   = @DocNumber
      ,@ResultHTML  = @ResultHTML out
      ,@CheckResult = @CheckResult out
  end
  else
  begin
    set @ResultHTML = '�������� �� �����������'
    set @CheckResult = 710 -- �������� �� �����������  
  end

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByWantedCar]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�.
  Desc   : ��������� ������ �������� �� ���� "������"
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2007-03-03
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByWantedCar]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN
  declare
     @NZA       varchar(20)  -- NZA
    ,@BodyNo    varchar(20)  -- ����� ������
    ,@ChassisNo varchar(20)  -- ����� �����
  --
  select 
     @NZA       = NZA
    ,@BodyNo    = case when LEN(BodyNo)    < 5 then NULL else REVERSE(BodyNo)    end
    ,@ChassisNo = case when LEN(ChassisNo) < 5 then NULL else REVERSE(ChassisNo) end
  from trApplications app
  where AppGUID = @AppGUID
  --
  exec DAISRV2.RTZ.dbo.tr_CheckByWantedCar
     @NZA         = @NZA
    ,@BodyNo      = @BodyNo
    ,@ChassisNo   = @ChassisNo
    ,@ResultHTML  = @ResultHTML out
    ,@CheckResult = @CheckResult out
  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByArrestedCar]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�.
  Desc   : ��������� ������ �������� �� ����� ������
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2006-11-24
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByArrestedCar]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN
  declare
     @NZA       varchar(20)  -- NZA
    ,@BodyNo    varchar(20)  -- ����� ������
    ,@ChassisNo varchar(20)  -- ����� �����
  --
  select 
     @NZA       = NZA
    ,@BodyNo    = case when LEN(BodyNo)    < 5 then NULL else REVERSE(BodyNo)    end
    ,@ChassisNo = case when LEN(ChassisNo) < 5 then NULL else REVERSE(ChassisNo) end
  from trApplications app
  where AppGUID = @AppGUID
  --
  exec DAISRV2.RTZ.dbo.tr_CheckByArrestedCar
     @NZA         = @NZA
    ,@BodyNo      = @BodyNo
    ,@ChassisNo   = @ChassisNo
    ,@ResultHTML  = @ResultHTML out
    ,@CheckResult = @CheckResult out
  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByControledCar]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�.
  Desc   : ��������� ������ �������� �� ��� "��������"
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2006-11-24
*/
CREATE  PROCEDURE [dbo].[tr_InvokeCheckByControledCar]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN
  declare 
     @BodyNo    varchar(20)  -- ����� ������
    ,@ChassisNo varchar(20)  -- ����� �����
  --
  select 
     @BodyNo    = case when LEN(BodyNo)    < 5 then NULL else REVERSE(BodyNo)    end
    ,@ChassisNo = case when LEN(ChassisNo) < 5 then NULL else REVERSE(ChassisNo) end
  from trApplications app
  where AppGUID = @AppGUID
  --
  exec DAISRV2.RTZ.dbo.tr_CheckByControledCar
     @BodyNo      = @BodyNo
    ,@ChassisNo   = @ChassisNo
    ,@ResultHTML  = @ResultHTML  out
    ,@CheckResult = @CheckResult out
  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByPerson]'
GO

/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�.
  Desc   : ��������� ������ �������� �� ��� "���� � �������"
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2006-11-24
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByPerson]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN
  exec DAISRV2.RTZ.dbo.tr_CheckByWantedPeople
     @ResultHTML  = @ResultHTML  out
    ,@CheckResult = @CheckResult out
  RETURN 0
END
GO 

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByOrderCertificate]'
GO

/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�.
  Desc   : ��������� ������ �������� �� ��� "�������-����"
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2006-11-24
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByOrderCertificate]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN
  declare 
    @DocNo varchar(100) -- ����� ���������
  select @DocNo = AppDocs.DocNo
  from trApplications A
    inner join trAppDocuments AppDocs on A.AppGUID = AppDocs.AppGUID
    inner join trDocuments Docs on Docs.DocID = AppDocs.DocID
  where A.AppGUID = @AppGUID
    and Docs.CheckID = 7 -- ������ �������

  if @DocNo is NOT NULL
  begin
    exec DAISRV2.RTZ.dbo.tr_CheckByOrderCertificate
       @DocNo       = @DocNo
      ,@ResultHTML  = @ResultHTML  out
      ,@CheckResult = @CheckResult out
  end
  else
  begin
    set @ResultHTML = '�������� �� �����������'
    set @CheckResult = 710 -- �������� �� �����������  
  end

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByAssignmentDoc]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�.
  Desc   : ��������� ������ �������� �� ��� "��� ������-��������"
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2006-11-24
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByAssignmentDoc]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN
  declare 
    @DocNo varchar(100) -- ����� ���������
  select @DocNo = AppDocs.DocNo
  from trApplications A
    inner join trAppDocuments AppDocs on A.AppGUID = AppDocs.AppGUID
    inner join trDocuments Docs on Docs.DocID = AppDocs.DocID
  where A.AppGUID = @AppGUID
    and Docs.CheckID = 8 -- ��� ������-��������

  if @DocNo is NOT NULL
  begin
    exec DAISRV2.RTZ.dbo.tr_CheckByAssignmentDoc
       @DocNo       = @DocNo
      ,@ResultHTML  = @ResultHTML  out
      ,@CheckResult = @CheckResult out
  end
  else
  begin
    set @ResultHTML = '�������� �� �����������'
    set @CheckResult = 710 -- �������� �� �����������  
  end

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByTransitDNZ]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�.
  Desc   : ��������� ������ �������� �� ��� "�������� ���"
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2006-11-24
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByTransitDNZ]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN
  declare 
    @DNZNo varchar(15) -- ����� ���������
  --
  select @DNZNo = SUBSTRING(PrevDNZNumber, 3, 6)
  from trApplications
  where AppGUID = @AppGUID
    and PrevDNZTypeID = 38 -- ������� ��� 2 ����.���. (�1��0001)
  --
  if @DNZNo is NOT NULL
  begin
    exec DAISRV2.RTZ.dbo.tr_CheckByTransitDNZ
       @DNZNo       = @DNZNo
      ,@ResultHTML  = @ResultHTML  out
      ,@CheckResult = @CheckResult out
  end
  else
  begin
    set @ResultHTML = '�������� �� �����������'
    set @CheckResult = 710 -- �������� �� �����������  
  end

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByArmor]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�.
  Desc   : ��������� ������ �������� �� ��� "�����"
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2010-06-04
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByArmor]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN
  declare 
     @LastName        varchar(50)
    ,@FirstName       varchar(20)
    ,@MiddleName      varchar(20)
    ,@Birthday        datetime
    ,@TempResultHTML  varchar(8000)
    ,@TempCheckResult int

  declare curArmor cursor local for
  select 
     LastName   = Person.RussianLastName
    ,FirstName  = Person.RussianFirstName
    ,MiddleName = Person.RussianMiddleName
    ,Birthday   = Person.Birthday
  from trApplications App
    inner join ctPersons Person on Person.RecordGUID = App.OwnerRecordGUID
  where App.AppGUID = @AppGUID
    and Person.Birthday is NOT NULL
  union all
  select 
     LastName   = Person.RussianLastName
    ,FirstName  = Person.RussianFirstName
    ,MiddleName = Person.RussianMiddleName
    ,Birthday   = Person.Birthday
  from trAppPersons AppPerson
    inner join ctPersons Person on Person.RecordGUID = AppPerson.RecordGUID
  where AppPerson.AppGUID = @AppGUID
    and Person.Birthday is NOT NULL

  open curArmor

  fetch next from curArmor into
     @LastName
    ,@FirstName
    ,@MiddleName
    ,@Birthday

  set @CheckResult = 710 -- �������� �� �����������    

  while @@FETCH_STATUS = 0
  begin
    exec DAISRV2.RTZ.dbo.tr_CheckByArmor
       @LastName    = @LastName
      ,@FirstName   = @FirstName
      ,@MiddleName  = @MiddleName
      ,@Birthday    = @Birthday
      ,@ResultHTML  = @TempResultHTML  out
      ,@CheckResult = @TempCheckResult out
   
    if @TempCheckResult > @CheckResult
      set @CheckResult = @TempCheckResult
  
    if @TempResultHTML is NOT NULL
      set @ResultHTML = ISNULL(@ResultHTML, '') + @TempResultHTML

    fetch next from curArmor into
       @LastName
      ,@FirstName
      ,@MiddleName
      ,@Birthday
  end

  close curArmor
  deallocate curArmor

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByBreach]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�.
  Desc   : ��������� ������ �������� �� ��� "������������"
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2007-08-07
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByBreach]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN
  declare 
     @LastName        varchar(50)
    ,@FirstName       varchar(20)
    ,@MiddleName      varchar(20)
    ,@Birthday        datetime
    ,@TempResultHTML  varchar(8000)
    ,@TempCheckResult int

  declare curBreach cursor local for
  select 
     LastName   = Person.LastName
    ,FirstName  = Person.FirstName
    ,MiddleName = Person.MiddleName
    ,Birthday   = Person.Birthday
  from trApplications App
    inner join ctPersons Person on Person.RecordGUID = App.OwnerRecordGUID
  where App.AppGUID = @AppGUID
    and Person.Birthday is NOT NULL
  union all
  select 
     LastName   = Person.LastName
    ,FirstName  = Person.FirstName
    ,MiddleName = Person.MiddleName
    ,Birthday   = Person.Birthday
  from trAppPersons AppPerson
    inner join ctPersons Person on Person.RecordGUID = AppPerson.RecordGUID
  where AppPerson.AppGUID = @AppGUID
    and Person.Birthday is NOT NULL

  open curBreach

  fetch next from curBreach into
     @LastName
    ,@FirstName
    ,@MiddleName
    ,@Birthday

  set @CheckResult = 710 -- �������� �� �����������    

  while @@FETCH_STATUS = 0
  begin
    exec DAISRV2.RTZ.dbo.tr_CheckByBreach
       @LastName    = @LastName
      ,@FirstName   = @FirstName
      ,@MiddleName  = @MiddleName
      ,@Birthday    = @Birthday
      ,@ResultHTML  = @TempResultHTML  out
      ,@CheckResult = @TempCheckResult out
   
    if @TempCheckResult > @CheckResult
      set @CheckResult = @TempCheckResult
  
    if @TempResultHTML is NOT NULL
      set @ResultHTML = ISNULL(@ResultHTML, '') + @TempResultHTML

    fetch next from curBreach into
       @LastName
      ,@FirstName
      ,@MiddleName
      ,@Birthday
  end

  close curBreach
  deallocate curBreach

  RETURN 0
END
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_InvokeCheckByQuery]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�.
  Desc   : ��������� ������ �������� �� ��� "������"
  Result : 0 - OK , -1 - Error 
  Last   : ������� �.�. / 2007-11-16
*/
CREATE PROCEDURE [dbo].[tr_InvokeCheckByQuery]
   @AppGUID     uniqueidentifier  -- ������������� ���������
  ,@ResultHTML  varchar(8000) out
  ,@CheckResult int out           -- ��������� ��������
AS BEGIN

  declare 
     @PrevAppNumber varchar(20)
    ,@PrevOVSCode   varchar(20)
    ,@TOIsTemporary int
    ,@TOClassID     int

  select 
     @PrevAppNumber = RTRIM(LTRIM(NULLIF(App.PrevAppNumber, '')))
    ,@TOClassID     = TechOper.ClassID
    ,@TOIsTemporary = TechOper.IsTemporary  
  from trApplications App (nolock)
    inner join trTechOperations TechOper on TechOper.TOID = App.TOID
  where App.AppGUID = @AppGUID
  --
  if @TOClassID = 5 -- ����� ������������� �� ������� ������
    and @TOIsTemporary = 0 -- ����������
    and exists (
      select 1
      from trApplications App (nolock)
        inner join trTechOperations TechOper on TechOper.TOID = App.TOID
      where App.AppNumber = @PrevAppNumber
        and TechOper.IsTemporary <> 0 -- ���������
        and (App.PrevOVSCode not like '1330%' or App.PrevOVSCode is NULL)-- �� ����
    )
  begin 
    exec DAISRV2.RTZ.dbo.tr_CheckByQuery
       @AppNumber   = @PrevAppNumber
      ,@ResultHTML  = @ResultHTML  out
      ,@CheckResult = @CheckResult out
  end
  else
  begin
    set @ResultHTML = '�������� �� �����������'
    set @CheckResult = 710 -- �������� �� �����������  
  end

  RETURN 0
END
GO

GRANT EXEC ON [dbo].[tr_InvokeCheckByUgon] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByDNZ] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByWantedDocs] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByWantedCar] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByArrestedCar] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByPerson] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByControledCar] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByOrderCertificate] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByAssignmentDoc] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByTransitDNZ] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByArmor] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByBreach] TO [gn_DBO]
GRANT EXEC ON [dbo].[tr_InvokeCheckByQuery] TO [gn_DBO]
GO
GRANT EXEC ON [dbo].[tr_InvokeCheckByUgon] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByDNZ] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByWantedDocs] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByWantedCar] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByArrestedCar] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByPerson] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByControledCar] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByOrderCertificate] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByAssignmentDoc] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByTransitDNZ] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByArmor] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByBreach] TO [CheckDNZ]
GRANT EXEC ON [dbo].[tr_InvokeCheckByQuery] TO [CheckDNZ]
GO