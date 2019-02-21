<?
include("../database.conf.php");	
	
session_start();

function backup_tables($tables = '*')
{
  global $con,$triggerin_db_name;
  
  //get all of the tables
  if($tables == '*')
  {
    $tables = array();
    $result = mysqli_query($con,'SHOW TABLES');
    while($row = mysqli_fetch_row($result))
    {
      $tables[] = $row[0];
    }
  }
  else
  {
    $tables = is_array($tables) ? $tables : explode(',',$tables);
  }
  //cycle through
  foreach($tables as $table)
  {
    $result = mysqli_query($con,'SELECT * FROM '.$table);
    $num_fields = mysqli_num_fields($result);
    
    $return.= 'DROP TABLE '.$table.';';
    $row2 = mysqli_fetch_row(mysqli_query($con,'SHOW CREATE TABLE '.$table));
    $return.= $row2[1].";";
    
    for ($i = 0; $i < $num_fields; $i++) 
    {
      while($row = mysqli_fetch_row($result))
      {
        $return.= 'INSERT INTO '.$table.' VALUES(';
        for($j=0; $j<$num_fields; $j++) 
        {
          $row[$j] = addslashes($row[$j]);
          $row[$j] = str_replace("\n","\\n",$row[$j]);
          if (isset($row[$j])) { $return.= '"'.$row[$j].'"' ; } else { $return.= '""'; }
          if ($j<($num_fields-1)) { $return.= ','; }
        }
        $return.= ");";
      }
    }
    $return.="\n\n\n";
  }
  
	$sql="SELECT * FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='".$triggerin_db_name."'";
	$result=mysqli_query($con,$sql);
	while ($result && $row=mysqli_fetch_assoc($result)) {
		$sql_create = "CREATE TRIGGER `{$row['TRIGGER_NAME']}` {$row['ACTION_TIMING']} {$row['EVENT_MANIPULATION']} ON `{$row['EVENT_OBJECT_TABLE']}`";
		$sql_create .= "\n".str_replace("\t",'',$row['ACTION_STATEMENT'])."\n";
		$return .= "\n/*\n".$sql_create."*/\n";
	}
  
  //save file
  $filename = 'dump/db-backup-'.time().'-'.(md5(implode(',',$tables))).'.sql';
  $handle = fopen($filename,'w+');
  fwrite($handle,$return);
  fclose($handle);
  return $filename;
}


function run_sql($q) {
	global $db;
	
	$db->query($q);
	if($db->error!="" && strpos($db->error,"Duplicate")===false) {
		return "<span style='color:#EE1111'>Error: ".$db->error."<br><i><b>".basename($f)."</b> $q</i> </span><br><hr size=1>";
	} else {
		if(strpos($db->error,"Duplicate")===false) {
			return "<span style='color:#11CC11'>Done: $q </span><br><hr size=1>";
		} else {
			return "<span style='color:#115511'>Previously executed: $q </span><br><hr size=1>";
		}
	}
}

$db = mysqli_connect($triggerin_db_host,$triggerin_db_user,$triggerin_db_pass,$triggerin_db_name);

if($_GET["runsql"]) {
	echo run_sql($_SESSION["runsql"][$_GET["runsql"]]);
	exit;
}
echo "Backing up db...";
//backup_tables();
echo "complete<br>";

$files = glob(dirname(__FILE__)."/changes_*.sql");

rsort($files);
while($f = array_shift($files)) {
	echo "<h1>".basename($f)."</h1>";
	$sql = explode(";",file_get_contents($f));
	foreach($sql as $s) {
		if(trim($s)=="") continue;
		
		try {
			list($sql_type) = explode(" ",trim($s));
			
			if(trim($sql_type)=="CREATE" || strpos($s,"ADD `")!==false) {
				echo run_sql($s);
			} else {
				$uid = uniqid();
				$_SESSION["runsql"][$uid] = $s;
				echo "<div id='runsql_$uid' style='background-color:#FFFFFF'><h3>Query needs confirmation <small>(Click to run)</small></h3><a href='#' onclick='runsql(\"$uid\");return false;'>$s</a><br><hr size=1></div>";
			}
			
			
			
		} catch(Exception $e) {
			echo "<span style='color:#EE1111'>Mysql Exception: ".$e->getMessage()."<br><i><b>".basename($f)."</b> $s</i></span><br><hr size=1>";
		}
	}
}
?>
<style>
	* {
		font-family: Arial;
		font-size: 13px;
	}
</style>
<script src="jquery.js"></script>
<script>
	function runsql(uid) {
		$("#runsql_"+uid).html("Running SQL...");
		$.get("?remote=<?= $_GET["remote"] ?>&runsql="+uid, function(r) {
			$("#runsql_"+uid).html(r);
			
		});
	}
</script>
