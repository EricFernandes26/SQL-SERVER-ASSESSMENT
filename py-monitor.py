import pyodbc
import csv
import os
from queries import queries

def sqlserver_assessment(csv_file_name, user, password, dbserver, dbname, query):
  
  if user is not None and password is not None:
    connection = pyodbc.connect(f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={dbserver};DATABASE={dbname};UID={user};PWD={password}')
  else:
    connection = pyodbc.connect(f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={dbserver};DATABASE={dbname}')

  # Execute the query.
  cursor = connection.execute(query)

  # Get the results of the query.
  results = []
  for row in cursor:
    results.append(row)

  # Create a CSV file and write the results to it.
  with open(f"./results/{csv_file_name}", 'w', newline='') as csvfile:
    csv_writer = csv.writer(csvfile)
    # Write the header row
    header = [column[0] for column in cursor.description]
    csv_writer.writerow(header)
    # Write the data rows
    csv_writer.writerows(results)

 # Close the cursor and connection.
  cursor.close()
  connection.close()

  return results

if __name__ == "__main__":
    if not os.path.exists('results'):
        os.makedirs('results')
        
    for query_key, query_value in queries.items():
        sqlserver_assessment(csv_file_name=f"{query_key}.csv", query=query_value, user='', password='', dbserver='', dbname='')