# shutdown a Machine Remotely prompt for the credentials to use 8 = Normal Shutdown.
(gwmi win32_operatingsystem -ComputerName 192.168.1.6 -cred (get-credential)).Win32Shutdown(8)