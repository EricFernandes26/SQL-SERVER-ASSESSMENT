queries = {
    "sqlserver_assessment_top_50_employees": """
        SELECT TOP (50) [BusinessEntityID]
            ,[DepartmentID]
            ,[ShiftID]
            ,[StartDate]
            ,[EndDate]
            ,[ModifiedDate]
        FROM [AdventureWorks2022].[HumanResources].[EmployeeDepartmentHistory]
        """,

    "sqlserver_assessment_top_1_DatabaseLog": """
       /****** Script for SelectTopNRows command from SSMS  ******/
    SELECT TOP (1) [DatabaseLogID]
      ,[PostTime]
      ,[DatabaseUser]
      ,[Event]
      ,[Schema]
      ,[Object]
      ,[TSQL]
      ,[XmlEvent]
      FROM [AdventureWorks2022].[dbo].[DatabaseLog]
    """ 

    #"<nome que vai ser do arquivo results>": """
       # query (colar consulta)

     #""" 

}