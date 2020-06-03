
make libmd && make grpunmap

mkdir -p rsrc/orig

./grpunmap rsrc_raw/grp/title_vram.bin rsrc_raw/map/title_nologo.bin 64 6 rsrc/orig/title_nologo.png -p rsrc_raw/pal/title.pal
# ./grpunmap rsrc_raw/grp/title_vram.bin rsrc_raw/map/title_logo.bin 64 6 rsrc/orig/title_logo.png -p rsrc_raw/pal/title.pal
./grpunmap rsrc_raw/grp/title_vram.bin rsrc_raw/map/title_logo.bin 64 7 rsrc/orig/title_logo.png -p rsrc_raw/pal/title.pal
