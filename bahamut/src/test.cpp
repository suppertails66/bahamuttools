#include <iostream>
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TBufStream.h"
//#include "util/TFolderManip.h"
#include "util/TStringConversion.h"
#include "util/TThingyTable.h"
#include "util/TGraphic.h"
#include "util/TPngConversion.h"
#include "md/Md.h"
#include <iostream>

using namespace std;
using namespace BlackT;
  
TIfstream rom;
TThingyTable thingy;

void readString() {
  while (true) {
    if ((unsigned char)rom.peek() == 0xFF) {
      rom.get();
      break;
    }
    else if ((unsigned char)rom.peek() >= 0x80) {
      if (((rom.peek() & 0x40) == 0)
          || ((rom.peek() & 0x1F) != 0)) {
        rom.get();
      }
      else {
        rom.get();
        rom.get();
      }
    }
    else {
      break;
    }
  }
  
  int count = ((unsigned char)rom.get() & 0x07) + 1;
  
  cout << "* =========" << endl;
  cout << "*  section" << endl;
  cout << "* =========" << endl;
  cout << "*" << endl;
  for (int i = 0; i < count; i++) {
    int addr = rom.tell();
    cout << "string " << TStringConversion::intToString(addr,
                            TStringConversion::baseHex)
        << endl;
    
    while (rom.peek() != 0x00) rom.get(); //cout << thingy.getEntry((unsigned int)rom.get());
    rom.get();
  }
  cout << endl;
}

int main(int argc, char* argv[]) {
/*  rom.open("bahamut.md", ios_base::binary);
  rom.seek(0x3E48E);
  thingy.readSjis("bahamut_8x8.tbl");
  
  while (rom.tell() < 0x3F9B9) {
    readString();
  } */
  
  rom.open("bahamut.md", ios_base::binary);
  rom.seek(0x2CDB2);
  
  for (int i = 0; i < 40; i++) {
    rom.readu8();
    int smallNamePtr = rom.tell();
    
    cout << "stringset "
      << TStringConversion::intToString(smallNamePtr,
              TStringConversion::baseHex)
      << " 1" << endl;
      
    while (rom.get() != 0x00);
    
    rom.seekoff(4);
    int count = rom.readu8() + 1;
    rom.seekoff(count);
  }
  
  return 0;
}
