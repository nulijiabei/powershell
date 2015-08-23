#.Synopsis
#   Test the HMAC hash(es) of a file
#.Description
#   Takes the HMAC hash of a file using specified algorithm, and optionally, compare it to a baseline hash
#.Example
#   Test-Hash npp.5.3.1.Installer.exe -HashFile npp.5.3.1.release.md5
# 
#   Searches the provided hash file for a line matching the "npp.5.3.1.Installer.exe" file name
#   and take the hash of the file (using the extension of the HashFile as the Type of Hash).
#
#.Example
#   Test-Hash npp.5.3.1.Installer.exe 360293affe09ffc229a3f75411ffa9a1 MD5
#
#   Takes the MD5 hash and compares it to the provided hash
#
#.Example
#   Test-Hash npp.5.3.1.Installer.exe 5e6c2045f4ddffd459e6282f3ff1bd32b7f67517 
#
#   Tests all of the hashes against the provided (Sha1) hash
#
function Test-Hash { 
#[CmdletBinding(DefaultParameterSetName="NoExpectation")]
PARAM(
   #[Parameter(Position=0,Mandatory=$true)]
   [string]$FileName
,
   #[Parameter(Position=2,Mandatory=$true,ParameterSetName="ManualHash")]
   [string]$ExpectedHash = $(if($HashFileName){  ((Get-Content $HashFileName) -match $FileName)[0].split(" ")[0]  })
,
   #[Parameter(Position=1,Mandatory=$true,ParameterSetName="FromHashFile")]
   [string]$HashFileName
,
   #[Parameter(Position=1,Mandatory=$true,ParameterSetName="ManualHash")]
   [string[]]$TypeOfHash = $(if($HashFileName){  
                          [IO.Path]::GetExtension((Convert-Path $HashFileName)).Substring(1) 
                 } else { "MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160" })
)
$ofs=""
  $hashes = @{}
  foreach($Type in $TypeOfHash) {
    [string]$hash = [Security.Cryptography.HashAlgorithm]::Create(
      $Type
    ).ComputeHash( 
      [IO.File]::ReadAllBytes( (Convert-Path $FileName) )
    ) | ForEach { "{0:x2}" -f $_ }
    $hashes.$Type = $hash
  }
  
  if($ExpectedHash) {
    ($hashes.Values -eq $hash).Count -ge 1
  } else {
    foreach($hash in $hashes.GetEnumerator()) {
      "{0,-8}{1}" -f $hash.Name, $hash.Value
    }        
  }
}