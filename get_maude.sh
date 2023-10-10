#!/bin/bash

# Script to download and do light wrangling on FDA MAUDE data
# Converts files at link to a flat csv file
# https://www.fda.gov/medical-devices/mandatory-reporting-requirements-manufacturers-importers-and-device-user-facilities/about-manufacturer-and-user-facility-device-experience-maude

# HOW TO RUN
# 1. Set a working directory where you want the data to be stored
#    Without removing intermediate files, this will take ~80Gb of disk space
MAXLINES=200000 #joined MAUDE database split into files with MAXLINES lines
WDIR='/local_data/maude/'
if [ ! -d ${WDIR} ]; then
	mkdir ${WDIR}
fi
# 2. Run from command line
#    $ ./get_maude.sh
# 3. Enjoy a coffee break and come back in about an hour
#    ~20 minutes to download at 10Mb/s and decompress everything
#    ~20 minutes to wrangle 2013+ data into a flat pipe-delimited csv file
# 4. Results will be placed in file MAUDE
#    I recommend checking the first few lines to make sure there aren't unexpected bugs
#    $ head MAUDE
#    Look up the MDR_REPORT_KEY and make sure the text lines up
#    https://www.accessdata.fda.gov/scripts/cdrh/cfdocs/cfMAUDE/TextSearch.cfm

# Variables that only need to be updated if FDA adds new data or changes format
URL=https://www.accessdata.fda.gov/MAUDE/ftparea/
TMP=${WDIR}temp
TMP2=${WDIR}temp2
DTYPES=(device foidev foitext patient mdrfoi)
device=({2000..2022} "" add change)
foidev=(thru1997 1998 1999)
foitext=(thru1995 {1996..2022} "" add change)
patient=(thru2022 add change "")
mdrfoi=(thru2022 add change "")

# Function definitions to keep the script readable
function download () { wget -q --show-progress -P ${WDIR} ${URL}$1;}
function decompress () { 
	unzip -n -q -L ${WDIR}$1 -d ${WDIR}
	rm ${WDIR}$1
}
function to_utf8 () {
	iconv -f latin1 -t UTF-8 ${WDIR}$1 | cat > ${TMP}
	mv ${TMP} ${WDIR}$1
}
function rm_winM () { sed -i -e "s/\r//g" ${WDIR}$1; }
function to_unix () { dos2unix -q ${WDIR}$1; }
function drop_multiline () {
	colIDs=$(head -1 ${WDIR}$1 | awk -F\| '{print NF}')
	regex="NF==${colIDs}"
	awk -F\| ${regex} ${WDIR}$1 | cat > ${TMP}
	mv ${TMP} ${WDIR}$1
}
function sort_body_by_key() {
		tail -n +2 ${WDIR}$1 | LANG=en_EN sort -t\| -s -k1,1 | cat - > ${TMP}
		head -1 ${WDIR}$1 > ${TMP2}
		cat ${TMP2} ${TMP} > ${WDIR}$1
		check_join_input $1
}
function check_join_input() { tail -n +2 ${WDIR}$1 | LANG=en_EN sort -s -c -t\| -k1,1; }
function multi_key_to_left() {
	paste -d\| <(cut -d\| -f$2,$3 ${WDIR}$1) <(cut -d\| -f$2,$3 --complement ${WDIR}$1) > ${TMP}
	mv ${TMP} ${WDIR}$1
}
function add_leading_zeros() {
	head -1 ${WDIR}$1 > columns
	tail -n +2 ${WDIR}$1 > body
	cut -d\| -f1 body > ${TMP}
	cat ${TMP} | awk '{ printf "%08d\n", $1 }' > ${TMP2}
	paste -d\| ${TMP2} <(cut -d\| -f1 --complement body) > ${TMP}
	cat columns ${TMP} > ${WDIR}$1
	rm columns body
}
function remove_leading_zeros() {
	head -1 ${WDIR}$1 > columns
	tail -n +2 ${WDIR}$1 > body
	cut -d\| -f1 body > ${TMP}
	cat ${TMP} | awk '{ printf "%d\n", $1 }' > ${TMP2}
	paste -d\| ${TMP2} <(cut -d\| -f1 --complement body) > ${TMP}
	cat columns ${TMP} > ${WDIR}$1
}
function get_maude_dataset() {
	filename=$1
	download ${filename}.zip
	decompress ${filename}.zip
	to_utf8 ${filename}.txt
	to_unix ${filename}.txt
	rm_winM ${filename}.txt
	drop_multiline ${filename}.txt
}

