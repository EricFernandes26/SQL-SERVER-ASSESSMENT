import pyodbc
import csv
import os
import pandas as pd
from queries import queries
from sqlalchemy import create_engine, text
import getpass

def get_connection_info():
    print("Por favor, insira as informações de conexão com o banco de dados:")
    user = input("Username: ")
    password = getpass.getpass("Password: ")
    dbserver = input("Server-name: ")
    dbname = input("Database-name: ")
    return user, password, dbserver, dbname

def sqlserver_assessment_para_dataframe(user, password, dbserver, dbname, query):
    connection_str = f'mssql+pyodbc://{user}:{password}@{dbserver}/{dbname}?driver=ODBC+Driver+17+for+SQL+Server'
    engine = create_engine(connection_str)

    # Use a conexão do SQLAlchemy para executar a consulta
    connection = engine.connect()

    # Converta a string da consulta em um objeto TextClause
    query_obj = text(query)

    # Execute a consulta
    result = connection.execute(query_obj)

    # Verifique se há algum resultado antes de tentar obter as linhas
    if result.returns_rows:
        # Use o pandas para ler os resultados em um DataFrame
        df = pd.DataFrame(result.fetchall(), columns=result.keys())
    else:
        df = pd.DataFrame()

    # Feche a conexão após obter os resultados
    connection.close()

    return df

if __name__ == "__main__":
    if not os.path.exists('results'):
        os.makedirs('results')

    user, password, dbserver, dbname = get_connection_info()

    # Cria um escritor Pandas Excel usando o XlsxWriter como mecanismo.
    excel_writer = pd.ExcelWriter('./results/resultados_consultas.xlsx', engine='xlsxwriter')

    for query_key, query_value in queries.items():
        # Ajuste os nomes das abas para garantir que sejam <= 31 caracteres
        sheet_name = query_key[:31]
        
        df = sqlserver_assessment_para_dataframe(user, password, dbserver, dbname, query_value)

        # Escreve o DataFrame no arquivo Excel
        df.to_excel(excel_writer, sheet_name=sheet_name, index=False)

    # Fecha o escritor Pandas Excel (não é necessário chamar um método save() aqui)
    excel_writer.close()
