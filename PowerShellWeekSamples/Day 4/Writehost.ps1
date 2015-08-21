$a = get-service | select-object name, status

foreach ($i in $a)
  {      
    if ($i.status -eq "running")
      {write-host $i.name -foregroundcolor "green"}
    elseif ($i.status -eq "stopped")
      {write-host $i.name -foregroundcolor "red"}
    else
      {write-host $i.name}
   }
