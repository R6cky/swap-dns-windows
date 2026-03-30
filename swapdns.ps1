# Load config
$configPath = "C:\\system_64\config.json"
$config = Get-Content  $configPath | ConvertFrom-Json
$countDnsFailure = 0


#----------------------------------------------------------------------------
#Log function
function Write-Log {
    param ($message)
    $timestamp = Get-Date -Format "dd/MM/yyyy_HH:mm:ss"
    "log_$timestamp -> $message" | Out-File -Append -FilePath $config.logFile
}


function Clear-Log () {
    if (((Get-Item $config.logFile).Length / 1MB) -gt 10) {
        Write-Log "Arquivo de log maior que 10MB"
        Write-Log "Limpando arquivo de log..."
        Set-Content $config.logFile ""
        continue
    }
}


#----------------------------------------------------------------------------
# Connectivity checks
function Test-Ping {
    Test-Connection -ComputerName $config.pingTarget -Count 2 -Quiet
}

function QualityPing {
    try {
        $timeResponse = (Test-Connection -ComputerName $config.pingTarget -Count 1).ResponseTime
        return $timeResponse
    }
    catch {
        return $false
    }
}

function Test-DNS {
    try {
        Resolve-DnsName $config.dnsTestDomain -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Test-HTTP {
    try {
        if (Invoke-WebRequest -Uri $config.httpTestUrl -UseBasicParsing -TimeoutSec 20) {
            return $true
        }
        if (Invoke-WebRequest -Uri $config.httpTestUrl2 -UseBasicParsing -TimeoutSec 20) {
            return $true
        }
    }
    catch {
        return $false
    }
}

function Internet-OK {
    $ping = Test-Ping
    $dns = Test-DNS
    $http = Test-HTTP
    
    if (($ping -and $dns -and $http) -or ($dns -and $http) -or ($ping -and $dns)) {
        $msPing = QualityPing
      
        if ($ping -and ($msPing -gt 100)) {
            Write-Log "Internet cabeada esta operante, mas tempo de resposta foi maior que 100ms - PING: $($msPing) ms"  
        }
        elseif ($ping) {
            Write-Log "Internet cabeada está operante - PING: $($msPing) ms"  
        }
        else {
            Write-Log "Internet cabeada está operante. [ Ping pode estar bloqueado. ]"  
        }

    }
    elseif ((($ping -and $http) -and !($dns)) -or ($http -and !($dns) )) {

        Write-Log "Houve um problema com a resolução de nomes... contagem: $($script:countDnsFailure)"
        $script:countDnsFailure++
        (ChangeDns)
        Start-Sleep -Seconds 3
    }
    else {
        Write-Log "Internet cabeada está com problemas..."
    }

}




#----------------------------------------------------------------------------
# change DNS function
function ChangeDns {
    if (($script:countDnsFailure -eq 4)) {
        Write-Log "Configurando DNS para ->> primario: $($config.primaryDNS) e secundario: $($config.secondaryDNS)"
        Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ServerAddresses ($config.primaryDNS, $config.secondaryDNS)   
        Clear-DnsClientCache  
        $script:countDnsFailure = 0
        $config.checkIntervalSeconds = 10
        continue
    }
    else {
        continue
    }
}

#----------------------------------------------------------------------------
# Network adapter checks

function Ethernet-Chek {
    $adapter = Get-NetAdapter -Name $config.ethernetAdapter
    return $adapter.Status
}


function Enable-Ethernet {
    Write-Log "Habilitando Adaptador Ethernet..."
    Enable-NetAdapter -Name $config.ethernetAdapter -Confirm:$false
}


#----------------------------------------------------------------------------
# Main loop

Write-Log "Script iniciado."


while ($true) {
    
    if (((Ethernet-Chek) -eq "Disabled") -or ((Ethernet-Chek) -eq "Not Present")) {
        Write-Log "A rede cabeada estava desabilitada."
        (Enable-Ethernet)
        Start-Sleep -Seconds 20
    }

    if (((Ethernet-Chek) -eq "Disconnected") -or ((Ethernet-Chek) -eq "Desconectado") ) {
        Write-Log "Verifique se o cabo de rede esta devidamente conectado nas duas extremidades..."
        Write-Log "Retire-o e conecte novamente no conector do computador e do ponto de rede"
        Write-Log "----------------------------------------------------"
        Start-Sleep -Seconds 20 
    }

    if ((Ethernet-Chek) -eq "Up" -and (Internet-OK)) {
        continue
    }
    (Clear-Log)     
    Start-Sleep -Seconds 30
}