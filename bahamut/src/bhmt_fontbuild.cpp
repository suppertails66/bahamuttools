#include "bahamut/BahamutScriptReader.h"
#include "md/MdPattern.h"
#include "util/TStream.h"
#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TStringConversion.h"
#include "util/TCsv.h"
#include "util/TGraphic.h"
#include "util/TPngConversion.h"
#include "exception/TGenericException.h"
#include <string>
#include <vector>
#include <map>
#include <sstream>
#include <iostream>

using namespace std;
using namespace BlackT;
using namespace Md;

const static int charW = 8;
const static int charH = 16;

int bgIndex = 0x0;
int fgIndex = 0xf;

struct FontChar {
  MdPattern top;
  MdPattern bottom;
};

void mdPatternFromGraphic(const TGraphic& src, MdPattern& dst,
                          int xOff, int yOff) {
  for (int j = 0; j < MdPattern::h; j++) {
    for (int i = 0; i < MdPattern::w; i++) {
      int x = (xOff + i);
      int y = (yOff + j);
      // transparent or white = background
      if ((src.getPixel(x, y).a() == TColor::fullAlphaTransparency)
          || ((src.getPixel(x, y).r() == 0xFF)
              && (src.getPixel(x, y).g() == 0xFF)
              && (src.getPixel(x, y).b() == 0xFF)
              )) {
        dst.pattern.data(i, j) = bgIndex;
      }
      else {
        dst.pattern.data(i, j) = fgIndex;
      }
    }
  }
}

void makeFontChar(const TGraphic& src, FontChar& dst, int x = 0, int y = 0) {
  mdPatternFromGraphic(src, dst.top, x, y);
  mdPatternFromGraphic(src, dst.bottom, x, y + MdPattern::h);
}

void mdPatternTo1bpp(const MdPattern& src, TStream& ofs) {
  for (int j = 0; j < MdPattern::h; j++) {
    int mask = 0x80;
    char next = 0;
    for (int i = 0; i < MdPattern::w; i++) {
      if (src.pattern.data(i, j) != 0) {
        next |= mask;
      }
      
      mask >>= 1;
    }
    ofs.put(next);
  }
}

int main(int argc, char* argv[]) {
  if (argc < 6) {
    cout << "Bahamut Senki font builder" << endl;
    cout << "Usage: " << argv[0] << " <fontsheet> <numchars> <outfile>"
      << " <bgindex> <fgindex>"
      << endl;
    
    return 0;
  }
  
  string fontsheetName(argv[1]);
  int numchars = TStringConversion::stringToInt(string(argv[2]));
  string outfileName(argv[3]);
  bgIndex = TStringConversion::stringToInt(string(argv[4]));
  fgIndex = TStringConversion::stringToInt(string(argv[5]));
  
  TGraphic sheet;
  TPngConversion::RGBAPngToGraphic(fontsheetName, sheet);
  
  int charsPerRow = (sheet.w() / charW);
  
  std::vector<FontChar> fontChars;
  fontChars.resize(numchars);
  for (int i = 0; i < numchars; i++) {
    int x = (i % charsPerRow) * charW;
    int y = (i / charsPerRow) * charH;
    
    makeFontChar(sheet, fontChars[i], x, y);
  }
  
  TOfstream ofs(outfileName.c_str(), ios_base::binary);
  for (unsigned int i = 0; i < fontChars.size(); i++) {
    mdPatternTo1bpp(fontChars[i].top, ofs);
    mdPatternTo1bpp(fontChars[i].bottom, ofs);
  }
  
  return 0;
}
