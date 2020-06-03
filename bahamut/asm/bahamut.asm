*******************************************************************************
* Bahamut Senki English translation hacks
*******************************************************************************

fontPackMapAddr     equ   $80000
stringMapAddr       equ   $90000
string8x8MapAddr    equ   $A0000
newCodeStartAddr    equ   $B0000

*******************************************************************************
* new 8x8 script ops
*******************************************************************************
  
smallStringCallRemap00 equ $F6
smallStringCallRemap01 equ $F7
smallStringCallRemap02 equ $F8
smallStringBlank       equ $F9
smallStringBackspace   equ $FA
smallStringCallRemap   equ $FB
smallStringJumpToRemap equ $FC
smallStringBr          equ $FD
smallStringUp          equ $FE
smallStringSpace       equ $FF
  
bangCharIndex equ $25
periodCharIndex equ $30
questionMarkCharIndex equ $34
commaCharIndex equ $35
quoteCharIndex equ $36
spaceCharIndex equ $FF

*******************************************************************************
* old routines
*******************************************************************************

toVdpDstCmd equ $4EA
loadFontPack equ $CA2
printTallNum equ $DFE
printBasicString equ $1A62
concatPlaceNameToPendingAdvisorString equ $2F46
concatUnitNameListToPendingAdvisorString equ $2F84
concatSrcUnitNameListToPendingAdvisorString equ $2FA6
concatToPendingAdvisorString equ $302E
addCharToPendingAdvisorString equ $304C

*******************************************************************************
* DEBUG
*******************************************************************************

  * no 8x8 font
*   org $E5E
*   nop
*   nop
  * no icons
*   org $E6E
*   rts

*******************************************************************************
* header: overseas title
*******************************************************************************

  org $150
  dc.b 'Record of the Bahamut War'

*******************************************************************************
* Changes to old code
*******************************************************************************

  **************************************
  * Reduce 16x16 font to 8x16
  **************************************

    ***********************************
    * reduce size of each character's
    * 1bpp data from 32 bytes to 16
    ***********************************
*     org $19F8
*     lsl.w     #4,D0   * multiply by 16
      
    org $19FE
    moveq     #$7,D3  * loop 8 times
      
    ***********************************
    * decompress 2 tiles instead of 4
    ***********************************
    org $1A02
  *    moveq     #$1,D2  * loop 2 times
      
    ***********************************
    * copy only 2 tiles during tilemap
    * conversion
    ***********************************
    org $1AA2
    tileVramCopyLoop:
    
    org $1AA4
    ADDQ.W   #2,A1  * space = 1 tile
    BRA.S    tileVramCopySpaceSkip
    
    org $1AAA
    * write tilemap of top row of character
    MOVE.W   D0,(A1)+
    ADDQ.W   #1,D0
    * write tilemap of bottom row of character to (addr+7E)
    MOVE.W   D0,$7E(A1)
    
    tileVramCopySpaceSkip:
    
    * fetch next character
    MOVE.W   (A0)+,D0
    * negative value = done
    BPL.S    tileVramCopyLoop
    RTS
      
    ***********************************
    * intro: 8x16
    ***********************************
    * 38E2 = character tilemap transfer?
    org $5B94
    MOVEQ    #$0,D2   * copy 1-tile wide area
    
    org $5B7C
    ADDQ.W   #2,$6A(A6) * advance 2 tiles

  **************************************
  * Use new 8x16 string lookup code
  **************************************
    
    org $1A62
    jmp lookupTallStringHashAndPrint

  **************************************
  * Use new font pack lookup code
  **************************************

    org $CA2
    jmp lookupFontPackHashAndLoad

  **************************************
  * Use new 8x8 string lookup code
  **************************************
  
  org $3812
  jmp lookupSmallStringHashAndPrint

  **************************************
  * Use new consecutive string rendering code
  **************************************
    
    org $1A4A
    jmp renderConsecutiveTallStringsA
    
    org $1A56
    jmp renderConsecutiveTallStringsB

  **************************************
  * Battle: fix consecutive string rendering for menu
  **************************************

    org $17808
    move.l  d3,-(a7)
    moveq   #6,d3
    jsr     renderConsecutiveTallStringsA
    move.l  (a7)+,d3
    rts

  **************************************
  * Use new font
  **************************************
  
  org $19EC
  lea newFontData,a3

  *************************************
  * use new title logo
  *************************************
  
  * intro
  org $92F6
  jmp loadNewTitleLogoGrpSub1
  
  * if intro skipped
  org $854A
  jmp loadNewTitleLogoGrpSub2
  
  * map
  org $856E
  jmp loadNewTitleLogoMapSub1
  
  * map
  org $853C
  jmp loadNewTitleLogoMapSub2

  **************************************
  * compute target font char srcaddr
  * correctly (original uses signed
  * offsets and could not exceed a
  * total size of $8000)
  **************************************
  
*   * font heap pos change?
*   org $194A
*   addq.w #2,d5
  
  org $1958
*  lsl.w #2,d0
  * compute size of content (which is halved due to 8x16 hack)
  lsl.w #1,d0
*   addq.w #4-2,d0

  **************************************
  * correctly update position of
  * window font heap
  **************************************
  
  org $19F8
  jmp doExpandedFontCharLookup

  **************************************
  * correctly update position of
  * window font heap 2
  **************************************
  
  org $5D7C
  lsl.w #2-1,d0
*   addq.w #4-2,d0

  **************************************
  * load rule screen font packs
  **************************************
  
  org $9D3C
  jsr loadRuleScreenSubPacks
  jmp $9D7A

  **************************************
  * remap shared strings for strategy
  * phase labels
  **************************************
  
  * these are offsets from the base address to the target string
  
  * 6069-0 -> 6063
  org $6048
  dc.w $0021-6
  
  * 606B (unique, not changed)
  org $6050
  dc.w $001B
  
  * 6069-1 -> 6064
  org $6058
  dc.w $0011-5
  
  * 6069-2 -> 6065
  org $6060
  dc.w $0009-4

  **************************************
  * remap shared strings for turn
  * start info banner
  **************************************
  
  org $59CC
  jsr printTurnStartInfoBannerContent
  jmp $59FE

  **************************************
  * draw unit names correctly --
  * original game uses shared strings
  **************************************
  
  org $1F646
  jmp printRemappedUnitName

  **************************************
  * do not use shared string to draw
  * unit status screen labels
  **************************************
  
  * disable initial draw
  org $18A10
  nop
  nop
  
  * do real draw
  org $18A20
  jmp drawNewStatusScreenLabel

  **************************************
  * correctly mark usable magic types
  * on unit status screen
  **************************************
  
  org $18CB6
  jmp drawStatusScreenUsableMagicTypes

  **************************************
  * adjust positions of right-side
  * labels on rule settings screen
  **************************************
  
  org $A492
  dc.w $A32A+4,$A4B2-4,$A62E

  **************************************
  * adjust position of number of turns
  * on rule settings screen
  **************************************
  
  org $A476
  lea $FFFFA796+10,a1

  **************************************
  * new lookup for stratagem names
  **************************************
  
  org $5AF0
  jmp newStratagemNameLookup
  
  * halve character count due to 8x16 hack
  org $5B1C
  lsl.w #2-1,d0
  * updated position in font stack
   addq.w #4-0,d0
  
  * calculate dstpos correctly
  org $5B26
*  jmp newStratagemGraphicSrcCalc
   addq.w #4-0,d5
  
  * write new tile targets
  org $5B4C
   addq.w #4-0,d4
  newStratagemTileNameWriteLoop:
    * top half
    move.w d4,(a1)+
    addq.w #1,d4
    * bottom half
    move.w d4,$7E(a1)
    addq.w #1,d4
    
    * this was used in the old code to automatically add spaces between
    * shorter entries so they would be "centered".
    * no longer needed.
*    adda.w d5,a1
    dbf d2,newStratagemTileNameWriteLoop
  jmp $5B6A
  
  * do not add hardcoded quote length to string length
  org $5AF8
  nop
  
  * never add hardcoded opening quote character
  org $5B06
  bra $5B0E

  **************************************
  * remap enemy stratagem message on
  * overworld(?)
  **************************************
  
  org $111C0
  move.l #$1138D+1,$FFFFF15C

  **************************************
  * use full stratagem effect message
  * set in tactics phase, because 
  * it's easier
  **************************************
  
*   org $10886
*   lea $11325(pc),a0

  **************************************
  * status effect incurred strings
  **************************************
  
  org $1A2A2
  jmp setUpStatusEffectIncurredStringCommand

  **************************************
  * position of number of squadrons on
  * move menu
  **************************************
  
*   org $62CA
*   lea -$82(a2),a1

*   org $12326
*   jmp getSquadsAbleToMoveNumDst
  
  org $1231E
  jmp getSquadsAbleToMoveNumDst

  **************************************
  * rule select screen text printing
  **************************************
  
  org $A582
  * halve time between character prints
  move.b #8/2,$1B(a6)
  
  * print one tile at a time instead of 2
  * a0 = src, a1 = dst
  org $A5C0
*  move.l (a0)+,(a1)
  move.w (a0)+,(a1)
  move.w a0,$34(a6)
  add.l #$800000,d0
*  lea $7C(a0),a0
  lea $7E(a0),a0
  move.l d0,$4(a1)
*  move.l (a0),(a1)
  move.w (a0),(a1)

  **************************************
  * double normal printing speed
  **************************************
  
  org $5B72
  jmp getNewTextPrintSpeed
  
  * battle
  org $1F5FA
  jmp getNewTextPrintSpeedBattle
  
  * narrow copy battle
  org $1F61C
  * number of iterations of copy loops
  * inner (x)
  moveq #1-1,d2
  * outer (y)
  moveq #1,d3

  **************************************
  * load new 8x8 font instead of old
  **************************************
  
  org $E52
  jmp loadNewSmallFont

  **************************************
  * fix alliance/time request message
  **************************************
  
  * move 8x16 portion up a line
  org $1061A
  jmp moveUpAllianceReqMessage

  * reset turn request line position, and move down
  org $1055A
  jmp moveRequestTurnCountDown
  
  * draw turn request correctly
  org $107B0
  jmp drawNewRequestTurnCount
  
  org $10612
  jmp drawNewRequestTurnCount_time

  **************************************
  * modify status screen weapons
  * drawing
  **************************************
  
  * no colon after range
  org $18B5A
  * more space after range
  addq.w #2+0,a3
  bra $18B64
  
  org $18B88
  jmp statusScreenWeaponDraw
  
  * less space to make up for larger space after range
  org $18C16
*   lea $17A-2(a3),a3

  **************************************
  * action battle menu
  **************************************
  
  org $21CD4
  jmp loadActionBattleMenuStrings
  
  * magic attack
  org $21D66
  jmp loadActionBattleMenu_fixMagicAttack

  **************************************
  * location of turn number on main
  * screen
  **************************************
  
  * to mem
  org $DC18
  lea $FFFFA08E+2,a1
  
  * size of transfer to vdp
  org $DC22
  * addr
  lea $FFFFA086+2,a0
  * w
  moveq #3,d2
  * h
  moveq #1,d3

  **************************************
  * change hardcoded position of font
  * stack for "3 turns left" stuff
  *************************************
  
  org $DA12
  move.w #$8408+$10,$FFFFF03A

  **************************************
  * fix "turn" label indicating
  * alliance time on map screen
  *************************************
  
  org $1190C
  * "T"
  move.w #$801E,(a1)+
  * "R"
  move.w #$801C,(a1)+
  * "N"
  move.w #$8018,(a1)+

  **************************************
  * advisor text
  *************************************
  
  * quote marks at start/end
  
  org $2F38
  move.b #quoteCharIndex,(a6)+
  
  org $3082
