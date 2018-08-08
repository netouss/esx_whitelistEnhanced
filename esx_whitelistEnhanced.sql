USE `essentialmode`;

CREATE TABLE `whitelist` (
	`identifier` varchar(70) NOT NULL,
	`last_connection` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	`ban_reason` text,
	`ban_until` timestamp NULL DEFAULT NULL,
	`vip` int(11) NOT NULL DEFAULT '0',

	PRIMARY KEY (`identifier`)
);

CREATE TABLE `rocade` (
	`identifier` VARCHAR(50) NOT NULL,
	`name` VARCHAR(50) NOT NULL,
	`inconnection` TINYINT(4) NOT NULL DEFAULT '0',
	`waiting` TINYINT(4) NOT NULL DEFAULT '0',
	`place` INT(11) NULL DEFAULT NULL,
	`priority` TINYINT(4) NOT NULL DEFAULT '0',
	PRIMARY KEY (`identifier`)
);
