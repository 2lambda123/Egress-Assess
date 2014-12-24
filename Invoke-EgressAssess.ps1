function Invoke-EgressAssess {
<#

.Synopsis
    Egress-assess powershell client.

.Description
    This script will connect to an Egress-assess server and transfer faux Personally Identifiable Information.
    Due to processing overhead in Powershell, numbers are created in batches of 5,000. 
    Reference: http://powershell.org/wp/2013/09/16/powershell-performance-the-operator-and-when-to-avoid-it/

.Parameter Client
    The string containing the protocol to egress data over

.Parameter IP
    The string containing the IP or hostname of the egress assess server.

.Parameter Proxy
    This switch is used when you need to exfiltrate data using the system proxy.

.Parameter Username
    The username for the ftp server

.Parameter Password
    The password for the ftp server

.Parameter Datatype
    The string containing the data you want to generate and exfil

.Parameter Size
    How many blocks of 5000 numbers to generate

.Example
    Import-Module Egress-Assess.ps1
    Invoke-EgressAssess -client http -ip 127.0.0.1 -datatype cc -Size 1 -Verbose

Script created by @rvrsh3ll @christruncer @harmj0y @sixdub
https://www.rvrsh3ll.net
https://www.christophertruncer.com/
http://blog.harmj0y.net/
http://sixdub.net/


#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$True)]
    [string]$CLIENT,
    [Parameter(Mandatory=$True)]
    [string]$IP,
    [switch]$Proxy,
    [Parameter(Mandatory=$True)]
    [string]$Datatype,
    [string]$Username,
    [string]$Password,
    [int]$Size=1
    )

begin {

    function Generate-SSN {

    $script:allSSN = @()
    Write-Verbose "Generating Social Security Numbers............."

    $stringBuilder = New-Object System.Text.StringBuilder
    $list = New-Object System.Collections.Generic.List[System.String]
    $num = $Size * 5000
     for ($i=0; $i -lt $num; $i++){
        $r = "$(Get-Random -minimum 100 -maximum 999)-$(Get-Random -minimum 10 -maximum 99)-$(Get-Random -minimum 1000 -maximum 9999)"
        $list.Add($r)
      }      
    $script:allSSN = $list.ToArray()
    }

    function Generate-CreditCards {

    $script:allCC =@()
    $stringBuilder = New-Object System.Text.StringBuilder
    $script:list = New-Object System.Collections.Generic.List[System.String]

    Write-Verbose "Generating Credit Cards............."
        function New-Visa {
             #generate a single random visa number, format 4xxx-xxxx-xxxx-xxxx
            $r = "4$(Get-Random -minimum 100 -maximum 999)-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)"
            $script:list.Add($r)
        }
        function New-MasterCard {
            # generate a single random mastercard number
            $r = "5$(Get-Random -minimum 100 -maximum 999)-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)"
            $script:list.Add($r)
        }
        function New-Discover {
            # generate a single random discover number
            $r = "6011-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)"
            $script:list.Add($r)
        }
        function New-Amex {
            # generate a single random amex number
            $script:allCC += "3$(Get-Random -minimum 100 -maximum 999)-$(Get-Random -minimum 100000 -maximum 999999)-$(Get-Random -minimum 10000 -maximum 99999)" 
            $r = "3$(Get-Random -minimum 100 -maximum 999)-$(Get-Random -minimum 100000 -maximum 999999)-$(Get-Random -minimum 10000 -maximum 99999)"
            $script:list.Add($r)
        }
        
       
        $num = $Size * 5000
        for ($i=0; $i -lt $num; $i++){
            $r = Get-Random -Minimum 1 -Maximum 5
            switch ($r) # Use switch statement to
            { 
                1 {New-Visa} 
                2 {New-MasterCard} 
                3 {New-Discover} 
                4 {New-Amex} 
                default {New-Visa}
            }
        }
    $script:allCC = $list.ToArray()

    }

    function Use-HTTP {
     

    # check for cc or ssn and pass to body
    if ($DATATYPE -eq "cc") {
        Generate-CreditCards
        $Body = @()
        $Body = $allCC
        if ($client -eq "http"){
            $url = "http://" + $IP + "/post_data.php"
        }
        elseif ($client -eq "https") {
            $url = "https://" + $IP + "/post_data.php"
        }
    }
    elseif ($DATATYPE -eq "ssn"){
        Generate-SSN
        $Body = @()
        $Body = $allSSN
        if ($client -eq "http"){
            $url = "http://" + $IP + "/post_data.php"
        }
        elseif ($client -eq "https"){
            $url = "https://" + $IP + "/post_data.php"
        }
    }
    else {
        Write-Verbose "You did not provide a data type to generate."
        Return
    }
    # This line is required to accept any SSL certificate errors  
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $uri = New-Object -TypeName System.Uri -ArgumentList $url
    $wc = New-Object -TypeName System.Net.WebClient
    if ($proxy) {
        $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        $wc.proxy = $proxy
    }
    Write-Verbose  "Uploading data.."
    $wc.UploadString($uri, $Body)
    Write-Verbose "Transaction Complete."
    }

    function Use-Ftp {

    $Date = Get-Date -Format Mdyyyy_hhmmss
    $Path = "ftpdata" + $Date + ".txt"

    if ($DATATYPE -eq "cc") {
        Generate-CreditCards
        $FTPData = $allCC 
    }
    elseif ($DATATYPE -eq "ssn"){
        Generate-SSN
        $FTPData=$allSSN
 
    }
    else {
        Write-Verbose "You did not provide a data type to generate."
    }
    $Destination = "ftp://" + $IP + "/" + $Path
    $Credential = New-Object -TypeName System.Net.NetworkCredential -ArgumentList $Username,$Password

    # Create the FTP request and upload the file
    $FtpRequest = [System.Net.FtpWebRequest][System.Net.WebRequest]::Create($Destination)
    if ($proxy) {
        $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        $FtpRequest.proxy = $proxy
    }
    $FtpRequest.KeepAlive = $False
    $FtpRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
    $FtpRequest.Credentials = $Credential

    # Get the request stream, and write the file bytes to the stream
    $Encoder = [system.Text.Encoding]::UTF8
    $RequestStream = $FtpRequest.GetRequestStream()
    $Encoder.GetBytes($FTPData) | % { $RequestStream.WriteByte($_); }
    $RequestStream.Close()

    Write-Verbose "File Transfer Complete."
    }

}
    process {

        if ($client -eq "http" -or $client -eq "https") {
            Use-HTTP
        }

        elseif ($client -eq "ftp") {
            Use-Ftp
        }
        else {
            Write-Verbose "You failed to provide a protocol"
            Return
        }
    }

    end {
        Write-Verbose "Exiting.."
    }

}
