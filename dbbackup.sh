#! /bin/sh

#set -x

# This program is free software published under the terms of the GNU GPL.
#
# (C) Institut TELECOM + Olivier Berger <olivier.berger@it-sudparis.eu> 2007-2009
# $Id: curl-backup-phpmyadmin.sh 10 2010-07-21 17:13:38Z berger_o $

# updated to support phpMyAdmin 3.5.8 @ Wedos by Vladimir Navrat

#
# This saves dumps of your Database using CURL and connecting to
# phpMyAdmin (via HTTPS), keeping the 10 latest backups by default
#
# Tested on phpMyAdmin 2.11.5.1
#
# For those interested in debugging/adapting this script, the firefox
# add-on LiveHttpHeaders is a very interesting extension to debug HTTP
# transactions and guess what's needed to develop such a CURL-based
# script.
#

# Please adapt these values :
user=yourusername
password=yourpassword
remote_host=pma-old.wedos.net
server=https://$remote_host/
# database to be saved
database=databasename

# will work with apache Basicauth, and needs to be changed if logging-in with phpmyadmin dialog
#auth=basicauth
auth=formauth

# if the phpmyadmin server is able to compress on server-side.
#compression=on
compression=off

# End of customisations

rm -f curl.headers
rm -f cookies.txt
rm -f export.php


###############################################################
#
# First login and fetch the cookie which will be used later
#
###############################################################

MKTEMP=/bin/tempfile
if [ ! -x $MKTEMP ]; then
     MKTEMP=$(which mktemp)
#    MKTEMP=$(whereis -b mktemp | grep -o -e "[^ ]*$")
fi

result=$($MKTEMP)

if [ "$auth" = "basicauth" ]
then
    # if using the apache auth

    entry_params="--anyauth -u$user:$password"
else
    # if using the phpmyadmin login dialog :

    # First, try to login from main page to initialize tokens and cookies from scratch
    #set -x
    curl -s -k -D curl.headers -L -c cookies.txt --keepalive-time 300 $server/index.php >$result

    token=$(grep link $result | grep token | sed "s/^.*token=//" | sed "s/&amp;.*//")
    #echo $token

    cookie=$(cat cookies.txt | cut  -f 6-7 | grep phpMyAdmin | cut -f 2)
    #echo $cookie

    # Then we can reuse these cookies and tokens to prepare a POST for actual login

    entry_params="-d \"phpMyAdmin=$cookie&phpMyAdmin=$cookie&pma_username=$user&pma_password=$password&server=1&phpMyAdmin=$cookie&lang=en-utf-8&convcharset=utf-8&collation_connection=utf8_general_ci&token=$token&input_go=Go\""
#    entry_params="-d \"pma_username=$user&pma_password=$password&server=1&token=$token&input_go=Go\""
#    entry_params="-d \"pma_username=$user&pma_password=$password&server=1&token=$token\""
fi

#user_agent="Mozilla/5.0 (X11; U; Linux i686; fr; rv:1.9.1.10) Gecko/20100623 Iceweasel/3.5.10 (like Firefox/3.5.10)"
#accept="Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

# POST of the login form
#-A "$user_agent" -H "$accept" -e $server/index.php
curl -s -S -k -L  -D curl.headers -b cookies.txt -c cookies.txt $entry_params $server/index.php >$result

if [ $? -ne 0 ]
then
     echo "Curl Error on : curl $entry_params -s -k -D curl.headers -L -c cookies.txt $server/index.php. Check contents of $result" >&2
     exit 1
fi
grep -q "HTTP/1.1 200 OK" curl.headers
if [ $? -ne 0 ]
then
         echo -n "Error : couldn't login to phpMyadmin on $server/index.php" >&2
         grep "HTTP/1.1 " curl.headers >&2
         exit 1
fi

# No need to go to the server_export.php page to get the token any longer
# Thanks to David Prévot <david@tilapin.org>, for confirming that, btw

#md5cookie=$(grep main.php $result | sed 's/.*token=//' | sed 's/".*//')
md5cookie=$token


