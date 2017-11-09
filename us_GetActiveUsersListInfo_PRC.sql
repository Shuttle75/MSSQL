if exists( select 1 from sysobjects where id = OBJECT_ID(N'[dbo].[us_GetActiveUsersListInfo]') 
    and OBJECTPROPERTY(id, N'IsProcedure') = 1 )
  DROP PROC [dbo].[us_GetActiveUsersListInfo]
GO


SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
GO


PRINT 'CREATE PROCEDURE [dbo].[us_GetActiveUsersListInfo]'
GO
/*-----------------------------------------------------------------------------
  Model  : pm
  Class  : pm
  Author : �������� �.�.
  Desc   : ������� ������ �������� ������������� ��� ��������� ���(���� ����. ���� ��� �� �����)
  Last   : �������� �.�. / 2009-11-10
  Cursor :
    [UserName]    varchar(128)   -- ϲ�
   ,[UserLogin]   varchar(128)   -- ����
   ,[MACAddress]  varchar(12)    -- MAC ������
   ,[HostName]    varchar(128)   -- ��� ���������
   ,[ProgramName] varchar(128)   -- ��������
   ,[LoginTime]   datetime       -- ��� ���������� 
*/
CREATE PROCEDURE [dbo].[us_GetActiveUsersListInfo]
  @OVSCode varchar(10)
AS BEGIN
  SET NOCOUNT ON
  -- 
  select
   [UserName]    = u.ugName
  ,[UserLogin]   = LTRIM(RTRIM(CONVERT(varchar(128),s.loginame)))
  ,[MACAddress]  = LTRIM(RTRIM(CONVERT(varchar(48),s.net_address))) -- ������ ���������
  ,[HostName]    = LTRIM(RTRIM(CONVERT(varchar(128),s.hostname)))
  ,[ProgramName] = LTRIM(RTRIM(CONVERT(varchar(128),s.[program_name])))
  ,[LoginTime]   = s.login_time
 from master.dbo.sysprocesses s
   inner join ususers u on u.LoginName = s.loginame 
 where u.OvsCode = @OvsCode or @OvsCode is NULL
   and NULLIF(s.hostname,'') <>''
  --
  RETURN 0
END -- procedure
GO
GRANT EXEC ON [dbo].[us_GetActiveUsersListInfo] TO gn_DBO
GO
