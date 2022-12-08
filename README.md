# DBInstanceInfo
Automação para gestão de instâncias SQL Server que provê o gerenciamento abaixo nesta versão

  -Informações da instância: Coleta dos dados version, display Version, TCP Port, MinServerMemory, Server Name, Collation, Patch KbUpdate
  
  -Disco: Coleta da sys.dm_os_volume_stats com sys.master_files, Informaçõa de espaço em disco nos discos que possuem datafiles
  
  -Datafiles: Coleta da sys.master_files com sys.filegroups rodando em um cursor para coletar informações dos datafiles com fileproperty e informação dos filegroups
  
  -Disk Grouwth: Uma sumarização de sum do growth dos datafiles agrupados por disco para determinar se o disco tem datafiles com growth habilitado
  
  -FileGroup: Uma sumarização de sum dos datafiles agrupados por filegroup para determinar a utilização de espaço dos filegroups
  
