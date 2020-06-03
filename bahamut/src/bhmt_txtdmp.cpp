#include "util/TIfstream.h"
#include "util/TBufStream.h"
#include "util/TStringConversion.h"
#include "util/TGraphic.h"
#include "util/TPngConversion.h"
#include "util/TThingyTable.h"
#include "md/MdPattern.h"
#include "bahamut/BahamutFontPackDecmp.h"
#include "bahamut/BahamutStringDecmp.h"
#include <map>
#include <string>
#include <iostream>

#define TABLEMODE 1

using namespace std;
using namespace BlackT;
using namespace Md;

TIfstream rom;
TThingyTable thingy;
std::ifstream ifs;
std::ofstream ofs;
map<int, int> fontPackMap;
int curPackAddr = -1;

#ifdef TABLEMODE
  void dumpString(int addr) {
    // decompress string
    rom.seek(addr);
    TBufStream datofs(0x1000);
    BahamutStringDecmp(rom, datofs)();
    datofs.seek(0);
    
    // write to output
    ofs << "String"
        << ","
          << TStringConversion::intToString(addr,
                        TStringConversion::baseHex)
        << ","
          << TStringConversion::intToString(rom.tell(),
                        TStringConversion::baseHex)
        << ","
          // render method (blank = default)
          << "default"
        << ",";
    
    // Japanese content
    ofs << "\"";
    while (datofs.remaining() > 0) {
      int index = datofs.readu16be();
      
      // index 0 == space
      if (index == 0) {
        ofs << "\x81\x40";
        continue;
      }
      
      map<int, int>::iterator findIt = fontPackMap.find(index);
      
      if (findIt == fontPackMap.end()) {
        cerr << "Bad index for string "
          << TStringConversion::intToString(addr,
                      TStringConversion::baseHex) << ": "
          << index << endl;
        break;
      }
      
      int realIndex = findIt->second;
  //        cerr << hex << index << "-";
  //        cerr << hex << realIndex << " ";
      if (!thingy.hasEntry(realIndex)) {
        cerr << "Bad real index for string "
          << TStringConversion::intToString(addr,
                      TStringConversion::baseHex) << ": "
          << realIndex << endl;
        break;
      }
      
      ofs << thingy.getEntry(realIndex);
    }
  //      cerr << endl;
    ofs << "\"";

    // Placeholder for English content
    ofs << ",";
    
    ofs << endl;
  }

  void dumpFontPack(int addr) {
    // decompress the font pack
    rom.seek(addr);
    TBufStream datofs(0x1000);
    BahamutFontPackDecmp(rom, datofs)();
    
    // set up map
    datofs.seek(0);
    int numEntries = datofs.readu16be() + 1;
    fontPackMap.clear();
    for (int i = 0; i < numEntries; i++) {
      fontPackMap[i + 1] = datofs.readu16be();
  //        std::cerr << std::hex << fontPackMap[i] << " ";
    }
  //      cerr << std::endl << std::endl;

    ofs << "FontPack," << TStringConversion::intToString(addr,
                      TStringConversion::baseHex)
        << ","
        << TStringConversion::intToString(rom.tell(),
                      TStringConversion::baseHex) << endl;
  }
#else
  void dumpString(int addr) {
    // decompress string
    rom.seek(addr);
    TBufStream datofs(0x1000);
    BahamutStringDecmp(rom, datofs)();
    datofs.seek(0);
    
    // write to output
    ofs << "// "
  //          << "string "
        << TStringConversion::intToString(addr,
                      TStringConversion::baseHex)
        << "-"
        << TStringConversion::intToString(rom.tell(),
                      TStringConversion::baseHex)
        << endl;
    while (datofs.remaining() > 0) {
      int index = datofs.readu16be();
      
      // index 0 == space
      if (index == 0) {
        ofs << "\x81\x40";
        continue;
      }
      
      map<int, int>::iterator findIt = fontPackMap.find(index);
      
      if (findIt == fontPackMap.end()) {
        cerr << "Bad index for string "
          << TStringConversion::intToString(addr,
                      TStringConversion::baseHex) << ": "
          << index << endl;
        break;
      }
      
      int realIndex = findIt->second;
  //        cerr << hex << index << "-";
  //        cerr << hex << realIndex << " ";
      if (!thingy.hasEntry(realIndex)) {
        cerr << "Bad real index for string "
          << TStringConversion::intToString(addr,
                      TStringConversion::baseHex) << ": "
          << realIndex << endl;
        break;
      }
      
      ofs << thingy.getEntry(realIndex);
    }
  //      cerr << endl;
    
    ofs << endl << endl;
  }

  void dumpFontPack(int addr) {
    // decompress the font pack
    rom.seek(addr);
    TBufStream datofs(0x1000);
    BahamutFontPackDecmp(rom, datofs)();
    
    // set up map
    datofs.seek(0);
    int numEntries = datofs.readu16be() + 1;
    fontPackMap.clear();
    for (int i = 0; i < numEntries; i++) {
      fontPackMap[i + 1] = datofs.readu16be();
  //        std::cerr << std::hex << fontPackMap[i] << " ";
    }
  //      cerr << std::endl << std::endl;
    
    ofs << "// *******************************************" << endl;
    ofs << "// pack " << TStringConversion::intToString(addr,
                      TStringConversion::baseHex)
        << "-" << TStringConversion::intToString(rom.tell(),
                      TStringConversion::baseHex)
        << endl;
    ofs << "// characters: ";
    for (int i = 0; i < numEntries; i++) {
      ofs << thingy.getEntry(fontPackMap[i + 1]) << " ";
    }
    ofs << endl;
    ofs << "// *******************************************" << endl;
    ofs << endl;
  }
