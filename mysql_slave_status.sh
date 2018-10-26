#! /bin/sh
PW=P4SWORD
DBUSER=DB-USER

echo -n "\n\n" $(hostname -f) "\n\n"
echo -n "SLAVE STATUS qualent to node-db1 master status \n"
mysql -u $DBUSER -p$PW -e "show slave status\G" | grep -E -i "Master_Log_File|Exec_Master_Log_Pos|Read_Master_Log_Pos|Err"

echo -n "MASTER STATUS\n"
mysql -u $DBUSER -p$PW -e "show master status\G"


