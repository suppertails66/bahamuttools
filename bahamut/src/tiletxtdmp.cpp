#include "util/TThingyTable.h"
#include "util/TStringConversion.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TBufStream.h"
#include "exception/TGenericException.h"
#include <string>
#include <fstream>
#include <iostream>

using namespace std;
using namespace BlackT;

void dumpTileText(TIfstream& ifs, std::ostream& ofs,
                  TThingyTable& thingy,
//                  int addr,
                  int w, int h) {
  int addr = ifs.tell();
  ofs << "// " << TStringConversion::intToString(addr,
                    TStringConversion::baseHex)
       << endl;
  ofs << "#SETADDR(" << TStringConversion::intToString(addr,
                    TStringConversion::baseHex)
       << ")"
       << endl;
  
  ifs.seek(addr);
  
  
  for (int j = 0; j < h; j++) {
    ofs << "//";
    for (int i = 0; i < w; i++) {
      int next = ifs.readu8();
      if (!thingy.hasEntry(next)) {
        ofs << "?";
        cerr << "error" << endl;
      }
      else {
        ofs << thingy.getEntry(next);
      }
    }
    ofs << endl;
  }
  
  ofs << endl << endl;
}

int main(int argc, char* argv[]) {
/*  if (argc < 4) {
    cout << "Binary -> text converter, via Thingy table" << endl;
    cout << "Usage: " << argv[0] << " <thingy> <rom> <outfile>"
      << endl;
    cout << "The Thingy table must be in SJIS (or compatible) format."
      << endl;
    cout << "Note that only one-byte encoding sequences are supported."
      << endl;
    
    return 0;
  }
  
  TThingyTable thingy;
  thingy.readSjis(string(argv[1]));
  NesRom rom = NesRom(string(argv[2]));
//  int offset = TStringConversion::stringToInt(argv[3]);
  TBufStream ifs(rom.size());
  ifs.write((char*)rom.directRead(0), rom.size());
//  std::ifstream ifs(argv[2], ios_base::binary);
  std::ofstream ofs(argv[3], ios_base::binary);
  
  ifs.seek(pointerTableStart);
  int bankNum
    = UxRomBanking::directToBankNumMovable(pointerTableStart);
  
  for (int i = 0; i < numPointerTableEntries; i++) {
    int pointer = ifs.readu16le();
    int nextPos = ifs.tell();
    int physicalPointer
      = UxRomBanking::bankedToDirectAddressMovable(bankNum, pointer);
    
    ifs.seek(physicalPointer);
    printScript(ifs, ofs, thingy);
    
    ifs.seek(nextPos);
  }
  
//  while (ifs.good()) {
//    int next = (unsigned char)ifs.get();
//    if (thingy.hasEntry(next)) {
//      ofs << thingy.getEntry(next);
//      
//      if (next == 0x00) ofs << endl;
//    }
//  } 
  
  return 0; */

  if (argc < 4) {
    cout << "Tile-based text dumper" << endl;
    cout << "Usage: " << argv[0] << " <thingy> <infile> <outfile>" << endl;
    cout << "The Thingy table must be in SJIS (or compatible) format."
      << endl;
    
    return 0;
  }
  
  TThingyTable thingy;
  thingy.readSjis(string(argv[1]));
//  TIfstream ifs(argv[2], ios_base::binary);
  std::ifstream ifs(argv[2], ios_base::binary);
  std::ofstream ofs(argv[3], ios_base::binary);
  
  
  while (ifs.good()) {
    int next = (unsigned char)ifs.get();
    
    if (thingy.hasEntry(next)) {
    
      ofs << thingy.getEntry(next);
    }
      
    if ((ifs.tellg() % 0x40) == 0) {
      ofs << std::endl;
      ofs << "// $" << std::hex << ifs.tellg() << std::endl;
    }
  } 
  
/*  for (int i = 0; i < 521; i++) {
    string left
      = TStringConversion::intToString(i, TStringConversion::baseHex);
    left = left.substr(2, string::npos);
    cout << left << "=？" << std::endl;
  } */
  
  return 0; 
}