*  move.b #quoteCharIndex,d0
  jmp printAdvisorString
  
  * new concatenation behavior
  org $302E
  jmp doNewAdvisorStringConcat
  
  org $3082
  jmp printAdvisorString
  
  * move "[x] says" text up a line
  org $310E
  lea -$180(a1),a1

  *************************************
  * advisor message fixes
  *************************************
  
  * add char directly to pending string
  org $304C
  move.b d0,(a6)+
  rts
  
  * comma-separated list generation
*   org $2F90
*   jmp genCommaSeparatedUnitList
  org $2F84
  jmp genCommaSeparatedUnitList
  
  * reverse verb/object order: list of musterable troops
  org $16412
*   lea $1693D(pc),a0
*   jsr concatToPendingAdvisorString
*   jsr concatUnitNameListToPendingAdvisorString
  jmp musterAdviceReverseSVO
  
  org $162D0
  jmp summonAdviceReverseSVO
  
  org $1643E
  jmp newMusteringRecsStart
  
  org $16386
  jmp newSummoningRecsStart
  
  * "i'd use [x] to hire [y]"
  org $164A6
  jmp doNewAdvisorHireWithUnitRec
  
  org $164B8
  jmp doNewAdvisorHireWithoutUnitRec
  
  org $2FDC
  jmp doFullNewSquadSrcNamePrint
  
  org $2FBE
  jmp doSrcSquadNotNecessaryMessage
  
  * list of squad members in an area
  org $2FF4
  jmp doNewSquadSrcNamePrint
  
  org $16522
  jmp doAdvisorInvasionEncourage
  
  * no "to" after "all squadrons"
  org $2FDA
  bra.s $302C
  
  org $2F60
  jmp fixAreaNameParen
  
*   org $16658
*   jmp scoutPlaceListAndFix
  
  org $16650
  jmp scoutPlaceListFinalFix
  
  org $F6AC
  jmp fixRulerNameDiplomacy1
  
  org $F75A
  jmp fixRulerNameDiplomacy_rulerLast
  
  org $F760
  jmp fixRulerNameDiplomacy_rulerLast_noSkip
  
  * i don't know what this is modifying in the string but we don't want it
  org $F748
  jsr fixRulerNameDiplomacy_rulerFirst_noSkip
  jmp $F756
  
  * "you might extend the time of alliance"
  org $F716
  jmp newAllianceTimeAdvice
  
  * "first, cooperate with"
  org $F696
  jmp newCooperationAdvice
  
  * summoning: "i wouldn't do that, but would..."
  org $16300
  jmp summonAdviceMoveSquadInsteadNew
  
  org $1634C
  jmp summonAdviceSummonElsewhereInsteadNew
  
  org $166F2
  jmp heroesAdviceAppointmentListNew
  
  org $16728
  jmp heroesAdviceDischargeNew1
  
  org $16734
  jmp heroesAdviceDischargeNew2
  
  org $F8C8
  jmp stratagemDiplomacyAdvice1
  
  org $F8BC
  jmp stratagemDiplomacyAdvice2
  
  org $F8DA
  jmp stratagemDiplomacyAdvice3
  
  * use expected sentence order for "summon squadron"
  * and "summon guardian" messages in case where
  * target area is current area.
  * original game has special check which uses
  * an alternate structure to replace the normal name
  * with "koko".
  org $16224
  jmp summonSchemeThisAreaAdviceNew
  
  org $16758
  jmp restAdvice1
  
  org $16584
  jmp moveAdvice1
  
  org $1673E
  jmp lookUpOneLineHeroName

  *************************************
  * labels on battle test screen
  *************************************
  
  org $7AA6
  moveq #$6+5,d2

  *************************************
  * character select
  *************************************
  
  org $AB66
  lea $7E(a1),a1
  jmp charSelNameCheckForSieg

  *************************************
  * hero names on unit status screen
  *************************************
  
  org $18A96
  lea $88-2(a3),a1

  *************************************
  * fix nonexistent place name
  * detection
  *************************************
  
  org $2F46
  jmp fixEmptyPlaceNameDetection
  
  *************************************
  * true ending
  *************************************
  
  * load new small font
  org $C1EA
  jmp trueEndLoadFont
  
  * text speed if a period
  org $C35A
  moveq #$1F,d0
*   moveq #$0,d0
  cmp.b #periodCharIndex,d7
  
  * text speed if not a period
  org $C362
  moveq #$B/2,d0
*   moveq #$0,d0
  
  * delay after each box
  org $C382
*   moveq #$1,d0
  moveq #$3C,d0
  
  * line spacing
  org $C372
  lea $100-$80(a0),a0
  
  * double line generation
  org $C30E
  jmp trueEndDoubleLineGen
  
  * initial text pos
  org $C30A
  lea $FFFFA882-$80,a3
  org $C322
  lea $FFFFA802-$80,a0
  
  * space between consecutive strings
*   org $C316
*   lea $FE-$80(a3),a3

  * height of line in tiles
*   org $C354
*   moveq #1-1,d3
  
  * correctly check for terminating line
  org $C334
  tst.l $80(a0)
  
  * clear one extra line between boxes
  org $C292
  moveq #$9+1,d3
  
  *************************************
  * lp request text
  *************************************
  
  org $10630
  jmp doNewLpRequestMessage
  
  org $105AA
  jmp doNewLpDonateMessage

  *************************************
  * adjust size of hero defection window
  * to accomodate 7-character-wide names
  *************************************
  
  org $11286
  * x
  * (must be moved left to avoid overlapping main menu or game
  * will crash when window closes)
  dc.w $0015-3
  * y?
  dc.w $000A
  * width
  * higher = wider, but this is not tile-granular
  dc.w $0002+1
  * ?
  dc.w $0002
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
*******************************************************************************
* Expansions
*******************************************************************************
  
  org newCodeStartAddr
  
  
  renderConsecutiveTallStringsA:
    movem.l d5,-(a7)
    move.l  #$180,d5
    bsr renderConsecutiveTallStrings
    movem.l  (a7)+,d5
    rts
    
  renderConsecutiveTallStringsB:
    movem.l d5,-(a7)
    move.l  #$200,d5
    bsr renderConsecutiveTallStrings
    movem.l  (a7)+,d5
    rts
    
  *******************************************************************************
  * render a series of consecutive 8x16 strings
  * A2 = initial src
  * A3 = initial dst
  * D3 = counter
  * D5 = dst incrementer
  *******************************************************************************
  
  renderConsecutiveTallStrings:
*     * look up hash of initial source
*     move.l    a2,d0
*     lea       stringMapAddr,a0
*     bsr       findHashMapEntry
*     
*     * done if failure
*     cmp.l     #$FFFFFFFF,a0
*     bne       renderConsecutiveTallStrings_preloop
*       rts
*     
*     renderConsecutiveTallStrings_preloop:
*       * prep arguments
*       
*     renderConsecutiveTallStrings_loop:
*       bsr       printTallString
*       * make up work (next destination)
*   *    LEA       $180(A3),A3
*       add.l     d5,a3
*       * recover next src
*       move.l    a2,a0
*       dbf       d3,renderConsecutiveTallStrings_loop
      
    renderConsecutiveTallStrings_loop:
      bsr       lookupTallStringHashAndPrint
      * make up work (next destination)
      add.l     d5,a3
      * recover next src
      move.l    a2,a0
      dbf       d3,renderConsecutiveTallStrings_loop
  
    rts
    
  *******************************************************************************
  * 8x16 string lookup from hash map
  * A2 = src
  * A3 = tilemap dst
  *******************************************************************************
  lookupTallStringHashAndPrint:
    
    * HACK: if targeting RAM FFF234, target (0x0001 & (*FFF234)) instead.
    * this deals with certain status effect messages.
    move.l  a2,d0
    and.l #$00FFFFFF,d0
    cmp.l #$00FFF234,d0
    bne lookupTallStringHashAndPrint_notSpecial
      moveq #0,d0
      move.w $FFFFF234,d0
      or.l #$00010000,d0
    lookupTallStringHashAndPrint_notSpecial:
    
  
    * look up value from string hash table
    lea     stringMapAddr,a0
    bsr     findHashMapEntry
    
    cmp.l   #$FFFFFFFF,a0
    beq     lookupTallStringHashAndPrint_failure
  
  printTallString:
    
    * make up work (string buffer dst)
    lea     $FFFFF800,a1
  
    * copy string content
    
    * get content length
    move.w  (a0)+,d1
    * done if FFFF (zero)
    bpl     lookupTallStringHashAndPrint_copyloop
      * write placeholder value (the game does not handle 0-length strings
      * correctly)
      move.w  #$00,(a1)+
      bra     lookupTallStringHashAndPrint_readOldSrc
      
    
    lookupTallStringHashAndPrint_copyloop:
      * get raw index
*      moveq   #0,d0
*      move.b  (a0)+,d0
      * multiply by 2 to get tile index
*      lsl.w   #1,d0

      * actually just copy as-is
      move.w  (a0)+,d0
      * copy to dst
      move.w  d0,(a1)+
      
      dbf     d1,lookupTallStringHashAndPrint_copyloop
      
    * add FFFF terminator
    * (done by code we jump to)
*    move.w  #$FFFF,d0
*    move.w  d0,(a1)+
    
    * read address of end of old src, so we can return it as if we had
    * read the string from its original location.
    * this allows consecutive strings to be remapped.
    lookupTallStringHashAndPrint_readOldSrc:
    move.b (a0)+,d0
    lsl.l #8,d0
    move.b (a0)+,d0
    lsl.l #8,d0
    move.b (a0)+,d0
    lsl.l #8,d0
    move.b (a0)+,d0
    move.l d0,a0
    
    * jump to tilemap conversion code
    lookupTallStringHashAndPrint_success:
    move.l   a0,a2
    jmp $1A96
  
  lookupTallStringHashAndPrint_failure:
  * do nothing (jump past tilemap conversion code)
*  move.l   a0,a2
*  jmp     $1AC0
  lea tallString_hashMapNotFoundFailEntry,a0
  bra printTallString
    
    tallString_hashMapNotFoundFailEntry:
      * empty string
      dc.w $FFFF
      * "next" address
      dc.l tallString_hashMapNotFoundFailEntry
    
  *******************************************************************************
  * 8x8 string lookup from hash map
  * A0 = orig src
  * A1 = tilemap dst
  *******************************************************************************
  
  * a0 = orig src
  * trashes d0
  lookupSmallStringHash:
    movem.l a1-a2,-(a7)
      * look up value from string hash table
      move.l a0,d0
      lea string8x8MapAddr,a0
      bsr findHashMapEntry
    movem.l (a7)+,a1-a2
    rts
  
  lookupSmallStringHashAndPrint:
    *****************
    * look up hash
    *****************
    
    * if src is a memory location, print using old routine
    move.l a0,d0
    and.l #$00FF0000,d0
    cmp.l #$00FF0000,d0
    bne lookupSmallStringHashAndPrint_notMem
