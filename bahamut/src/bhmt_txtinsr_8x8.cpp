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
#include <stack>
#include <map>
#include <sstream>
#include <iostream>
#include <cmath>
#include <cctype>

using namespace std;
using namespace BlackT;
using namespace Md;

const static int stringHashFactor = 0x1000; // hash mask plus one
const static int fontPackHashFactor = 0x1000; // hash mask plus one

//const int graphicAreaStart = 0x51;
const int graphicAreaStart = 0x37;
const int graphicAreaLimit = 0xAB;

TCsv script;
TThingyTable table;

int strloadaddr;

/*TBitmapFont vwfFontStandard;
TThingyTable vwfFontStandardTable;

TBitmapFont vwfFontNarrow;
TThingyTable vwfFontNarrowTable; */

TBitmapFont fontSmallname;
TThingyTable fontSmallnameTable;

//TBufStream fontbin;

map<int, TBufStream> addrStringMap;

std::vector<TGraphic> fontChars;
std::stack<int> availableFontIndices;
std::vector<TGraphic> origFontChars;

typedef std::map< int, std::vector<int> > HashToAddrBucketMap;



typedef map<string, int> PairCountMap;
typedef map<string, string> PairSrcMap;

PairCountMap totalUseCounts;
PairSrcMap lastSrcMap;

PairCountMap processSmallString(std::string str) {
  PairCountMap result;
//  resultStr = "";
  
  if ((str.size() % 2) != 0) str += " ";
  
  for (unsigned i = 0; i < str.size(); i += 2) {
    std::string sub = str.substr(i, 2);
    
    for (unsigned int j = 0; j < sub.size(); j++) sub[j] = toupper(sub[j]);
    
    if (sub.compare("LP") == 0) {
//      resultStr += "\x28";
      continue;
    }
    if (sub.compare("SP") == 0) {
//      resultStr += "\x29";
      continue;
    }
    if (sub.compare("  ") == 0) {
//      resultStr += "\xFF";
      continue;
    }
    
    if (result.find(sub) == result.end()) result[sub] = 0;
    ++result[sub];
    
    // PLACEHOLDER for custom symbol
//    resultStr += "X";
  }
  
  return result;
}

void addSmallStringPairCountMaps(const PairCountMap& src, PairCountMap& dst,
                      std::string srcStr) {
  for (PairCountMap::const_iterator it = src.cbegin();
       it != src.end();
       ++it) {
    if (dst.find(it->first) == dst.end()) dst[it->first] = 0;
    dst[it->first] += it->second;
    lastSrcMap[it->first] = srcStr;
  }
}

int countSmallStringSharedElements(const PairCountMap& master, const PairCountMap& sub) {
  int count = 0;
  for (PairCountMap::const_iterator it = sub.cbegin();
       it != sub.end();
       ++it) {
    if (master.find(it->first) != master.end()) ++count;
  }
  return count;
}



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
  if (argc < 5) {
    cout << "Bahamut Senki 8x8 script creation utility" << endl;
    cout << "Usage: " << argv[0] << " <scriptfile> <table>"
      " <strloadaddr> <outprefix>" << endl;
    
    return 0;
  }
  
  // output:
  // - binary file containing string hash table and string data (in that order)
  // - updated font with new smallname chars
  
  string scriptfileName(argv[1]);
  string tableName(argv[2]);
  string strloadaddrName(argv[3]);
//  string fontloadaddrName(argv[4]);
//  string fontbinName(argv[4]);
  string outprefix(argv[4]);
  
  {
    TIfstream ifs(scriptfileName.c_str(), ios_base::binary);
    script.readSjis(ifs);
  }
  
  {
    table.readSjis(tableName);
  }
  
  // font
  
  {
    TGraphic fontGrp;
    TPngConversion::RGBAPngToGraphic("rsrc/font_8x8.png", fontGrp);
    
    for (int i = 0; i < graphicAreaLimit; i++) {
      int x = (i % 16) * 8;
      int y = (i / 16) * 8;
      
      TGraphic grp(8, 8);
      grp.copy(fontGrp,
               TRect(0, 0, 0, 0),
               TRect(x, y, 8, 8));
      fontChars.push_back(grp);
      
//      TPngConversion::graphicToRGBAPng("debug.png", grp);
    }
  }
  
  origFontChars = fontChars;
  
