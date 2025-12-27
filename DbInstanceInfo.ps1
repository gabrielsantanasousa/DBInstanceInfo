

### FUNÇÕES PARA QUE NÃO POSSUI DATASET PARA EXCEUÇÃO DE DDL'S, DCL'S E DML'S de insert, delete, update NO MICROSOFT SQL COM .NET (NÃO EXECUTA SELECT)
### GABRIEL SANTANA DE SOUSA (CRIAÇÃO E MANUTENÇÃO)

Function change-mssql ([string]$instancia,[string]$banco,[string]$dml)
{
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = "Data Source=$instancia;Initial Catalog=$banco;Connection Timeout=60;$script:InfoConn"
$sqlConnection.Open()

$sqlcmd = New-Object System.Data.SqlClient.SqlCommand
$sqlcmd.CommandText = $dml
$sqlcmd.Connection = $sqlConnection
$sqlcmd.ExecuteNonQuery()
$sqlConnection.Close()
}

### FUNÇÕES PARA QUE POSSUI DATASET PARA EXCEUÇÃO DML'S DE SELECT NO MICROSOFT SQL COM .NET (EXECUTA SELECT)
### GABRIEL SANTANA DE SOUSA (CRIAÇÃO E MANUTENÇÃO)

Function select-mssql ([string]$instancia,[string]$banco,[string]$dml)
{
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = "Data Source=$instancia;Initial Catalog=$banco;Connection Timeout=90;$script:InfoConn"
$sqlConnection.Open()

$sqlcmd = New-Object System.Data.SqlClient.SqlCommand
$sqlcmd.CommandText = $dml
$sqlcmd.CommandTimeout = '90'
$sqlcmd.Connection = $sqlConnection

$sqladapter = New-Object System.Data.SqlClient.SqlDataAdapter
$sqladapter.SelectCommand = $sqlcmd
$DataSet = New-Object System.Data.DataSet
$sqladapter.Fill($DataSet)
$dataset.Tables
$sqlConnection.Close()
}


Function testeconnect-mssql ([string]$instancia)
{
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = "Data Source=$instancia;Initial Catalog=master;Connection Timeout=20;$script:InfoConn"
$sqlConnection.Open()
$sqlConnection.State
$sqlConnection.Close()
$sqlConnection.State
}


$script:querycms = @"
select shg.server_group_id,
shg.parent_id,
		shg.name,
		shgi.server_name,
		shgi.server_group_id
from sysmanagement_shared_server_groups shg 
inner join sysmanagement_shared_registered_servers_internal shgi on (shg.server_group_id = shgi.server_group_id)
where shg.parent_id in (6)
"@

$script:queryminmem = @"
select name as ConfigMemory, value as ValorMB from sys.configurations
where name like 'min server memory%'
"@

$script:querytcport = @"
select distinct local_tcp_port from sys.dm_exec_connections where local_net_address is not null
"@

$script:querydatabase = @"
select	sdt.name,
		sdt.cmptlevel,
		sdt.version,
		convert(numeric,sum(size/128)) as TotalSizeMB
from sys.sysdatabases sdt
inner join sys.master_files smf on (sdt.dbid = smf.database_id)
group by sdt.name, sdt.cmptlevel,sdt.version
"@


$script:querydisksizeall = @"
with FileSize as
(
	select 
		 left(db_name(mf.database_id),30) as BancoDados
		,left(mf.type_desc,20) as TipoArquivo
		,left(mf.name,30) as ArquivoDados
		,mf.physical_name
		,mf.size/128 as SizeMB
		,Crescimento = case mf.is_percent_growth when 1
			then
				mf.growth
			else
				mf.growth / 128
			end 
		,TipoCrescimento = case mf.is_percent_growth when 1 then 'PORCENTAGEM' else 'MEGA'	end
		,NewSize = convert(numeric (18,2),case mf.is_percent_growth when 1 then (mf.size + ((mf.size * mf.growth) / 100)) / 128. else (mf.size + mf.growth) / 128. end)
		,MaxSize = case mf.max_size when -1 then 'ILIMITADO'
									 when 268435456 then 'ILIMITADO'
									 else convert(varchar (20),convert(numeric (18,2),mf.max_size / 128.))
					end
		,volume_mount_point
		,convert(numeric (18,2),total_bytes /1024. /1024 /1024) as VOLUMESIZE
		,convert(numeric (18,2),available_bytes /1024. /1024  /1024) as AVAILABLE
		, convert( numeric (18,2),(available_bytes /1024. /1024  /1024) / (total_bytes /1024. /1024 /1024) ) * 100 as PERCENTFREE
	from sys.master_files as mf
	cross apply sys.dm_os_volume_stats(mf.database_id, mf.file_id)
),
DiskSize (ServerName, volume_mount_point, VOLUMESIZE, AVAILABLE, PERCENTFREE) as 
(
Select distinct @@SERVERNAME, volume_mount_point, VOLUMESIZE, AVAILABLE, PERCENTFREE 
from FileSize
)  
Select 
	 ds.volume_mount_point, ds.VOLUMESIZE
	,ds.PERCENTFREE
	,sum (convert(numeric (18,2),(fs.SizeMB)/1024.)) as SizeGB
	,ds.VOLUMESIZE - (sum (convert(numeric (18,2),(fs.SizeMB)/1024.))) as FreeSizeGB
	,sum (convert(numeric (18,2),(fs.NewSize)/1024)) as NewSizeGB 
	,sum (convert(numeric(18,2),(convert(numeric(18,2),(case when fs.MaxSize='ILIMITADO' then convert(numeric(18,2),fs.SizeMB) else convert(numeric(18,2),fs.MaxSize) end)))/1024)) as MaxSizeGB

