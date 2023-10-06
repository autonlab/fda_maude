# fda_maude
Scripts to download and wrangle publicly available data from FDA Manufacturer and User Facility Device Experience database

Script to download and do light wrangling on FDA MAUDE data
Converts files at link to a flat csv file
https://www.fda.gov/medical-devices/mandatory-reporting-requirements-manufacturers-importers-and-device-user-facilities/about-manufacturer-and-user-facility-device-experience-maude

HOW TO RUN
1. Edit the bash script with two variables
	 - Set a working directory where you want the data to be stored.  Without removing intermediate files, this will take ~80Gb of disk space
	 - Set the size of the resulting chunks - the 33Gb database will be split into small pieces
2. Run from command line
	$ ./get_maude.sh
3. Enjoy a coffee break and come back in about an hour
    ~30 minutes to download at 10Mb/s and decompress everything
    ~30 minutes to wrangle 2013+ data into a flat pipe-delimited csv file
4. Results will be placed in file MAUDE
    I recommend checking the first few lines to make sure there aren't unexpected bugs
    $ head MAUDE
    Look up the MDR_REPORT_KEY and make sure the text lines up
    https://www.accessdata.fda.gov/scripts/cdrh/cfdocs/cfMAUDE/TextSearch.cfm
