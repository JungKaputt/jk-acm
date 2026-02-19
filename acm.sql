CREATE TABLE IF NOT EXISTS `acm_organizations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `label` varchar(50) NOT NULL,
  `owner` varchar(50) NOT NULL COMMENT 'CitizenID of Owner',
  `balance` int(11) DEFAULT 0,
  `description` text DEFAULT NULL,
  `image` text DEFAULT NULL COMMENT 'URL Logo Organisasi',
  `announcements` text DEFAULT NULL,
  `rules` text DEFAULT NULL,
  `permissions` longtext DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `acm_members` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `org_id` int(11) NOT NULL,
  `citizenid` varchar(50) NOT NULL,
  `name` varchar(100) NOT NULL,
  `grade` int(11) DEFAULT 1 COMMENT '1: Recruit, 5: Boss',
  `joined_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `org_id` (`org_id`),
  CONSTRAINT `fk_acm_members` FOREIGN KEY (`org_id`) REFERENCES `acm_organizations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `acm_turfs` (
  `id` varchar(50) NOT NULL,
  `label` varchar(50) NOT NULL,
  `owner_org_id` int(11) DEFAULT 0,
  `progress` int(11) DEFAULT 0,
  `shield_expires` int(11) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `acm_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `org_id` int(11) NOT NULL,
  `citizenid` varchar(50) DEFAULT 'SYSTEM',
  `name` varchar(100) DEFAULT 'System',
  `action` varchar(50) NOT NULL,
  `amount` int(11) DEFAULT 0,
  `details` text DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `org_id` (`org_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `acm_stashes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `org_id` int(11) NOT NULL,
  `coords` text NOT NULL COMMENT 'JSON coordinates',
  `pin` varchar(10) NOT NULL,
  `placed_by` varchar(50) DEFAULT NULL,
  `items` longtext DEFAULT NULL COMMENT 'JSON Inventory Data', 
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `org_id` (`org_id`),
  CONSTRAINT `fk_acm_stashes` FOREIGN KEY (`org_id`) REFERENCES `acm_organizations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE acm_organizations 
ADD COLUMN logo LONGTEXT DEFAULT NULL,
ADD COLUMN slogan VARCHAR(255) DEFAULT NULL;
ALTER TABLE acm_organizations ADD COLUMN color VARCHAR(50) DEFAULT '#6c5ce7';

CREATE TABLE IF NOT EXISTS `acm_applications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `org_id` int(11) DEFAULT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `message` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `acm_dynamic_turfs` (
  `org_id` int(11) NOT NULL,
  `coords` text NOT NULL COMMENT 'JSON coordinates',
  `placed_by` varchar(50) DEFAULT NULL,
  `attacker_id` int(11) DEFAULT 0,
  `progress` int(11) DEFAULT 0,
  `shield_expires` int(11) DEFAULT 0,
  PRIMARY KEY (`org_id`),
  CONSTRAINT `fk_acm_dynamic_turfs` FOREIGN KEY (`org_id`) REFERENCES `acm_organizations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;