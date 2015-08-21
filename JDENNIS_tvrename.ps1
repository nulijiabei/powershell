[Reflection.Assembly]::LoadFrom( (Resolve-Path "C:\Powershell\taglib-sharp.dll") ) | Out-Null

function GetVideoInformation {param ($filename)
	[int]$Height = 0
    try {
		$media = [TagLib.File]::Create($filename)
		$Height = $media.Properties.VideoHeight 	
	}
	catch {
		
	}
	return $Height
}

function IsDirEmpty {param ($Dir)
	$items = Get-ChildItem -LiteralPath $Dir -Recurse
	[boolean]$DirectoryEmpty = $true 
	foreach($item in $items) {
	    if ($item.Name -ne $null) {
		    $DirectoryEmpty = $false
			break
		}    
	}
	return $DirectoryEmpty 
}

#$ErrorActionPreference = "SilentlyContinue"
#$ErrorActionPreference = 
#$TorrentFiles = Get-ChildItem -Path '$($DestPath)Episodes_Unsorted' -Filter *.avi -Recurse

#$TorrentFiles = Get-ChildItem -Path '$($DestPath)MovieSort' -Filter *.avi -Recurse
#$TorrentFiles = Get-ChildItem -Path '$($DestPath)Fairplay' -Filter *.avi -Recurse

#$TorrentFiles = Get-ChildItem -Path 'E:\Sorted' -Filter *.avi -Recurse
#$TorrentFiles = Get-ChildItem -Path 'G:\Movies 2' -Filter *.mkv -Recurse

$TorrentFiles = Get-ChildItem -Path 'E:\Sorted' -Recurse -include  *.avi, *.mp4, *.mkv

[string]$DestPath = "K:\"

[string]$DestDir = "$($DestPath)Episodes"
[string]$MovieDest = "$($DestPath)Movies"
[string]$DestDirDup = "$($DestPath)Duplicates"
[string]$Samples = "$($DestPath)Samples"

$Now = Get-Date
$LastWrite = $Now.AddDays(-30) 

