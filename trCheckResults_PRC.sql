if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_CheckApp]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_CheckApp]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_GetAllAppCheckResults]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_GetAllAppCheckResults]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_GetRightNowCheckResults]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_GetRightNowCheckResults]
GO
if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[tr_GetDNZCheckResults]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[tr_GetDNZCheckResults]
GO

SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS ON 
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_CheckApp]'
GO

/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�., ������� �.�., ��������� �.�.
  Desc   : ��������� ���������� �������� �� ����������� ����� 
  Result : 0 - OK , -1 - Error 
  Last   : ��������� �.�. / 2006-05-21
*/
CREATE PROCEDURE [dbo].[tr_CheckApp]
   @AppGUID uniqueidentifier
AS BEGIN
  SET NOCOUNT ON
  declare
     @CheckID     int            -- ������������� ��������
    ,@CallString  nvarchar(1000) -- ������ ������ ��� ��������
    ,@CheckResult int
    ,@ResultHTML  varchar(8000)
  -- �������� ���������� ���������� ��������, ���� ������� �����������
  delete trCheckResults 
  where AppGUID = @AppGUID
  -- ���� ��������� �� ���� ���������
  declare CheckList cursor for
    select CheckID, CallString
    from trChecks
    where FolderID = 265 -- ��������� ���
  -- ��������� �� ��������� ���������
  open CheckList
  fetch next from CheckList into @CheckID, @CallString
  while @@FETCH_STATUS = 0
    begin
    if @CallString is NOT NULL
    begin
      -- ��� ������ �������� ��������� ��������� ������
      select
         @ResultHTML  = CONVERT(varchar(8000), NULL)
        ,@CheckResult = CONVERT(int, NULL)

      exec sp_executesql 
         @CallString
        ,N'@AppGUID uniqueidentifier, @ResultHTML varchar(8000) out, @CheckResult int out'
        ,@AppGUID     = @AppGUID
        ,@ResultHTML  = @ResultHTML out
        ,@CheckResult = @CheckResult out

      set @ResultHTML = REPLACE(@ResultHTML, '<table><tr><td>', char(2))
      set @ResultHTML = REPLACE(@ResultHTML, '</td></tr></table>', char(3))
      set @ResultHTML = REPLACE(@ResultHTML, '</td><td>', char(4))
      set @ResultHTML = REPLACE(@ResultHTML, '<b><u>', char(5))
      set @ResultHTML = REPLACE(@ResultHTML, '</u></b>', char(6))
      set @ResultHTML = REPLACE(@ResultHTML, '&nbsp', char(7))
      set @ResultHTML = REPLACE(@ResultHTML, 'Interpol', char(8))

      -- ����� ��������� �������� � ����
      if @CheckResult > 710
      begin
        insert into trCheckResults(
           ChResGUID
          ,AppGUID
          ,CheckID
          ,ResultID
          ,ResultText
        )
        values(
           NEWID()
          ,@AppGUID
          ,@CheckID
          ,@CheckResult
          ,@ResultHTML
        ) 
      end
    end
    fetch next from CheckList into @CheckID, @CallString
  end
  --
  close CheckList
  deallocate CheckList
  --
  update trApplications
    set CheckDate = GETDATE()
  where AppGUID = @AppGUID
  if @@ERROR <> 0
  begin
    RAISERROR(60005, 16, 10, 'trApplications') WITH SETERROR
    RETURN -1
  end

  RETURN 0
END -- procedure
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_GetAllAppCheckResults]'
GO

/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�., ������� �.�., ��������� �.�., ������ �.�.
  Desc   : ��������� ��������� ���������� ���� �������� ��������� 
  Result : 0 - OK , -1 - Error 
  Last   : ������ �.�. / 2006-08-10
  Cursor :
    [BodyHTML]    text -- HTML - ����� � ����������� ��������
    [CheckResult] int  -- ��� ���������� ��������

  Test   : select AppGUID from trApplications where AppNumber = '222376-1330MB'
