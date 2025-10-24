crtsh () {
    query=$(cat <<-END
        SELECT
            ci.NAME_VALUE
        FROM
            certificate_and_identities ci
        WHERE
            plainto_tsquery('certwatch', '$1') @@ identities(ci.CERTIFICATE)
END
)
    echo "$query" | psql -t -h crt.sh -p 5432 -U guest certwatch | sed 's/ //g' | grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} -E --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox} ".*.\.$1" | sed 's/*\.//g' | tr '[:upper:]' '[:lower:]' | sort -u
}

get_certificate () {
    openssl s_client -showcerts -servername $1 -connect $1:443 2> /dev/null | openssl x509 -inform pem -noout -text
}

get_ip_asn () {
    input=""
    while read line
    do
        curl -s https://api.bgpview.io/ip/$line | jq -r ".data.prefixes[0].asn.asn"
    done < "${1:-/dev/stdin}"
}

get_asn_details () {
    input=""
    while read line
    do
        curl -s https://api.bgpview.io/asn/$line | jq -r ".data | {asn: .asn, name: .name, des: .description_short, email: .email_contacts}"
    done < "${1:-/dev/stdin}"
}

httpx_full () {
        input="" 
        while read line
        do
                echo $line | httpx -silent -follow-host-redirects -title -status-code -cdn -tech-detect -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:108.0) Gecko/20100101 Firefox/108.0" -H "Referer: $line"
        done < "${1:-/dev/stdin}"
}

dns_brute_full () {
        echo "cleaning..."
        rm -f "$1.wordlist $1.dns_brute $1.dns_gen"
        echo "making static wordlist..."
        awk -v domain="$1" '{print $0"."domain}' "$WL_PATH/subdomains/assetnote-merged.txt" >> "$1.wordlist"
        echo "making 4 chars wordlist..."
        awk -v domain="$1" '{print $0"."domain}' "$WL_PATH/4-lower.txt" >> "$1.wordlist"
        echo "shuffledns static brute-force..."
        shuffledns -list $1.wordlist -d $1 -r ~/.resolvers -m $(which massdns) -mode resolve -t 30 -silent | tee $1.dns_brute 2>&1 > /dev/null
        echo "[+] finished, total $(wc -l $1.dns_brute) resolved..."
        echo "running subfinder..."
        subfinder -d $1 -all | dnsx -silent | anew $1.dns_brute 2>&1 > /dev/null
        echo "[+] finished, total $(wc -l $1.dns_brute) resolved..."
        echo "running DNSGen..."
        cat $1.dns_brute | dnsgen -w $WL_PATH/subdomains/words.txt - > $1.dns_gen 2>&1 > /dev/null
        echo "finished with $(wc -l $1.dns_gen) words..."
        echo "shuffledns dynamic brute-force on dnsgen results..."
        shuffledns -list $1.dns_gen -d $1 -r ~/.resolvers -m $(which massdns) -mode resolve -t 30 -silent | anew $1.dns_brute 2>&1 > /dev/null
        echo "[+] finished, total $(wc -l $1.dns_brute) resolved..."
}

param_maker () {
    filename="$1"
    value="$2"
    counter=0
    query_string="?"
    while IFS= read -r keyword
    do
        if [ -n "$keyword" ]
        then
            counter=$((counter+1))
            query_string="${query_string}${keyword}=${value}${counter}&"
        fi
        if [ $counter -eq 25 ]
        then
            echo "${query_string%?}"
            query_string="?"
            counter=0
        fi
    done < "$filename"
    if [ $counter -gt 0 ]
    then
        echo "${query_string%?}"
    fi
}

nice_katana () {
    while read line
    do
        host=$(echo $line | unfurl format %d)
        echo "$line" | katana -js-crawl -jsluice -known-files all -automatic-form-fill -silent -crawl-scope $host -extension-filter json,js,fnt,ogg,css,jpg,jpeg,png,svg,img,gif,exe,mp4,flv,pdf,doc,ogv,webm,wmv,webp,mov,mp3,m4a,m4p,ppt,pptx,scss,tif,tiff,ttf,otf,woff,woff2,bmp,ico,eot,htc,swf,rtf,image,rf,txt,ml,ip | tee ${host}.katana
    done < "${1:-/dev/stdin}"
}
