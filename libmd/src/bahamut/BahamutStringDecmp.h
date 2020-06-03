#ifndef BAHAMUTSTRINGDECMP_H
#define BAHAMUTSTRINGDECMP_H


#include "util/TStream.h"

namespace Md {


class BahamutStringDecmp {
public:
  
  BahamutStringDecmp(BlackT::TStream& ifs__,
                       BlackT::TStream& ofs__);
  
  void operator()();
  
protected:
  BlackT::TStream* ifs;
  BlackT::TStream* ofs;
  
  
};


}


#endif
