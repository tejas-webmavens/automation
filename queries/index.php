<a href="?start=true">Start logging</a> | <a href="?stop=true">Stop logging</a><br>
<hr>
<?php if(isset($_GET['refresh'])){?>
<meta http-equiv="refresh" content="<?php echo $_GET['refresh']?>; url="+document.location.href>
<input type="button" value="stop" onclick="window.location.href=window.location.origin + window.location.pathname">

<?php } else{ ?>
<form>
<input type="text" name="refresh" placeholder="Enter Seconds" value="" autocomplete="off">
</form>
<?php } ?>
<?
include("../database.conf.php");	
require_once('SqlFormatter.php');

if(isset($_GET['start'])){
	mysqli_query($con,"SET global general_log = 1");
	mysqli_query($con,"SET global log_output = 'table'");
}
if(isset($_GET['stop'])){
	mysqli_query($con,"SET global general_log = 0");
}

global $ignore_strings;

$query = "select * from mysql.general_log order by event_time desc limit 100";
$ignore_strings[] = $query;
$ignore_strings[] = "webcables20";
$ignore_strings[] = "select * from mysql.general_log";
$ignore_strings[] = "root@localhost on ";
$ignore_strings[] = "";


$result = mysqli_query($con,$query);

$test = mysql_fetch_full_result_array($result);

print_a($test);


function mysql_fetch_full_result_array($result)
{
    $table_result=array();
    $r=0;
    
    while($row = mysqli_fetch_assoc($result)){
        $arr_row=array();
        $c=0;
        foreach ($row as $k=>$v){
        	$arr_row[$k] = $v;
        }
/*        $_rows = mysqli_num_rows($result);
        while ($c < $_rows) {
            $col = mysqli_fetch_field($result);
            echo $row[$col -> name];
            $arr_row[$col -> name] = $row[$col -> name];            
            $c++;
        }    */
        $table_result[$r] = $arr_row;
        $r++;
    }    
    return $table_result;
}

function print_a($data){
global $ignore_strings;
	$_head = "";$_data="";
	$td_style="style='border-bottom-style: solid;border-bottom-width: thin;border-bottom-color: rgb(0, 0, 0);font-size: x-small;'";
	$td_style_large="style='border-bottom-style: solid;border-bottom-width: thin;border-bottom-color: rgb(0, 0, 0);font-size: large;'";
	$heading_style="style='background-color:#ccc;border-bottom-style: solid;border-bottom-width: thin;border-bottom-color: rgb(0, 0, 0);'";
	if($data){
	$cols = array_keys($data[0]);
	foreach ($cols as $c){
		$_head .= "<td $heading_style><b>".$c."</b></td>";
	}
	
	foreach ($data as $d){
		$_data .="<tr>";
		if(in_array($d['argument'],$ignore_strings)){
			continue;
		}
		foreach ($cols as $k=>$_c){
			if($_c == 'argument'){
				$_data .= "<td $td_style_large>".SqlFormatter::format($d[$_c])."</td>";				
			}else{
				$_data .= "<td $td_style>".$d[$_c]."</td>";
			}
		
		
			
		}
		$_data.="</tr>";
	}
		echo "Total records found ".count($data)."<table border=0 cellspacing=0 cellpadding=5><tr>".$_head."</tr>".$_data."</table>";

	}
}

exit(0);

?>
