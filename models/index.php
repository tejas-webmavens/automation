<style>
td{font-family:verdana; font-size:13px;}
</style>
<?php
error_reporting(E_ALL);
ini_set('display_errors', '1');

include("../database.conf.php");
global $dbname;
$dbname = $triggerin_db_name;

echo "<form method='post'>";
echo "<table width=100%>";
echo "<tr><td align=center>";
echo "<b>Enter Table Name : </b><input type=text name='table' value=''>";
echo "</td></tr>";
echo "<tr><td align=center>";
echo "<input type='submit' name='Addtable' value='Submit'>";
echo "</td></tr>";
echo "</table>";
echo "</form>";

if(isset($_POST['Addtable']))
{
	$tablename = $_POST['table'];
	
	//echo $query = "SELECT COLUMN_NAME WHERE TABLE_NAME = '$tablename'";
	//$query = "SELECT distinct(COLUMN_NAME),COLUMN_COMMENT,IS_NULLABLE FROM INFORMATION_SCHEMA.columns WHERE TABLE_NAME = '$tablename' and TABLE_SCHEMA ='$db'";
	
	/*
	 * new query to not include audit fields in class file generation
	 */
	$query = "SELECT distinct(COLUMN_NAME),COLUMN_COMMENT,IS_NULLABLE FROM INFORMATION_SCHEMA.columns WHERE TABLE_NAME = '$tablename' and TABLE_SCHEMA ='$dbname' and COLUMN_NAME not in('audit_created_by', 'audit_updated_by', 'audit_created_date', 'audit_updated_date' ,'audit_ip')";
	$result = mysqli_query($con,$query);
	//ucwords(strtolower($bar))
	$tablename1 = ucwords(strtolower(str_replace("_","",$tablename)));

	echo "<form action='classgen2.php' method='post'>";
	echo "<table border=0 width=100% style='border:1px solid #006699'>";
	
	echo "<tr><td align=center colspan=5 bgcolor=#006699>";
	echo "<font color=white><b>Table Name : </b>$tablename";
	echo "</td></tr>";

	echo "<tr><td bgcolor=#006699 colspan=5></td></tr>";
	
	echo "<tr>";
	
	echo "<td align=center bgcolor=#006699>";
	echo "<font color=white><b>Column Name";
	echo "</td>";
	
	echo "<td align=center bgcolor=#006699>";
	echo "<font color=white><b>Comments";
	echo "</td>";
	
	echo "<td align=center bgcolor=#006699>";
	echo "<font color=white><b>Default";
	echo "</td>";
	
	echo "<td align=center bgcolor=#006699>";
	echo "<font color=white><b>Select Validation";
	echo "</td>";
	
	echo "<td align=center bgcolor=#006699>";
	echo "<font color=white><b>Enter Note For Validation";
	echo "</td>";
	
	echo "<tr><td bgcolor=#006699 colspan=5></td></tr>";
	
	echo "</tr>";
	echo "<tr><td>";
	echo "<input type=hidden name='hiddentable' value='$tablename1'>";
	echo "</td></tr>";
	echo "<tr><td>";
	echo "<input type=hidden name='hiddentable1' value='$tablename'>";
	echo "</td></tr>";
	
	while($row = mysqli_fetch_assoc($result))
	{		
		echo "<tr><td align=center>";
		echo "<input type=text name='COLUMN_NAME[]' value='$row[COLUMN_NAME]' readonly>";
		echo "</td>";
		echo "<td align=center>";
		echo "<input type=text name='COLUMN_COMMENT[]' value='$row[COLUMN_COMMENT]' readonly>";
		echo "</td>";
		echo "<td align=center>";
		echo "<input type=text name='IS_NULLABLE[]' value='$row[IS_NULLABLE]' readonly>";
		echo "</td>";
		echo "<td align=center>";
		
		echo "<select name='validate[]'>";
		echo "<option value=''>Select</option>";
		echo "<option value='NotEmpty'>Not Empty</option>";
		echo "<option value='EmailAddress'>Email Address</option>";
		echo "<option value='Date'>Date</option>";
		echo "<option value='DigitsOnly'>Digits Only</option>";
		echo "<option value='IP'>IP Address</option>";
		echo "</select>";
		echo "</td>";
		
		echo "<td align=center>";
		echo "<input type=text name=note[]>";
		echo "</td>";
		echo "</tr>";
	}
	echo "<tr><td align=center colspan=5>";
	echo "<input type='submit' name='Addrecord' value='Submit'>";
	echo "</td></tr>";
	echo "</table>";
	echo "</form>";	
}
?>