tr_GetAllAppCheckResults '1BF742D0-FF22-436D-9B49-66C7E18BB24D'
tr_GetRightNowCheckResults '1BF742D0-FF22-436D-9B49-66C7E18BB24D'
*/
CREATE PROCEDURE [dbo].[tr_GetAllAppCheckResults]
   @AppGUID uniqueidentifier
AS BEGIN
  SET NOCOUNT ON
  declare 
     @CheckID        int
    ,@CheckResult    int           -- ������ ����� ����������� ������� ��������
    ,@TmpCheckResult int           -- ��������� ������� ��������
    ,@ResultHTML     varchar(8000) -- ����� � ������� ��������
    ,@CheckName      varchar(255)  -- �������� ������� ��������
    ,@CheckNo        int           -- ����� ������� ��������
    ,@BodyHTML_Size  int           
    ,@BodyHTML_Ptr   binary(16)
    ,@CheckHeader    varchar(500)  -- ��������� �������� (����� � ��������)
    
  -- ������� ��������� ������� ��� �������� ������ � ����� ���� ��������� ������

  CREATE TABLE #BodyHTML (
    BodyHTML text
  )
  
  if not exists(select 1 from trCheckResults where AppGUID = @AppGUID)
  begin
    select 
       BodyHTML    = CONVERT(text, '<html></html>')
      ,CheckResult = CONVERT(int, NULL)
    RETURN 0
  end

  insert into #BodyHTML(
    BodyHTML
  )
  select 
    Header = '<HTML><HEAD><STYLE> body {font-size:12; font-family:"Verdana";}'
   + ' table {font-size:11; font-family:"Courier New"; text-align:left; border-collapse:collapse; border:none; width:700;} td {width:20%;}</STYLE></HEAD>'
   + '<BODY><font size=5><center>���������� �²����� �� "���"</center></font>'
   + ISNULL('<font size=2>���� ����²��� ������: '
     + CONVERT(varchar(10), App.CheckDate, 104) + ' (' + CONVERT(varchar(5), App.CheckDate, 108) + ')</font>', '') + '<br><br>'
  from trApplications App
  where App.AppGUID = @AppGUID

  -- ���� ��������� �� �����, ����� ������ ������
  if @@ROWCOUNT = 0
    insert into #BodyHTML(BodyHTML)
    values ('<HTML><HEAD><STYLE> body {font-size:12; font-family:"Verdana";}</STYLE></HEAD><BODY>')
  -- ��� ����� ������� �� �������� ������� TEXTPTR
  update #BodyHTML set 
    BodyHTML = BodyHTML
  --
  declare CheckResults cursor for
    select 
       [CheckID]    = Checks.CheckID
      ,[CheckName]  = Checks.CheckName
      ,[ResultID]   = ISNULL(CheckRes.ResultID, 710) -- �������� �� �����������
      ,[ResultText] = case 
                        when CheckRes.ResultID is NULL then '<i>�������� �� �����������</i>'
                        when CheckRes.ResultID = 720 and CheckRes.ResultText is NULL then '<u>�� ���������</u>'
                        else CheckRes.ResultText
                      end
    from trChecks Checks
      left outer join trCheckResults CheckRes on CheckRes.CheckID = Checks.CheckID and CheckRes.AppGUID = @AppGUID
    where Checks.FolderID = 265 -- ��������� ���
    order by Checks.CheckID
  open CheckResults

  fetch next from CheckResults into
     @CheckID
    ,@CheckName
    ,@TmpCheckResult
    ,@ResultHTML

  set @CheckNo = 0
  set @CheckResult = 710

  while @@FETCH_STATUS = 0
  begin
    set @CheckNo = @CheckNo + 1

    set @ResultHTML = REPLACE(@ResultHTML, char(2), '<table><tr><td>')
    set @ResultHTML = REPLACE(@ResultHTML, char(3), '</td></tr></table>')
    set @ResultHTML = REPLACE(@ResultHTML, char(4), '</td><td>')
    set @ResultHTML = REPLACE(@ResultHTML, char(5), '<b><u>')
    set @ResultHTML = REPLACE(@ResultHTML, char(6), '</u></b>')
    set @ResultHTML = REPLACE(@ResultHTML, char(7), '&nbsp')
    set @ResultHTML = REPLACE(@ResultHTML, char(8), 'Interpol')
    -- ����� ��������� ������� ��������
    select 
       @BodyHTML_Size = DATALENGTH(BodyHTML)
      ,@BodyHTML_Ptr = TEXTPTR(BodyHTML)
    from #BodyHTML
    set @CheckHeader = '<b><font size=2>' + CONVERT(varchar, @CheckNo)+ '.' + @CheckName + '</font></b><br>'
    updatetext #BodyHTML.BodyHTML @BodyHTML_Ptr @BodyHTML_Size NULL @CheckHeader
    -- ���������� � ������ ���������� ��������� ������� ��������
    set @ResultHTML = @ResultHTML + '<br><br>'
    select 
       @BodyHTML_Size = DATALENGTH(BodyHTML)
    from #BodyHTML
    updatetext #BodyHTML.BodyHTML @BodyHTML_Ptr @BodyHTML_Size NULL @ResultHTML

    if (@TmpCheckResult > @CheckResult)
      set @CheckResult = @TmpCheckResult

    fetch next from CheckResults into 
       @CheckID
      ,@CheckName
      ,@TmpCheckResult
      ,@ResultHTML
  end

  close CheckResults
  deallocate CheckResults

  -- ���� �� ���� �� ����� ��������, ����� �� ���� � �����
  if @CheckNo = 0
  begin
    select 
       @BodyHTML_Size = DATALENGTH(BodyHTML)
      ,@BodyHTML_Ptr = TEXTPTR(BodyHTML)
    from #BodyHTML
    updatetext #BodyHTML.BodyHTML @BodyHTML_Ptr @BodyHTML_Size NULL '<font color=red>�������� �� �����������.</font>'
  end
  select 
     @BodyHTML_Size = DATALENGTH(BodyHTML)
    ,@BodyHTML_Ptr = TEXTPTR(BodyHTML)
  from #BodyHTML
  updatetext #BodyHTML.BodyHTML @BodyHTML_Ptr @BodyHTML_Size NULL '</td></tr><tr height=100><td>���������������� _________________</td></tr></table></BODY></HTML>'  
  -- ���������� ����������
  select 
     BodyHTML
    ,CheckResult = @CheckResult
  from #BodyHTML

  RETURN 0