from DiskSize ds
join FileSize fs
  on fs.volume_mount_point = ds.volume_mount_point
group by  ds.volume_mount_point 
		 ,ds.VOLUMESIZE
		 ,ds.PERCENTFREE
"@


$script:querydatafile = @"
declare @nome nvarchar(150)
declare @sqldml nvarchar(3000)
declare bancocursor cursor for
select name from sysdatabases
open bancocursor
fetch next from bancocursor into @nome
while @@FETCH_STATUS = 0
begin
	select @sqldml = 'use ' + '[' + @nome + ']' + char(10) + 'select sdt.name as Nome, ' +  char(10) + 'case ' +  
                            char(10) + 'when smf.type = 0 then ''ROWS''' +  char(10) + 'when smf.type = 1 then ''LOG''' +  char(10) + 'else ''unknow''' +  char(10) + 
                            'end as TIPO, ' +  char(10) + 'smf.name  as ArquivoDados, ' +  char(10) + 'smf.physical_name,' +  char(10) + 'volume_mount_point,' + char(10) + 
                            'smf.size/128 as SizeMB, ' + char(10) + 'sfg.name as FileGroupName,' + char(10) + 'Crescimento = case smf.is_percent_growth when 1 then smf.growth else smf.growth / 128	end ,' + char(10) + 
                            'TipoCrescimento = case smf.is_percent_growth when 1 then ''PORCENTAGEM'' else ''MEGA'' end,' + char(10) + 
                            'NewSize = convert(numeric (18,0),case smf.is_percent_growth when 1 then (smf.size + ((smf.size * smf.growth) / 100)) / 128. else (smf.size + smf.growth) / 128. end),' + 
                            char(10) + 'MaxSize = case smf.max_size when -1 then ''ILIMITADO'' when 268435456 then ''ILIMITADO'' else convert(varchar(40),smf.max_size / 128) end,' + char(10) + 
                            'convert(int,FILEPROPERTY(smf.name,' + '''' + 'SpaceUsed' + '''' + ')) / 128 as UsedSpace,' + char(10) + 'convert(int,smf.size / 128) - (convert(int,FILEPROPERTY(smf.name,' + '''' + 'SpaceUsed' + '''' + ')) / 128) as FreeSpace' + char(10) + 
                            'from sys.sysdatabases sdt ' +  char(10) + 'inner join sys.master_files smf on (sdt.dbid = smf.database_id) ' +  char(10) + 'left join sys.filegroups sfg on (smf.data_space_id = sfg.data_space_id) ' + char(10) + 
                            'cross apply sys.dm_os_volume_stats (smf.database_id, smf.file_id)' +  char(10) + 'where sdt.name = ' + '''' + @nome + ''''
	execute sp_executesql @sqldml
	fetch next from bancocursor into @nome
end
close bancocursor
deallocate bancocursor
"@