# #location=$(grep Location: curl.headers)
# #token=$(grep Location: curl.headers | sed "s/^.*token=//" | sed "s/&phpMyAdmin.*//")
# #echo $token
# cookie=$(cat cookies.txt | cut  -f 6-7 | grep phpMyAdmin | cut -f 2)
# md5cookie=$(echo $cookie | md5sum | cut -d ' ' -f 1)

# # Access the page which contains the export POST form
# curl  -s -S -o server_export.php -k -D curl.headers -b cookies.txt -u$user:$password -e "$server/main.php?token=$md5cookie" "$server/server_export.php?token=$md5cookie"

# if [ $? -ne 0 ]
# then
#      echo "Curl Error" >&2
#      exit 1
# fi

# grep -q "HTTP/1.1 200 OK" curl.headers
# if [ $? -ne 0 ]
# then
#       echo -n "Error : access the form page at $server/server_export.php" >&2
#       grep "HTTP/1.1 " curl.headers >&2
#       exit 1
# fi

# # get new token from the hidden form param
# md5cookie=$(grep input server_export.php | grep hidden | grep token | sed 's/^.*value="//' | sed 's/".*//')


###############################################################
#
# Then fetch the dump using the cookie/token
#
###############################################################

# You may need to adapt this based on the setup on your side...

post_params="token=$md5cookie"
post_params="$post_params&export_type=server"

post_params="$post_params&export_method=quick"
post_params="$post_params&quick_or_custom=quick"

post_params="$post_params&db_select[]=$database"
post_params="$post_params&what=sql"
post_params="$post_params&codegen_structure_or_data=data"
# post_params="$post_params&codegen_format=0"
# post_params="$post_params&csv_separator=%3B"
# post_params="$post_params&csv_enclosed=%22"
# post_params="$post_params&csv_escaped=%5C"
# post_params="$post_params&csv_terminated=AUTO"
# post_params="$post_params&csv_null=NULL"
post_params="$post_params&csv_data="
# post_params="$post_params&excel_null=NULL"
# post_params="$post_params&excel_edition=win"
post_params="$post_params&excel_data="
# post_params="$post_params&htmlword_structure=something"
post_params="$post_params&htmlword_data=something"
# post_params="$post_params&htmlword_null=NULL"
# post_params="$post_params&latex_caption=something"
# post_params="$post_params&latex_structure=something"
# post_params="$post_params&latex_structure_caption=Structure+of+table+__TABLE__"
# post_params="$post_params&latex_structure_continued_caption=Structure+of+table+__TABLE__+%28continued%29"
# post_params="$post_params&latex_structure_label=tab%3A__TABLE__-structure"
# post_params="$post_params&latex_comments=something"
post_params="$post_params&latex_data=something"
# post_params="$post_params&latex_columns=something"
# post_params="$post_params&latex_data_caption=Content+of+table+__TABLE__"
# post_params="$post_params&latex_data_continued_caption=Content+of+table+__TABLE__+%28continued%29"
# post_params="$post_params&latex_data_label=tab%3A__TABLE__-data"
# post_params="$post_params&latex_null=%5Ctextit%7BNULL%7D"
post_params="$post_params&mediawiki_data="
# post_params="$post_params&ods_null=NULL"
post_params="$post_params&ods_data="
# post_params="$post_params&odt_structure=something"
# post_params="$post_params&odt_comments=something"
post_params="$post_params&odt_data=something"
# post_params="$post_params&odt_columns=something"
# post_params="$post_params&odt_null=NULL"
# post_params="$post_params&pdf_report_title="
post_params="$post_params&pdf_data=1"
post_params="$post_params&php_array_data="
post_params="$post_params&sql_header_comment="
post_params="$post_params&sql_include_comments=something"
post_params="$post_params&sql_compatibility=NONE"
#post_params="$post_params&sql_structure=something"
post_params="$post_params&sql_structure_or_data=structure_and_data"
post_params="$post_params&sql_if_not_exists=something"
post_params="$post_params&sql_auto_increment=something"
post_params="$post_params&sql_backquotes=something"
#post_params="$post_params&sql_data=something"
post_params="$post_params&sql_columns=something"
post_params="$post_params&sql_extended=something"
post_params="$post_params&sql_max_query_size=50000"
post_params="$post_params&sql_hex_for_blob=something"
post_params="$post_params&sql_type=INSERT"
# post_params="$post_params&texytext_structure=something"
post_params="$post_params&texytext_data=something"
# post_params="$post_params&texytext_null=NULL"
# post_params="$post_params&xls_null=NULL"
post_params="$post_params&xls_data="
# post_params="$post_params&xlsx_null=NULL"
post_params="$post_params&xlsx_data="
post_params="$post_params&yaml_data="
post_params="$post_params&asfile=sendit"
post_params="$post_params&filename_template=__SERVER__"
post_params="$post_params&remember_template=on"

