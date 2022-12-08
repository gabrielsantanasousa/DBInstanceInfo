use DBInstanceInfo
go


create table TBInstancia_MSSQL
		(
			CdInstancia int identity (1,1) constraint PK_TBInstancia_MSSQL primary key,
			Nome varchar(50)  not null,
			ServerName varchar(50) not null,
			Memoria varchar(20),
			TcpPort varchar(40),
			AlwaysON_AGName varchar(30),
			AlwysON_Nodes varchar(200),
			Collation varchar(40),
			Versao varchar(20),
			KbUpdate varchar(20),
			Edicao varchar(100)
		)
go

create unique index IDX_TBInstancia_MSSQL on TBInstancia_MSSQL(Nome,ServerName)
go


create table TBDatabase_MSSQL
	(
		CdInstancia int not null,
		Nome varchar(110) not null,
		cmptlevel varchar(8),
		version varchar(8),
		TotalSizeMB numeric (12,0)
	)
GO

alter table TBDatabase_MSSQL add constraint PK_TBDatabase_MSSQL_NomeCdInst primary key (CdInstancia,Nome)
go
alter table TBDatabase_MSSQL add constraint FK_TBInstancia_MSSQL_TBDatabase_MSSQL foreign key (CdInstancia) references TBInstancia_MSSQL(CdInstancia) on delete cascade
go

Create Table TBDisks_MSSQL
	(
		CdInstancia int not null constraint FK_TBInstancia_MSSQL_TBDisks_MSSQL foreign key (CdInstancia) references TBInstancia_MSSQL(CdInstancia) on delete cascade,
		MountPoint varchar(200) not null,
		VolumeSize numeric(12,2),
		PercentFree numeric(12,2),
		SizeGB numeric(12,2),
		FreeSizeGB numeric(12,2),
		NewSizeGB numeric(12,2),
		MaxSizeGB numeric(12,2)
	)
go
Alter table TBDisks_MSSQL add constraint PK_TBDisks_MSSQL primary key(CdInstancia,MountPoint)
go

create table TBDatabaseFiles_MSSQL
	(
		CdInstancia int not null,
		Nome varchar(110) not null,
		ArquivoDados varchar(110) not null,
		Tipo varchar (12) not null,
		physical_name varchar(150) not null,
		SizeMB numeric (12,2),
		Crescimento varchar (8),
		TipoCrescimento varchar (12),
		NewSize  numeric (12,2),
		MaxSize varchar(16)
	)
go
alter table TBDatabaseFiles_MSSQL add constraint FK_TBDatabase_MSSQL_TBDatabaseFiles_MSSQL foreign  key (CdInstancia,Nome) references TBDatabase_MSSQL (CdInstancia,Nome) on delete cascade
go
alter table TBDatabaseFiles_MSSQL add constraint PK_TBDatabaseFiles_MSSQL primary key (CdInstancia,Nome,ArquivoDados,tipo)
go
alter table TBDatabaseFiles_MSSQL add FileGroupName varchar(50)
go
alter table TBDatabaseFiles_MSSQL add volume_mount_point varchar(150)
go
alter table TBDatabaseFiles_MSSQL add UsedSpace int
go
alter table TBDatabaseFiles_MSSQL add FreeSpace int
go

create table TBIndex_MSSQL
	(
		CdInstancia int not null,
		Nome varchar(110) not null,
		schema_name varchar(50) not null,
		tabela varchar(70) not null,
		indice varchar(110) not null,
		tipo_indice varchar(60),
		avg_fragmentation int
	)
go
alter table TBIndex_MSSQL add constraint FK_TBDatabase_MSSQL_TBIndex_MSSQL foreign key (CdInstancia,Nome) references TBDatabase_MSSQL (CdInstancia,Nome) on delete cascade
go
alter table TBIndex_MSSQL add constraint PK_TBIndex_MSSQL primary key (CdInstancia,Nome,schema_name,tabela,indice)
go



create table ErroColeta_MSSQL
(
	Nome varchar(120),
	Data datetime,
	TipoColeta varchar(20)
) 
go
alter table ErroColeta_MSSQL alter column Nome varchar(160)
go
alter table ErroColeta_MSSQL alter column TipoColeta varchar(30)
go
alter table ErroColeta_MSSQL alter column Erro varchar(800)
go