$script:queryindice = @" 
declare @sqldml nvarchar(700)
declare @banco nvarchar(150)
declare bancocursor cursor for
select name from sysdatabases where dbid > 4
open bancocursor
fetch next from bancocursor into @banco
while @@FETCH_STATUS = 0
begin
Select @sqldml = 'use ' + '[' + @banco + ']' + char(13)
		 + 'select distinct db_name(dmi.database_id) banco,' + char(13) 
		+ 'schema_name(so.schema_id) as schema_name,' + char(13) 
		+ 'OBJECT_NAME(dmi.object_id) tabela,' + char(13) 
		+ 'si.name as indice,' + char(13) 
		+ 'dmi.index_type_desc as tipo_indice,' + char(13) 
		+ 'convert(int,dmi.avg_fragmentation_in_percent) as avg_fragmentation' + char(13) 
		+ 'From sys.dm_db_index_physical_stats (db_id(),null,null,null,' + '''' + 'LIMITED' + '''' + ') as dmi' + char(13) 
		+ 'inner join sys.all_objects as so on (dmi.object_id = so.object_id)' + char(13) 
		+ 'inner join sys.indexes as si on (dmi.index_id = si.index_id and dmi.object_id = si.object_id)' + char(13) 
	+ 'where dmi.index_type_desc not in (' + '''' + 'HEAP' + '''' + ')'
	execute sp_executesql @sqldml
	fetch next from bancocursor into @banco
end
close bancocursor
deallocate bancocursor
"@

Function Escreve-log ([string]$instancia,[string]$tipo,[string]$descricao)
{
    $datalog = (get-date).ToString('yyyy-MM-dd_HH')
    $data = (get-date).ToString('yyyy-MM-dd HH:mm:ss')
    $objeto = New-Object psobject
    $objeto | Add-Member -MemberType NoteProperty -Name DATA -Value "$data"
    $objeto | Add-Member -MemberType NoteProperty -Name TIPO -Value "$tipocoleta"
    $objeto | Add-Member -MemberType NoteProperty -Name INSTANCIA -Value "$instancia"
    $objeto | Add-Member -MemberType NoteProperty -Name DESCRICAO -Value "$descricao"
    $objeto | Export-Csv -NoTypeInformation -Append -Path "$env:TEMP\ETL-ISTANCEINFO_$($datalog).csv"

}

