-- =============================================
-- Pushes security based on the current environment variable setting
-- =============================================

PRINT '******************************* Deplying Permissions for DeployType = $(DeployType) ************************************'
--:on error ignore

IF ( '$(DeployType)' = 'Dev')
BEGIN
 :r .\SecurityAdditionsDEV.sql
END
ELSE IF ( '$(DeployType)' = 'QA')
BEGIN
 :r .\SecurityAdditionsQA.sql
END
ELSE IF ( '$(DeployType)' = 'Production')
BEGIN
 :r .\SecurityAdditionsProduction.sql
END
ELSE IF ( '$(DeployType)' = 'Staging')
BEGIN
 :r .\SecurityAdditionsStaging.sql
END
ELSE
ELSE IF ( '$(DeployType)' = 'Local')
BEGIN
 :r .\SecurityAdditionsLocal.sql
END
BEGIN
 :r .\SecurityAdditionsDefault.sql
END
