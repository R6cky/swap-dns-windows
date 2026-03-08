# =========================
# Load config
# =========================
$configPath = "C:\\system_32\config.json"
$config = Get-Content  $configPath | ConvertFrom-Json
$wifiRaw = netsh wlan show interfaces

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

    return (($ping -and $dns -and $http) -or ($dns -and $http) -or ($pingh -and $dns))
}


#======================
# Network Adapter checks
#======================

function Ethernet-Chek {
    $adapter = Get-NetAdapter -Name $config.ethernetAdapter
    return $adapter.Status
}


function Wifi-Chek {
    $adapter = Get-NetAdapter -Name $config.wifiAdapter
    return $adapter.Status
}



function Wifi-Connected-Status{
    $output = netsh wlan show interfaces
    $wifiInfo = @{}

    foreach ($line in $output) {
        if ($line -match "^\s*(.+?)\s*:\s*(.+)$") {
            $wifiInfo[$matches[1].Trim()] = $matches[2].Trim()
        }
    }

    $wifiObject = [PSCustomObject]$wifiInfo
    return $wifiObject
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

function Enable-Wifi {
    Write-Log "Habilitando Adaptador Wireless"
    Enable-NetAdapter -Name $config.wifiAdapter -Confirm:$false
}


function Connect-Wifi{
    Write-Log "Conectando na rede wireless $($config.wifiProfile)"
    netsh wlan connect name="$($config.wifiProfile)" | Out-Null
}

function Disable-Wifi {
    Write-Log "Desabilitando Adaptador Wireless..."
    Disable-NetAdapter -Name $config.wifiAdapter -Confirm:$false
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
            Write-Log "Verifique o cabo de rede está devidamente conectado nas duas extremidades."
            Write-Log "Retire-o e conecte novamente no conector do computador e do ponto de rede"
            Write-Log "------------------------------------------"

        }

        if((Ethernet-Chek) -eq "Up" -and (Internet-OK)){
            Write-Log "Teste de conexão em rede cabeada." 
            Write-Log "A internet esta OK. Utilzando internet cabeada"
            if ((Wifi-Chek) -eq "Disabled") { Write-Log " O adaptador wireles esta desabilitado" } else { (Disable-Wifi) }
            Write-Log "------------------------------------------"
            Start-Sleep -Seconds $config.checkIntervalSeconds
            continue
        }else{
            Write-Log "A Conexao cabeada esta com problemas"
            Write-Log "$(Internet-OK)"

            if((Wifi-Chek) -eq "Disabled" ){
               (Enable-Wifi)
            }else{
                Write-Log "A Rede Wireless esta Habilitada."
            }
            Start-Sleep -Seconds 20
            if(((Wifi-Connected-Status).Estado -eq "Conectado") -or ((Wifi-Connected-Status).State -eq "connected")){ 
                Write-Log "Wifi conectado a rede [ $((Wifi-Connected-Status).SSID) ]"
            }elseif(((Wifi-Connected-Status).Estado -eq "desconectado") -or ((Wifi-Connected-Status).State -eq "disconnected")){
                (Connect-Wifi) 
                
            }

            
            (Disable-Ethernet)
            
            Start-Sleep -Seconds $config.checkIntervalSeconds
        }
        


        if((Wifi-Chek) -eq "Up" -and (Internet-OK)){
                    Write-Log "----------------------------------------------------"
                    Write-Log "A internet Wireless esta sendo utilizada..."
                    Write-Log "----------------------------------------------------"
                    Write-Log "SSID: $((Wifi-Connected-Status).SSID)"  
                    Write-Log "----------------------------------------------------"
                    Write-Log "Status: = $((Wifi-Chek))"
                    Write-Log "----------------------------------------------------"

        }else{
                    (Internet-OK)
                    Write-Log "A internet Wireless esta com problemas..."
                    Write-Log "----------------------------------------------------"
                    Write-Log "Info: SSID = $((Wifi-Connected-Status).SSID)"  
                    Write-Log "Status da rede wifi = $(Wifi-Chek)"
                    Write-Log "----------------------------------------------------"

        }  
        
        
        }