*       * this is stupid and inefficient but should work?
*       moveq #0,d0
*       move.b (a0)+,d0
*       beq lookupSmallStringHashAndPrint_notMem_sub1
*         jmp $381A
*       lookupSmallStringHashAndPrint_notMem_sub1:
*       jmp $3868
      * never mind
      
      jmp printSmallString
    lookupSmallStringHashAndPrint_notMem:
    
    jsr lookupSmallStringHash
    
    cmp.l #$FFFFFFFF,a0
    beq lookupSmallStringHashAndPrint_failure
    
    *****************
    * print
    *****************
    
    jsr printSmallString
    
    *****************
    * immediately following the string is the address at which the
    * string it replaces ended.
    * retrieve and return this in a0, so that any calls which want to print
    * a series of consecutive strings will succeed.
    *****************
    
    move.b (a0)+,d0
    lsl.l #8,d0
    move.b (a0)+,d0
    lsl.l #8,d0
    move.b (a0)+,d0
    lsl.l #8,d0
    move.b (a0)+,d0
    
    move.l d0,a0
    
    * some callers of this routine depend on d0 being returned as zero
    moveq.l #0,d0
  
    lookupSmallStringHashAndPrint_failure:
    rts
  
  * a0 = src
  * a1 = dst
  printSmallString:
    move.l a2,-(a7)
      * a2 = saved base dstaddr
      move.l a1,a2
      
      * print string content
      lookupSmallStringHashAndPrint_printLoop:
        moveq #0,d0
        * d0 = fetch src byte
        move.b (a0)+,d0
        * done if zero
        beq lookupSmallStringHashAndPrint_done
        
        * if FF: space
        cmp.b #smallStringSpace,d0
        bne lookupSmallStringHashAndPrint_notSpace
          * advance dst past current target pos
          addq.w #2,a1
          bra lookupSmallStringHashAndPrint_printLoop
        lookupSmallStringHashAndPrint_notSpace:
        
        *****************
        * control codes
        *****************
        
        * blank next position
        cmp.b #smallStringBlank,d0
        bne lookupSmallStringHashAndPrint_notBlank
          moveq #0,d0
          or.w d3,d0
          move.w d0,(a1)+
          bra lookupSmallStringHashAndPrint_printLoop
        lookupSmallStringHashAndPrint_notBlank:
        
        * go back a character
        cmp.b #smallStringBackspace,d0
        bne lookupSmallStringHashAndPrint_notBackspace
          adda.w #-$2,a1
          bra lookupSmallStringHashAndPrint_printLoop
        lookupSmallStringHashAndPrint_notBackspace:
        
        * call a remapped string
        cmp.b #smallStringCallRemap,d0
        bne lookupSmallStringHashAndPrint_notCallRemap
          * fetch old address
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          
          * save old src
          move.l a0,-(a7)
            move.l d0,a0
          
            * get hash value
            jsr lookupSmallStringHash
            * print
            jsr printSmallString
          move.l (a7)+,a0
          
          * continue
          bra lookupSmallStringHashAndPrint_printLoop
        lookupSmallStringHashAndPrint_notCallRemap:
        
        * jump to a remapped string
        cmp.b #smallStringJumpToRemap,d0
        bne lookupSmallStringHashAndPrint_notJumpToRemap
          * fetch old address
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          
          * save old src
          move.l a0,-(a7)
            move.l d0,a0
          
            * get hash value
            jsr lookupSmallStringHash
            * print
            jsr printSmallString
          move.l (a7)+,a0
          
          * retrieve next srcstr and return as a0, as though
          * we had just printed it
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          move.l d0,a0
          
          * done
          bra lookupSmallStringHashAndPrint_done
        lookupSmallStringHashAndPrint_notJumpToRemap:
        
        * linebreak (1 line)
        cmp.b #smallStringBr,d0
        bne lookupSmallStringHashAndPrint_notBr
          * reset base position
          move.l a2,a1
          * move down a line
          adda.w #$80,a1
          * update base pos
          move.l a1,a2
          
          bra lookupSmallStringHashAndPrint_printLoop
        lookupSmallStringHashAndPrint_notBr:
        
        * reverse linebreak (1 line)
        cmp.b #smallStringUp,d0
        bne lookupSmallStringHashAndPrint_notUp
          * reset base position
          move.l a2,a1
          * move up a line
          adda.w #-$80,a1
          * update base pos
          move.l a1,a2
          
          bra lookupSmallStringHashAndPrint_printLoop
        lookupSmallStringHashAndPrint_notUp:
        
        
        *****************
        * otherwise, literal
        *****************
        
        or.w d3,d0
        move.w d0,(a1)+
        bra lookupSmallStringHashAndPrint_printLoop
        
        
      *****************
      * done
      *****************
      
      lookupSmallStringHashAndPrint_done:
    move.l (a7)+,a2
    
    * some callers of this routine depend on d0 being returned as zero
    moveq.l #0,d0
    
    rts
    
    
  *******************************************************************************
  * font pack from hash map
  * A0 = src
  *******************************************************************************
  
  lookupFontPackHashAndLoad:
    
    * make up work (buffer dst)
    lea     $FFFFF800,a1
    
    * look up value from string hash table
    move.l  a0,d0
    lea     fontPackMapAddr,a0
    bsr     findHashMapEntry
    
    cmp.l   #$FFFFFFFF,a0
    beq     lookupFontPackHashAndLoad_failure
    
      * copy font pack content
      
      * get content length
      move.w  (a0)+,d1
      
      * done if FFFF (zero)
      bpl     lookupFontPackHashAndLoad_precopyloop
        * write placeholder value (the game does not handle 0-length strings
        * correctly)
        move.w  #$00,(a1)+
        move.w  #$00,(a1)+
        bra     lookupFontPackHashAndLoad_success
        
      lookupFontPackHashAndLoad_precopyloop:
      * write numchars to output
      move.w    d1,(a1)+
      
      lookupFontPackHashAndLoad_copyloop:
        * get raw index
        move.w  (a0)+,d0
        * copy to dst
        move.w  d0,(a1)+
        
        dbf     d1,lookupFontPackHashAndLoad_copyloop
        
        
    
      * jump to tilemap conversion code
      lookupFontPackHashAndLoad_success:
      rts
    
    lookupFontPackHashAndLoad_failure:
    rts
  
  *******************************************************************************
  * hash map lookup
  * A0 = map address (trashed)
  * D0 = key (trashed)
  * 
  * returns result in A0 (FFFFFFFF
  * if not found)
  *******************************************************************************
  findHashMapEntry:
    movem.l A1/D1,-(A7)
    
    * d1 = hash value
    move.l  d0,d1
    and.l   #$FFF,d1
    * convert to address
    lsl.w   #2,d1
    add.l   d1,a0
    
    * get pointer to bucket
    move.l  (a0),a0
    * if value negative (i.e. -1), done
    bmi     findHashMapEntryDone
    
    * search bucket for target value
    findHashMapEntry_bucketSearchLoop:
      * fetch key
      move.l (a0)+,d1
      * key of -1 = end of bucket
      bmi    findHashMapEntry_failure
      
      * if this is not the key we're trying to find, move to next entry
      cmp.l  d1,d0
      bne    findHashMapEntry_bucketSearchFail
        
        * match found: return value in A0
        move.l (a0),a0
        bra    findHashMapEntryDone
      
      * move on to next entry
      findHashMapEntry_bucketSearchFail:
      add.l  #4,a0
      bra    findHashMapEntry_bucketSearchLoop
      
    findHashMapEntry_failure:
    move.l   #$FFFFFFFF,a0
    * hope
*    lea hashMapNotFoundFailEntry,a0
    
    findHashMapEntryDone:
    movem.l (A7)+,A1/D1
    rts
  
  *************************************************************************
  * rule select load fix
  *************************************************************************
  
  * original game relies on 
  
  loadRuleScreenSubPacks:
    * set up offset of first font pack
    addq.w #1,d0
*    lsl.w #2,d0
    lsl.w #1,d0
    * make up work
    add.w d0,d6
    move.l #$60000000,d0
    lea $A284,a4
    jsr $19DA
    lea $1B1C,a4
    
    * pack 1
    lea $A088,a0
    jsr loadRuleSubPack
    
    * pack 2
    lea $A0D7,a0
    jsr loadRuleSubPack
    
    rts
  
  loadRuleSubPack:
*     movea.l a6,a0
     move.l a1,-(a7)
      jsr loadFontPack
     movea.l (a7)+,a1
*     movea.l a0,a6
    lea $FFFFF800,a0
    move.w d6,(a5)+
    * set up offset of font pack
    move.w (a0),d0
    addq.w #1,d0
*    lsl.w #2,d0
    lsl.w #1,d0
    add.w d0,d6
    jsr $19F2
    
    rts
  
  *************************************************************************
  * 
  *************************************************************************
  
  printTurnStartInfoBannerContent:
*     * "#"
*     move.w $FFFFF036,d4
*     lea $6066-4,a2
*     lea $FFFFA084,a3
*     jsr printBasicString
*     
*     * turn number
*     move.w $FFFFF054,d0
*     addq.w #1,d0
*     lea $A(a3),a1
*     jsr printTallNum
*     
*     * "turn"
*     lea $6066-5,a2
*     lea $FFFFA08E,a3
*     jsr printBasicString
*     
*     * "start"
*     lea $6066-6,a2
*     move.w $FFFFF038,d4
*     lea $FFFFA09C,a3
*     jsr printBasicString
*     * "#"
*     move.w $FFFFF036,d4
*     lea $6066-4,a2
*     lea $FFFFA084,a3
*     jsr printBasicString
    * "#"
    move.w $FFFFF036,d4
*     lea $6066-4,a2
*     lea $FFFFA084,a3
*     jsr printBasicString
    
    * "turn"
    lea $6066-5,a2
    lea $FFFFA084,a3
    jsr printBasicString
    
    * turn number
    move.w $FFFFF054,d0
    addq.w #1,d0
*    lea $A(a3),a1
    * the turn number has been moved a tile to the right
    * to allow 3-digit values to fit comfortably.
    * see also the alteration at DC18.
    lea $C(a3),a1
    jsr printTallNum
    
    * "start"
    lea $6066-6,a2
    move.w $FFFFF038,d4
    lea $FFFFA09C,a3
    jsr printBasicString
    
    rts
  
  *************************************************************************
  * remap unit string using their font pack addresses,
  * because the font packs are unique but the strings are shared
  *************************************************************************
  
  printRemappedUnitName:
    * save font pack addr
    move.l a0,-(a7)
      * load font pack
      jsr $1944
    * restore font pack addr.
    * we substitute the address for the target string,
    * because the font pack is unique but the string is not.
    move.l (a7)+,a2
    
    * ?
    move.w $FFFFF03A,d4
    
    * return to normal print logic
    jmp $1F5D8
  
  *************************************************************************
  * do full multiply+add when looking up font chars to get around old
  * limitations due to use of signed 16-bit integers
  *************************************************************************
  
  doExpandedFontCharLookup:
    * multiply target char index by 16
    lsl.l #4,d0
    add.l a3,d0
    move.l d0,a2
    jmp $19FE
  
  *************************************************************************
  * draw new status screen labels.
  * originals used shared string.
  *************************************************************************
  
  drawNewStatusScreenLabel:
    * make up work
    * a4 = pointer to infostruct
    adda.w d0,a4
    * save to stack (not matched; this is done at the end of the handler)
    move.l a4,-(a7)
    
    move.l d0,-(a7)
    
      * a0 = retrieved pointer to target font pack
      movea.l a4,a2
      adda.w (a4),a2
      
      * use font pack pointer to draw string (which has been remapped
      * to this address)
      movea.w $2A(a5),a3
      jsr printBasicString
    
    move.l (a7)+,d0
    
    * make up work
    add.w d0,d0
    jmp $18A26
  
  *************************************************************************
  * draw usable magic types on status screen.
  * original relied on consecutive string printing.
  *************************************************************************
  
  drawStatusScreenUsableMagicTypes:
    move.l a4,-(a7)
      lea statusScreenMagicTypeStringPointerArray,a4
      
      moveq #3,d5
      drawStatusScreenUsableMagicTypes_loop:
        add.b d6,d6
        bcc drawStatusScreenUsableMagicTypes_notUsable
          move.l (a4),a2
          jsr printBasicString
          addq.w #4,a3
*          subq.w #1,a2
        drawStatusScreenUsableMagicTypes_notUsable:
*        addq.w #1,a2
        addq.w #4,a4
        dbf d5,drawStatusScreenUsableMagicTypes_loop
      
    move.l (a7)+,a4
    jmp $18CCE
    
    
  dc.w 0
  statusScreenMagicTypeStringPointerArray:
    dc.l $18F2D,$18F2E,$18F2F,$18F30
  
  *************************************************************************
  * look up new stratagem name strings
  *************************************************************************
  
  * a2 = old string location
  newStratagemNameLookup:
    
    * hash
    lea stringMapAddr,a0
    move.l a2,d0
    
    * if quote needed, add 1 to srcaddr
    tst.w d3
    beq newStratagemNameLookup_noQuote
      add.l #1,d0
    newStratagemNameLookup_noQuote:
    
    jsr findHashMapEntry
    
    move.l a0,a2
    
    * make up work
    move.w (a2)+,d0
    move.w d0,d1
    add.w d0,d0
    jmp $5AF6

    
