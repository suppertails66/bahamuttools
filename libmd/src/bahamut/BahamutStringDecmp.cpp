#include "bahamut/BahamutStringDecmp.h"
#include <iostream>

using namespace BlackT;

namespace Md {


BahamutStringDecmp::BahamutStringDecmp(BlackT::TStream& ifs__,
                     BlackT::TStream& ofs__)
  : ifs(&ifs__),
    ofs(&ofs__) { }

void BahamutStringDecmp::operator()() {
  char result;
  
  do {
    
    char byte1 = ifs->get();
    
    if ((byte1 & 0x80) != 0) {
      // high bit set: absolute
      
      result = byte1;
      
      int index = (unsigned char)byte1 & 0x3F;
      ofs->writeu16be(index);
    }
    else {
      // high bit unset: compressed
      
      char byte2 = ifs->get();
      result = byte2;
      
      int value = (unsigned char)byte2 & 0x3F;
      int count = ((unsigned char)byte1 & 0x3F) + 1;
      
      if ((byte1 & 0x40) == 0) {
        // copy value (count) times
        for (int i = 0; i < count; i++) {
          ofs->writeu16be(value);
        }
      }
      else {
        // copy value (count) times, incrementing each time
        for (int i = 0; i < count; i++) {
          ofs->writeu16be(value);
          ++value;
        }
      }
    }
    
  } while ((result & 0x40) == 0);
}


}
