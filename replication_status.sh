#! /bin/sh

    PW=P4SSWORD
DBUSER=DB-USER

remoteSlave=$(ssh -p22 node-db2 /home/user/mysql_slave_status.sh | grep -E -i "Master_Log_File|Exec_Master_Log_Pos" | awk '{print $2}'| uniq )
localMaster=$(mysql -u $DBUSER -p$PW -e "show master status\G" | grep -E "mariadb|Position" | awk '{print $2}')

echo -n "REPLICATION STATUS IS:\n"
if [ "$localMaster" == "$remoteSlave" ]; then echo "OK"; else echo "NOT OK";fi

echo -n "\n";
echo -n "remote Slave: "$remoteSlave"\n";
echo -n "local Master: "$localMaster"\n";