*   newStratagemGraphicSrcCalc:
*     * clear out high word of d5
* *     swap.w d5
* *     move.w #$0000,d5
* *     swap.w d5
*     
*     * make up work
*     addq.w #4-2,d5
*     lsl.w #5,d5
*     move.w d3,-(a7)
*     
*     jmp $5B2C
  
  *************************************************************************
  * status effect incurred messages
  *************************************************************************
  
  setUpStatusEffectIncurredStringCommand:
    * a0 = src font pack address
    lea $1A8D2,a0
    adda.w $FFFFF1E8,a0
    adda.w (a0),a0
    
    * save low word to what would have been the generated string content
    move.w a0,$FFFFF234
    
    * make up work
    lea $FFFFF234,a0
    jmp $1A2B0
  
  *************************************************************************
  * location of number on count of squads able to move
  *************************************************************************
  
  getSquadsAbleToMoveNumDst:
*     * make up work
*     lea $70A(a3),a3
*     lea $C(a3),a1
*     
*     * now, a1 = dst
*     * offset position
*     adda.w #4,a1
    
*    jmp $1232E
    
*     lea $123DB,a2
*     movea.w $28(a5),a3
*     lea $70A(a3),a3
*     
*     * a1 = number dst
*     lea $C(a3),a1
*     * d0 = number
*     move.w $FFFFF23C,d0
*     
*     * print number if needed
*     beq getSquadsAbleToMoveNumDst_noNumber
*       lea $123D1,a2
*       jsr printTallNum
*     getSquadsAbleToMoveNumDst_noNumber:
*     
*     * print string
*     move.w $FFFFF03A,d4
*     move.w a3,-(a7)
*       jsr printBasicString
*     movea.w (a7)+,a0
    
    * a2 = default string: "cannot move any more"
    lea $123DB,a2
    * change if needed
    tst.w $FFFFF23C
    beq getSquadsAbleToMoveNumDst_noStringChange
      lea $123D1,a2
      cmp.w #$0001,$FFFFF23C
      * use special new string if exactly one squadron
      bne getSquadsAbleToMoveNumDst_moreThanOneSquad
        adda.w #1,a2
      getSquadsAbleToMoveNumDst_moreThanOneSquad:
    getSquadsAbleToMoveNumDst_noStringChange:
    
    movea.w $28(a5),a3
    lea $70A(a3),a3
    
    * print string
    move.w $FFFFF03A,d4
    move.w a3,-(a7)
      jsr printBasicString
    movea.w (a7)+,a3
    
    * a1 = number dst
    lea $C+$4(a3),a1
    * d0 = number
    move.w $FFFFF23C,d0
    
    * print number if needed
    beq getSquadsAbleToMoveNumDst_noNumber
      jsr printTallNum
    getSquadsAbleToMoveNumDst_noNumber:
    
    movea.w a3,a0
    
    rts
  
  *************************************************************************
  * new text printing speed (overworld, intro, etc.)
  *************************************************************************
  
  getNewTextPrintSpeed:
    * get text printing reload counter
    move.b $FFFFF047,d0
    * halve
    lsr.b #1,d0
    * copy to counter
    move.b d0,$1A(a6)
    jmp $5B78
  
  *************************************************************************
  * new text printing speed (battle)
  *************************************************************************
  
  getNewTextPrintSpeedBattle:
    * get text printing reload counter
    move.b $FFFFF047,d0
    * halve
    lsr.b #1,d0
    * copy to counter
    move.b d0,$1A(a6)
    
    * also halve copy size
    movea.w $6A(a6),a0
    addq.w #4/2,$6A(a6)
    move.w (a0),d0
    
    jmp $1F60A
  
  *************************************************************************
  * load uncompressed graphic
  * a0 = src
  * d0 = vdp dstaddr
  * d1 = size in words
  *************************************************************************
  
  loadUncompressedGraphic:
    movem.l a1,-(a7)
      * d0 = VDP dstcmd
      jsr toVdpDstCmd
      
      lea $C00000,a1
      move.l d0,$4(a1)
      
      * ?
      * probably status flag to indicate loading in progress
      bset #2,$FFFFF000
      
      loadUncompressedGraphic_loop:
        move.w (a0)+,(a1)
        dbf d1,loadUncompressedGraphic_loop
      
      bclr #2,$FFFFF000
    movem.l (a7)+,a1
    rts
  
  *************************************************************************
  * load new font
  *************************************************************************
  
  loadNewSmallFont:
    lea newSmallFontData,a0
    move.w #$0000,d0
    move.w #(newSmallFontData_end-newSmallFontData)/2,d1
    bsr loadUncompressedGraphic
*     * set dstaddr
*     lea $C00000,a1
*     move.l #$40000000,$4(a1)
*     
*     * ?
*     * probably status flag to indicate loading in progress
*     bset #2,$FFFFF000
*       
*       lea newSmallFontData,a0
*       move.w #(newSmallFontData_end-newSmallFontData)/2,d0
*       loadNewSmallFont_loop:
*         move.w (a0)+,(a1)
*         dbf d0,loadNewSmallFont_loop
*         
*         
*     bclr #2,$FFFFF000
    jmp $E62
  
  loadNewSmallFontLowerCase:
    lea newSmallFontLowerCaseData,a0
    move.w #$0000,d0
    move.w #(newSmallFontLowerCaseData_end-newSmallFontLowerCaseData)/2,d1
    bsr loadUncompressedGraphic
    rts
  
  *************************************************************************
  * load new title logo graphics
  *************************************************************************

  
titleLogoGrpDst equ $510*$20
titleLogoTilemapMemDst equ $FFFFB580
  
  loadNewTitleLogoGrp:
    lea newTitleLogoTileData,a0
    move.w #titleLogoGrpDst,d0
    move.w #(newTitleLogoTileData_end-newTitleLogoTileData)/2,d1
    
    jmp loadUncompressedGraphic
  
  loadNewTitleLogoMap:
    movem.l a0-a1/d0-d1,-(a7)
      lea newTitleLogoMapData,a0
      lea titleLogoTilemapMemDst,a1
      move.w #((newTitleLogoMapData_end-newTitleLogoMapData)/2)-1,d1
      
      loadNewTitleLogoMap_loop:
        move.w (a0)+,(a1)+
        dbf d1,loadNewTitleLogoMap_loop
    movem.l (a7)+,a0-a1/d0-d1
    
    rts
  
  *************************************************************************
  * alliance/time request fixes
  *************************************************************************
  
  moveUpAllianceReqMessage:
    * move dstpos up a line
    adda.l #-$80,a3
    
    * make up work
    jsr $1A62
    jsr $107C4
    jmp $10622
  
  moveRequestTurnCountDown:
    * make up work
    movea.w $FFFFF0A0,a6
    jsr $200A
    * save base putpos for window
*     move.l a3,-(a7)
      lea $1082E,a0
      jsr $3812
*     move.l (a7)+,a1
    
    * reset printing position to start + 3 lines
    movea.w $28(a5),a1
    lea $100+$E+$180(a1),a1
    jmp $1056A
    
  drawNewRequestTurnCount_shared:
    * offset to make this look nicer
    adda.l #20,a1
    
    * insert digit 4 characters ahead.
    * full message: "for [digit] turns."
    adda.l #8,a1
    * d0 = count
    move.w $FFFFF23C,d0
    * add base digit tilemap
    add.w #$8002,d0
    move.w d0,(a1)
    
    * move back to base pos and draw message
    suba.l #8,a1
    lea $10830,a0
    
    * use singular message if 1 turn
    * (a value of 0 == 1 turn, etc.)
    move.w $FFFFF23C,d0
    bne drawNewRequestTurnCount_shared_notZero
      adda.l #1,a0
    drawNewRequestTurnCount_shared_notZero:
    
    rts
    
  drawNewRequestTurnCount:
    bsr drawNewRequestTurnCount_shared
    
    jmp $3812
    
  drawNewRequestTurnCount_time:
    bsr drawNewRequestTurnCount_shared
    
    * change to alt "OF" form
    adda.l #2,a0
    
    jsr $3812
    
    * make up work
    lea $104C2,a2
    jmp $1061A
  
  *************************************************************************
  * status screen weapons
  *************************************************************************
  
  statusScreenWeaponDraw:
    
    * number of attacks
    addq.w #1,d0
    addq.w #4,a1
    jsr printTallNum
    
    * "x"
    lea $18EBC,a2
    move.w a3,-(a7)
      lea -$2(a1),a3
      jsr printBasicString
    movea.w (a7)+,a3
    
    addq.w #2,a1
    
    jmp $18BA6
  
  *************************************************************************
  * action battle menu
  *************************************************************************
  
  loadActionBattleMenuStrings:
*     * make up work
*     addq.b #1,$FFFFBE00
*     
*     * remap string
*     movem.l a1-a2,-(a7)
*       * look up value from string hash table
*       move.l a0,d0
*       lea string8x8MapAddr,a0
*       bsr findHashMapEntry
*     movem.l (a7)+,a1-a2
*     
*     
*     
*     jmp $21CDA

    * make up work
    addq.b #1,$FFFFBE00
    
    * write remap jump command
    move.b #smallStringJumpToRemap,(a2)+
    
    * write target string address from a3 to (a2)
    move.l a3,d1
    rol.l #8,d1
    move.b d1,(a2)+
    rol.l #8,d1
    move.b d1,(a2)+
    rol.l #8,d1
    move.b d1,(a2)+
    rol.l #8,d1
    move.b d1,(a2)+
    
    * skip src string
    adda.l #$C,a3
    
    * write next dstaddr
    move.l a2,d1
    add.l #$C-1-4,d1
    rol.l #8,d1
    move.b d1,(a2)+
    rol.l #8,d1
    move.b d1,(a2)+
    rol.l #8,d1
    move.b d1,(a2)+
    rol.l #8,d1
    move.b d1,(a2)+
    
    * skip remainder of 12-byte dst area
    adda.l #$C-1-4-4,a2
    
    jmp $21CE0
  
  loadActionBattleMenu_fixMagicAttack:
    * make up work
    lea $FFFFF216,a2
    movea.l a2,a0
    
    * write remap command
    move.b #smallStringCallRemap,(a2)+
    
    * write target address
    move.l a1,d1
    rol.l #8,d1
    move.b d1,(a2)+
    rol.l #8,d1
    move.b d1,(a2)+
    rol.l #8,d1
    move.b d1,(a2)+
    rol.l #8,d1
    move.b d1,(a2)+
    
    * seriously??
    move.b #smallStringBackspace,(a2)+
    
    * write magic level?
    addq.w #2,d0
    move.b d0,(a2)+
    
    * terminator
    move.b #$00,(a2)+
    
    jmp $21D78
  
  *************************************************************************
  * advisor messages
  *************************************************************************
  
