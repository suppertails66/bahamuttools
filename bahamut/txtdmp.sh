
make libmd && make bhmt_txtdmp
make libmd && make bhmt_txtdmp_8x8
make libmd && make bhmt_listdmp

mkdir -p script/csv
./bhmt_txtdmp bahamut.md table/bahamut_16x16.tbl script/bahamut_txt_dmpscript_16x16.txt script/csv/bahamut_16x16.csv
./bhmt_txtdmp_8x8 bahamut.md table/bahamut_8x8.tbl script/bahamut_txt_dmpscript_8x8.txt script/csv/bahamut_8x8.csv
./bhmt_listdmp bahamut.md table/bahamut_16x16.tbl > script/csv/bahamut_events.csv