//  fontbin.open(fontbinName.c_str());
//  fontbin.seek(fontbin.size());
  
//  vwfFontStandard.load("font/standard/");
//  vwfFontNarrow.load("font/narrow/");
  fontSmallname.load("font/smallname/");
  
//  vwfFontStandardTable.readSjis("font/standard/table.tbl");
//  vwfFontNarrowTable.readSjis("font/narrow/table.tbl");
  fontSmallnameTable.readSjis("font/smallname/table.tbl");
  
  // additional font characters are assigned IDs starting from one past the
  // highest currently used ID
//  if (table.entries.size() > 0) {
//    fontAdditionBase = (--(table.entries.end()))->first + 1;
//  }
//  else {
//    fontAdditionBase = 0;
//  }
  
  strloadaddr = TStringConversion::stringToInt(strloadaddrName);
//  fontloadaddr = TStringConversion::stringToInt(fontloadaddrName);
//  activeFontPackAddr = -1;

  // set up available font indices
  
  // old kana set and other unneeded stuff
  for (int i = graphicAreaStart; i < graphicAreaLimit; i++) {
    availableFontIndices.push(i);
  }
  // Q
//  availableFontIndices.push(0x1B);
  // X
//  availableFontIndices.push(0x22);
  // Z
//  availableFontIndices.push(0x24);
  
  for (int i = 1; i < script.numRows(); i++) {
    int rowNum = i;
    string command = script.cell(0, i);
    
    if (command.compare("String") == 0) {
      int srcAddr = TStringConversion::stringToInt(script.cell(1, i));
      int endAddr = TStringConversion::stringToInt(script.cell(2, i));
      string renderType = script.cell(3, i);
      
      istringstream ss(renderType);
      string renderCmd;
      ss >> renderCmd;
      if ((renderCmd.compare("default") == 0)
          || (renderCmd.compare("binary") == 0)) {
        string english = script.cell(5, i);
//        if (english.size() <= 0) goto done; // skip if no content defined
        TBufStream src;
        src.write(english.c_str(), english.size());
        TBufStream rawString;
        src.seek(0);
        BahamutScriptReader(src, rawString, table)();
        
        rawString.seek(0);
        TBufStream localString;
        while (rawString.remaining() > 0) {
          int rawIndex = rawString.readu16be();
          
          localString.writeu8(rawIndex);
        }
        
        if (renderCmd.compare("binary") == 0) {
          std::string name;
          ss >> name;
          
          localString.save(name.c_str());
          continue;
        }
        
        // terminator
        localString.writeu8(0x00);
        
        // append "next" string location
        localString.writeu32be(endAddr);
        
        addrStringMap[srcAddr] = localString;
      }
      else if (renderCmd.compare("smallname") == 0) {
//        string fontName;
//        ss >> fontName;
        
        string english = script.cell(5, i);
        
        std::string content = english;
        for (unsigned int i = 0; i < content.size(); i++) {
          content[i] = toupper(content[i]);
        }
        
        std::string extendedContent = " " + content;
        
        if ((content.size() % 2) != 0) content += " ";
        if ((extendedContent.size() % 2) != 0) extendedContent += " ";
        
        PairCountMap firstMap = processSmallString(content);
        PairCountMap secondMap = processSmallString(extendedContent);
        
        int firstSize = countSmallStringSharedElements(totalUseCounts, firstMap);
        int secondSize = countSmallStringSharedElements(totalUseCounts, secondMap);
        
        // add whichever version has more shared elements
        std::string resultStr;
        if ((extendedContent.size() <= 12) && (secondSize > firstSize)) {
          addSmallStringPairCountMaps(secondMap, totalUseCounts, extendedContent);
          resultStr = extendedContent;
        }
        else {
          addSmallStringPairCountMaps(firstMap, totalUseCounts, content);
          resultStr = content;
        }
        
        std::string outputString;
        
        // pad string to center alignment for target 6-tile space
//        if (resultStr.size() < 10) {
          int tileSize = resultStr.size() / 2;
  //        int numPadTiles = ceil((double)(6 - tileSize) / (double)2);
          int numPadTiles = (6 - tileSize) / 2;
          for (int i = 0; i < numPadTiles; i++) {
            outputString += "\xFF";
          }
//        }
        
//        if (srcAddr == 0x2D0D2) cerr << tileSize << endl;
        
        for (unsigned int i = 0; i < resultStr.size(); i += 2) {
          std::string nextPair = resultStr.substr(i, 2);
          
          // HACKS:
          // LP and SP are already in the font
          if (nextPair.compare("LP") == 0) {
            outputString += "\x28";
            continue;
          }
          else if (nextPair.compare("SP") == 0) {
            outputString += "\x29";
            continue;
          }
          // as is space
          else if (nextPair.compare("  ") == 0) {
            outputString += "\xFF";
            continue;
          }
          
          TGraphic newTileGrp;
          
          TBufStream renderIfs;
          renderIfs.writeString(nextPair);
          renderIfs.seek(0);
          fontSmallname.render(newTileGrp, renderIfs, fontSmallnameTable);
          
          // check if generated tile matches any existing one
          int existingIndex = -1;
          for (unsigned int i = 0; i < fontChars.size(); i++) {
            if (fontChars[i] == newTileGrp) {
              existingIndex = i;
              break;
            }
          }
          
          if (existingIndex != -1) {
            outputString += (char)existingIndex;
            continue;
          }
          
          if (availableFontIndices.empty()) {
            throw TGenericException(T_SRCANDLINE,
                                    "main()",
                                    string("Ran out of smallfont tiles on row ")
                                    + TStringConversion::intToString(rowNum));
          }
          
          int newTileIndex = availableFontIndices.top();
          availableFontIndices.pop();
          
          fontChars.at(newTileIndex) = newTileGrp;
          
          outputString += (char)newTileIndex;
        }
        
        // write output
        TBufStream localString;
        localString.writeString(outputString);
        
        // terminator
        localString.writeu8(0x00);
        
        // append "next" string location
        localString.writeu32be(endAddr);
        
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
  
//  cout << "Number of font packs: " << addrFontPackMap.size() << endl;
  cout << "Number of strings: " << addrStringMap.size() << endl;
  
  HashToAddrBucketMap stringBucketMap;
  int stringBucketsSize
    = generateBuckets(addrStringMap, stringBucketMap, stringHashFactor);
  
//  HashToAddrBucketMap fontPackBucketMap;
//  int fontPackBucketsSize
//    = generateBuckets(addrFontPackMap, fontPackBucketMap, fontPackHashFactor);
    
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
//    stringContentBin.alignToWriteBoundary(2);
    
//    cout << "string: " << TStringConversion::intToString(it->first,
//                            TStringConversion::baseHex) << " -> "
//      << TStringConversion::intToString(
//          stringContentBaseAddr + stringContentBin.tell(),
//          TStringConversion::baseHex) << endl;
    
    // 16-bit numchars - 1
//    stringContentBin.writeu16be((it->second.size() / 2) - 1);
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
  // output everything
  // ******************************************
  
  stringIndexBin.seek(0);
  stringBucketBin.seek(0);
  stringContentBin.seek(0);
  TBufStream stringEverythingBin;
  stringEverythingBin.writeFrom(stringIndexBin, stringIndexBin.size());
  stringEverythingBin.writeFrom(stringBucketBin, stringBucketBin.size());
  stringEverythingBin.writeFrom(stringContentBin, stringContentBin.size());
  stringEverythingBin.save((outprefix + "table_strings_8x8.bin").c_str());
  
  //=====================================
  // update font with newly generated
  // chars
  //=====================================
  
  {
    TBufStream ofs;
    for (unsigned int i = 0; i < fontChars.size(); i++) {
      TGraphic& grp = fontChars[i];
      MdPattern pattern;
      pattern.fromGrayscaleGraphic(grp);
      pattern.write(ofs);
    }
    ofs.save((outprefix + "font_8x8.bin").c_str());
  }
  
  {
    TBufStream ofs;
    for (unsigned int i = 0; i < origFontChars.size(); i++) {
      TGraphic& grp = origFontChars[i];
      MdPattern pattern;
      pattern.fromGrayscaleGraphic(grp);
      pattern.write(ofs);
    }
    ofs.save((outprefix + "font_8x8_lower.bin").c_str());
  }
  
/*  fontbin.seek(fontbin.size());
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
  
  fontbin.save(fontbinName.c_str()); */
  
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
