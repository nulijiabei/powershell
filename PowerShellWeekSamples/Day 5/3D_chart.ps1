get-wmiobject win32_perfformatteddata_perfdisk_logicaldisk | select-object name,percentfreespace | out-chart -View3D_Enabled true -view3D_rotated true -Palette "ChartFX6.EarthTones"