Function Cadastra-InstanciaMSSQL
{

    
    $tipocoleta = "Cadastra-Instancia"
    change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "delete from ErroColeta_MSSQL where TipoColeta = '$tipocoleta'"
    foreach ($instancia in $script:IntancesArray)
    {
        
        $Error.clear()
        try
        {
            
            Write-Host "VALIDA CONEXAO INSTANCIA $instancia"
            Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "VALIDA CONEXAO INSTANCIA $instancia"
            testeconnect-mssql -instancia $instancia
            $validaversao = (select-mssql -instancia $instancia -banco master -dml "SELECT @@VERSION as versao").versao
            if ($validaversao -like "*2008*")
            {
                Write-Host "INSTANCIA $instancia VERSAO 2008"
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "INSTANCIA $instancia VERSAO 2008"
            }
            else
            {
                $agname = (select-mssql -instancia $instancia -banco master -dml "select name from sys.availability_groups").name
                $ag_replicas = (select-mssql -instancia $instancia -banco master -dml "select replica_server_name from sys.availability_replicas").replica_server_name
                $ag_nodes = $ag_replicas -join ","
            }
            
            if (!$agname)
            {
                $tcpport = (select-mssql -instancia $instancia -banco master -dml "$script:querytcport").local_tcp_port
                $tcpport = $tcpport -join ","
                $minmemory = (select-mssql -instancia $instancia -banco master -dml "$script:queryminmem").ValorMB
                $serverproperty = select-mssql -instancia $instancia -banco master -dml "
                                        SELECT SERVERPROPERTY('ServerName') as ServerName,
                                        SERVERPROPERTY('Collation') as Collation,
                                        SERVERPROPERTY('productversion') as Versao, 
                                        SERVERPROPERTY('ProductUpdateReference') as KbUpdate,
                                        SERVERPROPERTY('Edition') as Edicao"
                $servername = $serverproperty.ServerName
                $collation = $serverproperty.Collation
                $versao = $serverproperty.Versao
                $KbUpdate = $serverproperty.KbUpdate
                $Edicao = $serverproperty.Edicao

                $cadastro = (select-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "select Nome, ServerName from TBInstancia_MSSQL where Nome = '$instancia'").Nome
                
                if (!$cadastro)
                {
                    Write-Warning "CADASTRO DA INSTNACIA $instancia E SERVIOR $servername NO DATABASE DBInstanceInfo"
                    Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "CADASTRO DA INSTNACIA $instancia E SERVIOR $servername NO DATABASE DBInstanceInfo"
                    change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into TBInstancia_MSSQL values ('$instancia','$servername','$minmemory','$tcpport',NULL,NULL,'$collation','$versao','$KbUpdate','$Edicao')"
                }
                else
                {
                    Write-Warning "INSTNACIA $instancia E SERVIDOR $servername CADASTRADOS NO DATABASE DBInstanceInfo, ATUALIZANDO INFORMACOES"
                    Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "INSTNACIA $instancia E SERVIDOR $servername CADASTRADOS NO DATABASE DBInstanceInfo, ATUALIZANDO INFORMACOES"
                    change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "update TBInstancia_MSSQL set Nome = '$instancia', ServerName = '$servername', Memoria = '$minmemory', TcpPort = '$tcpport', AlwaysON_AGName = NULL, AlwysON_Nodes = NULL, Collation = '$collation', versao = '$versao', KbUpdate = '$KbUpdate', Edicao = '$Edicao' where nome = '$instancia'"
                }
            }
            else
            {
                    
                    
                    $tcpport = (select-mssql -instancia $instancia -banco master -dml "$script:querytcport").local_tcp_port
                    $tcpport = $tcpport -join ","
                    $minmemory = (select-mssql -instancia $instancia -banco master -dml "$script:queryminmem").ValorMB
                    $serverproperty = select-mssql -instancia $instancia -banco master -dml "
                                            SELECT SERVERPROPERTY('ServerName') as ServerName,
                                            SERVERPROPERTY('Collation') as Collation,
                                            SERVERPROPERTY('productversion') as Versao, 
                                            SERVERPROPERTY('ProductUpdateReference') as KbUpdate,
                                            SERVERPROPERTY('Edition') as Edicao"
                    $servername = $serverproperty.ServerName
                    $collation = $serverproperty.Collation
                    $versao = $serverproperty.Versao
                    $KbUpdate = $serverproperty.KbUpdate
                    $Edicao = $serverproperty.Edicao

                    $cadastro = (select-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "select Nome, ServerName from TBInstancia_MSSQL where Nome = '$instancia'").Nome
                
                    if (!$cadastro)
                    {
                        Write-Warning "CADASTRO DA INSTNACIA $instancia E SERVIOR $servername NO DATABASE DBInstanceInfo"
                        Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "CADASTRO DA INSTNACIA $instancia E SERVIOR $servername NO DATABASE DBInstanceInfo"
                        change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into TBInstancia_MSSQL values ('$instancia','$servername','$minmemory','$tcpport','$agname','$ag_nodes','$collation','$versao','$KbUpdate','$Edicao')"
                    }
                    else
                    {
                        Write-Warning "INSTNACIA $instancia E SERVIDOR $servername CADASTRADOS NO DATABASE DBInstanceInfo, ATUALIZANDO INFORMACOES"
                        Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "INSTNACIA $instancia E SERVIDOR $servername CADASTRADOS NO DATABASE DBInstanceInfo, ATUALIZANDO INFORMACOES"
                        change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "update TBInstancia_MSSQL set Nome = '$instancia', ServerName = '$servername', Memoria = '$minmemory', TcpPort = '$tcpport', AlwaysON_AGName = '$agname', AlwysON_Nodes = '$ag_nodes', Collation = '$collation', versao = '$versao', KbUpdate = '$KbUpdate', Edicao = '$Edicao' where nome = '$instancia'"
                    }

            }

        }
        catch
        {
           Write-Warning "ERRO NA INSTANCIA $instancia : $servername"
           $Error
           $Errotratado = $error -replace "'",""
           Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "$Error"
           $dataexecucao = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
           change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into ErroColeta_MSSQL values ('$instancia','$dataexecucao','Cadastra-Instancia','$Errotratado')"
        }
    }

}