if [ "$compression" = "on" ]
then
    post_params="$post_params&compression=gzip"
else
    post_params="$post_params&compression=none"
fi

#&sql_hex_for_binary=something

#2.7.0-pl2
#post_params="$post_params&sql_structure=structure"
#post_params="$post_params&sql_auto_increment=1"
#post_params="$post_params&sql_compat=NONE"
#post_params="$post_params&use_backquotes=1"
#post_params="$post_params&sql_data=data"
#post_params="$post_params&hexforbinary=yes"
#post_params="$post_params&sql_type=insert"
#post_params="$post_params&lang=fr-utf-8&server=1&collation_connection=utf8_general_ci&buttonGo=Exécuter"

# eventually for not full database dump, but selection of tables, adapt something like :
#db=$database&export_type=database&table_select%5B%5D=dc_captcha&table_select%5B%5D=dc_categorie&table_select%5B%5D=dc_comment&table_select%5B%5D=dc_link&table_select%5B%5D=dc_log&table_select%5B%5D=dc_ping&table_select%5B%5D=dc_post&table_select%5B%5D=dc_post_cat&table_select%5B%5D=dc_post_meta&table_select%5B%5D=dc_session&table_select%5B%5D=dc_spamplemousse&table_select%5B%5D=dc_spamwords&table_select%5B%5D=dc_spam_categories&table_select%5B%5D=dc_spam_wordfreqs&table_select%5B%5D=dc_user&filename_template=__DB__


#set -x

# Now do the real export reusing the cookies

#curl -v $entry_params -s -S -O -k -D curl.headers -b cookies.txt -d "$post_params&buttonGo=Go" $server/export.php
#-e "$server/server_export.php?token=$token"
#curl -v -s -S -O -k -D curl.headers -L -b cookies.txt -d "$post_params&buttonGo=Go" $server/export.php
#curl -s -S -O -k -D curl.headers -L -b cookies.txt -A "$user_agent" -H "$accept" -d "$post_params" $server/export.php
curl -s -S -O -k -D curl.headers -L -b cookies.txt -d "$post_params" $server/export.php


grep -q "Content-Disposition: attachment" curl.headers
if [ $? -eq 0 ]
then

    #filename=$(grep "Content-Disposition: attachment" curl.headers | sed -e 's/.*filename="//' | sed -e 's/".*$//' | sed -e "s/\.sql/_${database}_$(date  +%Y%m%d%H%M).sql/")

    filename="$(echo $remote_host | sed 's/\./-/g')_${database}_$(date  +%Y%m%d%H%M).sql"

    if [ "$compression" = "on" ]
    then
        filename="$filename.gz"
        mv export.php backup_mysql_$filename
        echo "Saved in backup_mysql_$filename"
    else
        mv export.php backup_mysql_$filename
        gzip backup_mysql_$filename
        echo "Saved in backup_mysql_$filename.gz"
    fi

fi

# remove the old backups and keep the 10 younger ones.
#ls -1 backup_mysql_*${database}_*.gz | sort -u | head -n-10 | xargs -r rm -v

rm -f $result
