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
#include "util/TBitmapFont.h"
#include "util/TThingyTable.h"
#include "exception/TGenericException.h"
#include <string>
#include <vector>
#include <map>
#include <sstream>
#include <iostream>

using namespace std;
using namespace BlackT;
using namespace Md;

const static int stringHashFactor = 0x1000; // hash mask plus one
const static int fontPackHashFactor = 0x1000; // hash mask plus one

TCsv script;
TThingyTable table;

int strloadaddr;
int fontloadaddr;

TBitmapFont vwfFontStandard;
TThingyTable vwfFontStandardTable;

TBitmapFont vwfFontNarrow;
TThingyTable vwfFontNarrowTable;

TBufStream fontbin;

//vector<FontPack> fontPacks;
//FontPack activeFontPack;
typedef vector<int> FontPack;
FontPack activeFontPack;
map<int, int> activeFontPackRev;
int activeFontPackAddr;
map<int, FontPack> addrFontPackMap;

map<int, TBufStream> addrStringMap;

vector<TGraphic> additionalFontChars;
int fontAdditionBase;

bool stringModeAbsolute = false;

typedef std::map< int, std::vector<int> > HashToAddrBucketMap;

template <class T>
int generateBuckets(const T& t, HashToAddrBucketMap& dst,
                     int hashFactor) {
  int hashMask = hashFactor - 1;
  for (typename T::const_iterator it = t.cbegin();
       it != t.cend();
       ++it) {
    int addr = it->first;
    int hashAddr = addr & hashMask;
    dst[hashAddr].push_back(addr);
  }
  
  // return size in bytes of the bucket entries this will generate
  
  int totalBuckets = dst.size();
  int totalEntries = 0;
  for (HashToAddrBucketMap::const_iterator it = dst.cbegin();
       it != dst.cend();
       ++it) {
    totalEntries += it->second.size();
  }
  
  // each generated bucket consists of a series of 8-byte structs (old/new
  // addr) terminated by FFFFFFFF
  return (totalEntries * 8) + (totalBuckets * 4);
}

void generateIndexAndBucketContents(const HashToAddrBucketMap& src,
                     const map<int, int>& oldToNewAddrMap,
                     TBufStream& indexOfs,
                     TBufStream& bucketOfs,
                     int bucketBaseAddr,
                     int hashFactor) {
  for (int i = 0; i < hashFactor; i++) {
    HashToAddrBucketMap::const_iterator findIt = src.find(i);
    // no entries = 0xFFFFFFFF in index
    if (findIt == src.cend()) {
      indexOfs.writeu32be(0xFFFFFFFF);
      continue;
    }
    
    // write bucket list pointer to index
    indexOfs.writeu32be(bucketBaseAddr + bucketOfs.tell());
    
    // write bucket list
    const std::vector<int>& oldAddresses = findIt->second;
    for (int i = 0; i < oldAddresses.size(); i++) {
      int oldAddr = oldAddresses[i];
      map<int, int>::const_iterator findIt = oldToNewAddrMap.find(oldAddr);
      if (findIt == oldToNewAddrMap.cend()) {
        throw TGenericException(T_SRCANDLINE,
                                "generateIndexAndBucketContents()",
                                string("Non-remapped content at ")
                                  + TStringConversion::intToString(oldAddr,
                                      TStringConversion::baseHex));
      }
      
      int newAddr = findIt->second;
      
      // write bucket
      bucketOfs.writeu32be(oldAddr);
      bucketOfs.writeu32be(newAddr);
    }
    
    // write bucket list terminator
    bucketOfs.writeu32be(0xFFFFFFFF);
  }
}

int getPixelIndex(const TGraphic& grp, int x, int y,
                 int bgIndex, int solidIndex) {
  TColor color = grp.getPixel(x, y);
  if ((color.a() == TColor::fullAlphaOpacity)
      && ((color.r() != 0) || (color.g() != 0) || (color.b() != 0))) {
    // solid
    return solidIndex;
  }
  else {
    // transparent
    return bgIndex;
  }
}