Function Cadastra-DatabaseMSSQL
{
    
    $tipocoleta = "Cadastra-Database"
    $queryinstancias = select-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "select Nome from TBInstancia_MSSQL"
    change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "delete from ErroColeta_MSSQL where TipoColeta = '$tipocoleta'"
    foreach ($instancia in $queryinstancias.Nome)
    {
        $error.Clear()
        try{

                [int]$CodInstancia = (select-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml  "select CdInstancia from TBInstancia_MSSQL where Nome = '$instancia'").CdInstancia
                Write-Host "TESTA CONEXAO INSTANCIA $instancia"
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "TESTA CONEXAO INSTANCIA $instancia"
                testeconnect-mssql -instancia $instancia
                Write-Warning "LIMPEZA DE REGISTROS DOS DATABASES DA INSTANCIA $instancia"
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "LIMPEZA DE REGISTROS DOS DATABASES DA INSTANCIA $instancia"
                change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "delete from TBDatabase_MSSQL where CdInstancia = $CodInstancia"
                
                $databaseinfo = select-mssql -instancia $instancia -banco master -dml "$script:querydatabase"
                if ($databaseinfo.name.Count -eq 0)
                {

                     Write-Warning "ISTANCIA $instancia NAO POSSUI DATABASES PARA CADASTRO"
                }
                elseif ($databaseinfo.name.Count -eq 1)
                {

                    $dbname = $databaseinfo.name
                    $cmptlevel = $databaseinfo.cmptlevel
                    $version = $databaseinfo.version
                    $TotalSizeMB = $databaseinfo.TotalSizeMB

                    if ($dbname)
                    {
                        Write-Host "CADASTRA DATABASE $dbname"
                        Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "CADASTRA DATABASE $dbname"
                        change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into TBDatabase_MSSQL values ($CodInstancia, '$dbname','$cmptlevel','$version','$TotalSizeMB')"
                    }
                }
                else
                {
                    
                    for ($i=0; $i -le $databaseinfo.name.Count; $i++ )
                    {
                        $dbname = $databaseinfo.name[$i]
                        $cmptlevel = $databaseinfo.cmptlevel[$i]
                        $version = $databaseinfo.version[$i]
                        $TotalSizeMB = $databaseinfo.TotalSizeMB[$i]
                        
                        if ($dbname)
                        {
                            Write-Host "CADASTRA DATABASE $dbname"
                            Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "CADASTRA DATABASE $dbname"
                            change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into TBDatabase_MSSQL values ($CodInstancia, '$dbname','$cmptlevel','$version','$TotalSizeMB')"
                        }
   
                    }
                }
            }
        catch
            {
                Write-Warning "ERRO INSNTANCIA $instancia banco $script:databasename"
                $error
                $Errotratado = $error -replace "'",""
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "$Errotratado"
                $dataexecucao = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into ErroColeta_MSSQL values ('$($instancia) $($script:databasename)','$dataexecucao','Cadastra-Database','$Errotratado')"
            }
    }
}


Function Cadastra-DiscosMSSQL
{
    $tipocoleta = "Cadastra-DiscosMSSQL"
    $queryinstancias = select-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "select Nome from TBInstancia_MSSQL"
    change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "delete from ErroColeta_MSSQL where TipoColeta = 'Cadastra-DiscosMSSQL'"
    foreach ($instancia in $queryinstancias.Nome)
    {
        try
            {
                
                $InfoInstancia = select-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml  "select CdInstancia, Nome from TBInstancia_MSSQL where Nome = '$instancia'"
                [int]$codinstancia = $InfoInstancia.CdInstancia
                Write-Host "VALIDA CONEXAO INSTANCIA $instancia"
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "VALIDA CONEXAO INSTANCIA $instancia"
                testeconnect-mssql -instancia $instancia
                Write-Host "EXECUTA LIMPEZA DOS DADOS DE DISCO DA INSTANCIA $instancia"
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "EXECUTA LIMPEZA DOS DADOS DE DISCO DA INSTANCIA $instancia"
                change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "delete from TBDisks_MSSQL where CdInstancia = $codinstancia"

                $resultdisksizeall = select-mssql -instancia $instancia -banco master -dml "$script:querydisksizeall"
                if ($resultdisksizeall.volume_mount_point.Count -eq 0)
                {
                    Write-Host "NAO HA DATAFILES NOS MOUNTPOINTS DA INSTANCIA $instancia"
                }
                elseif ($resultdisksizeall.volume_mount_point.Count -eq 1)
                {
                    $volume_mount_point = $resultdisksizeall.volume_mount_point
                    $VOLUMESIZE = $resultdisksizeall.VOLUMESIZE
                    $PERCENTFREE = $resultdisksizeall.PERCENTFREE
                    $SizeGB = $resultdisksizeall.SizeGB
                    $FreeSizeGB = $resultdisksizeall.FreeSizeGB
                    $NewSizeGB = $resultdisksizeall.NewSizeGB
                    $MaxSizeGB = $resultdisksizeall.MaxSizeGB

                    if($volume_mount_point -eq ""){$volume_mount_point= $null}
                    if($volume_mount_point)
                    {
                        Write-Host "CADASTRO DO DISCO $volume_mount_point INSTANCIA $instancia"
                        Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "CADASTRO DO DISCO $volume_mount_point INSTANCIA $instancia"
                        change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into TBDisks_MSSQL values ($codinstancia,'$volume_mount_point','$VOLUMESIZE','$PERCENTFREE','$SizeGB','$FreeSizeGB','$NewSizeGB','$MaxSizeGB')"
                    }
                }
                else
                {
                    for ($i=0; $i -le $resultdisksizeall.volume_mount_point.Count; $i++)
                    {
                        $volume_mount_point = $resultdisksizeall.volume_mount_point[$i]
                        $VOLUMESIZE = $resultdisksizeall.VOLUMESIZE[$i]
                        $PERCENTFREE = $resultdisksizeall.PERCENTFREE[$i]
                        $SizeGB = $resultdisksizeall.SizeGB[$i]
                        $FreeSizeGB = $resultdisksizeall.FreeSizeGB[$i]
                        $NewSizeGB = $resultdisksizeall.NewSizeGB[$i]
                        $MaxSizeGB = $resultdisksizeall.MaxSizeGB[$i]

                        if($volume_mount_point -eq ""){$volume_mount_point= $null}
                        
                        if($volume_mount_point)
                        {
                            Write-Host "CADASTRO DO DISCO $volume_mount_point INSTANCIA $instancia"
                            Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "CADASTRO DO DISCO $volume_mount_point INSTANCIA $instancia"
                            change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into TBDisks_MSSQL values ($codinstancia,'$volume_mount_point','$VOLUMESIZE','$PERCENTFREE','$SizeGB','$FreeSizeGB','$NewSizeGB','$MaxSizeGB')"
                        }
                    }
                }
            }
            catch
            {
                Write-Warning "ERRO INSNTANCIA $instancia"
                $error
                $Errotratado = $error -replace "'",""
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "$Errotratado"
                $dataexecucao = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into ErroColeta_MSSQL values ('$($instancia)','$dataexecucao','Cadastra-DiscosMSSQL','$Errotratado')"

            }
    }

}



