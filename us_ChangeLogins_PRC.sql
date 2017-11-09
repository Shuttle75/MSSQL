if exists(select * from sysobjects where id = OBJECT_ID(N'[dbo].[us_ChangeLogins]')
  and OBJECTPROPERTY(id, N'IsProcedure') = 1 ) 
    DROP PROC [dbo].[us_ChangeLogins]
GO

SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS ON 
GO

PRINT 'CREATE PROCEDURE [dbo].[us_ChangeLogins]'
GO
/*-----------------------------------------------------------------------------
  Model  : TR
  Class  : Transport
  Author : Осадчий А.П.
  Desc   : Обновление пользователей в базе
  Result : 0 - OK, -1 - ERROR
  Last   : Осадчий А.П. / 2007-05-09
*/
CREATE PROCEDURE [dbo].[us_ChangeLogins]
AS BEGIN

  declare
     @ugID      int
    ,@LoginName varchar(128)
    ,@Password  varchar(50)
    ,@RetCode   int
    ,@SPID      int
    ,@SQLStr    varchar(255)

  if exists (select 1 from master..sysdatabases where Name = 'RTZ' and Category & 0x0001 = 1)
  begin 
	  select 
	     @ugID      = ugID
	    ,@LoginName = LoginName
	    ,@Password  = CONVERT(varchar(32), REVERSE([Password]))
	  from usUsers
	  where IsUnprocByPub = 1
	    and IsGroup <> 1
	    and LoginName not in ('sa', 'distributor_admin')
  end 
  else
  begin
	  select 
	     @ugID      = ugID
	    ,@LoginName = LoginName
	    ,@Password  = CONVERT(varchar(32), REVERSE([Password]))
	  from usUsers
	  where IsUnprocBySub = 1
	    and IsGroup <> 1
	    and LoginName not in ('sa', 'distributor_admin')
  end 


  if @@ROWCOUNT > 0 begin
    -- Киляем процесс, если он существует
    if exists (select 1 from master..sysprocesses where loginame = @LoginName)
    begin
      select @SPID = spid from master..sysprocesses where loginame = @LoginName
      select @SQLStr = 'kill ' + CONVERT(varchar(10), @SPID)
      exec(@SQLStr)
    end

    -- Удаляем логин
    if exists (select 1 from master.dbo.sysdatabases where [name] = 'RTZ')
    begin
      if exists (select 1 from RTZ.dbo.sysusers where [name] = @LoginName)
      begin
        exec @RetCode = sp_revokedbaccess
           @name_in_db = @LoginName
        if @RetCode <> 0 or @@ERROR <> 0
        begin
          RAISERROR(60003, 16, 10, 'sp_revokedbaccess') WITH SETERROR
          RETURN -1
        end
      end
    end

    if exists (select 1 from master.dbo.sysdatabases where [name] = 'RTZ_Hist')
    begin
      if exists (select 1 from RTZ_Hist.dbo.sysusers where [name] = @LoginName)
      begin
        exec @RetCode = RTZ_Hist.dbo.sp_revokedbaccess
         @name_in_db = @LoginName
        if @RetCode <> 0 or @@ERROR <> 0
        begin
          RAISERROR(60003, 16, 10, 'sp_revokedbaccess') WITH SETERROR
          RETURN -1
        end
      end
    end

    if exists (select 1 from master.dbo.sysxlogins where [name] = @LoginName)
    begin
      exec @RetCode = sp_droplogin
        @loginame = @LoginName
      if @RetCode <> 0 or @@ERROR <> 0
      begin
        RAISERROR(60003, 16, 10, 'sp_droplogin') WITH SETERROR
        RETURN -1
      end
    end

    if exists (select 1 from usUsers where ugID = @ugID and OvsCode is NOT NULL and IsActive = 1)
    begin
      -- Создаем новый логин
      exec @RetCode = sp_addlogin
         @loginame = @LoginName
        ,@passwd = @Password
      if @RetCode <> 0 or @@ERROR <> 0
      begin
        RAISERROR(60003, 16, 10, 'sp_addlogin') WITH SETERROR
        RETURN -1
      end
      -- RTZ
      exec @RetCode = sp_grantdbaccess
          @loginame = @LoginName
      if @RetCode <> 0 or @@ERROR <> 0
      begin
        RAISERROR(60003, 16, 10, 'sp_grantdbaccess') WITH SETERROR
        RETURN -1
        end
      exec @RetCode = sp_addrolemember
         @rolename   = 'gn_DBO'
        ,@membername = @LoginName
      if @RetCode <> 0 or @@ERROR <> 0
      begin
        RAISERROR(60003, 16, 10, 'sp_addrolemember') WITH SETERROR
        RETURN -1
      end
      -- RTZ_Hist
      exec @RetCode = RTZ_Hist.dbo.sp_grantdbaccess
         @loginame = @LoginName
      if @RetCode <> 0 or @@ERROR <> 0
      begin
        RAISERROR(60003, 16, 10, 'sp_grantdbaccess') WITH SETERROR
        RETURN -1
      end
      exec @RetCode = RTZ_Hist.dbo.sp_addrolemember
         @rolename   = 'gn_DBO'
        ,@membername = @LoginName
      if @RetCode <> 0 or @@ERROR <> 0
      begin
        RAISERROR(60003, 16, 10, 'sp_addrolemember') WITH SETERROR
        RETURN -1
      end
    end
  end

  if exists (select 1 from master..sysdatabases where Name = 'RTZ' and Category & 0x0001 = 1)
  begin 
    update usUsers set 
      IsUnprocByPub = 0
    where ugID = @ugID
  end 
  else
  begin
    update usUsers set 
      IsUnprocBySub = 0
    where ugID = @ugID
  end 

  RETURN 0
END -- procedure
GO

