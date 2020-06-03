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
#include <cctype>

using namespace std;
using namespace BlackT;
using namespace Md;
  
TIfstream rom;
TThingyTable table;
TCsv script;

typedef map<string, int> PairCountMap;
typedef map<string, string> PairSrcMap;

PairCountMap totalUseCounts;
PairSrcMap lastSrcMap;

PairCountMap processString(std::string str) {
  PairCountMap result;
  
  if ((str.size() % 2) != 0) str += " ";
  
  for (unsigned i = 0; i < str.size(); i += 2) {
    std::string sub = str.substr(i, 2);
    
    for (unsigned int j = 0; j < sub.size(); j++) sub[j] = toupper(sub[j]);
    
    if (sub.compare("LP") == 0) continue;
    if (sub.compare("SP") == 0) continue;
    if (sub.compare("  ") == 0) continue;
    
    if (result.find(sub) == result.end()) result[sub] = 0;
    ++result[sub];
  }
  
  return result;
}

void addPairCountMaps(const PairCountMap& src, PairCountMap& dst,
                      std::string srcStr) {
  for (PairCountMap::const_iterator it = src.cbegin();
       it != src.end();
       ++it) {
    if (dst.find(it->first) == dst.end()) dst[it->first] = 0;
    dst[it->first] += it->second;
    lastSrcMap[it->first] = srcStr;
  }
}

int countSharedElements(const PairCountMap& master, const PairCountMap& sub) {
  int count = 0;
  for (PairCountMap::const_iterator it = sub.cbegin();
       it != sub.end();
       ++it) {
    if (master.find(it->first) != master.end()) ++count;
  }
  return count;
}

void addContent(std::string content) {
  std::string extendedContent = " " + content;
  
  PairCountMap first = processString(content);
  PairCountMap second = processString(extendedContent);
  
  int firstSize = countSharedElements(totalUseCounts, first);
  int secondSize = countSharedElements(totalUseCounts, second);
  
  // add whichever version has more shared elements
  if ((extendedContent.size() <= 12) && (secondSize > firstSize)) {
    addPairCountMaps(second, totalUseCounts, extendedContent);
  }
  else {
    addPairCountMaps(first, totalUseCounts, content);
  }
}

int main(int argc, char* argv[]) {
  rom.open("bahamut.md", ios_base::binary);
  rom.seek(0x3E48E);
  
//  std::string scriptfileName = "script/trans/bahamut_8x8.csv";
  std::string scriptfileName = "bahamut_names_8x8.csv";
  std::string tableName = "table/bahamut_en_8x8.tbl";
  
  table.readSjis(tableName.c_str());
  
  {
    TIfstream ifs(scriptfileName.c_str(), ios_base::binary);
    script.readSjis(ifs);
  }
  
  for (int i = 1; i < script.numRows(); i++) {
    string command = script.cell(0, i);
    
    if (command.compare("String") == 0) {
      string content = script.cell(4, i);
      addContent(content);
    }
  }
  
  for (PairCountMap::const_iterator it = totalUseCounts.cbegin();
       it != totalUseCounts.end();
       ++it) {
    cout << it->first << " " << it->second << " " << lastSrcMap[it->first] << endl;
  }
  
  std::cout << totalUseCounts.size() << std::endl;
  
  return 0;
}
