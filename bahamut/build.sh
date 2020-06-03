
echo "********************************************************************************"
echo "Bahamut Senki English translation build script"
echo "********************************************************************************"

echo "********************************************************************************"
echo "Setting up environment..."
echo "********************************************************************************"

set -o errexit

PATH=".:$PATH"

BASE_PWD=$PWD
INROM="bahamut.md"
OUTROM="bahamut_en.md"
#WLADX="./wla-dx/binaries/wla-z80"
#WLALINK="./wla-dx/binaries/wlalink"
#rm -f -r "out"

M68KASM="68kasm/68kasm"

cp "$INROM" "$OUTROM"

echo "********************************************************************************"
echo "Building project tools..."
echo "********************************************************************************"

make blackt
make libmd
make

if [ ! -f $M68KASM ]; then
  echo "************************************************************************"
  echo "Building 68kasm..."
  echo "************************************************************************"
  
  cd 68kasm
    gcc -std=c99 *.c -o 68kasm
    
#    if [ ! $? -eq 0 ]; then
#      echo "Error compiling 68kasm"
#      exit
#    fi
  cd "$BASE_PWD"
fi

# cd 68kasm
# 
#   echo "************************************************************************"
#   echo "Assembling hacks..."
#   echo "************************************************************************"
# 
#   # Assemble code
#   ./68kasm -l bahamut.asm
# 
# cd "$BASE_PWD"

echo "********************************************************************************"
echo "Generating font..."
echo "********************************************************************************"

mkdir -p out
bhmt_fontbuild "font/8x16.png" 0x3F "out/font_8x16.bin" 0x0 0xF
#./datpatch "$OUTROM" "$OUTROM" out/font_8x16.bin 0x77880

echo "*******************************************************************************"
echo "Building tilemaps..."
echo "*******************************************************************************"

mkdir -p out/maps
mkdir -p out/grp

for file in tilemappers/*; do
  echo $file
  ./tilemapper_md "$file"
done

for file in out/grp/*.bin; do
  ./bin2dcb "$file" > $(dirname $file)/$(basename $file .bin).inc
done

for file in out/maps/*.bin; do
  ./bin2dcb "$file" > $(dirname $file)/$(basename $file .bin).inc
done

echo "********************************************************************************"
echo "Generating script binaries (8x16)..."
echo "********************************************************************************"

mkdir -p out/script/8x16
bhmt_txtinsr "script/trans/bahamut_16x16.csv" "table/bahamut_en_8x16.tbl" 0x90000 0x80000 "out/font_8x16.bin" "out/script/8x16/"

./bin2dcb "out/font_8x16.bin" > "out/asm/font_8x16.inc"

echo "********************************************************************************"
echo "Generating script binaries (8x8)..."
echo "********************************************************************************"

mkdir -p out/script/8x8
bhmt_txtinsr_8x8 "script/trans/bahamut_8x8.csv" "table/bahamut_en_8x8.tbl" 0xA0000 "out/script/8x8/"
mv -f out/script/8x8/font_8x8.bin out
mv -f out/script/8x8/font_8x8_lower.bin out

./bin2dcb "out/font_8x8.bin" > "out/asm/font_8x8.inc"
./bin2dcb "out/font_8x8_lower.bin" > "out/asm/font_8x8_lower.inc"

./bin2dcb "out/territory_menu_header.bin" > "out/asm/territory_menu_header.inc"

echo "********************************************************************************"
echo "Applying ASM patches..."
echo "********************************************************************************"

mkdir -p out/asm
cp asm/* out/asm/

$M68KASM -l "out/asm/bahamut.asm"
  
echo "************************************************************************"
echo "Patching assembled hacks to ROM..."
echo "************************************************************************"

# "Link" output
./srecpatch "$OUTROM" "$OUTROM" < "out/asm/bahamut.h68"
  
echo "************************************************************************"
echo "Patching script binaries to ROM..."
echo "************************************************************************"

# "Link" output
./datpatch "$OUTROM" "$OUTROM" out/script/8x16/table_fontpacks.bin 0x80000
./datpatch "$OUTROM" "$OUTROM" out/script/8x16/table_strings_8x16.bin 0x90000
./datpatch "$OUTROM" "$OUTROM" out/script/8x8/table_strings_8x8.bin 0xA0000
  
echo "************************************************************************"
echo "Finalizing ROM..."
echo "************************************************************************"

./romprep "$OUTROM" 0x100000 "$OUTROM"

echo "********************************************************************************"
echo "Success!"
echo "Output ROM: $OUTROM"
echo "********************************************************************************"



