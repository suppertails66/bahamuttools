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
/*  if (argc < 5) {
    cout << "Bahamut Senki font dumper" << endl;
    cout << "Usage: " << argv[0] << " <infile> <outprefix> <pos> <numchars>"
      << endl;
    
    return 0;
  } */
  
  TIfstream ifs("bahamut.md", ios_base::binary);
  
  TThingyTable table;
  table.readSjis("table/bahamut_16x16.tbl");
  
  ifs.seek(0x1A976);
  TBufStream datofs;
  BahamutFontPackDecmp(ifs, datofs)();
  
  std::cerr << "end: " << std::hex << ifs.tell() << std::endl;
  
  datofs.seek(0);
//  for (int i = 0; i < TStringConversion::stringToInt(string(argv[1])); i++) {
    int numchars = datofs.readu16be() + 1;
    std::vector<int> chars;
    for (int j = 0; j < numchars; j++) {
      chars.push_back(datofs.readu16be());
    }
    
    for (int j = 0; j < chars.size(); j++) {
      cout << table.getEntry(chars[j]);
    }
    cout << endl;
//  }
  
  return 0;
}
