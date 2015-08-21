#1.   We'll need to load the MySQL.Net connector into memory by entering the following command with the full path to the MySQL.Data.dll file (note that your path may differ):

[void][system.reflection.Assembly]::LoadFrom("C:\Program Files\MySQL\Connector NET 6.4.4\Assemblies\v2.0\MySQL.Data.dll")
Here is the default path for 64 bit systems:

[void][system.reflection.Assembly]::LoadFrom("C:\Program Files (x86)\MySQL\MySQL Connector Net 6.4.4\Binaries\.NET 2.0\MySQL.Data.dll")
The LoadWithPartialName() function also does the job:

[void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data") 
#2.   Create a variable to hold the connection:
$myconnection = New-Object MySql.Data.MySqlClient.MySqlConnection
#3.   Set the connection string (replace the user id and password with your own):
$myconnection.ConnectionString = "database=test;server=localhost;Persist Security Info=false;user id=myid;pwd=mypw"
#4.   Call the Connection object's Open() method:
$myconnection.Open()
#5.   Create a new Command and set the text to your query:

$command = $myconnection.CreateCommand()
$command.CommandText = "select * from powershell_tests";
6.   Create a new Dataset to store the results of the query:

$dataSet = New-Object System.Data.DataSet 
#7.   Process the results. In this example we're just going to display all of the table contents in the console. We can fetch each field value using the GetValue() function, passing in the zero-based column index. The writing of each value to the console is done using the write-output command:

write-output $reader.GetValue(0).ToString()
A While loop is utilized to iterate over all the results:

while
($reader.Read()) {
  for ($i= 0; $i -lt $reader.FieldCount; $i++) {
    write-output $reader.GetValue($i).ToString()
  }
}
#Closing the Database Connection
#In theory the database connection will be closed when PowerShell finishes. However, it is always a good practice to close any open connections explicitly:

$connection.Close()