#endif

int main(int argc, char* argv[]) {
  if (argc < 5) {
    cout << "Bahamut Senki text dumper" << endl;
    cout << "Usage: " << argv[0] << " <rom> <thingy> <ripfile> <outfile>"
      << endl;
    
    return 0;
  }
  
/*  TIfstream ifs("bahamut.md", ios_base::binary);
  ifs.seek(0xB52);
  
  TBufStream ofs(0x10000);
  
  BahamutFontPackDecmp(ifs, ofs)();
  
  ofs.save("test.bin"); */
  
/*  TIfstream rom(argv[1], ios_base::binary);
  TThingyTable thingy;
  thingy.readSjis(string(argv[2]));
  std::ifstream ifs(argv[3]);
  std::ofstream ofs(argv[4]); */
  
  rom.open(argv[1], ios_base::binary);
  thingy.readSjis(string(argv[2]));
  ifs.open(argv[3]);
  ofs.open(argv[4]);
  
  #ifdef TABLEMODE
    ofs << "cmd,addr,end,rendercmd,jp,en" << endl;
  #endif
  
  string command;
  ifs >> command;
  
  while (ifs.good()) {
    if (command.size() <= 0) break;
    
    if (command[0] == '#') {
      // comment -- handled by getline below
    }
    else if (command.compare("*") == 0) {
      string output;
      getline(ifs, output);
      ifs.unget();
      if (output.size() > 0) {
        #ifdef TABLEMODE
          ofs << ",,,\"";
          ofs << "//" << output.substr(1, string::npos);
  //        ofs << endl;
          ofs << "\"";
          ofs << endl;
        #else
          ofs << "//" << output.substr(1, string::npos) << endl;
        #endif
      }
      else
        ofs << endl;
    }
    else if (command.compare("pack") == 0) {
      string addrstr;
      ifs >> addrstr;
      int addr = TStringConversion::stringToInt(addrstr);
      curPackAddr = addr;
      
      dumpFontPack(addr);
    }
    else if (command.compare("string") == 0) {
      string addrstr;
      ifs >> addrstr;
      int addr = TStringConversion::stringToInt(addrstr);
      
      dumpString(addr);
    }
    else if (command.compare("stringset") == 0) {
      string addrstr;
      ifs >> addrstr;
      int addr = TStringConversion::stringToInt(addrstr);
      
      string countstr;
      ifs >> countstr;
      int count = TStringConversion::stringToInt(countstr);
      
      for (int i = 0; i < count; i++) {
        #ifndef TABLEMODE
          ofs << "// set " << addrstr << ", string " << i + 1 << endl;
        #endif
        dumpString(addr);
        addr = rom.tell();
      }
    }
    else if (command.compare("stringsetfixed") == 0) {
      string addrstr;
      ifs >> addrstr;
      int addr = TStringConversion::stringToInt(addrstr);
      
      string sizestr;
      ifs >> sizestr;
      int size = TStringConversion::stringToInt(sizestr);
      
      string countstr;
      ifs >> countstr;
      int count = TStringConversion::stringToInt(countstr);
      
      for (int i = 0; i < count; i++) {
        #ifndef TABLEMODE
          ofs << "// set " << addrstr << ", size " << size
            << ", string " << i + 1 << endl;
        #endif
        dumpString(addr);
        addr += size;
      }
    }
    else {
      cerr << "Error: unknown command " << command << endl;
      return 1;
    }

    string garbage;
    getline(ifs, garbage);
  
    ifs >> command;
  }
  
//  TBufStream ofs(0x10000);
  
//  BahamutStringDecmp(ifs, ofs)();
  
//  ofs.save("test2.bin");
  
//  std::cout << ofs.size() << std::endl;
  
  return 0;
}