void graphicTo4bpp(const TGraphic& grp, int baseX, int baseY, int w, int h,
                   TStream& ofs,
                   int bgIndex, int solidIndex) {
  bool hasOddWidth = (w & 1) != 0;
  for (int j = 0; j < h; j++) {
    for (int i = 0; i < w; i += 2) {
      int x = baseX + i;
      int y = baseY + j;
      
      int index1 = getPixelIndex(grp, x, y, bgIndex, solidIndex);
      
      int index2 = 0;
      if (!(hasOddWidth && (i == w))) {
        index2 = getPixelIndex(grp, x + 1, y, bgIndex, solidIndex);
      }
      
      TByte output = 0x00;
      output |= (index1 << 4);
      output |= (index2);
      ofs.put(output);
    }
  }
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
    cout << "Bahamut Senki script creation utility" << endl;
    cout << "Usage: " << argv[0] << " <scriptfile> <table>"
      " <strloadaddr> <fontloadaddr> <outprefix>" << endl;
    
    return 0;
  }
  
  // output:
  // - binary file containing string hash table and string data (in that order)
  // - binary file containing font pack hash table and data
  // - series of additional font characters generated by "img" format commands
  //   (e.g. "200.png")
  // - index of generated font characters
  
  string scriptfileName(argv[1]);
  string tableName(argv[2]);
  string strloadaddrName(argv[3]);
  string fontloadaddrName(argv[4]);
  string fontbinName(argv[5]);
  string outprefix(argv[6]);
  
  {
    TIfstream ifs(scriptfileName.c_str(), ios_base::binary);
    script.readSjis(ifs);
  }
  
  {
    table.readSjis(tableName);
  }
  
  fontbin.open(fontbinName.c_str());
  fontbin.seek(fontbin.size());
  
  vwfFontStandard.load("font/standard/");
  vwfFontNarrow.load("font/narrow/");
  
  vwfFontStandardTable.readSjis("font/standard/table.tbl");
  vwfFontNarrowTable.readSjis("font/narrow/table.tbl");
  
  // additional font characters are assigned IDs starting from one past the
  // highest currently used ID
  if (table.entries.size() > 0) {
    fontAdditionBase = (--(table.entries.end()))->first + 1;
  }
  else {
    fontAdditionBase = 0;
  }
  
  strloadaddr = TStringConversion::stringToInt(strloadaddrName);
  fontloadaddr = TStringConversion::stringToInt(fontloadaddrName);
  activeFontPackAddr = -1;
  
  for (int i = 1; i < script.numRows(); i++) {
    string command = script.cell(0, i);
    
    if (command.compare("StringModeAbsolute") == 0) {
      stringModeAbsolute = true;
    }
    else if (command.compare("StringModeRelative") == 0) {
      stringModeAbsolute = false;
    }
    else if (command.compare("FontPack") == 0) {
      int srcAddr = TStringConversion::stringToInt(script.cell(1, i));
//      int srcEnd = TStringConversion::stringToInt(script.cell(2, i));
      
      if (activeFontPackAddr != -1) {
        addrFontPackMap[activeFontPackAddr] = activeFontPack;
      }
      
      activeFontPack.clear();
      activeFontPackRev.clear();
      activeFontPackAddr = srcAddr;
    }
    else if (command.compare("String") == 0) {
      int srcAddr = TStringConversion::stringToInt(script.cell(1, i));
      int srcEnd = TStringConversion::stringToInt(script.cell(2, i));
      string renderType = script.cell(3, i);
      
      istringstream ss(renderType);
      string renderCmd;
      ss >> renderCmd;
      if (renderCmd.compare("default") == 0) {
        string english = script.cell(5, i);
//        if (english.size() <= 0) goto done; // skip if no content defined
        TBufStream src;
        src.write(english.c_str(), english.size());
        TBufStream rawString;
        src.seek(0);
        BahamutScriptReader(src, rawString, table)();
        
        // check if each character is in active font pack and add if not;
        // otherwise, map to existing character
        rawString.seek(0);
        TBufStream localString;
        while (rawString.remaining() > 0) {
          int rawIndex = rawString.readu16be();
          if (activeFontPackRev.find(rawIndex) == activeFontPackRev.end()) {
            activeFontPackRev[rawIndex] = activeFontPack.size();
            activeFontPack.push_back(rawIndex);
          }
          
          if (activeFontPack.size() > 0x100) {
            throw TGenericException(T_SRCANDLINE,
                                    "main()",
                                    string("Line ")
                                      + TStringConversion::intToString(i)
                                      + ": Too many characters in font pack");
          }
          
          // add 8-bit local index to string
//          localString.writeu8(activeFontPackRev[rawIndex]);
          // write tile offset
          // +1 because 0 is treated as a space
          // the game takes this into account and offsets tile lookup
          // positions by 4, but we've modified it to treat characters as
          // 2 tiles each, so we have to add 2 here to get the right result
          localString.writeu16be(((activeFontPackRev[rawIndex] + 1) * 2) + 2);
        }
        
        // write address of end of old string
        localString.writeu32be(srcEnd);
        
        addrStringMap[srcAddr] = localString;
      }
      else if (renderCmd.compare("img") == 0) {
        
      }
      else if (renderCmd.compare("vwf") == 0) {
        string fontName;
        ss >> fontName;
        
        TBitmapFont* font = &vwfFontStandard;
        TThingyTable* table = &vwfFontStandardTable;
        
        bool alignRight = false;
        bool alignCenter = false;
        bool padToWidth = false;
        int targetPadWidth = 0;
        while (!ss.eof()) {
          string option;
          ss >> option;
          
          if (option.compare("ralign") == 0) alignRight = true;
          else if (option.compare("center") == 0) alignCenter = true;
          else if (option.compare("pad") == 0) {
            padToWidth = true;
            ss >> option;
            targetPadWidth = TStringConversion::stringToInt(option);
          }
        }
        
        if (fontName.compare("standard") == 0) {
        
        }
        else if (fontName.compare("narrow") == 0) {
          font = &vwfFontNarrow;
          table = &vwfFontNarrowTable;
        }
        else {
          throw TGenericException(T_SRCANDLINE,
                                  "main()",
                                  string("Unknown VWF font name on line ")
                                    + TStringConversion::intToString(i)
                                    + ": "
                                    + fontName);
        }
        
        TBufStream msg;
        msg.writeString(script.cell(5, i));
        msg.seek(0);
        
        TGraphic grp;
        font->render(grp, msg, *table);
        
        if (alignRight || alignCenter) {
          int w = ((grp.w() / 8) * 8);
          if ((grp.w() % 8) != 0) w += 8;
          
          int offset = 0;
          if (alignRight) offset = w - grp.w();
          else if (alignCenter) offset = (w - grp.w()) / 2;
          
          TGraphic grpAligned(w, grp.h());
          grpAligned.clearTransparent();
          grpAligned.copy(grp,
                          TRect(offset, 0, 0, 0));
          
          grp = grpAligned;
        }
        
        if (padToWidth
            && (grp.w() < targetPadWidth)) {
          TGraphic grpPadded(targetPadWidth, grp.h());
          grpPadded.clearTransparent();
          
          int targetX = 0;
          if (alignRight) targetX = targetPadWidth - grp.w();
          else if (alignCenter) targetX = (targetPadWidth - grp.w()) / 2;
          
          grpPadded.copy(grp,
                         TRect(targetX, 0, 0, 0));
          grp = grpPadded;
        }
        
//        if (srcAddr == 0x104CB) {
//          TPngConversion::graphicToRGBAPng("debug.png", grp);
//        }
        
        int numChars = grp.w() / 8;
        if (grp.w() % 8 != 0) ++numChars;
        
        TBufStream localString;
        
        for (int i = 0; i < numChars; i++) {
          int x = i * 8;
          int y = 0;
          int w = 8;
          int h = 16;
          
          if (grp.w() - x < 8) {
            w = grp.w() - x;
          }
          
          TGraphic charGrp(8, 16);
          charGrp.clearTransparent();
          
          charGrp.copy(grp,
                       TRect(0, 0, 0, 0),
                       TRect(x, y, w, h));
          
          // add to font
          
          int newRawIndex = fontAdditionBase + additionalFontChars.size();
          int newLocalIndex = activeFontPack.size();
          
          // TODO: duplicate character use within font pack detection
          
          bool isDuplicate = false;
          for (int i = 0; i < activeFontPack.size(); i++) {
            int rawIndex = activeFontPack[i];
            TGraphic& checkGrp = additionalFontChars[rawIndex - fontAdditionBase];
            if (checkGrp == charGrp) {
//              std::cerr << "here: " << i << " " << rawIndex << std::endl;
              newRawIndex = rawIndex;
              newLocalIndex = i;
              isDuplicate = true;
              break;
            }
          }
          
          if (!isDuplicate) {
            additionalFontChars.push_back(charGrp);
          
            // add to pack
            activeFontPackRev[newRawIndex] = newLocalIndex;
            activeFontPack.push_back(newRawIndex);
          }
          
          if (!stringModeAbsolute
              && (activeFontPack.size() > 0x100)) {
            throw TGenericException(T_SRCANDLINE,
                                    "main()",
                                    string("Line ")
                                      + TStringConversion::intToString(i)
                                      + ": Too many characters in font pack");
          }
          
          // absolute index of character in composite font
          if (stringModeAbsolute)
            localString.writeu16be(newRawIndex);
          // write tile offset to generated local string
          // +1 because 0 is treated as a space
          // the game takes this into account and offsets tile lookup
          // positions by 4, but we've modified it to treat characters as
          // 2 tiles each, so we have to add 2 here to get the right result
          else
            localString.writeu16be(((activeFontPackRev[newRawIndex] + 1) * 2) + 2);
        }
        
        // write address of end of old string
        localString.writeu32be(srcEnd);
        
        // add string
        addrStringMap[srcAddr] = localString;
      }
      else {
        throw TGenericException(T_SRCANDLINE,
                                "main()",
                                string("Unknown render command on line ")
                                  + TStringConversion::intToString(i)
                                  + ": "
                                  + renderCmd);
      }
//      done:
//      1;
    }
    
  }
  
  // add final font pack to collection
  if (activeFontPackAddr != -1) {
    addrFontPackMap[activeFontPackAddr] = activeFontPack;
  }
  
  cout << "Number of font packs: " << addrFontPackMap.size() << endl;
  cout << "Number of strings: " << addrStringMap.size() << endl;
  
  HashToAddrBucketMap stringBucketMap;
  int stringBucketsSize
    = generateBuckets(addrStringMap, stringBucketMap, stringHashFactor);
  
  HashToAddrBucketMap fontPackBucketMap;
  int fontPackBucketsSize
    = generateBuckets(addrFontPackMap, fontPackBucketMap, fontPackHashFactor);
    
  // ******************************************
  //      STRINGS
  // ******************************************
  
  // output new content and generate map of old addresses to new content
  
  int stringBucketsBaseAddr = strloadaddr + (stringHashFactor * 4);
  int stringContentBaseAddr = stringBucketsBaseAddr + stringBucketsSize;
  
  // write strings
  std::map<int, int> stringOldToNewAddrMap;
  TBufStream stringContentBin;
  for (map<int, TBufStream>::iterator it = addrStringMap.begin();
       it != addrStringMap.end();
       ++it) {
    stringOldToNewAddrMap[it->first]
      = stringContentBaseAddr + stringContentBin.tell();
    it->second.seek(0);
    
    // align to 16-bit boundary
    stringContentBin.alignToWriteBoundary(2);
    
//    cout << "string: " << TStringConversion::intToString(it->first,
//                            TStringConversion::baseHex) << " -> "
//      << TStringConversion::intToString(
//          stringContentBaseAddr + stringContentBin.tell(),
//          TStringConversion::baseHex) << endl;
    
    // 16-bit numchars - 1 - trailing end addr size in bytes (2)
    stringContentBin.writeu16be((it->second.size() / 2) - 1 - 2);
    // content
    stringContentBin.writeFrom(it->second, it->second.size());
  }
  
  // generate actual hash buckets and index
  
  TBufStream stringIndexBin;
  TBufStream stringBucketBin;
  generateIndexAndBucketContents(stringBucketMap, stringOldToNewAddrMap,
                                 stringIndexBin, stringBucketBin,
                                 stringBucketsBaseAddr,
                                 stringHashFactor);
    
  // ******************************************
  //      FONT PACKS
  // ******************************************
  
  // output new content and generate map of old addresses to new content
  
  int fontPackBucketsBaseAddr = fontloadaddr + (fontPackHashFactor * 4);
  int fontPackContentBaseAddr = fontPackBucketsBaseAddr + fontPackBucketsSize;
  
  // write font packs
  std::map<int, int> fontPackOldToNewAddrMap;
  TBufStream fontPackContentBin;
  for (map<int, FontPack>::iterator it = addrFontPackMap.begin();
       it != addrFontPackMap.end();
       ++it) {
    fontPackOldToNewAddrMap[it->first]
      = fontPackContentBaseAddr + fontPackContentBin.tell();
        
    // pack
    // character count - 1
    fontPackContentBin.writeu16be(it->second.size() - 1);
    // characters
    for (int i = 0; i < it->second.size(); i++) {
      fontPackContentBin.writeu16be(it->second[i]);
    }
  }
  
  // generate actual hash buckets and index
  
  TBufStream fontPackIndexBin;
  TBufStream fontPackBucketBin;
  generateIndexAndBucketContents(fontPackBucketMap, fontPackOldToNewAddrMap,
                                 fontPackIndexBin, fontPackBucketBin,
                                 fontPackBucketsBaseAddr,
                                 fontPackHashFactor);
    
  // ******************************************
  // output everything
  // ******************************************
  
  stringIndexBin.seek(0);
  stringBucketBin.seek(0);
  stringContentBin.seek(0);
  TBufStream stringEverythingBin;
  stringEverythingBin.writeFrom(stringIndexBin, stringIndexBin.size());
  stringEverythingBin.writeFrom(stringBucketBin, stringBucketBin.size());
  stringEverythingBin.writeFrom(stringContentBin, stringContentBin.size());
  stringEverythingBin.save((outprefix + "table_strings_8x16.bin").c_str());
  
  fontPackIndexBin.seek(0);
  fontPackBucketBin.seek(0);
  fontPackContentBin.seek(0);
  TBufStream fontPackEverythingBin;
  fontPackEverythingBin.writeFrom(fontPackIndexBin, fontPackIndexBin.size());
  fontPackEverythingBin.writeFrom(fontPackBucketBin, fontPackBucketBin.size());
  fontPackEverythingBin.writeFrom(fontPackContentBin, fontPackContentBin.size());
  fontPackEverythingBin.save((outprefix + "table_fontpacks.bin").c_str());
  
  //=====================================
  // update font with newly generated
  // chars
  //=====================================
  
  fontbin.seek(fontbin.size());
  for (unsigned int i = 0; i < additionalFontChars.size(); i++) {
    TGraphic& grp = additionalFontChars[i];
//    int index = fontAdditionBase + i;
    
    TBufStream pattern;
    
    // top
    pattern.seek(0);
    graphicTo4bpp(grp, 0, 0, 8, 8, pattern, 0x0, 0xF);
    pattern.seek(0);
    MdPattern top;
    top.read(pattern);
    
    // bottom
    pattern.seek(0);
    graphicTo4bpp(grp, 0, 8, 8, 8, pattern, 0x0, 0xF);
    pattern.seek(0);
    MdPattern bottom;
    bottom.read(pattern);
    
    mdPatternTo1bpp(top, fontbin);
    mdPatternTo1bpp(bottom, fontbin);
  }
  
  fontbin.save(fontbinName.c_str());
  
/*  TBufStream stringHashBin(0x10000);
  for (int i = 0; i < stringHashFactor; i++) {
    // if no entry, fill in hash pointer with 0xFFFFFFFF
    if (stringBucketMap.find(i) == stringBucketMap.end()) {
      stringHashBin.writeu32be(0xFFFFFFFF);
      continue;
    }
    
    // output 
  } */
  
  return 0;
}