Function Cadastra-DataFilesMSSQL
{
    $tipocoleta = "Cadastra-DataFilesMSSQL"
    $queryinstancias = select-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "select Nome from TBInstancia_MSSQL"
    change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "delete from ErroColeta_MSSQL where TipoColeta = 'Cadastra-DataFilesMSSQL'"
    foreach ($instancia in $queryinstancias.Nome)
    {
        $error.Clear()
        try
            {

                
                [int]$CodInstancia = (select-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml  "select CdInstancia from TBInstancia_MSSQL where Nome = '$instancia'").CdInstancia
                Write-Host "VALIDA CONEXAO INSTANCIA $instancia"
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "VALIDA CONEXAO INSTANCIA $instancia"
                testeconnect-mssql -instancia $instancia
                Write-Warning "LIMPEZA DOS REGISTROS DE DATAFILES DA INSTANCIA $instancia"
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "LIMPEZA DOS REGISTROS DE DATAFILES DA INSTANCIA $instancia"
                change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "delete from TBDatabaseFiles_MSSQL where CdInstancia = $CodInstancia"
                $datafilesinfo = select-mssql -instancia $instancia -banco master -dml "$script:querydatafile"
                if ($datafilesinfo.Nome.Count -eq 0)
                {
                    Write-Host "NAO CONSTA DATAFILES INSTANCIA $instancia"
                }
                elseif ($datafilesinfo.Nome.Count -eq 1)
                {
                    $NomeDB = $datafilesinfo.Nome
                    $ArquivoDados = $datafilesinfo.ArquivoDados
                    $Tipo = $datafilesinfo.TIPO
                    $physicalName = $datafilesinfo.physical_name
                    $volume_mount_point = $datafilesinfo.volume_mount_point
                    $SizeMB = $datafilesinfo.SizeMB
                    $Crescimento = $datafilesinfo.Crescimento
                    $TipoCrescimento = $datafilesinfo.TipoCrescimento
                    $NewSize = $datafilesinfo.NewSize
                    $MaxSize = $datafilesinfo.MaxSize
                    $FileGroupName = $datafilesinfo.FileGroupName
                    $UsedSpace = $datafilesinfo.UsedSpace
                    $FreeSpace = $datafilesinfo.FreeSpace
                    
                    if ($NomeDB -eq ""){$NomeDB = $null}
                    if ($NomeDB)
                    {
                        Write-Host "CADASTRA DATAFILE $physicalName INSTANCIA $instancia"
                        Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao  "CADASTRA DATAFILE $physicalName INSTANCIA $instancia"
                        change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into TBDatabaseFiles_MSSQL values ($CodInstancia,'$NomeDB','$ArquivoDados','$Tipo','$physicalName','$SizeMB','$Crescimento','$TipoCrescimento','$NewSize','$MaxSize','$FileGroupName','$volume_mount_point','$UsedSpace','$FreeSpace')"
                    }

                }
                else
                {
                    for ($i=0; $i -le $datafilesinfo.Nome.Count; $i++)
                    {
                        $NomeDB = $datafilesinfo.Nome[$i]
                        $ArquivoDados = $datafilesinfo.ArquivoDados[$i]
                        $Tipo = $datafilesinfo.TIPO[$i]
                        $physicalName = $datafilesinfo.physical_name[$i]
                        $volume_mount_point = $datafilesinfo.volume_mount_point[$i]
                        $SizeMB = $datafilesinfo.SizeMB[$i]
                        $Crescimento = $datafilesinfo.Crescimento[$i]
                        $TipoCrescimento = $datafilesinfo.TipoCrescimento[$i]
                        $NewSize = $datafilesinfo.NewSize[$i]
                        $MaxSize = $datafilesinfo.MaxSize[$i]
                        $FileGroupName = $datafilesinfo.FileGroupName[$i]
                        $UsedSpace = $datafilesinfo.UsedSpace[$i]
                        $FreeSpace = $datafilesinfo.FreeSpace[$i]

                        if ($NomeDB -eq ""){$NomeDB = $null}
                        if ($NomeDB)
                        {
                            Write-Host "CADASTRA DATAFILE $physicalName INSTANCIA $instancia"
                            Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao  "CADASTRA DATAFILE $physicalName INSTANCIA $instancia"
                            change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into TBDatabaseFiles_MSSQL values ($CodInstancia,'$NomeDB','$ArquivoDados','$Tipo','$physicalName','$SizeMB','$Crescimento','$TipoCrescimento','$NewSize','$MaxSize','$FileGroupName','$volume_mount_point','$UsedSpace','$FreeSpace')"
                        }
                    }
                }

            }
        catch
            {
                 Write-Warning "ERRO INSNTANCIA $instancia banco $NomeDB"
                $error
                $Errotratado = $error -replace "'",""
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "$Errotratado"
                $dataexecucao = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into ErroColeta_MSSQL values ('$($instancia) $($NomeDB)','$dataexecucao','Cadastra-DataFilesMSSQL','$Errotratado')"

            }

    }
}



