<html>
<head>
<title>Guards Ban List</title>
<style>
body {
	background-color: #555555;
}

.thread_title
{
	background-color: #1C6EA4;
	color: white;
	text-align: center;
	border-bottom: 100% solid #1C6EA4;
}

table.blueTable {
  border: 1px solid #1C6EA4;
  background-color: #FFFFFF;
  width: 100%;
  height: 5px;
  text-align: center;
  border-collapse: collapse;
}
table.blueTable td, table.blueTable th {
  border: 2px solid #AAAAAA;
  padding: 3px 2px;
}
table.blueTable tbody td {
  font-size: 13px;
}
table.blueTable tr:nth-child(even) {
  background: #D0E4F5;
}
table.blueTable thead {
  background: #1C6EA4;
  background: -moz-linear-gradient(top, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
  background: -webkit-linear-gradient(top, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
  background: linear-gradient(to bottom, #5592bb 0%, #327cad 66%, #1C6EA4 100%);
  border-bottom: 2px solid #444444;
}
table.blueTable thead th {
  font-size: 16px;
  font-weight: bold;
  color: #FFFFFF;
  text-align: center;
  border-left: 2px solid #D0E4F5;
}
table.blueTable thead th:first-child {
  border-left: none;
}

table.blueTable tfoot {
  font-size: 14px;
  font-weight: bold;
  color: #FFFFFF;
  background: #D0E4F5;
  background: -moz-linear-gradient(top, #dcebf7 0%, #d4e6f6 66%, #D0E4F5 100%);
  background: -webkit-linear-gradient(top, #dcebf7 0%, #d4e6f6 66%, #D0E4F5 100%);
  background: linear-gradient(to bottom, #dcebf7 0%, #d4e6f6 66%, #D0E4F5 100%);
  border-top: 2px solid #424242;
}
table.blueTable tfoot td {
  font-size: 14px;
}
table.blueTable tfoot .links {
  text-align: right;
}
table.blueTable tfoot .links a{
  display: inline-block;
  background: #1C6EA4;
  color: #FFFFFF;
  padding: 2px 8px;
  border-radius: 5px;
}
</style>
</head>
<body>
<h1 class="thread_title"> Guards Ban List </h1>
<table class="blueTable">
	<thead>
	<tr>
	<th> Player nickname </th>
	<th> Player SteamID </th>
	<th> Ban Duration </th>
	<th> Reason </th>
	<th> Admin name </th>
	<th> Admin SteamID </th>
	</tr>
	</thead>
	
	<?php
	$host = "127.0.0.1";
	$username = "root";
	$pass = "pass";
	$dbname = "jailbreak";
	
	//$mysqlConnection = mysql_connect($host, $username, $pass);
	$mysqlConnection = new mysqli($host, $username, $pass, $dbname);
	// Check connection
	if ($mysqlConnection->connect_error) {
		die("Connection failed: " . $conn->connect_error);
	}
	
	$sql = "SELECT * FROM `jb_CTbans`;";
	$result = $mysqlConnection->query($sql);
	
	if ($result->num_rows > 0) {
		echo "<tbody>";
		// output data of each row
		while($row = $result->fetch_assoc()) {
			echo "<tr>".
				"<td>" . $row["player_name"] . "</td>".
				"<td>" . $row["authid"] . "</td>".
				((time() > intval($row["length"])) ? "<td style='background-color: green;'>":"<td>") . gmdate("Y-m-d\TH:i:s\Z", $row["length"]) . "</td>".
				"<td>" . $row["reason"] . "</td>".
				"<td>" . $row["admin_name"] . "</td>".
				"<td>" . $row["admin_authid"] . "</td>".
				"</tr>";
		}
		echo "</tbody>";
	} else {
		echo "<tr>No one is banned !</tr>";
	}
	
	$mysqlConnection->close();
	?>
</table>
</body>
</html>

<!-- credits to devtable.com for the style sheet :) --->