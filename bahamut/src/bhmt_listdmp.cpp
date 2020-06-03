#include "util/TIfstream.h"
#include "util/TBufStream.h"
#include "util/TStringConversion.h"
#include "util/TGraphic.h"
#include "util/TPngConversion.h"
#include "util/TThingyTable.h"
#include "md/MdPattern.h"
#include "bahamut/BahamutFontPackDecmp.h"
#include "bahamut/BahamutStringDecmp.h"
#include <string>
#include <vector>
#include <iostream>

using namespace std;
using namespace BlackT;
using namespace Md;

int main(int argc, char* argv[]) {
  if (argc < 3) {
    cout << "Bahamut Senki event list dumper" << endl;
    cout << "Usage: " << argv[0] << " <infile> <table>"
      << endl;
    
    return 0;
  }
  
/*  TIfstream ifs("bahamut.md", ios_base::binary);
  ifs.seek(0xB52);
  
  TBufStream ofs(0x10000);
  
  BahamutFontPackDecmp(ifs, ofs)();
  
  ofs.save("test.bin"); */
  
/*  TIfstream ifs("bahamut.md", ios_base::binary);
  ifs.seek(0xB9F);
  
  TBufStream ofs(0x10000);
  
  BahamutStringDecmp(ifs, ofs)();
  
  ofs.save("test2.bin"); */
  
//  std::cout << ofs.size() << std::endl;
  
  TIfstream ifs(argv[1], ios_base::binary);
  
/*  ifs.seek(0x37ECA);
  for (int i = 0; i < 0x3A; i++) {
    int baseaddr = ifs.tell();
    int offset = ifs.readu16be();
//    ifs.seek(baseaddr + offset);
    
    cout << "pack "
      << TStringConversion::intToString(baseaddr + offset,
          TStringConversion::baseHex)
      << endl;
      
    ifs.seek(baseaddr + (0x3A * 2));
    int stringbaseaddr = ifs.tell();
    int stringoffset = ifs.readu16be();
    
    cout << "string "
      << TStringConversion::intToString(stringbaseaddr + stringoffset,
          TStringConversion::baseHex)
      << endl;
    
    cout << endl;
    
    ifs.seek(baseaddr + 2);
  } */
  
  // endings
/*  ifs.seek(0xB9B0);
  for (int i = 0; i < 0x9; i++) {
    int baseaddr = ifs.tell();
    int offset = ifs.readu16be();
    int textOffset = ifs.readu16be();
//    ifs.seek(baseaddr + offset);
    
    
    cout << "* =============================================" << endl;
    cout << "*  ending " << i << endl;
    cout << "* =============================================" << endl;
    cout << "*" << endl;
    cout << "pack "
      << TStringConversion::intToString(baseaddr + offset,
          TStringConversion::baseHex)
      << endl;
      
    ifs.seek(baseaddr + 2 + textOffset);
    int unknown = ifs.readu8be();
//    int stringbaseaddr = ifs.tell();
//    int stringoffset = ifs.readu16be();
    
//    cout << "*  code: " << TStringConversion::intToString(unknown,
//          TStringConversion::baseHex) << endl;
    cout << "stringset "
      << TStringConversion::intToString(baseaddr + 2 + textOffset + 1,
          TStringConversion::baseHex)
      << " "
      << TStringConversion::intToString(unknown + 1,
          TStringConversion::baseHex)
      << endl;
    
    cout << endl;
    
    ifs.seek(baseaddr + 4);
  } */
  
  // ?
/*  ifs.seek(0x6046);
  for (int i = 0; i < 0x4; i++) {
    int baseaddr = ifs.tell();
    int numstr = ifs.readu16be();
    int textOffset = ifs.readu16be();
    int ptr = ifs.readu32be();
//    ifs.seek(baseaddr + offset);
    
    
    cout << "* =============================================" << endl;
    cout << "*  ??? " << i << endl;
    cout << "* =============================================" << endl;
    cout << "*" << endl;
    cout << "pack "
      << TStringConversion::intToString(ptr,
          TStringConversion::baseHex)
      << endl;
      
//    ifs.seek(baseaddr + 2 + textOffset);
//    int unknown = ifs.readu8be();
//    int stringbaseaddr = ifs.tell();
//    int stringoffset = ifs.readu16be();
    
//    cout << "*  code: " << TStringConversion::intToString(unknown,
//          TStringConversion::baseHex) << endl;
    cout << "stringset "
      << TStringConversion::intToString(baseaddr + 2 + textOffset,
          TStringConversion::baseHex)
      << " "
      << TStringConversion::intToString(1,
          TStringConversion::baseHex)
      << endl;
    
    cout << endl;
    
    ifs.seek(baseaddr + 8);
  } */
  
  cout << "cmd,addr,rendercmd,jp,en" << endl;
  
  TThingyTable table;
  table.readSjis(string(argv[2]));
  ifs.seek(0x1B70);
//  for (int i = 0; i < TStringConversion::stringToInt(string(argv[1])); i++) {
  for (int i = 0; i < 30; i++) {
    cout << "String,";
    cout << TStringConversion::intToString(ifs.tell(),
          TStringConversion::baseHex);
    cout << ",default,";
    int numchars = ifs.readu16be() + 1;
    std::vector<int> chars;
    for (int j = 0; j < numchars; j++) {
      chars.push_back(ifs.readu16be());
    }
    
    cout << "\"";
    for (int j = 0; j < chars.size(); j++) {
      cout << table.getEntry(chars[j]);
    }
    cout << "\"";
    
    cout << endl;
  }
  
  return 0;
}
