# =========================
# Load config
# =========================
$configPath = "C:\\system_32\config.json"
$config = Get-Content  $configPath | ConvertFrom-Json
$count = 0

function Write-Log {
    param ($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -Append -FilePath $config.logFile
}

# =========================
# Connectivity checks
# =========================
function Test-Ping {
    Test-Connection -ComputerName $config.pingTarget -Count 2 -Quiet
}

function QualityPing {
    try {
         $timeResponse = (Test-Connection -ComputerName google.com -Count 1).ResponseTime
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
    } catch {
        return $false
    }
}

function Test-HTTP {
    try {
        if(Invoke-WebRequest -Uri $config.httpTestUrl -UseBasicParsing -TimeoutSec 20){
            return $true
        }
        if(Invoke-WebRequest -Uri $config.httpTestUrl2 -UseBasicParsing -TimeoutSec 20){
            return $true
        }
    } catch {
        return $false
    }
}

function Internet-OK {
    $ping = Test-Ping
    $dns  = Test-DNS
    $http = Test-HTTP
    
    if(($ping -and $dns -and $http) -or ($dns -and $http) -or ($ping -and $dns)){
      $msPing = QualityPing
      
        if($ping -and ($msPing -gt 80)){
            Write-Log "Internet cabeada está operante, mas merece atenção !!!! $($msPing)"  
        }elseif($ping){
            Write-Log "Internet cabeada está operante - PING: $($msPing)"  
        }else{
            Write-Log "Internet cabeada está operante."  
        }

    }elseif((($ping -and $http) -and !($dns)) -or ($http -and !($dns) )){

        $script:count++
        Write-Log "Houve um problema com a resolução de nomes... contagem: $($count)"
        
    }else {
        Write-Log "Internet cabeada está com problemas..."
    }
  
}






function ChangeDns {
   if(($count -eq 4)){
      Write-Log "Configurando DNS para ->> primario: $($config.primaryDNS) e secundario: $($config.secondaryDNS)"
      Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ServerAddresses ($config.primaryDNS,$config.secondaryDNS)   
      Clear-DnsClientCache  
      $script:count = 0
      $config.checkIntervalSeconds = 30
      continue
    }
}


#======================
# Network Adapter checks
#======================

function Ethernet-Chek {
    $adapter = Get-NetAdapter -Name $config.ethernetAdapter
    return $adapter.Status
}



# =========================
# Adapter control Functions 
# =========================
function Enable-Ethernet {
    Write-Log "Habilitando Adaptador Ethernet..."
    Enable-NetAdapter -Name $config.ethernetAdapter -Confirm:$false
}

function Disable-Ethernet {
    Write-Log "Desabilitando Adaptador Ethernet..."
    Disable-NetAdapter -Name $config.ethernetAdapter -Confirm:$false
}


# =========================
# Main loop
# =========================

Write-Log "----------------------------------------------------"
Write-Log "Script iniciado."
Write-Log "----------------------------------------------------"


while ($true) {
        

        if((Ethernet-Chek) -eq "Disabled"){
            Write-Log "A rede cabeada estava desabilitada."
            (Enable-Ethernet)
            Start-Sleep -Seconds 20
        }

        if(((Ethernet-Chek) -eq "Disconnected") -or ((Ethernet-Chek) -eq "Desconectado") ){
            Write-Log "Verifique o cabo de rede  devidamente conectado nas duas extremidades."
            Write-Log "Retire-o e conecte novamente no conector do computador e do ponto de rede"
            Write-Log "------------------------------------------"

        }

        if((Ethernet-Chek) -eq "Up" -and (Internet-OK)){
            Write-Log "Teste de conexão em rede cabeada." 
            Write-Log "A internet esta OK. Utilzando internet cabeada"

            Start-Sleep -Seconds $config.checkIntervalSeconds

            continue
        }else{
            Write-Log "A Conexao cabeada esta com problemas"
            Write-Log "$(Internet-OK)"
            Write-Log "$(ChangeDns)"
            Start-Sleep -Seconds $config.checkIntervalSeconds
            (ChangeDns)
        }



        

}