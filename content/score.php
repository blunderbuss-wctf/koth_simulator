<?php

$fp = fopen("lock.txt", "r+");

if (flock($fp, LOCK_EX)) {
   // Setting this header instructs Nginx to disable fastcgi_buffering and disable
   // gzip for this request... data gets sent back to the user right away
   header('X-Accel-Buffering: no');

   file_put_contents("teams.txt", $_GET['team_name']." ".time()."\n", FILE_APPEND | LOCK_EX);

   $scores = nl2br(shell_exec("cat teams.txt | awk '{print $1}' | sort | uniq -c"));

$t = <<<EX
<html>
<head>
<title>King of the Hill</title>
</head>
<body>
<style>
body {background-color: #F6F4F3;}
</style>
<center>
The following team has scored:
<h1 style="font-family:Courier New;">{$_GET['team_name']}</h1>
<br>
Locking Access Point
</center>
<br>
<br>
<br>
<h2 style="font-family:Courier New;">Team Scores:</h2>
<h2>$scores</h2>
</body>
</html>
EX;

    echo $t;
    ob_flush();
    flush();

    exec("supervisorctl stop koth:*");
    sleep(100); // just trying to sleep long enough for everything to be stopped yet not have another team score
}

fclose($fp);

?>
