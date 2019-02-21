<?php

$ufilename = trim(ucfirst($_POST['hiddentable']));
$filename  = trim($_POST['hiddentable']);
$filename1 = trim($_POST['hiddentable1']);

$null = $_POST['IS_NULLABLE'];
$drop = $_POST['validate'];
$note = $_POST['note'];

echo "<pre>";
$columnname = $_POST['COLUMN_NAME'];
$comment = $_POST['COLUMN_COMMENT'];

$file = trim($_POST['hiddentable']).".php";
$fwrite = fopen("$file","w") or exit("<br><hr>Unable to open file</hr></br>");

$file = $fwrite;

$str = "<?php \nclass $ufilename extends SH_Base{ \n\n"	;
fputs($file, $str);

$count = count($_POST['COLUMN_NAME']);

for($i=0;$i<$count;$i++)
{
	fputs($file,"\t\tprivate \$".$columnname[$i]."; \t\t// $comment[$i]\n");
	
}

$str1 = "\n \t\tpublic function __construct(\$_idValue=null){
	\n\t\t\$this->dbFields = array(";
fputs($file, $str1);

$count = count($_POST['COLUMN_NAME']);

for($i=0;$i<$count;$i++)
{
	fputs($file,"'".$columnname[$i]."'");
	if($i!=$count-1)
	{
		fputs($file,",");
	}
}

$str2 = ");
\t\t\$this->tableName = \"$filename1\";
\t\tparent::__construct(\$_idValue);
\n\t\t//add those tables in add reference which are linked with this table's id;
\t\t//\$this->addReference('tablename','column name');
\n\t\t}\n\n";
fputs($file, $str2);

for($i=0;$i<$count;$i++)
{
	$ucolumnname[] = ucfirst($columnname[$i]);
	$str3 = "\t\tpublic function get$ucolumnname[$i](){
		\treturn \$this->$columnname[$i];
	\t}\n";
	fputs($file, $str3);
}


for($i=0;$i<$count;$i++)
{
	$ucolumnname[] = ucfirst($columnname[$i]);
	
	$str4 = "\t\tpublic function set$ucolumnname[$i](\$_$columnname[$i]){
		\t\$this->$columnname[$i] = \$_$columnname[$i];
		\treturn \$this;
	\t}\n ";
	fputs($file, $str4);
}

$str6 = "\t\tpublic function validate(){\n\n";
fputs($file, $str6);

	for($i=0;$i<$count;$i++)
	{
		if($null[$i]=='NO')
		{
			$str8 = "\t\t\t\$this->addValidator('$drop[$i]','$columnname[$i]','$note[$i]');\n";
			fputs($file,$str8);
		}
	}
	$str9 = "\n\t\t\treturn parent::validate();\n";
	fputs($file,$str9);
	
	
	$str7 = "\t\t}\n";
	fputs($file, $str7);


$str5 = "}\n?>";
fputs($file, $str5);

echo "File Created Successfully <b>($_POST[hiddentable].php)</b>";

?>