# The main part of the script - Download all available files from FDA, wrangle them, and join into a single BIG file
for dtype in ${DTYPES[@]}; do
	dsnames="${dtype}[@]" #https://stackoverflow.com/questions/40307250/indirect-reference-to-array-values-in-bash
	for dsname in ${!dsnames}; do
		if ! test -f ${WDIR}${dtype}${dsname}.txt; then
			get_maude_dataset ${dtype}${dsname}
		else
			echo "${dtype}${dsname}.zip exists in ${WDIR}"
		fi
	done
done
dtype='problems' # less rigid structure around these files that provide mappings to decipher select attributes inI above datasets
problems=(deviceproblemcodes patientproblemcode patientproblemdata foidevproblem)
for dsname in ${problems[@]}; do
	download ${dsname}.zip
	decompress ${dsname}.zip
done
#patientproblemdata unzips to patientproblemcodes.csv
for filename in deviceproblemcodes.csv patientproblemcode.txt patientproblemcodes.csv foidevproblem.txt; do
	to_utf8 ${filename}
	to_unix ${filename}
	rm_winM ${filename}
done
# Start manipulating files - starting by tackling the well structured stuff and will expand to edge cases
cat ${WDIR}patientthru2022.txt > ${WDIR}patient
cat ${WDIR}mdrfoithru2022.txt > ${WDIR}mdr
cat ${WDIR}device2013.txt > ${WDIR}device
cat ${WDIR}foitext2013.txt > ${WDIR}text
#Online database only has back to 2013, so mirroring here
for year in {2013..2022}; do 
	tail -n +2 ${WDIR}device${year}.txt | cat >> ${WDIR}device
	tail -n +2 ${WDIR}foitext${year}.txt | cat >> ${WDIR}text
done
#patient, mdr, device, text, should contain at least 2000-2022 records
for ds in patient mdr device text; do
	add_leading_zeros ${ds}
	sort_body_by_key ${ds}
done
## Join on MDR_REPORT_KEY
echo MDR_REPORT_KEY > KEY
paste <(head -1 ${WDIR}mdr) <(head -1 ${WDIR}patient) <(head -1 ${WDIR}device) <(head -1 ${WDIR}text) -d\| | \
	sed -e "s/MDR_REPORT_KEY|//g" | paste -d\| KEY - > columns
join -j1 -t\| <(tail -n +2 ${WDIR}mdr) <(tail -n +2 ${WDIR}patient) > ${TMP}
join -j1 -t\| ${TMP} <(tail -n +2 ${WDIR}device) > ${TMP2}
join -j1 -t\| ${TMP2} <(tail -n +2 ${WDIR}text) > ${WDIR}MAUDE
remove_leading_zeros MAUDE

# Clean Up, split into small files and add header to each,
# Header has duplicates that need suffixes to become unique
# How to check contiguous chunks of the file:
# $ head -n 100 MAUDE | tail -n 50
# The above will return rows 50-100 of MAUDE
for repeated_column_name in DATE_RECEIVED DATE_REPORT PATIENT_SEQUENCE_NUMBER; do
	#https://stackoverflow.com/questions/23001835/how-do-i-pass-shell-variable-into-a-perl-search-and-replace
	#https://unix.stackexchange.com/questions/402286/how-to-make-incremental-replace-in-files-with-bash
	perl -i -pe "s/$repeated_column_name\K/sprintf \"_%d\",++\$i/ge" columns
done
split -l ${MAXLINES} -a 3 -d ${WDIR}MAUDE ${WDIR}MAUDE_S
for filename in ${WDIR}MAUDE_S*; do
	echo ${filename}
	#drop quotations which confuse newlines and drop rows with too many/few rows
	cat columns ${filename} | sed -e "s/\"//g" | awk -F\| "NF==126" | cat >${TMP}
	cp ${TMP} ${filename}
done
rm ${TMP} ${TMP2} columns body
