#include "bahamut/BahamutScriptReader.h"
#include "util/TBufStream.h"
#include "util/TStringConversion.h"
#include "exception/TGenericException.h"
#include <cctype>
#include <algorithm>
#include <string>
#include <iostream>

using namespace BlackT;

namespace Md {


const static int scriptBufferCapacity = 0x10000;

BahamutScriptReader::BahamutScriptReader(
                  BlackT::TStream& src__,
                  BlackT::TStream& dst__,
                  const BlackT::TThingyTable& thingy__)
  : src(src__),
    dst(dst__),
    thingy(thingy__),
    lineNum(0)
//    currentScriptBuffer(scriptBufferCapacity)
    {
  loadThingy(thingy__);
}

void BahamutScriptReader::operator()() {
  while (!src.eof()) {
    std::string line;
    src.getLine(line);
    ++lineNum;
    
    if (line.size() <= 0) continue;
    
    // discard lines containing only ASCII spaces and tabs
//    bool onlySpace = true;
//    for (int i = 0; i < line.size(); i++) {
//      if ((line[i] != ' ')
//          && (line[i] != '\t')) {
//        onlySpace = false;
//        break;
//      }
//    }
//    if (onlySpace) continue;
    
    TBufStream ifs(line.size());
    ifs.write(line.c_str(), line.size());
    ifs.seek(0);
    
    // check for comments
    if ((ifs.size() >= 2)
        && (ifs.peek() == '/')) {
      ifs.get();
      if (ifs.peek() == '/') continue;
      else ifs.unget();
    }
    
    // check for special stuff
    if (ifs.peek() == '#') {
      // directives
      ifs.get();
      processDirective(ifs);
      continue;
    }
    
    while (!ifs.eof()) {
      outputNextSymbol(ifs);
    }
  }
}
  
void BahamutScriptReader::loadThingy(const BlackT::TThingyTable& thingy__) {
  thingy = thingy__;

  // To efficiently unmap script values, we order the thingy's strings
  // by length
  thingiesBySize.clear();
  thingiesBySize.resize(thingy.entries.size());
  int pos = 0;
  for (TThingyTable::RawTable::iterator it = thingy.entries.begin();
       it != thingy.entries.end();
       ++it) {
    ThingyValueAndKey t = { it->second, it->first };
    thingiesBySize[pos++] = t;
  }
  std::sort(thingiesBySize.begin(), thingiesBySize.end());
}
  
void BahamutScriptReader::outputNextSymbol(TStream& ifs) {
  // literal value
  if ((ifs.remaining() >= 5)
      && (ifs.peek() == '<')) {
    int pos = ifs.tell();
    
    ifs.get();
    if (ifs.peek() == '$') {
      ifs.get();
      std::string valuestr = "0x";
      valuestr += ifs.get();
      valuestr += ifs.get();
      
      if (ifs.peek() == '>') {
        ifs.get();
        int value = TStringConversion::stringToInt(valuestr);
        
        dst.writeu8(value);
//        currentScriptBuffer.writeu8(value);

        return;
      }
    }
    
    // not a literal value
    ifs.seek(pos);
  }
  for (int i = thingiesBySize.size() - 1; i >= 0; i--) {
    if (checkSymbol(ifs, thingiesBySize[i].value)) {
      int symbolSize = 2;
//      if (thingiesBySize[i].key <= 0xFF) symbolSize = 1;
//      else if (thingiesBySize[i].key <= 0xFFFF) symbolSize = 2;
//      else if (thingiesBySize[i].key <= 0xFFFFFF) symbolSize = 3;
//      else symbolSize = 4;
      
      dst.writeInt(thingiesBySize[i].key, symbolSize,
        EndiannessTypes::big, SignednessTypes::nosign);
  
//      std::cerr << thingiesBySize[i].value << std::endl;
//      currentScriptBuffer.writeInt(thingiesBySize[i].key, symbolSize,
//        EndiannessTypes::big, SignednessTypes::nosign);
      
      return;
    }
  }
  
  std::string remainder;
  ifs.getLine(remainder);
  
  // if we reached end of file, this is not an error: we're done
  if (ifs.eof()) return;
  
  throw TGenericException(T_SRCANDLINE,
                          "BahamutScriptReader::outputNextSymbol()",
                          "Line "
                            + TStringConversion::intToString(lineNum)
                            + ":\n  Couldn't match symbol at: '"
                            + remainder
                            + "'");
}
  
bool BahamutScriptReader::checkSymbol(BlackT::TStream& ifs, std::string& symbol) {
  if (symbol.size() > ifs.remaining()) return false;
  
  int startpos = ifs.tell();
  for (int i = 0; i < symbol.size(); i++) {
    if (symbol[i] != ifs.get()) {
      ifs.seek(startpos);
      return false;
    }
  }
  
  return true;
}
  
void BahamutScriptReader::processDirective(BlackT::TStream& ifs) {
  skipSpace(ifs);
  
  std::string name = matchName(ifs);
  matchChar(ifs, '(');
  
  for (int i = 0; i < name.size(); i++) {
    name[i] = toupper(name[i]);
  }
  
  if (name.compare("LOADTABLE") == 0) {
    processLoadTable(ifs);
  }
  else {
    throw TGenericException(T_SRCANDLINE,
                            "BahamutScriptReader::processDirective()",
                            "Line "
                              + TStringConversion::intToString(lineNum)
                              + ":\n  Unknown directive: "
                              + name);
  }
  
  matchChar(ifs, ')');
}

void BahamutScriptReader::processLoadTable(BlackT::TStream& ifs) {
  std::string tableName = matchString(ifs);
  TThingyTable table(tableName);
  loadThingy(table);
}

void BahamutScriptReader::skipSpace(BlackT::TStream& ifs) const {
  ifs.skipSpace();
}

bool BahamutScriptReader::checkString(BlackT::TStream& ifs) const {
  skipSpace(ifs);
  
  if (!ifs.eof() && (ifs.peek() == '"')) return true;
  return false;
}

bool BahamutScriptReader::checkInt(BlackT::TStream& ifs) const {
  skipSpace(ifs);
  
  if (!ifs.eof()
      && (isdigit(ifs.peek()) || ifs.peek() == '$')) return true;
  return false;
}

bool BahamutScriptReader::checkChar(BlackT::TStream& ifs, char c) const {
  skipSpace(ifs);
  
  if (!ifs.eof() && (ifs.peek() == c)) return true;
  return false;
}

std::string BahamutScriptReader::matchString(BlackT::TStream& ifs) const {
  skipSpace(ifs);
  if (ifs.eof()) {
    throw TGenericException(T_SRCANDLINE,
                            "BahamutScriptReader::matchString()",
                            "Line "
                              + TStringConversion::intToString(lineNum)
                              + ":\n  Unexpected end of line");
  }
  
  if (!checkString(ifs)) {
    throw TGenericException(T_SRCANDLINE,
                            "BahamutScriptReader::matchString()",
                            "Line "
                              + TStringConversion::intToString(lineNum)
                              + ":\n  Unexpected non-string at: "
                              + getRemainingContent(ifs));
  }
  
  ifs.get();
  
  std::string result;
  while (!ifs.eof() && (ifs.peek() != '"')) result += ifs.get();
  
  matchChar(ifs, '"');
  
  return result;
}

int BahamutScriptReader::matchInt(BlackT::TStream& ifs) const {
  skipSpace(ifs);
  if (ifs.eof()) {
    throw TGenericException(T_SRCANDLINE,
                            "BahamutScriptReader::matchInt()",
                            "Line "
                              + TStringConversion::intToString(lineNum)
                              + ":\n  Unexpected end of line");
  }
  
  if (!checkInt(ifs)) {
    throw TGenericException(T_SRCANDLINE,
                            "BahamutScriptReader::matchInt()",
                            "Line "
                              + TStringConversion::intToString(lineNum)
                              + ":\n  Unexpected non-int at: "
                              + getRemainingContent(ifs));
  }
  
  std::string numstr;
  // get first character (this covers the case of an initial '$' for
  // hexadecimal)
  numstr += ifs.get();
  // handle possible initial "0x"
  if ((numstr[0] == '0') && (tolower(ifs.peek()) == 'x')) numstr += ifs.get();
  
  char next = ifs.peek();
  while (!ifs.eof()
         && (isdigit(next)
          || (tolower(next) == 'a')
          || (tolower(next) == 'b')
          || (tolower(next) == 'c')
          || (tolower(next) == 'd')
          || (tolower(next) == 'e')
          || (tolower(next) == 'f'))) {
    numstr += ifs.get();
    next = ifs.peek();
  }
  
  return TStringConversion::stringToInt(numstr);
}

void BahamutScriptReader::matchChar(BlackT::TStream& ifs, char c) const {
  skipSpace(ifs);
  if (ifs.eof()) {
    throw TGenericException(T_SRCANDLINE,
                            "BahamutScriptReader::matchChar()",
                            "Line "
                              + TStringConversion::intToString(lineNum)
                              + ":\n  Unexpected end of line");
  }
  
  if (ifs.peek() != c) {
    throw TGenericException(T_SRCANDLINE,
                            "BahamutScriptReader::matchChar()",
                            "Line "
                              + TStringConversion::intToString(lineNum)
                              + ":\n  Expected '"
                              + c
                              + "', got '"
                              + ifs.get()
                              + "'");
  }
  
  ifs.get();
}
  
std::string BahamutScriptReader
  ::getRemainingContent(BlackT::TStream& ifs) const {
  std::string content;
  while (!ifs.eof()) content += ifs.get();
  return content;
}

std::string BahamutScriptReader::matchName(BlackT::TStream& ifs) const {
  skipSpace(ifs);
  if (ifs.eof()) {
    throw TGenericException(T_SRCANDLINE,
                            "BahamutScriptReader::matchName()",
                            "Line "
                              + TStringConversion::intToString(lineNum)
                              + ":\n  Unexpected end of line");
  }
  
  if (!isalpha(ifs.peek())) {
    throw TGenericException(T_SRCANDLINE,
                            "BahamutScriptReader::matchName()",
                            "Line "
                              + TStringConversion::intToString(lineNum)
                              + ":\n  Couldn't read name at: "
                              + getRemainingContent(ifs));
  }
  
  std::string result;
  result += ifs.get();
  while (!ifs.eof()
         && (isalnum(ifs.peek()) || (ifs.peek() == '_'))) {
    result += ifs.get();
  }
  
  return result;
}


}