END -- procedure
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_GetRightNowCheckResults]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�., ������� �.�., ��������� �.�., ������ �.�.
  Desc   : ��������� ��������� ���������� ���� �������� ��������� 
  Result : 0 - OK , -1 - Error 
  Last   : ������ �.�. / 2006-08-10
  Cursor :
    [BodyHTML]    text -- HTML - ����� � ����������� ��������
    [CheckResult] int  -- ��� ���������� ��������
*/
CREATE PROCEDURE [dbo].[tr_GetRightNowCheckResults]
   @AppGUID uniqueidentifier
AS BEGIN
  SET NOCOUNT ON
  declare 
     @CheckID        int
    ,@CheckResult    int            -- ������ ����� ����������� ������� ��������
    ,@CallString     nvarchar(1000) -- ������ ������ ��� ��������
    ,@TmpCheckResult int            -- ��������� ������� ��������
    ,@ResultHTML     varchar(8000)  -- ����� � ������� ��������
    ,@CheckName      varchar(255)   -- �������� ������� ��������
    ,@CheckNo        int            -- ����� ������� ��������
    ,@BodyHTML_Size  int           
    ,@BodyHTML_Ptr   binary(16)
    ,@CheckHeader    varchar(500)   -- ��������� �������� (����� � ��������)

  select @CheckResult = 710 -- �� �����������
    
  -- ������� ��������� ������� ��� �������� ������ � ����� ���� ��������� ������
  CREATE TABLE #BodyHTML (
    BodyHTML text
  )
  insert into #BodyHTML(
    BodyHTML
  )
  select 
    Header = '<HTML><HEAD><STYLE> body {font-size:12; font-family:"Verdana";}'
   + ' table {font-size:11; font-family:"Courier New"; text-align:left; border-collapse:collapse; border:none; width:700;} td {width:20%;}</STYLE></HEAD>'
   + '<BODY><font size="5"><center>�����Ͳ ���������� �²����� �� "���"</center></font>'
   + ISNULL('<font size=2>���� ����²��� ������: '
   + CONVERT(varchar(10), GETDATE(), 104) + ' (' + CONVERT(varchar(5), GETDATE(), 108) + ')</font>','') + '<br><br>'
  from trApplications A
  where A.AppGUID = @AppGUID

  -- ���� ��������� �� �����, ����� ������ ������
  if @@ROWCOUNT = 0
  begin
    insert into #BodyHTML(BodyHTML) values ('<HTML><meta http-equiv="Content-Type" content="text/html; charset=windows-1251"><BODY>')
  end
  -- ��� ����� ������� �� �������� ������� TEXTPTR
  update #BodyHTML set 
    BodyHTML = BodyHTML

  -- ���� ��������� �� ���� ���������
  declare CheckList cursor for
  select CheckID, CheckName, CallString
  from trChecks
  where FolderID = 265 -- ��������� ���
  -- ��������� �� ��������� ���������

  open CheckList

  fetch next from CheckList into
     @CheckID
    ,@CheckName
    ,@CallString

  set @CheckNo = 0

  while @@FETCH_STATUS = 0
  begin
    set @CheckNo = @CheckNo + 1
    if @CallString is not null
    begin
      -- ��� ������ �������� ��������� ��������� ������
      select
         @ResultHTML  = CONVERT(varchar(8000), NULL)
      exec sp_executesql 
         @CallString
        ,N'@AppGUID uniqueidentifier, @ResultHTML varchar(8000) out, @CheckResult int out'
        ,@AppGUID     = @AppGUID
        ,@ResultHTML  = @ResultHTML out
        ,@CheckResult = @TmpCheckResult out
      -- 
      set @ResultHTML = REPLACE(@ResultHTML, char(2), '<table><tr><td>')
      set @ResultHTML = REPLACE(@ResultHTML, char(3), '</td></tr></table>')
      set @ResultHTML = REPLACE(@ResultHTML, char(4), '</td><td>')
      set @ResultHTML = REPLACE(@ResultHTML, char(5), '<b><u>')
      set @ResultHTML = REPLACE(@ResultHTML, char(6), '</u></b>')
      set @ResultHTML = REPLACE(@ResultHTML, char(7), '&nbsp')
      set @ResultHTML = REPLACE(@ResultHTML, char(8), 'Interpol')
      set @ResultHTML = case 
                          when ISNULL(@TmpCheckResult, 710) = 710 then '<i>�������� �� �����������</i>'
                          when @TmpCheckResult = 720 and @ResultHTML is NULL then '<u>�� ���������</u>'
                          else @ResultHTML
                        end
      --
      if (@TmpCheckResult > @CheckResult)
        set @CheckResult = @TmpCheckResult
      -- ���������� � ������ ���������� ��������� ������� ��������
      select 
         @BodyHTML_Size = DATALENGTH(BodyHTML)
        ,@BodyHTML_Ptr  = TEXTPTR(BodyHTML)
      from #BodyHTML
      set @CheckHeader = '<b><font size=2 face="Verdana">' + CONVERT(varchar(10), @CheckNo)+ '.' + @CheckName + '</font></b><br>'
      updatetext #BodyHTML.BodyHTML @BodyHTML_Ptr @BodyHTML_Size NULL @CheckHeader
      -- ���������� � ������ ���������� ��������� ������� ��������
      set @ResultHTML = @ResultHTML + '<br><br>'
      select 
         @BodyHTML_Size = DATALENGTH(BodyHTML)
      from #BodyHTML
      updatetext #BodyHTML.BodyHTML @BodyHTML_Ptr @BodyHTML_Size NULL @ResultHTML
    end
    --
    fetch next from CheckList into
       @CheckID
      ,@CheckName
      ,@CallString
  end

  close CheckList
  deallocate CheckList

  -- ���������� ����������
  select 
     BodyHTML
    ,CheckResult = @CheckResult
  from #BodyHTML

  RETURN 0
