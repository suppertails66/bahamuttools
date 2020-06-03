#include "util/TIfstream.h"
#include "util/TBufStream.h"
#include "util/TStringConversion.h"
#include "util/TGraphic.h"
#include "util/TPngConversion.h"
#include "md/MdPattern.h"
#include <string>
#include <iostream>

using namespace std;
using namespace BlackT;
using namespace Md;

MdPattern read1bppPattern(TStream& ifs) {
//  TGraphic g(MdPattern::w, MdPattern::h);
//  g.clearTransparent();

  MdPattern pattern;
  
  int pos = 0;
  for (int j = 0; j < 4; j++) {
    int command = ifs.readu16be();
    
    int shift = 15;
    int mask = 0x1 << shift;
    while (mask > 0) {
      int x = (pos % MdPattern::w);
      int y = (pos / MdPattern::w);
      
      int value = (command & mask) >> shift;
      
      if (value != 0) {
        pattern.pattern.data(x, y) = 0x1;
      }
      else {
        pattern.pattern.data(x, y) = 0x0;
      }
      
      --shift;
      mask >>= 1;
      ++pos;
    }
  }
  
//  return g;
  return pattern;
}

int main(int argc, char* argv[]) {
  if (argc < 5) {
    cout << "Bahamut Senki font dumper" << endl;
    cout << "Usage: " << argv[0] << " <infile> <outprefix> <pos> <numchars>"
      << endl;
    
    return 0;
  }
  
  char* infile = argv[1];
  string outprefix = string(argv[2]);
  int address = TStringConversion::stringToInt(string(argv[3]));
  int numchars = TStringConversion::stringToInt(string(argv[4]));
  
  TIfstream ifs(infile, ios_base::binary);
  ifs.seek(address);
  for (int i = 0; i < numchars; i++) {
    
/*    int pos = 0;
    for (int j = 0; j < 16; j++) {
      int command = ifs.readu16be();
      
      int shift = 12;
      int mask = 0xF << shift;
      while (mask > 0) {
        int value = (command & mask) >> shift;
        
        int x = (pos % 16);
        int y = (pos / 8);
        
        shift -= 4;
        mask >> 4;
        ++pos;
      }
    } */
    
    MdPattern ul = read1bppPattern(ifs);
    MdPattern ur = read1bppPattern(ifs);
    MdPattern ll = read1bppPattern(ifs);
    MdPattern lr = read1bppPattern(ifs);
    
    TGraphic g(16, 16);
    g.clearTransparent();
    ul.toGrayscaleGraphic(g, 0, 0);
    ur.toGrayscaleGraphic(g, 8, 0);
    ll.toGrayscaleGraphic(g, 0, 8);
    lr.toGrayscaleGraphic(g, 8, 8);
    
    string numstr = TStringConversion::intToString(i, TStringConversion::baseHex)
      .substr(2, string::npos);
    while (numstr.size() < 4) numstr = string("0") + numstr;
    string dst = outprefix
      + numstr
      + ".png";
    
    TPngConversion::graphicToRGBAPng(dst, g);
  }
  
  return 0;
}
