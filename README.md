
DBInstanceInfo.ps1

Automação para gestão de instâncias SQL Server que provê o gerenciamento baseado em coletas e ETL das informações das instâncias em uma base de dados centralizada.

O progama faz reflection de libs (.dll's) do SQL Server para fazer coletar e fazer ETL das informações para adminstração de uma instância SQL Server, programa formato de script do powershell.

 - Instance Info: Coleta dos dados version, display Version, TCP Port, MinServerMemory, Server Name, Collation, Patch KbUpdate;

 - Disk Size: Coleta da sys.dm_os_volume_stats com sys.master_files, Informaçõa de espaço em disco nos discos que possuem datafiles;

 - Datafiles: Coleta da sys.master_files com sys.filegroups rodando em um cursor para coletar informações dos datafiles com fileproperty e informação dos filegroups;
 
 - Disk Grouwth: Uma sumarização de sum do growth dos datafiles agrupados por disco para determinar se o disco tem datafiles com growth habilitado;

 - FileGroups: Uma sumarização de sum dos datafiles agrupados por filegroup para determinar a utilização de espaço dos filegroups;

 - Index Fragmentation: Coleta de dados com schema.table.index.fragmentation

 Melhorias previstas:
  - Página específica para Min Server Memory, Max Server Memory, PLE, Host Memory, Host Available Momory
  - Página específica pra plano de acesso aos índices
