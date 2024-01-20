Write-Host "Collecting info...`n`n"

$obj_cpu = Get-CimInstance -Class Win32_Processor
$obj_gpu = Get-CimInstance -Class Win32_VideoController
$obj_monitor = Get-CimInstance -Class WmiMonitorID -Namespace root\wmi
$obj_mb = Get-CimInstance -Class Win32_BaseBoard
$obj_ram = Get-CimInstance -Class Win32_PhysicalMemory
$obj_disk = Get-PhysicalDisk

###CPU###
$cpu_name = $obj_cpu | Select-Object -ExpandProperty Name
$cpu_socket = $obj_cpu | Select-Object -ExpandProperty SocketDesignation

###GPU###
$gpu_name = $obj_gpu | Select-Object -ExpandProperty Name
# The AdapterRAM field is broken, so we read it from registry
$gpu_vram = ((Get-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" -Name HardwareInformation.qwMemorySize -ErrorAction SilentlyContinue)."HardwareInformation.qwMemorySize")/1GB
$gpu_horizontal = $obj_gpu | Select-Object -ExpandProperty CurrentHorizontalResolution
$gpu_vertical = $obj_gpu | Select-Object -ExpandProperty CurrentVerticalResolution
$gpu_refresh = $obj_gpu | Select-Object -ExpandProperty MaxRefreshRate

###MONITOR### (still experimental, needs feedback)
$monitor_raw = $obj_monitor | Select-Object -ExpandProperty UserFriendlyName
$monitor_letter_list=@()
$i=0
while($monitor_raw[$i] -ne $NULL){
	if($monitor_raw[$i] -ne 0){
		$monitor_letter_list+=[System.Text.Encoding]::UTF8.GetString($monitor_raw[$i])
	}
	if($i % 13 -eq 12){
		$monitor_letter_list+=", "
	}
	$i++
}
$monitor_letter_list[$monitor_letter_list.Length-1]=""
$monitor = "Connected monitor: " + -join $monitor_letter_list

###MB###
$mb_maker = $obj_mb | Select-Object -ExpandProperty Manufacturer
$mb_product = $obj_mb | Select-Object -ExpandProperty Product

###RAM###
$ram_bank = $obj_ram | Select-Object -ExpandProperty BankLabel
$ram_size = $obj_ram | Select-Object -ExpandProperty Capacity
$ram_currentspeed = $obj_ram | Select-Object -ExpandProperty ConfiguredClockSpeed
$ram_maker = $obj_ram | Select-Object -ExpandProperty Manufacturer
# If it can't read the partnumber, then use ThaiphoonBurner or Aida64
$ram_part = $obj_ram | Select-Object -ExpandProperty PartNumber

###DISK###
$disk_name = $obj_disk | Select-Object -ExpandProperty FriendlyName
$disk_bustype = $obj_disk | Select-Object -ExpandProperty BusType
$disk_mediatype = $obj_disk | Select-Object -ExpandProperty MediaType
$disk_size = $obj_disk | Select-Object -ExpandProperty Size


$cpu = "CPU: {0} ({1})" -f $cpu_name.Trim(), $cpu_socket
$mb = "MB: {0} {1}" -f $mb_maker, $mb_product
$gpu = "GPU: {0} ({1} GB) @ {2}x{3}@{4} Hz" -f $gpu_name, $gpu_vram, $gpu_horizontal, $gpu_vertical, $gpu_refresh
$i = 0
$ram = "`n"
if ($ram_bank.GetType().Name -eq "String"){
	$size = $ram_size / 1GB
	$ram += "RAM {0}: {1} GB {2} MHz {3} {4}`n" -f $bank, $size, $ram_currentspeed, $ram_maker, $ram_part
}
else{
	foreach ($bank in $ram_bank){
		$size = $ram_size[$i] / 1GB
		$ram += "RAM {0}: {1} GB {2} MHz {3} {4}`n" -f $bank, $size, $ram_currentspeed[$i], $ram_maker[$i], $ram_part[$i]
		$i++
	}
}

$i = 0
$disk = ""
if ($disk_name.GetType().Name -eq "String"){
	[int]$size = $disk_size / 1GB
	$disk += "{0} {1} GB {2} {3}`n" -f $disk_name, $size, $disk_bustype, $disk_mediatype
}
else{
	foreach ($item in $disk_name){
		[int]$size = $disk_size[$i] / 1GB
		$disk += "{0} {1} GB {2} {3}`n" -f $disk_name[$i], $size, $disk_bustype[$i], $disk_mediatype[$i]
		$i++
	}
}

Write-Host $cpu
Write-Host $mb
Write-Host $gpu
Write-Host $monitor
Write-Host $ram
Write-Host $disk

$all = $cpu + "`n" + $mb + "`n" + $gpu + "`n" + $monitor + "`n" + $ram + "`n" + $disk
Set-Clipboard -Value $all
Write-Host "`nCopied to clipboard!`n"
pause