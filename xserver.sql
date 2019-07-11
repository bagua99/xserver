drop database if exists xserver;

create database xserver character set utf8;

use xserver;

-- ----------------------------
-- Table structure for account
-- ----------------------------
DROP TABLE IF EXISTS `account`;
CREATE TABLE `account` (
  `account` varchar(32) NOT NULL,
  `password` varchar(32) DEFAULT NULL,
  `sex` int(11) DEFAULT NULL,
  `headimgurl` varchar(256) DEFAULT NULL,
  `nickname` varchar(64) DEFAULT NULL,
  `userid` int(11) DEFAULT NULL,
  `openid` varchar(64) DEFAULT NULL,
  `unionid` varchar(64) DEFAULT NULL,
  `refresh_token` varchar(64) DEFAULT NULL,
  `refresh_time` datetime DEFAULT NULL,
  `access_token` varchar(64) DEFAULT NULL,
  `access_time` datetime DEFAULT NULL,
  `language` varchar(32) DEFAULT NULL,
  `city` varchar(32) DEFAULT NULL,
  `province` varchar(32) DEFAULT NULL,
  `country` varchar(32) DEFAULT NULL,
  `privilege` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for player
-- ----------------------------
DROP TABLE IF EXISTS `player`;
CREATE TABLE `player` (
  `userid` int(11) NOT NULL,
  `score` bigint(24) DEFAULT NULL,
  `roomcard` int(11) DEFAULT NULL,
  `sign` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`userid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Table structure for roomcard_log
-- ----------------------------
DROP TABLE IF EXISTS `roomcard_log`;
CREATE TABLE `roomcard_log` (
  `userid` int(11) DEFAULT NULL,
  `add_type` int(11) DEFAULT NULL,
  `roomid` int(11) DEFAULT NULL,
  `begin_roomcard` int(11) DEFAULT NULL,
  `end_roomcard` int(11) DEFAULT NULL,
  `cost_roomcard` int(11) DEFAULT NULL,
  `date` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
