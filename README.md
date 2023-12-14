# SQL-SERVER-ASSESSMENT
Assessment tool for sql server

This tool is under development and studies to tighten the SQL Server assessment

Attention points:
  For the program to work you need your sql server to accept connections from your user using SQL Server authentication.
  Make sure your user has the necessary permissions to run the program.

1 - Download the project zip

2 - Unzip the file and rename the folder to “SQL-SERVER-ASSESSMENT”

3 - Then copy the folder to the desktop. The program will only run if you leave the folder on the desktop, otherwise errors will occur.

4 - Then run CMD in the SQL-SERVER-ASSESSMENT folder on the desktop.

5 - Now we are going to install the dependencies for the program to work and to do this we are going to run the **Instaler-python.bat** file and the expected result is this and then the file will download the necessary libraries for the program to work:
![image](https://github.com/EricFernandes26/SQL-SERVER-ASSESSMENT/assets/83287307/33bbd57e-819e-46c4-b929-e5bb704a5386)

5.1 - After installing the dependencies you can close CMD and open another one in the same folder.

6.1 - When you run this file it will ask for some outputs.
Username
Password
Server
Database name

After filling in the items above this is the result
![image](https://github.com/EricFernandes26/SQL-SERVER-ASSESSMENT/assets/83287307/345e5091-c3e4-4588-8f2a-c322ec92edcf)

The script will ask if you also want to collect information from the machine's disks. If you want to run the script, these are the options:
![image](https://github.com/EricFernandes26/SQL-SERVER-ASSESSMENT/assets/83287307/b1cc6f77-4b25-46ad-b529-e0b1d25737b4)

If you select [R] Run Once the final result will be as follows:
![image](https://github.com/EricFernandes26/SQL-SERVER-ASSESSMENT/assets/83287307/e5f91862-61bd-4b16-a4c2-8525ca7abe9a)



7 - now in the results folder you can view the csv file with the instance recommendation for AWS:
![image](https://github.com/EricFernandes26/SQL-SERVER-ASSESSMENT/assets/83287307/b03144c7-1697-4f92-85e3-b55e6ba822df)