scanOrPrintAdvisorString_noPrintId equ $00
scanOrPrintAdvisorString_printId   equ $FF
advisorMessageLineWidth equ 24
advisorMessageFirstLineStart equ 6
advisorMessageDstLineSize equ $80
advisorMessageDstMask equ $8000
advisorMessageOldLineCount equ $FFFFC802
advisorMessageStringStart equ $FFFFC804
advisorMessageWordBufStart equ $FFFFC804+128-24
* advisorMessageWordBufStart equ $FFFFC804+160-24
  
  ********************
  * concatenate to currently pending string
  *
  * a0 = src
  * a6 = dst
  * d7 = remaining chars in line?
  * FFC800 = count of lines?
  * FFC802 = line x?
  ********************
  doNewAdvisorStringConcat:
    * satisfy stuff that uses linebreak count to determine whether
    * material has been printed yet
    move.w #1,advisorMessageOldLineCount
    
    * we don't care about any of the old line splitting logic.
    * we just append the new material to the buffer.
    movem.l d0,-(a7)
      ********************
      * if src points to memory, we copy to the buffer
      ********************
      
      move.l a0,d0
      and.l #$00FF0000,d0
      cmp.l #$00FF0000,d0
      bne doNewAdvisorStringConcat_srcNotMem
        doNewAdvisorStringConcat_memCpy_loop:
          * fetch
          move.b (a0)+,d0
          
          * do not copy terminator
          beq doNewAdvisorStringConcat_memCpy_loop_done
          
          * copy to dst
          move.b d0,(a6)+
          bra doNewAdvisorStringConcat_memCpy_loop
        doNewAdvisorStringConcat_memCpy_loop_done:
        jmp doNewAdvisorStringConcat_done
      doNewAdvisorStringConcat_srcNotMem:
      
      ********************
      * otherwise, create a remap call command to save space in the dst buffer
      ********************
      
      * if high word of addr is 00, 01, or 02, we can use a short remap command
      
      move.l a0,d0
      
      swap d0
      tst.w d0
      bne doNewAdvisorStringConcat_srcHighWordNot0000
        move.b #smallStringCallRemap00,(a6)+
        bra doNewAdvisorStringConcat_cmdWrite_half
      doNewAdvisorStringConcat_srcHighWordNot0000:
      
      cmp.w #$0001,d0
      bne doNewAdvisorStringConcat_srcHighWordNot0001
        move.b #smallStringCallRemap01,(a6)+
        bra doNewAdvisorStringConcat_cmdWrite_half
      doNewAdvisorStringConcat_srcHighWordNot0001:
      
      cmp.w #$0002,d0
      bne doNewAdvisorStringConcat_srcHighWordNot0002
        move.b #smallStringCallRemap02,(a6)+
        bra doNewAdvisorStringConcat_cmdWrite_half
      doNewAdvisorStringConcat_srcHighWordNot0002:
      
      swap d0
      
      move.b #smallStringCallRemap,(a6)+
      
      rol.l #8,d0
      move.b d0,(a6)+
      rol.l #8,d0
      move.b d0,(a6)+
      doNewAdvisorStringConcat_cmdWrite_half:
      rol.l #8,d0
      move.b d0,(a6)+
      rol.l #8,d0
      move.b d0,(a6)+
      
      doNewAdvisorStringConcat_cmdWriteDone:
      
      * advance to end of src string as though we'd actually read it
      doNewAdvisorStringConcat_skip_loop:
        tst.b (a0)+
        bne doNewAdvisorStringConcat_skip_loop
    
    doNewAdvisorStringConcat_done:
    movem.l (a7)+,d0
    rts
  
  ********************
  * print pending string with word wrap.
  * or, if specified, do not actually print and instead just
  * evaluate the string and return the line count (single-spaced).
  ********************
  
  * a0 = src
  * a1 = dst (if printing)
  * d6 = if zero, scan -- do not print.
  *      if nonzero, print.
  *
  * return d0 = line count (0 = 1 line, etc.)
  
  scanOrPrintAdvisorString:
    * init dst baseaddr
    move.l a1,a2
    * init word startpos
    move.l a0,a3
    * init word buffer pos
    lea advisorMessageWordBufStart,a4
    * init line position (first line starts at 5, not 0)
    moveq #advisorMessageLineWidth-advisorMessageFirstLineStart,d3
    * init line count
    moveq #0,d4
    * init current word space count
    moveq #0,d5
    
    bsr scanOrPrintAdvisorString_sub
    
    * send any remaining content
    bsr sendCurrentAdvisorWord
    
    * return line count
    move.b d4,d0
    
    rts
  
  * a0 = src
  * a1 = dst (if printing)
  * a2 = baseaddr of current line
  * a3 = start pos for current word
  * a4 = word buffer pos
  * d3 = remaining chars on current line
  * d4 = count of current lines
  * d5 = number of pending spaces
  * d6 = if zero, scan -- do not print.
  *      if nonzero, print.
  *
  * return d0 = line count (0 = 1 line, etc.)
  
  scanOrPrintAdvisorString_sub:
    scanOrPrintAdvisorString_sub_fetchLoop:
      * fetch from src
      move.b (a0),d0
      
      * done if terminator (zero)
      beq scanOrPrintAdvisorString_sub_done
      
      cmp.b #spaceCharIndex,d0
      bne scanOrPrintAdvisorString_sub_notSpace
        * if space count nonzero, send next word
*         tst.b d5
*         bne scanOrPrintAdvisorString_sub_noWordSend
          bsr sendCurrentAdvisorWord
*         scanOrPrintAdvisorString_sub_noWordSend:
        
        * increment space count and go to next
        add.b #1,d5
        add.l #1,a0

        * reset word start addr.
        * this ensures that (wordend - wordstart) will be zero,
        * preventing erroneous sends.
*         move.l a0,a3
        
        bra scanOrPrintAdvisorString_sub_fetchLoop
      
      scanOrPrintAdvisorString_sub_notSpace:
        * check for remapped call command
        cmp.b #smallStringCallRemap,d0
        bne scanOrPrintAdvisorString_sub_notCallRemap
        scanOrPrintAdvisorString_sub_doCallRemap:
          * send current word if one exists
*           bsr sendCurrentAdvisorWord
          
          * skip past trigger op
          add.l #1,a0
          
          * fetch remap address
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          lsl.l #8,d0
          move.b (a0)+,d0
          
          scanOrPrintAdvisorString_sub_doCallRemap_end:
          
          * do the remap call
          * save next srcpos
          movem.l a0,-(a7)
            move.l d0,a0
            * a0 = remapped string src
            jsr lookupSmallStringHash
            
*             * reset word start pos
*             move.l a0,a3
            
            * handle the remapped string content
            jsr scanOrPrintAdvisorString_sub
          movem.l (a7)+,a0
          
*           * reset word start pos
*           move.l a0,a3
          
          * continue as normal
          bra scanOrPrintAdvisorString_sub_fetchLoop
        scanOrPrintAdvisorString_sub_notCallRemap:
        
        * short call remap 00
        cmp.b #smallStringCallRemap00,d0
        bne scanOrPrintAdvisorString_sub_notCallRemap00
          
          * fill in high word of address
          moveq #0,d0
          
          scanOrPrintAdvisorString_sub_notCallRemap00_sub:
          
          * skip past trigger op
          add.l #1,a0
          
          * fetch remap address
          move.b (a0)+,d0
          lsl.w #8,d0
          move.b (a0)+,d0
          
          * handle as normal
          bra scanOrPrintAdvisorString_sub_doCallRemap_end
        scanOrPrintAdvisorString_sub_notCallRemap00:
        
        * short call remap 01
        cmp.b #smallStringCallRemap01,d0
        bne scanOrPrintAdvisorString_sub_notCallRemap01
          * fill in high word of address
          moveq #1,d0
          swap d0
          bra scanOrPrintAdvisorString_sub_notCallRemap00_sub
        scanOrPrintAdvisorString_sub_notCallRemap01:
        
        * short call remap 02
        cmp.b #smallStringCallRemap02,d0
        bne scanOrPrintAdvisorString_sub_notCallRemap02
          * fill in high word of address
          moveq #2,d0
          swap d0
          bra scanOrPrintAdvisorString_sub_notCallRemap00_sub
        scanOrPrintAdvisorString_sub_notCallRemap02:
        
*         * if word size zero, set word startpos
* *         tst.b d5
* *         beq scanOrPrintAdvisorString_sub_notStartingWord
*         bsr getCurrentWordSize
*         tst.b d0
*         bne scanOrPrintAdvisorString_sub_notStartingWord
*           lea advisorMessageWordBufStart,a3
*         scanOrPrintAdvisorString_sub_notStartingWord:
        
        * skip char
        move.b (a0)+,(a4)+
*         add.l #1,a0
        bra scanOrPrintAdvisorString_sub_fetchLoop
      
    scanOrPrintAdvisorString_sub_done:
    * send current word (if any)
*     bsr sendCurrentAdvisorWord
    * move past terminator
    add.l #1,a0
    rts
  
  getCurrentWordSize:
*     move.l a0,d0
*     move.l a3,d1
*     sub.l d1,d0
    move.l a4,d0
*     move.l #advisorMessageWordBufStart,d1
    sub.l #advisorMessageWordBufStart,d0
    rts
    
  sendCurrentAdvisorWord:
    * d1 = size of current word
    bsr getCurrentWordSize
    move.b d0,d1
    * do nothing if size is zero
    beq sendCurrentAdvisorWord_done
    
      * d2 = word size + space count
      move.b d1,d2
      add.b d5,d2
      
      * if word size + space count <= remaining line chars,
      * we can fit the content on the current line
      cmp.b d2,d3
      bcc sendCurrentAdvisorWord_fullContentFits
*         * HACK: if sending exactly one character,
*         * and it is a quotation mark or comma,
*         * allow it to print into the margin of the box.
*         cmp.b #1,d2
*         bne sendCurrentAdvisorWord_needLinebreak
*           move.b -(a0),d0
*           addq.l #1,a0
*           cmp.b #quoteCharIndex,d0
*           beq sendCurrentAdvisorWord_fullContentFits
*           cmp.b #commaCharIndex,d0
*           beq sendCurrentAdvisorWord_fullContentFits
*         sendCurrentAdvisorWord_needLinebreak:
        
        * reset space count
        moveq #0,d5
        
        * break line
        bsr breakAdvisorLine
      sendCurrentAdvisorWord_fullContentFits:
      
      * subtract space size from line pos
      sub.b d5,d3
      * subtract word size from line pos
      sub.b d1,d3
      
      * don't send content if not actually printing
      tst.b d6
      beq sendCurrentAdvisorWord_notPrinting
        * add spaces (if any)
*         tst.b d5
*         beq sendCurrentAdvisorWord_noSpacePrint
          and.l #$000000FF,d5
          lsl.l #1,d5
          adda.l d5,a1
*         sendCurrentAdvisorWord_noSpacePrint:
        
        * copy chars from src to dst
        sub.b #1,d1
        and.w #$00FF,d1
        lea advisorMessageWordBufStart,a4
        sendCurrentAdvisorWord_printLoop:
          moveq #0,d0
          * fetch from word start
          move.b (a4)+,d0
          * OR with dstmask
          or.w #advisorMessageDstMask,d0
          
          * send to dst (which may not be word-aligned)
*           ror.l #8,d0
*           move.b d0,(a1)+
*           rol.l #8,d0
*           move.b d0,(a1)+
          move.w d0,(a1)+
          
          dbf d1,sendCurrentAdvisorWord_printLoop
      sendCurrentAdvisorWord_notPrinting:
      
      * reset wordbuf pos
      lea advisorMessageWordBufStart,a4
      * reset space count
      moveq #0,d5
      
      * in case we printed into the margin, linebreak if needed
*       tst.b d3
*       bpl sendCurrentAdvisorWord_noFinalReset
*         bsr breakAdvisorLine
*         * HACK: space count should be zero after this.
*         * we know a space triggered it, and will increment the
*         * value we return by one, so we return -1 instead of 0.
*         moveq #-1,d5
*       sendCurrentAdvisorWord_noFinalReset:
    sendCurrentAdvisorWord_done:
    rts
  
  breakAdvisorLine:
    * if linecount == 0, offset dst to account for differing position
    * of first line compared to rest
    * (now checking for linecount of 0 due to shifting text up a line)
