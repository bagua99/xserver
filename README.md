1、导入mysql

mysql -u root -p

输入密码进入mysql

source /home/bagua/xserver/xserver.sql;


2、编译skynet

cd /home/bagua/xserver/skynet

make linux


3、修改/home/bagua/xserver/ 目录下config_game_pdk.lua、config_game_dgnn.lua、config_game_yzbp.lua里面IP地址改为自己云服务器IP


4、启动login.sh(登录服)、lobby.sh(大厅)、game_pdk.sh(跑得快游戏)、game_dgnn.sh(地锅牛牛)、game_yzbp.sh(永州包牌)
