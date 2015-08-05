# Set max acceptable temperature
$MAXCPUCORETEMPERATURE = 60; # search your cpu model for an appropriate value

# Set email 
$SMTPSERVER =  "mail.mailserverdomain.com"; 
$MAILFROM = "mailfrom@domain.com";
$SMTPPORT = 25; 
$MAILPASSWORD = "PROVIDE_PASSWORD";

# sent to email recipients
$MAIL_COMMA_DELIMITED_LIST = "someemail@mail.com,someotheremail@email.com";


##########################################################################################################
###                                                                                                    ###
### CPU OVERHEAT ALERT                                                                                 ###
###                                                                                                    ###
### Checks current temperatures of all CPU cores. Sends an email in case of overheat.                  ###
###                                                                                                    ###
### Requirements:                                                                                      ###
###    - Powershell v.2                                                                                ###
###    - Open Hardware monitor must be downloaded and placed in nested OpenHardwareMonitor directory.  ###
###      (download url: http://openhardwaremonitor.org/)                                               ###
###    - Administrative rights (open hardware monitor requirement)                                     ###
###    - SMTP Serer acount                                                                             ###
###                                                                                                    ###
### Tested on: Windows 7 x64, Windows Server 2003 x86                                                  ###
###                                                                                                    ###
##########################################################################################################


function sendMail ( $toCommaDelimited, $subject, $body)
{
     Write-Host "Sending Email"

     #Creating a Mail object
     $msg = new-object Net.Mail.MailMessage

     #Creating SMTP server object
	 $smtp = new-object Net.Mail.SmtpClient($SMTPSERVER, $SMTPPORT)
	 
     #Email structure 
	 $msg.From = $MAILFROM;

    
     foreach ($mailto in $toCommaDelimited.Split(','))
     {
         $msg.To.Add($mailto)
     }
     
     $msg.subject = $subject;
     $msg.body = $body; 

	 $smtp.Credentials = New-Object System.Net.NetworkCredential($MAILFROM, $MAILPASSWORD);
	 
     #Sending email 
     $smtp.Send($msg)
  
}


# reference open monitor dll 
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition;
$openmonitorDLL = "$scriptPath\OpenHardwareMonitor\OpenHardwareMonitorLib.dll";
[System.Reflection.Assembly]::LoadFile($openmonitorDLL)

# add c sharp type
add-type -Language CSharpVersion3 -TypeDefinition @"
    public class TemperatureInformation
    {
        public TemperatureInformation(string cpuname, string sensorname, float? temperature) 
        {
            this.CPUName = cpuname; 
            this.SensorName = sensorname;
            this.Temperature = temperature;
        }

        public string CPUName { get; set; }
        public string SensorName { get; set; }
        public float? Temperature { get; set; }
    }
"@

#$infoList = New-Object 'System.Collections.Generic.List[TemperatureInformation]'; //not supported in powershell 2.0 
$infoList = New-Object 'System.Collections.Generic.List[Object]'; 

$computer = New-Object OpenHardwareMonitor.Hardware.Computer;
$computer.CPUEnabled = 1;
$computer.Open();
$allCPUs = $computer.Hardware | where {$_.HardwareType -eq 'CPU' }

Foreach ($cpu in $allCPUs)
{
    $temperatureSensorns = $cpu.Sensors | where {$_.SensorType -eq 'Temperature' };
    Foreach ($sensor in $temperatureSensorns)
    {
        $infoList.Add((New-Object TemperatureInformation($cpu.Name, $sensor.Name, $sensor.Value)));
    }
}

$reportString = ""; 
Foreach ($item in $infoList)
{
    $cpuname = $item.CPUName; 
    $sensorname = $item.SensorName; 
    $temperature = $item.Temperature; 
    $reportString += "Temerature: $temperature °C - Sensor: $sensorname - $cpuname`n";
}
Write-Host $reportString;

$problemCores = $infoList | where {$_.Temperature -ge $MAXCPUCORETEMPERATURE};
if ($problemCores.Count -gt 0) 
{
    $bodyData = "CPU MAX temperature is set to $MAXCPUCORETEMPERATURE°C`n`nCurrent Temperature list`n`n$reportString";
    sendMail $MAIL_COMMA_DELIMITED_LIST "$env:computername CPU overheat WARNING" $bodyData
};