*     tst.b d4
    cmp.b #1,d4
    bne breakAdvisorLine_notFirstLinebreak
      adda.w #-10,a2
    breakAdvisorLine_notFirstLinebreak:
    
    * ++linecount
    add.b #1,d4
    * reset line pos
    moveq #advisorMessageLineWidth,d3
    * update line base dstaddr
    adda.l #advisorMessageDstLineSize,a2
    move.l a2,a1
    
    * if linecount == 1 after add, use reduced line width (space is taken up by
    * character portrait)
    cmp.b #1,d4
    bne breakAdvisorLine_notFirstLinebreak2
      moveq #advisorMessageLineWidth-advisorMessageFirstLineStart,d3
    breakAdvisorLine_notFirstLinebreak2:
    
    rts
  
  ********************
  * print pending advisor string
  ********************
  
  printAdvisorString:
  * reset old line count for stuff that cares about it
  clr.w advisorMessageOldLineCount
  
  * a0 = ? window struct info pointer?
  * a6 = current string dstpos
  * d2 = ? window settings?
    * add ending quotation mark
    move.b #quoteCharIndex,(a6)+
    * add terminator
    move.b #$00,(a6)+
    
    * scan string to determine line count
    movem.l a0/a1/a2/a3/a4/a6/d1-d6,-(a7)
      * src
      lea $FFFFC804,a0
      * settings
      move.b #scanOrPrintAdvisorString_noPrintId,d6
      
      bsr scanOrPrintAdvisorString
    movem.l (a7)+,a0/a1/a2/a3/a4/a6/d1-d6
    
    * now, d0 = line count (0 = 1 line, etc.)
    move.b d0,d1
    and.w #$00FF,d1
*     add.w #1,d1
    * halve (to account for double-spacing)
    lsr.w #1,d1
    * result cannot exceed 5
    cmp.w #6,d1
    bcs printAdvisorString_windowSizeValid
      move.w #5,d1
    printAdvisorString_windowSizeValid:
    
    move.l a0,-(a7)
      * open the window
      movea.w $FFFFF0A0,a6
      moveq #0,d7
      lea $FFFFF206,a4
      movea.l a4,a1
      move.l d2,(a1)+
      move.l #$60003,d0
      * add line count
      add.w d1,d0
      move.l d0,(a1)+
      jsr $6108
    
      * ?
      movea.l (a7),a4
      * a1 = dst?
      movea.w (a4)+,a1
      
      * move up a line to get more space
      adda.w #-$80,a1
      
      * print for real this time
      lea $FFFFC804,a0
      movem.l a0/a1/a2/a3/a4/a6/d1-d6,-(a7)
        * settings
        move.b #scanOrPrintAdvisorString_printId,d6
        
        bsr scanOrPrintAdvisorString
      movem.l (a7)+,a0/a1/a2/a3/a4/a6/d1-d6
    
      * continue with normal logic
      jmp $30CA
  
  *************************************************************************
  * advisor message fixes
  *************************************************************************
  
  * a2 = unit ID array pointer.
  *      terminated with negative entry (FF?)
  * a6 = dst (string)
  
  genCommaSeparatedUnitList:
*     * make up work
*     * a0 = string addr
*     adda.w (a0),a0
*     
*     move.l a0,-(a7)
*       * if final item, need "and" before name
*       tst.b (a2)
*       bpl genCommaSeparatedUnitList_isNotLastItemPre
*         * "AND "
*         move.l #$80,a0
*         jsr concatToPendingAdvisorString
*       genCommaSeparatedUnitList_isNotLastItemPre:
*     move.l (a7)+,a0
*     
*     * offset to get plural form
*     addq.w #2,a0
*     jsr concatToPendingAdvisorString
*     
*     * check if this is the last item
*     tst.b (a2)
*     bmi genCommaSeparatedUnitList_isLastItem
*       * comma
*       move.b #commaCharIndex,d0
*       jsr addCharToPendingAdvisorString
*     genCommaSeparatedUnitList_isLastItem:
*     * space
*     move.b #spaceCharIndex,d0
*     jsr addCharToPendingAdvisorString
*     
*     jmp $2F9C
    
    * the original logic is to always put a comma at the start of the list.
    * we don't want that.
    * we also have to account for the English idiosyncracy of putting "and"
    * between the final two items in a list of multiple items.
    
    move.l d6,-(a7)
    
      * get count of items in d6
      moveq #-1,d6
      move.l a2,-(a7)
      genCommaSeparatedUnitList_countLoop:
        addq.w #1,d6
        tst.b (a2)+
        bpl genCommaSeparatedUnitList_countLoop
      move.l (a7)+,a2
      
      * should never happen
      tst.w d6
      beq genCommaSeparatedUnitList_done
      
      * if one unit, just write its name alone
      cmp.w #1,d6
      bne genCommaSeparatedUnitList_multipleUnits
        moveq #0,d0
        move.b (a2)+,d0
        bsr sendUnitNameFromListToString
        bra genCommaSeparatedUnitList_done
      genCommaSeparatedUnitList_multipleUnits:
      
      * if multiple units, write a proper list
      bra genCommaSeparatedUnitList_writeLoop_end
      
      genCommaSeparatedUnitList_writeLoop:
        
        ****************
        * if final item, need "and" before name
        ****************
        
        move.l a0,-(a7)
          tst.b (a2)
          bpl genCommaSeparatedUnitList_isNotLastItemPre
            * if two items, need space before
            cmp.w #2,d6
            bne genCommaSeparatedUnitList_notTwoItemsPre
              move.l d0,-(a7)
                move.b #spaceCharIndex,d0
                jsr addCharToPendingAdvisorString
              move.l (a7)+,d0
            genCommaSeparatedUnitList_notTwoItemsPre:
            
            * "AND "
            move.l #$80,a0
            jsr concatToPendingAdvisorString
          genCommaSeparatedUnitList_isNotLastItemPre:
        move.l (a7)+,a0
        
        ****************
        * send name
        ****************
        
        bsr sendUnitNameFromListToString
        
        ****************
        * add comma if needed
        ****************
        
        * check if this is the last item
        tst.b (a2)
        bmi genCommaSeparatedUnitList_isLastItem
          * no comma if two items
          cmp.w #2,d6
          beq genCommaSeparatedUnitList_isLastItem
            * comma
            move.b #commaCharIndex,d0
            jsr addCharToPendingAdvisorString
            * space
            move.b #spaceCharIndex,d0
            jsr addCharToPendingAdvisorString
        genCommaSeparatedUnitList_isLastItem:
        
        ****************
        * loop
        ****************
        
        genCommaSeparatedUnitList_writeLoop_end:
        * continue while list not terminated
        move.b (a2)+,d0
        bpl genCommaSeparatedUnitList_writeLoop
      
      addq.l #1,a2
      
    genCommaSeparatedUnitList_done:
    move.l (a7)+,d6
    rts
  
  * d0 = ID
  sendUnitNameFromListToString:
    lea $2D042,a0
    adda.w d0,a0
    adda.w d0,a0
    adda.w (a0),a0
    
    * get plural form
    addq.w #2,a0
    
    jmp concatToPendingAdvisorString
  
  *************************************************************************
  * advisor message fixes (specific)
  *************************************************************************
  
  musterAdviceReverseSVO:
    * "you can hire"
    lea $1693D,a0
    jsr concatToPendingAdvisorString
    
    * unit names
    jsr concatUnitNameListToPendingAdvisorString
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    jmp $1641E
  
  summonAdviceReverseSVO:
    * "you can call"
    lea $16968,a0
    jsr concatToPendingAdvisorString
    
    * unit names
    jsr concatUnitNameListToPendingAdvisorString
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    jmp $162DC
  
  ******************
  * hiring recs
  ******************
  
  doNewAdvisorHireWithUnitRec:
    move.l a0,-(a7)
      * "i'd use"
      lea $81,a0
      jsr concatToPendingAdvisorString
    move.l (a7)+,a0
      
    * make up work
    move.w d3,$FFFFF23E
    
    * source unit name print (OR forible break from this routine if none)
    jsr $2FA6
    
    *******************
    * *** CODE BELOW HERE IS NOT GUARANTEED TO EXECUTE ***
    *******************
    
    * "to call/hire"
    move.l a1,a0
    jsr concatToPendingAdvisorString
    
    * list of squadrons to hire
    lea $FFFFF236,a2
    jsr $2F84
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    * use this to check if execution was broken or not
    lea $0,a0
    
    rts
  
  doNewAdvisorHireWithoutUnitRec:
    * change target message to no-src version
    adda.w #1,a1
    
    * print message
    movea.l a1,a0
    jsr concatToPendingAdvisorString
    
    * list of target units
    lea $FFFFF236,a2
    jsr concatUnitNameListToPendingAdvisorString
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    * use this to check if execution was broken or not
    lea $0,a0
    
    rts
  
  newMusteringRecsStart:
    move.l a1,-(a7)
      * "to hire"
      lea $1694E,a1
      jsr $1647A
    move.l (a7)+,a1
    
    * branch if previous call was forcibly broken
    cmp.l #0,a0
    bne musteringSummoningRecsAltEnd
    
    jmp $167C0
  
  newSummoningRecsStart:
    move.l a1,-(a7)
      * "to call"
      lea $16971,a1
      jsr $1647A
    move.l (a7)+,a1
    
    * branch if previous call was forcibly broken
    cmp.l #0,a0
    bne musteringSummoningRecsAltEnd
    
    jmp $167C0
  
  * FIXME: does this do whatever it's supposed to???
  musteringSummoningRecsAltEnd:
*     lea $16934,a0
*     jmp $167BC
    jmp $167C0
  
  *************************************************************************
  * print list of selected units from an area
  *************************************************************************
  
  * when force-breaking caller due to no units, clear the existing
  * message content first
  doSrcSquadNotNecessaryMessage:
    * reset stringpos to start of buffer (+1 due to quote)
    lea advisorMessageStringStart+1,a6
    
    * make up work
    addq.w #4,a7
    jsr $302E
    jmp $3062
  
  doFullNewSquadSrcNamePrint:
    * save a3, which we are abusing as a counter for number of units to
    * print due to all D registers being occupied.
    * a4 is abused as a count of total entries.
    movem.l a3-a4,-(a7)
      movem.l a0-a2/a4-a6/d0-d6,-(a7)
        bsr countSquadSrcNamePrintableEntries
      movem.l (a7)+,a0-a2/a4-a6/d0-d6
      
      * now, a3 = count of printable entries
      * save this total to a4
      move.l a3,a4
      
      * do the actual printing
      
      moveq #-1,d3
      doFullNewSquadSrcNamePrint_loop:
        lsr.w #1,d5
        bcc doFullNewSquadSrcNamePrint_skip
          move.b (a2),d0
          cmp.b d3,d0
          beq doFullNewSquadSrcNamePrint_noCheck
            bsr doNewSquadSrcNamePrint
            moveq #-1,d4
          doFullNewSquadSrcNamePrint_noCheck:
          addq.w #1,d4
        doFullNewSquadSrcNamePrint_skip:
        addq.w #8,a2
        dbf d6,doFullNewSquadSrcNamePrint_loop
      
      * final run
      bsr doNewSquadSrcNamePrint
    
    movem.l (a7)+,a3-a4
    rts
  
  * return a3 = count of entries that will be printed
  countSquadSrcNamePrintableEntries:
    moveq #-1,d3
    lea $0,a3
    countSquadSrcNamePrintableEntries_loop:
      lsr.w #1,d5
      bcc countSquadSrcNamePrintableEntries_skip
        move.b (a2),d0
        cmp.b d3,d0
        beq countSquadSrcNamePrintableEntries_noCheck
          
          bsr countSquadSrcNamePrintableEntries_checkPrintable
          
          moveq #-1,d4
        countSquadSrcNamePrintableEntries_noCheck:
        addq.w #1,d4
      countSquadSrcNamePrintableEntries_skip:
      addq.w #8,a2
      dbf d6,countSquadSrcNamePrintableEntries_loop
    
    * final run
    bsr countSquadSrcNamePrintableEntries_checkPrintable
    
    rts
  
  countSquadSrcNamePrintableEntries_checkPrintable:
    * check if printable
    move.b d3,d1
    move.b d0,d3
    ext.w d1
    bmi countSquadSrcNamePrintableEntries_checkPrintable_noPrint
      * success
      adda.w #1,a3
    countSquadSrcNamePrintableEntries_checkPrintable_noPrint:
    rts
    
  * d4 = squad quantity, or zero if none
  doNewSquadSrcNamePrint:
    * make up work
    * d1 = squad unit ID
    move.b d3,d1
    * d3 = ??
    move.b d0,d3
    ext.w d1
    bmi doNewSquadSrcNamePrint_done
      * decrement remaining entries count
      suba.w #1,a3
      
      * look up squad name
      move.l d1,-(a7)
        add.w d1,d1
        lea $2D042,a0
        adda.w d1,a0
        adda.w (a0),a0
      move.l (a7)+,d1
      
      * if squad has no ID, assume it's plural
