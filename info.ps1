###Changelog###
#
# For the disks it now shows the drive letter(s) too

Write-Host "Collecting info...`n`n"

$obj_cpu = Get-CimInstance -Class Win32_Processor
$obj_gpu = Get-CimInstance -Class Win32_VideoController
$obj_monitor = Get-CimInstance -Class WmiMonitorID -Namespace root\wmi
$obj_mb = Get-CimInstance -Class Win32_BaseBoard
$obj_ram = Get-CimInstance -Class Win32_PhysicalMemory

###CPU###
$cpu_name = $obj_cpu | Select-Object -ExpandProperty Name
$cpu_socket = $obj_cpu | Select-Object -ExpandProperty SocketDesignation

###GPU###
# The AdapterRAM field is broken (reading DWORD with 4GB limit, instead of QWORD), so we read it from registry
# Note: If you get multiple entries of a GPU, that is not in the system, then you have to remove the inactive entry from device manager (show hidden devices)
$gpu_name = ""
$gpu_vram = ""
$gpu_output = $obj_gpu | Select-Object -ExpandProperty Name
if ($gpu_output.GetType().BaseType.Name -eq "Array"){
	$i = 0
	foreach ($item in $gpu_output){
		$gpu_name += (Get-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\000$i" -Name HardwareInformation.AdapterString -ErrorAction SilentlyContinue)."HardwareInformation.AdapterString" + ", "
		$i++
	}
	$gpu_name = $gpu_name.SubString(0,$gpu_name.Length-2)
	
	$gpu_vrams = (Get-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" -Name HardwareInformation.qwMemorySize -ErrorAction SilentlyContinue)."HardwareInformation.qwMemorySize"
	foreach ($item in $gpu_vrams){
		$item /= 1GB
		$item = $item | Out-String
		$item = $item.SubString(0,$item.Length-2)
		$gpu_vram += $item + " GB, "
	}
	$gpu_vram = $gpu_vram.SubString(0,$gpu_vram.Length-2)
}
else{
	$gpu_name = $gpu_output
	$gpu_vram = (((Get-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" -Name HardwareInformation.qwMemorySize -ErrorAction SilentlyContinue)."HardwareInformation.qwMemorySize")/1GB | Out-String) + " GB"
}

$gpu_horizontal = $obj_gpu | Select-Object -ExpandProperty CurrentHorizontalResolution
$gpu_vertical = $obj_gpu | Select-Object -ExpandProperty CurrentVerticalResolution
$gpu_refresh = $obj_gpu | Select-Object -ExpandProperty MaxRefreshRate

###MONITOR###
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
$monitor_letter_list[$monitor_letter_list.Length-1] = ""
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
$disk_obj = Get-Disk | ForEach-Object {
    $disk = $_
    $physical = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $disk.Number }
    $partitions = Get-Partition -DiskNumber $disk.Number

    $driveLetters = $partitions | ForEach-Object {
        $volume = Get-Volume -Partition $_ -ErrorAction SilentlyContinue
        if ($volume -and $volume.DriveLetter) {
            $volume.DriveLetter
        }
    }
    [PSCustomObject]@{
        Name  = $physical.FriendlyName
        DriveLetters  = ($driveLetters -join ', ')
        Size        = '{0:0} GB' -f ($disk.Size / 1GB)
		Bus       = $physical.BusType
        Media     = $physical.MediaType
    }
}



$cpu = "CPU: {0} ({1})" -f $cpu_name.Trim(), $cpu_socket
$mb = "MB: {0} {1}" -f $mb_maker, $mb_product
$gpu = "GPU: {0} ({1}) @ {2}x{3}@{4} Hz" -f $gpu_name, $gpu_vram, $gpu_horizontal, $gpu_vertical, $gpu_refresh
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

$disk = ""
$disk_obj = $disk_obj | Sort-Object{
	$_.DriveLetters.Split(',')[0].Trim()
}
foreach ($item in $disk_obj){
	$disk += "{0}:\ {1} {2} {3} {4}`n" -f  $item.DriveLetters, $item.Name, $item.Size, $item.Bus, $item.Media
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