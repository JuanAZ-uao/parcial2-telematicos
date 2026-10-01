# Helper para generar evidencias desde Windows (PowerShell).
# Uso:  . E:\parcial2\scripts\evidencia.ps1
#       Ev cliente "curl ..." "07_filezilla_equivalente.txt"
# Ejecuta el comando en la VM por SSH y guarda "comando + salida" en evidencias\.

$Global:P2 = "E:\parcial2"
$Global:P2Ports = @{ srv1 = 2601; srv2 = 2602; cliente = 2603 }

function Ev {
  param([string]$Vm, [string]$Cmd, [string]$Archivo)
  $key = "$P2\.vagrant\machines\$Vm\virtualbox\private_key"
  $host_ = @{ srv1 = "srv1-1005968285"; srv2 = "srv2-1005968285"; cliente = "cliente-1005968285" }[$Vm]
  $out = & ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR -o BatchMode=yes `
              -i $key -p $P2Ports[$Vm] vagrant@127.0.0.1 $Cmd 2>&1 | ForEach-Object { "$_" }
  $bloque = @("", "vagrant@${host_}:~`$ $Cmd") + $out
  if ($Archivo) { $bloque | Out-File -Append -Encoding utf8 "$P2\evidencias\$Archivo" }
  $bloque
}
