get-wmiobject win32_perfformatteddata_perfdisk_logicaldisk | select-object name,percentfreespace | where-object {$_.Name -eq "_Total"} | out-gauge