foreach ($file in $TorrentFiles ) {  
	Write-Host "`n"
	[string]$Filename = $file.Name
	[string]$Directory = $file.Directory
	$DirResult = IsDirEmpty $Directory 
	Write-Host "Processing File $filename"
	if ($DirResult -eq $true) {
	    Write-Host "The $Directory has no files in it, i would have deleted it"
	}
	else {
	
		if ($file.CreationTime -le $LastWrite) {

			[string]$WithoutDots = $Filename
			$WithoutDots = $WithoutDots.replace("."," ")
			$WithoutDots = $WithoutDots.replace("-"," ")
			$WithoutDots = $WithoutDots.replace("_"," ")
		    $WithoutDots = $WithoutDots.Replace("["," ")
		    $WithoutDots = $WithoutDots.Replace("]"," ")		
			[boolean]$processfile = $false
			
			
			if ($Filename.contains("[") -eq $true) {
			   #write-host "conatins brackets $WithoutDots"		   
			   #[System.IO.File]::Move($file.FullName, $Directory+"\"+$NewName) 		   
			}
			
			switch -regex ($WithoutDots) {
			"(the colbert report)" {
			
			#The.Colbert.Report.2011.05.16.Alison.Klayman.HDTV.XviD-FQM.[VTV]
			    $RegexEpisodeNumber = [regex]'(20\d{2})'
				$Results = $RegexEpisodeNumber.matches($WithoutDots)	
				[string]$FullEpisodeNumber = $($Results.get_Item(0)).value	 
				$Season = $FullEpisodeNumber
				$ShowName = "The Colbert Report"
				[int]$intSeason = $Season
				$processfile = $true
			}
			
			"(\d{1,2}x\d{2})" {
			    #write-host "match $WithoutDots " 
				$RegexEpisodeNumber = [regex]'(\d{1,2}x\d{2})'
				$Results = $RegexEpisodeNumber.matches($WithoutDots)	
				[string]$FullEpisodeNumber = $($Results.get_Item(0)).value	   
				[string]$ShowName = $($WithoutDots.Substring(0,$WithoutDots.ToUpper().IndexOf($FullEpisodeNumber.ToUpper()))).Trim()
				$Season = $null
				
				$Season = $FullEpisodeNumber.Substring(0,$FullEpisodeNumber.ToLower().IndexOf("x"))
				$Season = $Season.ToUpper().Replace("S","")
				[int]$intSeason = $Season			
				
				$EpNumber = $FullEpisodeNumber.Substring($FullEpisodeNumber.ToLower().IndexOf("x"))
				$EpNumber = $EpNumber.ToUpper().Replace("X","")					
				if ($EpNumber.Length -eq 1) {$EpNumber = "0"+$EpNumber}
				
				if ($($ShowName.Length) -gt 0) {
					$EpisodeNumber = $Season+"x"+$EpNumber
					[string]$EpisodeTitle = ""
				    [string]$url = "http://services.tvrage.com/feeds/episodeinfo.php?key=nhdAfh8lSmtciblKjqmf&show=$ShowName&exact=1&ep=$EpisodeNumber"						
					try {
						
						[xml]$xml = (new-object System.Net.WebClient).DownloadString($url)
						
						
						[string]$EpisodeTitle = $xml.show.episode.title			
						
						$EpisodeTitle = $EpisodeTitle.replace("\"," ")
						$EpisodeTitle = $EpisodeTitle.replace("/"," ")
						$EpisodeTitle = $EpisodeTitle.replace("*"," ")
					    $EpisodeTitle = $EpisodeTitle.Replace("?"," ")
						$EpisodeTitle = $EpisodeTitle.Replace(":"," ")
						$EpisodeTitle = $EpisodeTitle.Replace("<"," ")
						$EpisodeTitle = $EpisodeTitle.Replace(">"," ")
						$EpisodeTitle = $EpisodeTitle.Replace("|"," ")
						$EpisodeTitle = $EpisodeTitle.Replace(""""," ")
					    $EpisodeTitle = $EpisodeTitle.Replace("  "," ")						
						
						
						[string]$OfficialShowTitle = $xml.show.name
						
						$OfficialShowTitle = $OfficialShowTitle.replace("\"," ")
						$OfficialShowTitle = $OfficialShowTitle.replace("/"," ")
						$OfficialShowTitle = $OfficialShowTitle.replace("*"," ")
					    $OfficialShowTitle = $OfficialShowTitle.Replace("?"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace(":"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace("<"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace(">"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace("|"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace(""""," ")
					    $OfficialShowTitle = $OfficialShowTitle.Replace("  "," ")						
						
						if ($EpisodeTitle.Length -gt 3 ) {
						    $processfile = $true
						}
										
					}
					
					catch {
					    Write-Host "`tFailed to get $url $_"
					}
				}
				else {
					#$FullEpisodeNumber			
				}  		  		   
			}		
			
			"(Season \d{1,2} Episode \d{2})" {
			    #write-host "match $WithoutDots " 
				$RegexEpisodeNumber = [regex]'(Season \d{1,2} Episode \d{2})'
				$Results = $RegexEpisodeNumber.matches($WithoutDots)	
				[string]$FullEpisodeNumber = $($Results.get_Item(0)).value	   
				[string]$ShowName = $($WithoutDots.Substring(0,$WithoutDots.ToUpper().IndexOf($FullEpisodeNumber.ToUpper()))).Trim()
				$Season = $null
				
				$RegexEpisodeNumber = [regex]'(Season \d{1,2})'
				[string]$Season = $RegexEpisodeNumber.matches($WithoutDots)
				$Season = $Season.replace("Season","").Trim()
				[int]$intSeason = $Season			
				
				$RegexEpisodeNumber = [regex]'(Episode \d{1,2})'			
				[string]$EpNumber = $RegexEpisodeNumber.matches($WithoutDots)
				$EpNumber = $EpNumber.replace("Episode","").Trim()

				if ($EpNumber.Length -eq 1) {$EpNumber = "0"+$EpNumber}
				
				if ($($ShowName.Length) -gt 0) {
					$EpisodeNumber = $Season+"x"+$EpNumber
					[string]$EpisodeTitle = ""
				    [string]$url = "http://services.tvrage.com/feeds/episodeinfo.php?key=nhdAfh8lSmtciblKjqmf&show=$ShowName&exact=1&ep=$EpisodeNumber"						
					try {
						[xml]$xml = (new-object System.Net.WebClient).DownloadString($url)
						[string]$EpisodeTitle = $xml.show.episode.title			
						
						$EpisodeTitle = $EpisodeTitle.replace("\"," ")
						$EpisodeTitle = $EpisodeTitle.replace("/"," ")
						$EpisodeTitle = $EpisodeTitle.replace("*"," ")
					    $EpisodeTitle = $EpisodeTitle.Replace("?"," ")
						$EpisodeTitle = $EpisodeTitle.Replace(":"," ")
						$EpisodeTitle = $EpisodeTitle.Replace("<"," ")
						$EpisodeTitle = $EpisodeTitle.Replace(">"," ")
						$EpisodeTitle = $EpisodeTitle.Replace("|"," ")
						$EpisodeTitle = $EpisodeTitle.Replace(""""," ")
					    $EpisodeTitle = $EpisodeTitle.Replace("  "," ")						
												
						[string]$OfficialShowTitle = $xml.show.name
						
						$OfficialShowTitle = $OfficialShowTitle.replace("\"," ")
						$OfficialShowTitle = $OfficialShowTitle.replace("/"," ")
						$OfficialShowTitle = $OfficialShowTitle.replace("*"," ")
					    $OfficialShowTitle = $OfficialShowTitle.Replace("?"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace(":"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace("<"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace(">"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace("|"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace(""""," ")
					    $OfficialShowTitle = $OfficialShowTitle.Replace("  "," ")						
						
						if ($EpisodeTitle.Length -gt 3 ) {
						    $processfile = $true
						}
										
					}
					
					catch {
					    Write-Host "`tFailed to get $url"
					}
				}
				else {
					#$FullEpisodeNumber			
				}  		  		   
			}
			"(S\d{1,2}E\d{2})" {
			    
				$RegexEpisodeNumber = [regex]'([sS]\d{1,2}[eE]\d{2})'
				$Results = $RegexEpisodeNumber.matches($WithoutDots)	
				[string]$FullEpisodeNumber = $($Results.get_Item(0)).value	   
				[string]$ShowName = $($WithoutDots.Substring(0,$WithoutDots.ToUpper().IndexOf($FullEpisodeNumber.ToUpper()))).Trim()
				$Season = $null
				
				$Season = $FullEpisodeNumber.Substring(0,$FullEpisodeNumber.ToLower().IndexOf("e"))
				$Season = $Season.ToUpper().Replace("S","")
				
				$EpNumber = $FullEpisodeNumber.Substring($FullEpisodeNumber.ToLower().IndexOf("e"))
				$EpNumber = $EpNumber.ToUpper().Replace("E","")			
				if ($EpNumber.Length -eq 1) {$EpNumber = "0"+$EpNumber}
				[int]$intSeason = $Season			
				
				if ($($ShowName.Length) -gt 0) {
					$EpisodeNumber = $Season+"x"+$EpNumber
					[string]$EpisodeTitle = ""
				    [string]$url = "http://services.tvrage.com/feeds/episodeinfo.php?key=nhdAfh8lSmtciblKjqmf&show=$ShowName&exact=1&ep=$EpisodeNumber"						
					try {
						[xml]$xml = (new-object System.Net.WebClient).DownloadString($url)
						[string]$EpisodeTitle = $xml.show.episode.title			
						$EpisodeTitle = $EpisodeTitle.replace("\"," ")
						$EpisodeTitle = $EpisodeTitle.replace("/"," ")
						$EpisodeTitle = $EpisodeTitle.replace("*"," ")
					    $EpisodeTitle = $EpisodeTitle.Replace("?"," ")
						$EpisodeTitle = $EpisodeTitle.Replace(":"," ")
						$EpisodeTitle = $EpisodeTitle.Replace("<"," ")
						$EpisodeTitle = $EpisodeTitle.Replace(">"," ")
						$EpisodeTitle = $EpisodeTitle.Replace("|"," ")
						$EpisodeTitle = $EpisodeTitle.Replace(""""," ")
					    $EpisodeTitle = $EpisodeTitle.Replace("  "," ")							
						
						[string]$OfficialShowTitle = $xml.show.name				
						$OfficialShowTitle = $OfficialShowTitle.replace("\"," ")
						$OfficialShowTitle = $OfficialShowTitle.replace("/"," ")
						$OfficialShowTitle = $OfficialShowTitle.replace("*"," ")
					    $OfficialShowTitle = $OfficialShowTitle.Replace("?"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace(":"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace("<"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace(">"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace("|"," ")
						$OfficialShowTitle = $OfficialShowTitle.Replace(""""," ")
					    $OfficialShowTitle = $OfficialShowTitle.Replace("  "," ")																		
										
						if ($EpisodeTitle.Length -gt 3 ) {
						    $processfile = $true
						}									
					}				
					catch {
					    Write-Host "`tFailed to get $url"
					}
				}
				else {
					#$FullEpisodeNumber			
				}
			}
			#"(S\d{2}\E\d{2}\)$" {}
			default {
			    #Write-Host "not match $filename"
				}
			}	
			
			if ($processfile -eq $true ) {			
				$VideoHeight = GetVideoInformation $file.FullName			    
				$ChangeRequired = $false
				If ($EpisodeTitle.Length -gt 2) {						
					if ($OfficialShowTitle.Length -gt  3 ) {
					    $ShowName = $OfficialShowTitle
					}												
					$TempEpisodeNumber = "S"+$Season+"E"+$EpNumber
					
					if ($VideoHeight -ge 720) {
					    $NewName = "$ShowName - $TempEpisodeNumber - $EpisodeTitle - $VideoHeight"+$($file.Extension)
					}
					else {
					    $NewName = "$ShowName - $TempEpisodeNumber - $EpisodeTitle"+$($file.Extension)
					}
					
					
					
					if ($($file.FullName) -ne $NewName ){
						try {
						    #Rename-Item -Path "$($file.FullName)" -NewName $NewName
							[System.IO.File]::Move($file.FullName, $Directory+"\"+$NewName) 
							$Filename = $NewName
						    Add-Content -Path "$($DestPath)Rename-Log.txt" -Value "Renamed '$($file.fullname)' to '$($NewName)'"
						}
						catch {
						    Write-Host "`tFailed: $NewName"
							Write-Host "`t$_"
						    Add-Content -Path "$($DestPath)Rename-Log.txt" -Value "Failed to rename '$($file.fullname)' to '$($NewName)'"
						}						
					}				
					else {
						Write-Host "`tRename not required, file name was already '$NewName'"
					}
				}
				
				else {					
					if ($Filename.tolower().Contains("[") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("hdtv") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("xvid-fqm") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("[vtv]") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("fqm") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("proper") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("fever") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("asap") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("mkv") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("asap") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("xvid") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("lmao") -eq $true ) {$ChangeRequired = $true}
					if ($Filename.tolower().Contains("2hd") -eq $true ) {$ChangeRequired = $true}
					
					if ($ChangeRequired -eq $true) {
						[string]$NewName = $WithoutDots
						
						$NewName = $NewName -ireplace "hdtv", ""
						$NewName = $NewName -ireplace "xvid-", ""
						$NewName = $NewName -ireplace "vtv", ""
						$NewName = $NewName -ireplace "fqm", ""
						$NewName = $NewName -ireplace "lol", ""
						$NewName = $NewName -ireplace "avi", ""
						$NewName = $NewName -ireplace "mp4", ""
						$NewName = $NewName -ireplace "fever", ""
						$NewName = $NewName -ireplace "proper", ""
						$NewName = $NewName -ireplace "asap", ""
						$NewName = $NewName -ireplace "mkv", ""
						$NewName = $NewName -ireplace "xvid", ""
						$NewName = $NewName -ireplace "lmao", ""
						$NewName = $NewName -ireplace "2hd", ""
						
						$NewName = $NewName.Replace("[","")
						$NewName = $NewName.Replace("]","")
						$NewName = $NewName.Replace("  "," ")
						$NewName = $NewName.Trim()
						$NewName = $NewName + "$($file.Extension)"
						
						$Filename = $NewName

						try {
						    #Rename-Item -Path "$($file.FullName)" -NewName $NewName
							[System.IO.File]::Move($file.FullName, $Directory+"\"+$NewName) 
						    Add-Content -Path "$($DestPath)Rename-Log.txt" -Value "Renamed '$($file.fullname)' to '$($NewName)'"
						}
						catch {
						    Write-Host "`tFailed: $_"
						    Add-Content -Path "$($DestPath)Rename-Log.txt" -Value "Failed to rename '$($file.fullname)' to '$($NewName)'"
						}
					    
					}
				}
				$HasFolder = $null
				$HasSeasonFolder = $null
				$HasFolder = Test-Path "$DestDir\$showname"	
				$HasSeasonFolder = Test-Path "$DestDir\$showname\Season $intSeason"
				if ($HasFolder -eq $false) {mkdir "$DestDir\$showname" | out-null;Write-Host "Created new show folder for $showname"}
				if ($HasSeasonFolder -eq $false) {mkdir  "$DestDir\$showname\Season $intSeason" | out-null;Write-Host "Created season $intSeason for $showname"}
				if ("$Directory\$Filename" -ne "$DestDir\$showname\Season $intSeason\$Filename") {				
					if ($(Test-Path "$DestDir\$showname\Season $intSeason\$Filename") -eq $false ) {				
					    try {
					       Move-Item -path "$Directory\$Filename" -Destination "$DestDir\$showname\Season $intSeason\"	   				   
						   Write-Host "`tMoved file $Directory\$Filename to $DestDir\$showname\Season $intSeason\"					 
						   Add-Content -Path "$($DestPath)Move-Log.txt" -Value "Moved '$($file.fullname)' to '$DestDir\$showname\Season $intSeason\$Filename'"
						}
						catch {
						    Write-Host "`tfailed to move file $filename to $DestDir\$showname\Season $intSeason"
						}						
					}
					else {										
					    Move-Item -path "$Directory\$Filename" -Destination "$DestDirDup\"
					    Write-Host "`tDuplicate for $filename"		
					}						
				}
				else {
				    Write-Host "`t$Filename is already in correct folder"
				}
			}	
			else {
				try {
					Write-Host "`t$Filename Might be a movie"					

					if ($filename.ToLower() -eq "sample.avi") {
					    Remove-Item -Force -Path $file.fullname
						Add-Content -path $($DestPath)Delete-Log.log -Value "Deleting $($file.Fullname)"
					}
					else {			
						$RegexEpisodeNumber = [regex]'(20\d{2})'
						$Results = $RegexEpisodeNumber.matches($WithoutDots)	
						if ($Results.Count -eq 1) {
							[string]$Year = $($Results.get_Item(0)).value	 			
							[string]$Title = $($WithoutDots.Substring(0,$WithoutDots.ToUpper().IndexOf($Year.ToUpper()))).Trim()									
							[string]$url = "http://www.imdbapi.com/?t=$($title)&y=$($Year)"													
							if ($Year.Length -gt 0 -and $Title.Length -gt 0 -and $filename.ToLower().Contains("sample") -eq $false ) {
							    Write-Host "`tYep, it really does look like a moive"
								$http = new-object -com "Microsoft.XmlHttp"
								$http.open("GET",$url,$false)
								$http.send($null)
								$response = $http.responseText			
								Add-Content -Path "$($DestPath)IMDB-Reponses.txt" -Value "$($response) `n"
								$response = $response.Replace("{","")
								$response = $response.Replace("}","")
								$response = $response.Replace("?","")						
								$response = $response.Replace("\","")
								$response = $response.Replace("/","")
								
								$Array = $response.Split(",")
								[string]$IMDBTitle = $null
								[string]$IMDBYear = $null
								[string]$IMDBRating = ""
								$OutputText = $null 
								$OutputText = @()
								foreach ($element in $Array) {
									try {			
										$OutputText += $element
									    $ValueName = $element.substring(0,$element.indexof(""":"""))
										$ValueName = $ValueName.Replace("""","")
										$Value = $element.substring($element.indexof(""":""")+2)
										$Value = $Value.Replace("""","")
										switch ($ValueName.ToLower().Trim() ) {
										    "title" {$IMDBTitle = $Value;$IMDBTitle=$IMDBTitle.Replace(":"," - ")}
										    "year" {$IMDBYear = $Value}
										}																
									}
									catch {
									}					
								}
								
								[boolean]$ProcessMovie = $false 
								if ($IMDBTitle.Length -gt 0 -and $IMDBYear.Length -gt 0 ) {
									Write-Host "`tIMDB Thinks its a movie called $IMDBTitle from $IMDBYear"													
									if  ($title -eq $IMDBTitle ) {
									    $ProcessMovie = $true 
									
									}
									else {
									
										[array]$arrIMDBtitle = $IMDBTitle.Split(" ")															
										[int]$TotalWordsToMatch = 0
										[int]$intMatchedWords = 0
										[int]$intNotMatchedWords = 0
										[int]$ActualTotalWordsToMatch = 0
										foreach ($Word in $arrIMDBtitle) {
											$Word = $Word.Trim()									
											if ($Word -eq "-" -or $Word -eq "" -or $word.Length -eq 0 ) {}
											else {
												$TotalWordsToMatch+=1
												$WordFound = $title.contains($Word)
											    if ($WordFound -eq $true ) {
												    $intMatchedWords+=1
												}
												else {
													$intNotMatchedWords+=1
												}																								
											}																
										}
										[array]$arrTitle = $Title.Split(" ")	
										foreach ($Word in $arrTitle) {
											$Word = $Word.Trim()									
											if ($Word -eq "-" -or $Word -eq "" -or $word.Length -eq 0 ) {}
											else {
												$ActualTotalWordsToMatch+=1																													
											}																
										}								
																		
										if ($intMatchedWords -gt 0 ){
										    $PercentageMatch = $intMatchedWords / $TotalWordsToMatch	
											$ActualPercentageMatch = $intMatchedWords / $ActualTotalWordsToMatch
											
											if ($ActualPercentageMatch -ge .75) {
												Write-Host "`tI agree with IMDB that the movie is '$IMDBTitle'"
											    $ProcessMovie = $true 
											}
										}
									}

									if ($ProcessMovie -eq $true ) {
										[string]$FullTitle = "$IMDBTitle - $IMDBYear$($file.Extension)"
										try {												
											$HasFolder = $null
											$HasFolder = Test-Path "$MovieDest\$IMDBTitle"	
											if ($HasFolder -eq $false) {mkdir "$MovieDest\$IMDBTitle "	| out-null;Write-Host "`tCreated new movie folder for $IMDBTitle"}
											if ($file.FullName -ne "$MovieDest\$IMDBTitle\$FullTitle") {
												if ($(Test-Path "$MovieDest\$IMDBTitle\$($FullTitle)") -eq $false ) {					
												    try {
														[System.IO.File]::Move($file.FullName, "$MovieDest\$IMDBTitle\$FullTitle")											
												       	#Move-Item -path "$Directory\$FullTitle" -Destination "$MovieDest\$IMDBTitle\$FullTitle"	  																
													   	Write-Host "`tMoved file $Directory\$FullTitle to $MovieDest\$IMDBTitle\$FullTitle"	 		
														Add-Content -Path "$($DestPath)Move-Log.txt" -Value "Moved '$($file.fullname)' to '$MovieDest\$IMDBTitle\$FullTitle'"	
														Add-Content -Path "$MovieDest\$IMDBTitle\MovieInfo.txt" -Value $OutputText									
													}
													catch {
													    Write-Host "`tFailed to move file $filename to $MovieDest\$IMDBTitle\$FullTitle"	
														write-host $_
													}							
												}
												else {
												    Move-Item -path "$Directory\$FullTitle" -Destination "$DestDirDup\"
												    Write-Host "`tDuplicate for $filename"		
												}
											}
											else {
											    Write-Host "`tNo need to move, already correct"
											}
										}
										catch {
										    Write-Host "`tMovie failed to move $_"
										}																
									}
									else {
									    Write-Host "`tI don't like what imdb thinks, it says the movie is '$IMDBTitle' which isn't close to what I have"						
									}
								}
								else {
								    Write-Host "`tNo IMDB referance for $Title"
								}
							}					
							else {																	
								Write-Host "`tnope, no title and/or year found in title"
							}										
							
						}
						else {
						    Write-Host "`tnope, no title and/or year found in title"   
						}
					}
					else {
						Write-Host "failed here"
					}
				}
				catch {
				
				}			
			}
		}
		else {
		    Write-Host "`tLess than 20 days ($Filename)"
		}
	}
}