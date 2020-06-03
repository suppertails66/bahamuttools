#ifndef BAHAMUTFONTPACKDECMP_H
#define BAHAMUTFONTPACKDECMP_H


#include "util/TStream.h"

namespace Md {


class BahamutFontPackDecmp {
public:
  
  BahamutFontPackDecmp(BlackT::TStream& ifs__,
                       BlackT::TStream& ofs__);
  
  void operator()();
  
protected:
  BlackT::TStream* ifs;
  BlackT::TStream* ofs;
  
  void decmpPlane(int numEntries, char cmpByte);
  
  
};


}


#endif
