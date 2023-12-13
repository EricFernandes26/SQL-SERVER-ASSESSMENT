import pyodbc
import csv
import os
from queries import queries
import getpass

def get_connection_info():
    print("Please enter your database connection information:")
    user = input("Username: ")
    password = getpass.getpass("Password: ")
    dbserver = input("Server: ")
    dbname = input("Database name: ")
    return user, password, dbserver, dbname

def sqlserver_assessment(csv_file_name, user, password, dbserver, dbname, query):
    if user is not None and password is not None:
        connection = pyodbc.connect(f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={dbserver};DATABASE={dbname};UID={user};PWD={password}')
    else:
        connection = pyodbc.connect(f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={dbserver};DATABASE={dbname}')

    cursor = connection.execute(query)

    # Obter todas as linhas de uma vez
    results = cursor.fetchall()

    with open(f"./results/{csv_file_name}", 'w', newline='') as csvfile:
        csv_writer = csv.writer(csvfile, delimiter=';')
        
        # Escreve a linha de cabeçalho
        header = [column[0] for column in cursor.description]
        csv_writer.writerow(header)

        # Escreve as linhas de dados
        csv_writer.writerows(results)

    cursor.close()
    connection.close()

    return results

if __name__ == "__main__":
    if not os.path.exists('results'):
        os.makedirs('results')

    user, password, dbserver, dbname = get_connection_info()

    for query_key, query_value in queries.items():
        sqlserver_assessment(csv_file_name=f"{query_key}.csv", query=query_value, user=user, password=password, dbserver=dbserver, dbname=dbname)