Function Cadastra-IndiceMSSQL
{
    $tipocoleta = "Cadastra-IndiceMSSQL"
    $queryinstancias = (select-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "select Nome from TBInstancia_MSSQL").Nome
    change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "delete from ErroColeta_MSSQL where TipoColeta = 'Cadastra-IndiceMSSQL'"
    foreach ($instancia in $queryinstancias)
    {
        $error.Clear()
        try
            {

                [int]$CodInstancia = (select-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml  "select CdInstancia from TBInstancia_MSSQL where Nome = '$instancia'").CdInstancia
                Write-Host "VALIDA CONEXAO INSTANCIA $instancia (CdInstancia: $CodInstancia)"
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "VALIDA CONEXAO INSTANCIA $instancia"
                testeconnect-mssql -instancia $instancia
                Write-Warning "LIMPEZA DOS REGISTROS DE INDICE DA INSTANCIA $instancia"
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "LIMPEZA DOS REGISTROS DE INDICE DA INSTANCIA $instancia"
                change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "delete from TBIndex_MSSQL where CdInstancia = $CodInstancia"
                $indexinfo = select-mssql -instancia $instancia -banco master -dml "$script:queryindice"
                if ($indexinfo.banco.Count -eq 0)
                {
                    Write-Host "NAO CONSTA DATAFILES INSTANCIA $instancia"
                }
                elseif ($indexinfo.banco.Count -eq 1)
                {
                    $NomeDB = $indexinfo.banco
                    $schema_name = $indexinfo.schema_name
                    $tabela = $indexinfo.tabela
                    $indice = $indexinfo.indice
                    $tipo_indice = $indexinfo.tipo_indice
                    $avg_fragmentation = $indexinfo.avg_fragmentation
                    
                    if ($NomeDB -eq ""){$NomeDB = $null}
                    if ($NomeDB)
                    {
                        Write-Host "CADASTRA INDICE $indice INSTANCIA $instancia"
                        Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao  "CADASTRA INDICE $indice INSTANCIA $instancia"
                        change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into TBIndex_MSSQL values ($CodInstancia,'$NomeDB','$schema_name','$tabela','$indice','$tipo_indice',$avg_fragmentation)"
                    }

                }
                else
                {
                    for ($i=0; $i -le $indexinfo.banco.Count; $i++)
                    {
                        $NomeDB = $indexinfo.banco[$i]
                        $schema_name = $indexinfo.schema_name[$i]
                        $tabela = $indexinfo.tabela[$i]
                        $indice = $indexinfo.indice[$i]
                        $tipo_indice = $indexinfo.tipo_indice[$i]
                        $avg_fragmentation = $indexinfo.avg_fragmentation[$i]
                    
                        if ($NomeDB -eq ""){$NomeDB = $null}
                        if ($NomeDB)
                        {
                            Write-Host "CADASTRA INDICE $indice INSTANCIA $instancia"
                            Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao  "CADASTRA INDICE $indice INSTANCIA $instancia"
                            $validaindice = $null
                            $validaindice = (select-mssql -instancia "$script:DbInstanceInfo" -banco "DBInstanceInfo" -dml "select indice from TBIndex_MSSQL where CdInstancia = $CodInstancia and nome = '$NomeDB' and schema_name = '$schema_name' and tabela = '$tabela' and indice = '$indice'").indice
                            
                            if (!$validaindice)
                            {
                                change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into TBIndex_MSSQL values ($CodInstancia,'$NomeDB','$schema_name','$tabela','$indice','$tipo_indice',$avg_fragmentation)"
                            }
                            else
                            {
                                Write-Warning "$($instancia): O INDICE $indice DA TABELA $($tabela) ENCONTRA CADASTRADO"
                            }
                        }
                    }
                }

            }
        catch
            {
                 Write-Warning "ERRO INSNTANCIA $instancia banco $NomeDB"
                $error
                $Errotratado = $error -replace "'",""
                Escreve-log -instancia "$instancia" -tipo $tipocoleta -descricao "$Errotratado"
                $dataexecucao = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                change-mssql -instancia $script:DbInstanceInfo -banco DBInstanceInfo -dml "insert into ErroColeta_MSSQL values ('$($instancia) $($NomeDB)','$dataexecucao','Cadastra-IndiceMSSQL','$Errotratado')"

            }

    }
}

