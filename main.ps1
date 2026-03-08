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
        Invoke-WebRequest -Uri $config.httpTestUrl -UseBasicParsing -TimeoutSec 20 | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Internet-OK {
    $ping = Test-Ping
    $dns  = Test-DNS
    $http = Test-HTTP
    Write-Log "Ping=$ping | DNS=$dns | HTTP=$http | $wifiObject" 

    if(($ping -and $http) -and ($dns -eq $false)){
        Write-Log "Apenas a resolução de nomes está falhando..."
        return "change-dns"
    }

    return (($ping -and $dns -and $http) -or ($dns -and $http) -or ($pingh -and $dns))
}



function ChangeDns {
   if((Internet-OK) -eq "change-dns"){
      Write-Log "Configurando DNS para ->> primario: $() e secundario: $()  "
      Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses ("8.8.8.8","8.8.4.4")
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
        }
        

        }