END -- procedure
GO

PRINT 'CREATE PROCEDURE [dbo].[tr_GetDNZCheckResults]'
GO
/*-----------------------------------------------------------------------------
  Model  : tr 
  Class  : transport
  Author : ������� �.�.
  Desc   : ��������� ��������� ���������� ���� �������� ��������� 
  Result : 0 - OK , -1 - Error 
  Last   : ������ �.�. / 2006-08-10
  Cursor :
    [BodyHTML]    text -- HTML - ����� � ����������� ��������
    [CheckResult] int  -- ��� ���������� ��������
  Test   : tr_GetDNZCheckResults '��4812��'
*/
CREATE PROCEDURE [dbo].[tr_GetDNZCheckResults]
   @DNZNumber varchar(15)
  ,@HostName  varchar(15)
AS BEGIN
  SET NOCOUNT ON
  declare
     @AppGUID        uniqueidentifier 
    ,@CheckID        int
    ,@CheckResult    int            -- ������ ����� ����������� ������� ��������
    ,@CallString     nvarchar(1000) -- ������ ������ ��� ��������
    ,@TmpCheckResult int            -- ��������� ������� ��������
    ,@ResultHTML     varchar(8000)  -- ����� � ������� ��������
    ,@CheckName      varchar(255)   -- �������� ������� ��������
    ,@CheckNo        int            -- ����� ������� ��������
    ,@BodyHTML_Size  int           
    ,@BodyHTML_Ptr   binary(16)
    ,@CheckHeader    varchar(500)   -- ��������� �������� (����� � ��������)

  set @AppGUID = NULL

  select @CheckResult = 710 -- �� �����������
  select @AppGUID = AppGUID
  from trApplications App
  where ISNULL(DNZNumber, PrevDNZNumber) = @DNZNumber
    and isActive = 0x1
    and VehicleTypeID = 700

  -- ������� ��������� ������� ��� �������� ������ � ����� ���� ��������� ������
  CREATE TABLE #BodyHTML (
    BodyHTML text
  )
  --
  if @AppGUID is NULL
  begin
    insert into #BodyHTML(BodyHTML)
    select '<html><meta http-equiv="Content-Type" content="text/html; charset=windows-1251">'
     + '<body><font color=red size=6>����� �������� ��������� �� �������������</font></body>'
    --
    select 
       BodyHTML
      ,CheckResult = @CheckResult
    from #BodyHTML
    --  
    RETURN 0
  end
  else
  begin
    insert into #BodyHTML(BodyHTML)
    select '<html><meta http-equiv="Content-Type" content="text/html; charset=windows-1251"><head><style> body {font-size:12; font-family:"Verdana";}'
     + ' table {font-size:11; font-family:"Courier New"; text-align:left; border-collapse:collapse; border:none; width:700;} td {width:20%;}</style></head>'
     + '<body>'
     + '<br>�������: <b>' + case when App.OrgRecordGUID is NULL
         then ISNULL(Per.LastName, '') + ISNULL(' ' + Per.FirstName, '') + ISNULL(' ' + Per.MiddleName, '') + ISNULL(' ' + CONVERT(varchar(10), Per.Birthday, 104) + ' �.�.', '')
         else ISNULL(Org.OrgName, '')
       end + '</b>'
     + '<br>������: <b>' + case when App.[OrgRecordGUID] is NULL
         then dbo.ct_GetAddress(Per.RegionID, Per.StreetName, Per.HouseNo, Per.BuildingNo, Per.FlatNo, '��.')
         else dbo.ct_GetAddress(Org.RegionID, Org.StreetName, Org.HouseNo, Org.BuildingNo, Org.Office, '��.')
       end + '</b>'
     + '<br><br>'
    from trApplications App (nolock)
      left outer join ctOrganizations Org on App.OrgRecordGUID = Org.RecordGUID
      left outer join ctPersons Per (nolock) on App.OwnerRecordGUID = Per.RecordGUID
    where AppGUID = @AppGUID
  end

  -- ��� ����� ������� �� �������� ������� TEXTPTR
  update #BodyHTML set 
    BodyHTML = BodyHTML

  -- ���� ��������� �� ���� ���������
  declare CheckList cursor for
  select CheckID, CheckName, CallString
  from trChecks
  where CheckID in (1, 2, 3, 4, 5, 6, 10, 11)
  -- ��������� �� ��������� ���������

  open CheckList

  fetch next from CheckList into
     @CheckID
    ,@CheckName
    ,@CallString

  set @CheckNo = 0

  while @@FETCH_STATUS = 0
  begin
    set @CheckNo = @CheckNo + 1
    if @CallString is not null
    begin
      -- ��� ������ �������� ��������� ��������� ������
      select
         @ResultHTML  = CONVERT(varchar(8000), NULL)
      exec sp_executesql 
         @CallString
        ,N'@AppGUID uniqueidentifier, @ResultHTML varchar(8000) out, @CheckResult int out'
        ,@AppGUID     = @AppGUID
        ,@ResultHTML  = @ResultHTML out
        ,@CheckResult = @TmpCheckResult out
      -- 
      if @CheckID = 4 and @TmpCheckResult > 720 -- ������
      begin
        insert into RTZ_Hist.dbo.trCheckDNZLog (
           [DNZNumber]
          ,[CheckID]
          ,[CheckDate]
          ,[HostName]
          )                
        select
           [DNZNumber]  = @DNZNumber
          ,[CheckID]    = @CheckID
          ,[CheckDate]  = GETDATE()
          ,[HostName]   = @HostName
      end

      set @ResultHTML = case 
                          when ISNULL(@TmpCheckResult, 710) = 710 then '<i>�������� �� �����������</i>'
                          when @TmpCheckResult = 720 and @ResultHTML is NULL then '<u>�� ���������</u>'
                          else @ResultHTML
                        end
      --
      if (@TmpCheckResult > @CheckResult)
        set @CheckResult = @TmpCheckResult
      -- ���������� � ������ ���������� ��������� ������� ��������
      select 
         @BodyHTML_Size = DATALENGTH(BodyHTML)
        ,@BodyHTML_Ptr  = TEXTPTR(BodyHTML)
      from #BodyHTML
      set @CheckHeader = '<b><font size=2 face="Verdana">' + CONVERT(varchar(10), @CheckNo)+ '.' + @CheckName + '</font></b><br>'
      updatetext #BodyHTML.BodyHTML @BodyHTML_Ptr @BodyHTML_Size NULL @CheckHeader
      -- ���������� � ������ ���������� ��������� ������� ��������
      set @ResultHTML = @ResultHTML + '<br><br>'
      select 
         @BodyHTML_Size = DATALENGTH(BodyHTML)
      from #BodyHTML
      updatetext #BodyHTML.BodyHTML @BodyHTML_Ptr @BodyHTML_Size NULL @ResultHTML
    end
    --
    fetch next from CheckList into
       @CheckID
      ,@CheckName
      ,@CallString
  end

  close CheckList
  deallocate CheckList

  -- ���������� ����������
  select 
     BodyHTML
    ,CheckResult = @CheckResult
  from #BodyHTML

  RETURN 0
END -- procedure
GO

GRANT EXECUTE ON [dbo].[tr_CheckApp] TO [gn_DBO]
GRANT EXECUTE ON [dbo].[tr_GetAllAppCheckResults] TO [gn_DBO]
GRANT EXECUTE ON [dbo].[tr_GetRightNowCheckResults] TO [gn_DBO]
GRANT EXECUTE ON [dbo].[tr_GetDNZCheckResults] TO [CheckDNZ]
GO