clear-host
WRITE-HOST "DBINSTANCE INFO - COLETA DE INFORMAÇÔES centralizadas de instâncias SQL SERVER"
$script:DbInstanceInfo = read-host  "INFORME A INSTANCIA DO DBINSTANCEINFO"
DO {
       
        clear-host
        WRITE-HOST "DBINSTANCE INFO - COLETA DE INFORMAÇÔES centralizadas de instâncias SQL SERVER"
        WRITE-HOST "UTILIZARÁ CMS OU NOME DAS INSTÂNCIAS SEPARADAS POR VÍRGULA"
        Write-Host "DIGITE 1 - COLETA USANDO CMS"
        Write-Host "DIGITE 2 - COLETA COM NOME DAS INSTÂNCIAS SEPARADAS POR VÍRGULA"
        Write-Host "DIGITE UMA DAS OPCOES OU SAIR"
        $script:tipocoleta = Read-Host "INFORME UMA DAS OPCOES, 1, OU 2, OU SAIR"
    } until ($script:tipocoleta -eq 1 -or $script:tipocoleta -eq 2 -or $script:tipocoleta -eq "SAIR")

switch ($script:tipocoleta)
{
    1 {
         select-mssql -instancia $script:DbInstanceInfo -banco MSDB -dml $script:querycms
        }
    2 {
            $script:IntancesArray = read-host  "Informe a lista de instancias separadas por virgula"
            $script:IntancesArray = $script:IntancesArray -replace " ","" -split ","
        }
}

DO {
       
        clear-host
        WRITE-HOST "DBINSTANCE INFO - COLETA DE INFORMAÇÔES centralizadas de instâncias SQL SERVER"
        WRITE-HOST "UTILIZARÁ WINDOWS AUTENTHICATION OU USUÁRIO E SENHA?"
        Write-Host "DIGITE 1 - WINDOWS AUTHENTICATION"
        Write-Host "DIGITE 2 - USUARIO E SENHA"
        Write-Host "DIGITE UMA DAS OPCOES OU SAIR"
        $script:autenticacao = Read-Host "INFORME UMA DAS OPCOES"
    } until ($script:autenticacao -eq 1 -or $script:autenticacao -eq 2 -or $script:autenticacao -eq "SAIR")


switch ($script:autenticacao)
{
    1{
        $script:InfoConn = "Integrated Security = True"
        }
    2{
        $usuario = Read-Host "INFORME O USUARIO"
        $senha = Read-Host "INFORME A SENHA"
        $script:InfoConn = "User ID=$usuario;Password=$senha"
        }

}

# Integrated Security = True


Write-Host "################## CADASTRA INSTANCIA ##################"
Cadastra-InstanciaMSSQL
Write-Host "################## CADASTRA DISCO ##################"
Cadastra-DiscosMSSQL
Write-Host "################## CADASTRA DATABASE ##################"
Cadastra-DatabaseMSSQL
Write-Host "################## CADASTRA DATAFILE ##################"
Cadastra-DataFilesMSSQL
Write-Host "################## CADASTRA INDICE ##################"
Cadastra-IndiceMSSQL