*       tst.w d4
*       bne doNewSquadSrcNamePrint_idNotZero
*         adda.w #2,a0
*         bra doNewSquadSrcNamePrint_finish
*       doNewSquadSrcNamePrint_idNotZero:
      * assume singular
      adda.w #1,a0
      
      * if squad has no quantity, append "one" before the name,
      * unless it is a ruler (ID < 9)
      tst.b d4
      bne doNewSquadSrcNamePrint_idNotZero
*        cmp.b #9,d3
        cmp.b #9,d1
        bcs doNewSquadSrcNamePrint_idNotZero
          move.l a0,-(a7)
            * "one "
            lea $88,a0
            jsr concatToPendingAdvisorString
          move.l (a7)+,a0
      doNewSquadSrcNamePrint_idNotZero:
      
*       doNewSquadSrcNamePrint_finish:
      
      move.l a0,-(a7)
        * if quantity exists, add space before number
        tst.w d4
        beq doNewSquadSrcNamePrint_idZero
  *         move.b #spaceCharIndex,d0
  *         jsr addCharToPendingAdvisorString
          
          * append quantity
          move.w d4,d0
          cmp.b #$A,d0
          bcs doNewSquadSrcNamePrint_noFirstIdDigit
            moveq #2,d0
            jsr addCharToPendingAdvisorString
            move.w d4,d0
            sub.w #$A,d0
          doNewSquadSrcNamePrint_noFirstIdDigit:
          addq.w #2,d0
          jsr addCharToPendingAdvisorString
          
          move.b #spaceCharIndex,d0
          jsr addCharToPendingAdvisorString
          
          * "of the "
          lea $87,a0
          jsr concatToPendingAdvisorString
        doNewSquadSrcNamePrint_idZero:
      move.l (a7)+,a0
      
      * print name
      jsr concatToPendingAdvisorString
          
      tst.w d4
      beq doNewSquadSrcNamePrint_idZero2
        * space
        move.b #spaceCharIndex,d0
        jsr addCharToPendingAdvisorString
        
        * append "squadrons" text
        lea $37E5,a0
        jsr concatToPendingAdvisorString
      doNewSquadSrcNamePrint_idZero2:
      
      * append comma if not last entry, and if total entries != 2
      cmpa.w #0,a3
      beq doNewSquadSrcNamePrint_isLast
        cmpa.w #2,a4
        beq doNewSquadSrcNamePrint_isLast
          * comma
          move.b #commaCharIndex,d0
          jsr addCharToPendingAdvisorString
          
          * space
          move.b #spaceCharIndex,d0
          jsr addCharToPendingAdvisorString
      doNewSquadSrcNamePrint_isLast:
    
      * append "AND " if second-to-last entry
      cmpa.w #1,a3
      bne doNewSquadSrcNamePrint_notSecondToLast
        * add space if total entries == 2 (no comma + space preceding)
        cmpa.w #2,a4
        bne doNewSquadSrcNamePrint_noAndSpace
          move.b #spaceCharIndex,d0
          jsr addCharToPendingAdvisorString
        doNewSquadSrcNamePrint_noAndSpace:
        
        lea $80,a0
        jsr concatToPendingAdvisorString
      doNewSquadSrcNamePrint_notSecondToLast:
    
    doNewSquadSrcNamePrint_done:
    
