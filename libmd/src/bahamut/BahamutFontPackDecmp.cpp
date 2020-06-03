#include "bahamut/BahamutFontPackDecmp.h"
#include <iostream>

using namespace BlackT;

namespace Md {


BahamutFontPackDecmp::BahamutFontPackDecmp(BlackT::TStream& ifs__,
                     BlackT::TStream& ofs__)
  : ifs(&ifs__),
    ofs(&ofs__) { }

void BahamutFontPackDecmp::operator()() {
  // 1b numentries
  int numEntries = ifs->readu8();
  // write as 16-bit
  ofs->writeu16be(numEntries);
  int initialOutputPos = ofs->tell();
  
  // fetch initial compression byte
  char initialCmpByte = ifs->get();
  
  // if bit 7 of initial compression byte is set, then even plane does not
  // exist: the next byte in the stream is the top byte of all entries
  if (initialCmpByte < 0) {
    int value = (ifs->readu8());
    value <<= 8;
    for (int i = 0; i < numEntries; i++) {
      ofs->writeu16be(value);
    }
    
    // initial compression byte is inverted from its correct value
    initialCmpByte = -initialCmpByte;
  }
  else {
    // decompress even byteplane
    decmpPlane(numEntries, initialCmpByte);
    
    // get next initial compression byte
    initialCmpByte = ifs->get();
  }
  
  // rewind output stream for odd byteplane
  ofs->seek(initialOutputPos + 1);
  
  // decompress odd byteplane
  decmpPlane(numEntries, initialCmpByte);
}

void BahamutFontPackDecmp::decmpPlane(int numEntries, char cmpByte) {
  
  do {
    
    int len = (cmpByte & 0x0F) - 1;
    // if low nybble is zero, yielding negative result, next byte is
    // 8-bit extended length
    if (len < 0) {
      len = ifs->readu8();
    }
    
    // increment for use as loop counter
    ++len;
    
    int cmpCmd = (cmpByte & 0x70) >> 4;
    
    switch (cmpCmd) {
    case 0:
      // terminate decompression
      return;
      break;
    case 1: // copy next byte
    {
      int next = ifs->readu8();
      for (int i = 0; i < len; i++) {
        ofs->writeu8(next);
        ofs->seekoff(1);
      }
    }
      break;
    case 2: // copy next bytes
    {
      for (int i = 0; i < len; i++) {
        int next = ifs->readu8();
        ofs->writeu8(next);
        ofs->seekoff(1);
      }
    }
      break;
    case 3: // copy next byte with increment
    {
      int next = ifs->readu8();
      for (int i = 0; i < len; i++) {
        ofs->writeu8(next);
        ofs->seekoff(1);
        
        // 8-bit wrapping
        next = (next + 1) & 0xFF;
      }
    }
      break;
    case 4: // copy run repeatedly
    {
      int runLen = ifs->readu8() + 1;
      
      int initialPos = ifs->tell();
      for (int i = 0; i < len; i++) {
        ifs->seek(initialPos);
        
        for (int j = 0; j < runLen; j++) {
          int next = ifs->readu8();
          ofs->writeu8(next);
          ofs->seekoff(1);
        }
      }
    }
      break;
    case 5: // repeated incremental run
    {
      int runLen = ifs->readu8() + 1;
      int initialNext = ifs->readu8();
      for (int i = 0; i < len; i++) {
        int next = initialNext;
        for (int j = 0; j < runLen; j++) {
          ofs->writeu8(next);
          ofs->seekoff(1);
        
          // 16-bit wrapping
          next = (next + 1) & 0xFFFF;
        }
      }
    }
      break;
    case 6:
      // special "uncompressed" command
      
      // seek input back a byte
      ifs->seekoff(-1);
      // copy plane
      for (int i = 0; i < numEntries + 1; i++) {
        ofs->writeu8(ifs->readu8());
        ofs->seekoff(1);
      }
      
      // terminate decompression
      return;
      
      break;
    default:
      std::cerr << "illegal decompression command " << cmpCmd << std::endl;
      break;
    }
    
    cmpByte = ifs->get();
    
  } while (cmpByte != 0x00);
  
}


}