*     * HACK: if return addr is not $2FEA, this is the final run
*     * of the subroutine, and the final "and" we added must be erased
*     cmp.l #$00002FEA,(a7)
*     beq doNewSquadSrcNamePrint_noAndErase
* *       * skip space after "and"
* *       subq.w #1,a6
* *       doNewSquadSrcNamePrint_andEraseLoop:
* *         * search for last space before "and"
* *         cmp.b #spaceCharIndex,-(a6)
* *         bne doNewSquadSrcNamePrint_andEraseLoop
*       bsr eraseLastAdvisorWord
*     doNewSquadSrcNamePrint_noAndErase:
    
    rts
  
  * a6 = src (starting from pointer past the space after target word
  eraseLastAdvisorWord:
    * skip space after "and"
    subq.w #1,a6
    eraseLastAdvisorWord_eraseLoop:
      * search for last space before "and"
      cmp.b #spaceCharIndex,-(a6)
      bne eraseLastAdvisorWord_eraseLoop
    rts
  
  *************************************************************************
  * advisor invasion messages
  *************************************************************************
  
  doAdvisorInvasionEncourage:
    * "let's invade"
    lea $16934,a0
    jsr concatToPendingAdvisorString
    
    * place name
    move.w d6,d0
    jsr $2F46
    
    * " with "
    lea $82,a0
    jsr concatToPendingAdvisorString
    
    * unit list, or "all squadrons", or break call and display error instead
    lea $16824,a0
    swap d6
    jsr $2FA6
    swap d6
    
    * exclamation mark
    move.b #bangCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    jmp $167C0
  
  fixAreaNameParen:
    * space
    move.b #spaceCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    * make up work
    moveq #$2D,d0
    jsr $304C
    jmp $2F66
  
  *************************************************************************
  * 
  *************************************************************************
  
*   scoutPlaceListAndFix:
*     
*     jmp $1665E
    
  scoutPlaceListFinalFix:
    scoutPlaceListFinalFix_loop:
      moveq #0,d0
      move.b (a4)+,d0
      jsr $2F46
      
      * space
      move.b #spaceCharIndex,d0
      jsr addCharToPendingAdvisorString
      
      * "and "
      lea $80,a0
      jsr concatToPendingAdvisorString
      
      dbf d4,scoutPlaceListFinalFix_loop
    
    * erase final "and"
    bsr eraseLastAdvisorWord
    
    * make up work
    jmp $16666
  
  *************************************************************************
  * advisors diplomacy
  *************************************************************************
  
  ****************
  * advising invasion 1
  ****************
    
  fixRulerNameDiplomacy1:
    * "let's invade "
    lea $FCFB,a0
    jsr concatToPendingAdvisorString
    
    * ruler name
    lsl.w #7,d2
    lea $FFFF943A,a0
    movea.l (a0,d2.w),a0
    * change to normal font
    adda.l #1,a0
    jsr concatToPendingAdvisorString
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    jmp $F6C2
  
  ****************
  * advising invasion 2
  ****************
  
  * probably list of rulers in an alliance, etc.
  fixRulerNameDiplomacy_rulerLast:
    * skip message if ruler list empty
    subq.w #1,d5
    bcc fixRulerNameDiplomacy_rulerLast_noSkip
      rts
    fixRulerNameDiplomacy_rulerLast_noSkip:
    
    * conjunction message
    bsr fixRulerNameDiplomacy_rulerLast_doConjunctionMessage
    
    * main message
    movea.l a4,a0
    jsr concatToPendingAdvisorString
    
    bsr fixRulerNameDiplomacy_rulerLast_printNames
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    rts
  
  fixRulerNameDiplomacy_rulerLast_doConjunctionMessage:
    lea $FFFF943A,a2
    tst.w $FFFFC802
    beq fixRulerNameDiplomacy_rulerLast_noConjunctionMessage
      * space
      move.b #spaceCharIndex,d0
      jsr addCharToPendingAdvisorString
      
      movea.l a3,a0
      jsr concatToPendingAdvisorString
    fixRulerNameDiplomacy_rulerLast_noConjunctionMessage:
    
    rts
  
  fixRulerNameDiplomacy_rulerLast_printNames:
    * if one name, print only that
    tst.w d5
    bne fixRulerNameDiplomacy_rulerLast_printNames_not0
      bra fixRulerNameDiplomacy_printNextRulerName
    fixRulerNameDiplomacy_rulerLast_printNames_not0:
    
    * if two names, print those separated by "and"
    cmp.w #1,d5
    bne fixRulerNameDiplomacy_rulerLast_printNames_not1
      bsr fixRulerNameDiplomacy_printNextRulerName
      
      * space
      move.b #spaceCharIndex,d0
      jsr addCharToPendingAdvisorString
      
      * "and "
      lea $80,a0
      jsr concatToPendingAdvisorString
      
      bra fixRulerNameDiplomacy_printNextRulerName
    fixRulerNameDiplomacy_rulerLast_printNames_not1:
    
    * otherwise, print list
    fixRulerNameDiplomacy_rulerLast_loop:
      bsr fixRulerNameDiplomacy_printNextRulerName
      
      * if not last entry, print ", "
      tst.w d5
      beq fixRulerNameDiplomacy_rulerLast_loop_is0
        * comma
        move.b #commaCharIndex,d0
        jsr addCharToPendingAdvisorString
        
        * space
        move.b #spaceCharIndex,d0
        jsr addCharToPendingAdvisorString
      fixRulerNameDiplomacy_rulerLast_loop_is0:
      
      * if next-to-last entry, print "and "
      cmp.w #1,d5
      bne fixRulerNameDiplomacy_rulerLast_loop_not1
        lea $80,a0
        jsr concatToPendingAdvisorString
      fixRulerNameDiplomacy_rulerLast_loop_not1:
      
      dbf d5,fixRulerNameDiplomacy_rulerLast_loop
    
    rts
  
  fixRulerNameDiplomacy_printNextRulerName:
    * ruler name
    move.w -(a1),d0
    lsl.w #7,d0
    movea.l (a2,d0.w),a0
    * convert to normal font
    adda.l #1,a0
    jmp concatToPendingAdvisorString
  
  ****************
  * advising invasion 3
  ****************
  
  * exactly same as before but put the string after the ruler(s)
  fixRulerNameDiplomacy_rulerFirst:
    * skip message if ruler list empty
    subq.w #1,d5
    bcc fixRulerNameDiplomacy_rulerFirst_noSkip
      rts
    fixRulerNameDiplomacy_rulerFirst_noSkip:
    
    * conjunction message
    bsr fixRulerNameDiplomacy_rulerLast_doConjunctionMessage
    
    * ruler list
    bsr fixRulerNameDiplomacy_rulerLast_printNames
    
    * main message
    movea.l a4,a0
    jsr concatToPendingAdvisorString
    
    * period
*     move.b #periodCharIndex,d0
*     jsr addCharToPendingAdvisorString
    
    rts
  
  newAllianceTimeAdvice:
    * make up work
    lea $FD19,a4
    jsr fixRulerNameDiplomacy_rulerLast
    
*     * period
*     move.b #periodCharIndex,d0
*     jsr addCharToPendingAdvisorString
    
    jmp $F71C
  
  newCooperationAdvice:
*     * make up work
*     subq.w #1,d5
*     bcc newCooperationAdvice_notEmpty
*       rts
*     newCooperationAdvice_notEmpty:
    
    * "first, let's cooperate with ..."
    move.w d5,-(a7)
      lea $FCF1,a4
      jsr fixRulerNameDiplomacy_rulerLast
    move.w (a7)+,d5
    
    * skip extra content if empty message
    subq.w #1,d5
    bcs newCooperationAdvice_notEmpty
      * erase period
      subq.l #1,a6
      
*       * comma
*       move.b #commaCharIndex,d0
*       jsr addCharToPendingAdvisorString
*         
*       * space
*       move.b #spaceCharIndex,d0
*       jsr addCharToPendingAdvisorString
*       
*       * "and "
*       lea $80,a0
*       jsr concatToPendingAdvisorString
      
      * " to "
      lea $86,a0
      jsr concatToPendingAdvisorString
      
      bra newCooperationAdvice_done
    newCooperationAdvice_notEmpty:
      * space
*       move.b #spaceCharIndex,d0
*       jsr addCharToPendingAdvisorString
    newCooperationAdvice_done:
    
    jmp $F69E
  
  *************************************************************************
  * advisors summon
  *************************************************************************
  
  ****************
  * move squads instead
  ****************
  
  summonAdviceMoveSquadInsteadNew:
    * "i wouldn't do that,"
    lea $169A4,a0
    jsr concatToPendingAdvisorString
    
    tst.b d5
    beq summonAdviceMoveSquadInsteadNew_noSquadList
      * "but would move the "
      lea $1699A,a0
      jsr concatToPendingAdvisorString
      
      * list of units
      lsl.w #8,d5
      move.b #$FF,d5
      lea $FFFFF236,a2
      move.w d5,(a2)
      jsr $2F84
      
      * " from "
*       lea $83,a0
*       jsr concatToPendingAdvisorString
      * " to "
      lea $86,a0
      jsr concatToPendingAdvisorString
      
      * name of destination
      move.w d6,d0
      jsr concatPlaceNameToPendingAdvisorString
      
      * period
      move.b #periodCharIndex,d0
      jsr addCharToPendingAdvisorString
      
      jmp summonAdviceMoveSquadInsteadNew_done
    summonAdviceMoveSquadInsteadNew_noSquadList:
    
    * "but would dispatch squadrons to "
    lea $1698D,a0
    jsr concatToPendingAdvisorString
    
    * name of destination
    move.w d6,d0
    jsr concatPlaceNameToPendingAdvisorString
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    summonAdviceMoveSquadInsteadNew_done:
    
    jmp $167C0
  
  ****************
  * summon elsewhere
  ****************
  
  summonAdviceSummonElsewhereInsteadNew:
    * "i wouldn't do that,"
    lea $169A4,a0
    jsr concatToPendingAdvisorString
    
    * "but would summon at"
    lea $16982,a0
    jsr concatToPendingAdvisorString
    
    * name of destination
    move.w d6,d0
    jsr concatPlaceNameToPendingAdvisorString
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    jmp $167C0
  
  *************************************************************************
  * advisors heroes
  *************************************************************************
  
  ****************
  * appointments
  ****************
  
  heroesAdviceAppointmentListNew:
    * "why not appoint"
    lea $168A7,a0
    jsr concatToPendingAdvisorString
    
    * if only one hero, no need for list
    tst.w d6
    bne heroesAdviceAppointmentListNew_multipleHeroes
      bsr heroesAdviceAppointmentList_doNextEntry
      bra heroesAdviceAppointmentListNew_done
    heroesAdviceAppointmentListNew_multipleHeroes:
    
    heroesAdviceAppointmentListNew_loop:
      bsr heroesAdviceAppointmentList_doNextEntry
      
      * add comma if not last entry
      tst.w d6
      beq heroesAdviceAppointmentListNew_loop_isLast
        * comma
        move.b #commaCharIndex,d0
        jsr addCharToPendingAdvisorString
        
        * space
        move.b #spaceCharIndex,d0
        jsr addCharToPendingAdvisorString
        
*         bra heroesAdviceAppointmentListNew_loop_end
      heroesAdviceAppointmentListNew_loop_isLast:
      
      * if second-to-last, add "and"
      cmp.w #1,d6
      bne heroesAdviceAppointmentListNew_loop_isNotNextToLast
*         * space
*         move.b #spaceCharIndex,d0
*         jsr addCharToPendingAdvisorString
        
        * "and "
        lea $80,a0
        jsr concatToPendingAdvisorString
        
*        bra heroesAdviceAppointmentListNew_loop_end
      heroesAdviceAppointmentListNew_loop_isNotNextToLast:
      
      heroesAdviceAppointmentListNew_loop_end:
      
      dbf d6,heroesAdviceAppointmentListNew_loop
      
    heroesAdviceAppointmentListNew_done:
    
    * question mark
    move.b #questionMarkCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    jmp $1671A
  
  heroesAdviceAppointmentList_doNextEntry:
    * hero name
    move.w (a5)+,d0
    jsr $1673E
    
    * check pending place name ID.
    * it may be FF, signalling no specified place.
    * the original game does not correctly check for this condition,
    * and will sometimes print garbage strings as a result!
    move.w (a5),d0
    tst.b d0
    bmi heroesAdviceAppointmentList_doNextEntry_noLoc
      * " to "
      lea $168A4,a0
      jsr concatToPendingAdvisorString
      
      * place name
      move.w (a5)+,d0
      jsr concatPlaceNameToPendingAdvisorString
      
      bra heroesAdviceAppointmentList_done
    heroesAdviceAppointmentList_doNextEntry_noLoc:
      adda.l #2,a5
    heroesAdviceAppointmentList_done:
    rts
  
  ****************
  * discharge
  ****************
  
  heroesAdviceDischargeNew1:
    * space
    move.b #spaceCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    * "then,"
    lea $16834,a0
    jsr concatToPendingAdvisorString
    
    jmp $16730
  
  heroesAdviceDischargeNew2:
    move.l d0,-(a7)
      * "discharge"
      lea $168B1,a0
      jsr concatToPendingAdvisorString
    move.l (a7)+,d0
    
    * hero name
    jsr $1673E
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    jmp $167C0
  
  *************************************************************************
  * advisors stratagem diplomacy
  *************************************************************************
  
  stratagemDiplomacyAdvice1:
    * print message first
    move.l a2,a0
    jsr concatToPendingAdvisorString
    
    * print target ruler
    lea $FFFF943A,a0
    lsl.w #7,d0
    movea.l (a0,d0.w),a0
    * convert to regular font
    adda.w #1,a0
    jsr concatToPendingAdvisorString
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    rts
  
  stratagemDiplomacyAdvice2:
    move.l d0,-(a7)
      * space
      move.b #spaceCharIndex,d0
      jsr addCharToPendingAdvisorString
      
      * "then,"
      lea $FD2B,a0
      jsr concatToPendingAdvisorString
    move.l (a7)+,d0
    rts
  
  stratagemDiplomacyAdvice3:
    * print message first
    move.l a2,a0
    jsr concatToPendingAdvisorString
    
    * print place name
    jsr concatPlaceNameToPendingAdvisorString
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    rts
  
  * A2 = target message pointer
  summonSchemeThisAreaAdviceNew:
    * print message first
    move.l a2,a0
    jsr concatToPendingAdvisorString
    
    * "this area"
    lea $16A39,a0
    jsr concatToPendingAdvisorString
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    rts
  
  *************************************************************************
  * advisors rest
  *************************************************************************
    
  restAdvice1:
    * "let's rest"
    lea $16846,a0
    jsr concatToPendingAdvisorString
    
    * unit list or break call
    lea $16824,a0
    jsr concatSrcUnitNameListToPendingAdvisorString
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    jmp $167C0
  
  *************************************************************************
  * advisors move
  *************************************************************************
  
  moveAdvice1:
    * "head to"
    lea $1690B,a0
    jsr concatToPendingAdvisorString
    
    * destination
    move.w d6,d0
    jsr concatPlaceNameToPendingAdvisorString
    
    * period
    move.b #periodCharIndex,d0
    jsr addCharToPendingAdvisorString
    
    jmp $167C0
  
  *************************************************************************
  * one-line hero name lookup
  *************************************************************************
  
  lookUpOneLineHeroName:
    * make up work
    lea $3E060,a0
    lsl.w #4,d0
    adda.w d0,a0
    * convert to one-line
    adda.l #1,a0
    jmp concatToPendingAdvisorString
  
  *************************************************************************
  * new title logo
  *************************************************************************
  
  * intro
  loadNewTitleLogoGrpSub1:
    * make up work
    move.l #$50000001,d0
    lea $9324,a0
    jsr $89C
    
    * load graphics
    jmp loadNewTitleLogoGrp
  
  * if intro skipped
  loadNewTitleLogoGrpSub2:
    * make up work
    lea $2D98A,a5
    jsr $8550
    
    * load graphics
    jmp loadNewTitleLogoGrp
  
  * map
  loadNewTitleLogoMapSub1:
    * make up work
    lea $86D6,a3
    jsr $8586
    jsr $8574
    
    * load map
    jmp loadNewTitleLogoMap
  
  loadNewTitleLogoMapSub2:
    * make up work
    lea $8732,a3
    jsr $8586
    
    * load map
    jmp loadNewTitleLogoMap
  
  *************************************************************************
  * corectly position sieg's name on character select
  *************************************************************************
  
  charSelNameCheckForSieg:
    * check if sieg's name (string address == 0x27000)
    cmpa.l #$27000,a0
    bne charSelNameCheckForSieg_notSieg
      * move dst 1 tile left
      subq.w #2,a1
    charSelNameCheckForSieg_notSieg:
    jmp $AB72
  
  *************************************************************************
  * 
  *************************************************************************
  
  fixEmptyPlaceNameDetection:
    * make up work
    move.w d0,d1
    bmi fixEmptyPlaceNameDetection_skip
    * extra check: make sure byte is not negative either.
    * this can happen (and the original game did not check for it, resulting
    * in display errors)
    tst.b d0
    bmi fixEmptyPlaceNameDetection_skip
      * make up work
      lsl.w #7,d1
      jmp $2F4C
    fixEmptyPlaceNameDetection_skip:
    rts
  
  *************************************************************************
  * true ending
  *************************************************************************
  
  trueEndLoadFont:
    * make up work
    lea $7D568,a0
    jsr $89C
    
    jsr loadNewSmallFontLowerCase
    
    jmp $C1F4
  
  trueEndDoubleLineGen:
    * make up work
    move.w d3,(a3)+
    movea.l a3,a1
    
    * set start of next row to 0x8000 so it is recognized as a text line
    move.w d3,$7E(a3)
    
    * make up work
    jsr $3812
    jmp $C316
  
  *************************************************************************
  * lp request
  *************************************************************************
  
  doNewLpRequestMessage:
    * "requested LP"
    lea $104D4,a2
    move.w $FFFFF03A,d4
    addq.w #4,a3
    move.l a3,-(a7)
      jsr $1A62
    move.l (a7)+,a3
    
    * number
    adda.w #16,a3
    move.w $FFFFF23C,d0
    addq.w #1,d0
    moveq #0,d5
    jsr $3920
    
    jmp $1064A
  
  doNewLpDonateMessage:
    * "donated LP"
    lea $104CB,a2
    move.w $FFFFF03A,d4
    addq.w #4,a3
    move.l a3,-(a7)
      jsr $1A62
    move.l (a7)+,a3
    
    * number
    adda.w #14,a3
    move.w $FFFFF23C,d0
    addq.w #1,d0
    moveq #0,d5
    jsr $3920
    
    jmp $105C4
  
  
  
  
  
  
  
  
  
  
  
  
  
  

  
  *************************************************************************
  * new data
  *************************************************************************
  
  dc.w 0
  
  newFontData:
    include out/asm/font_8x16.inc
  
  newSmallFontData:
    include out/asm/font_8x8.inc
  newSmallFontData_end:
  
  newSmallFontLowerCaseData:
    include out/asm/font_8x8_lower.inc
  newSmallFontLowerCaseData_end:
  
  newTitleLogoTileData:
    include out/grp/title_logo.inc
  newTitleLogoTileData_end:
  
  newTitleLogoMapData:
    include out/maps/title_logo.inc
  newTitleLogoMapData_end:

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  *************************************************************************
  * final overwrites
  *************************************************************************
  
  org $11662
  include out/asm/territory_menu_header.inc
  