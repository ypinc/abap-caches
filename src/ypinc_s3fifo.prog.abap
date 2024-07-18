*& ABAP S3FIFO cache (c) Pavel Niherysh 2024
*&---------------------------------------------------------------------*
* This is a MACRO to define a CLASS which implements an S3F cache
*   of the structures by their key (one key field)
* This version is the downport and should be compatible with 7.02 BASIS
* Usage pattern - you define a S3F cache for the data from the TABLE
* with the given KEY as a class with two methods:
* - GET( importing iv_KEY type TABLE-KEY ) returning rs_TABLE
*   which returns the TABLE entry from the cache and if it is missing -
*   calls another method SELECT to retrieve it. You have to code this:
* - SELECT( importing iv_KEY type TABLE-KEY ) returning rs_TABLE
* As a bonus, you have two static attributes for hits and misses count
* to estimate the performance of your caching
**
* Usage example: we want to cache our beloved KNA1 customers
*   by their KUNNR number in order to keep a cache for 128 of them:
*
*  create_lcl_S3F KNA1 KUNNR 128
*      select single * from KNA1 into RS_KNA1 where KUNNR = IV_KUNNR.
*    endmethod. " because we finishing the method implementation
*  endclass. " because we finishing the class implementation
*
* Now you can call it in your program like that:
*   lv_name = lcl_S3F_kna1_by_kunnr( lt_vbap-kunag )-name1.
*
* You can even combine this with standard SAP where the code is used
* from several places and enhancements within one session:
*
*  create_lcl_S3F MARA MATNR 100
*      CALL FUNCTION 'MARA_SINGLE_READ'
*        EXPORTING MATNR = IV_MATNR
*        IMPORTING W_MARA = RS_MARA
*        EXCEPTIONS OTHERS = 4.
*    endmethod. " because we finishing the method implementation
*  endclass. " because we finishing the class implementation

define create_lcl_s3f. "&1 table &2 key &3 size

*constants: lc_size type i value 128.

class lcl_s3f_&1_by_&2 definition.
  public section.
  class-methods:
  class_constructor,
  get    importing iv_&2 type &2 returning value(rs_&1) type &1,
  select importing iv_&2 type &2 returning value(rs_&1) type &1.
  class-data:
        miss type i,
        hits type i.
  private section.
  types:
  begin of ty_node,
    next type ref to data, " to have an ability to emulate queue
          freq type byte,
    data type &1,
  end of ty_node,
  begin of ty_key_node,
    prev type ref to data, " double-linked list over the hash in order
    next type ref to data, " to have an ability to emulate queue
          okey type tadir-devclass, "&1-&2,
  end of ty_key_node.
  class-data:
  heap type hashed table of ty_node with unique key data-devclass initial size 64, " both "hot" and "cold" entries
        keys type hashed table of ty_key_node with unique key okey      initial size 64, " evicted "warm" entries
        mhead type ref   to ty_node, " head of MAIN LRU list
        mtail type ref   to ty_node, " tail of MAIN LRU list
        msize type i,                " max size of LRU
        ihead type ref   to ty_node, " head of INPUT FIFO queue
        itail type ref   to ty_node, " tail of INPUT FIFO queue
        isize type i, " max size of INPUT FIFO
        khead type ref   to ty_key_node, " head of KEYS FIFO queue
        ktail type ref   to ty_key_node, " tail of KEYS FIFO queue
        ksize type i, " max size of KEYS storage
        incnt type i, " current size of INPUT
        ss_node type ty_node, " static node
        sr_node type ref to ty_node.  " static link to the last accessed node
endclass.

class lcl_S3F_&1_by_&2 implementation.
  method class_constructor.
    msize = &3.
    if msize < 10. msize = 10. endif.
    ksize = msize div 2. " outsize contains only keys for 50% of buffer
    isize = msize div 10. " input contains minimum 10% of values
    msize = &3 - isize.  " main contains 75% of values
    get reference of ss_node into sr_node.
  endmethod.
  method get.
    data: ls_okey type ty_key_node,
          lr_okey type ref to ty_key_node, " to check how WARM the entry is
          lr_tkey type ref to ty_key_node. " temporary node for deletion
*1. if X in AM/AI -> S3F AM, return
    if sr_node->data-devclass ne iv_&2. " not the last access
      read table heap reference into sr_node with key data-devclass = iv_&2.
    endif.
    if sy-subrc = 0.
      rs_&1 = sr_node->data.
      add 1 to hits. " hit, return the value
      if sr_node->freq < 3. " saturate freq with 3 in order to demote quickly
        add 1 to sr_node->freq.
      endif.
      return. " 1.2 found in INPUT, do nothing
    endif.

    add 1 to miss. " well, it's a miss, baby, we should find some place in HEAP to read the whole new data
    ss_node-data = select( iv_&2 ). " the actual reading is done within a custom method
    if ss_node-data is initial. " there is no data, keep it in the negative?
      return.
    endif.
    rs_&1 = ss_node-data.
    insert ss_node into table heap reference into sr_node. " add X to the HEAP, classify later

    while ( incnt > isize ) and ( lines( heap ) > msize + isize ).  " HEAP is full, eviction time. INP -> evict in one step;
      "first we evict something from the INPUT, itail is not NULL
      subtract 1 from incnt.
      if ihead->freq > 1. " has been referenced, promote this entry to MAIN main.enq( input.deq )
        if mtail is bound. "any entries in MAIN?
          mtail->next = ihead. " relink to the main, update OLD tail
        else.
          mhead = ihead. " the only entry in MAIN is freshly evicted node from INP
        endif.
        mtail = ihead. " NEW tail is the evicted INPUT
        mtail->freq = mtail->freq - 2. " decrease freq to save on relink
        ihead ?= ihead->next. " dequeue INPUT
        clear mtail->next.
      else. " low referenced, evict to WARM KEYS
        ls_okey-okey = ihead->data-devclass. " save the key before deleting the tail
        ihead ?= ihead->next. " dequeue INPUT
        delete table heap with table key data-devclass = ls_okey-okey. " free entry from INPUT
        insert ls_okey into table keys reference into lr_tkey. " add this key to WARM
        if khead is initial. " first entry, adjust tail
          ktail = lr_tkey.
        else.
          lr_tkey->next = khead. " adjust link to the current head
          khead->prev = lr_tkey.
        endif.
        khead = lr_tkey." and replace the head
        if lines( keys ) > ksize. " 3.2 overflow, delete last key
          ls_okey-okey = ktail->okey. " save the key, delete the tail
          ktail ?= ktail->prev. " get previous node,
          clear ktail->next. " clear the link to the tail
          delete table keys with table key okey = ls_okey-okey. " clear the space
        endif.
        exit. " while -> we have evicted something
      endif.
    endwhile.
*    endif.

    while lines( heap ) > msize + isize. " HEAP is full, eviction time. MAIN -> demotion loop
      if mhead->freq = 0. " cannot be NULL as we have enough entries there
        ls_okey-okey = mhead->data-devclass. " save the key, dequeue an item
        mhead ?= mhead->next. " shift head
        delete table heap with table key data-devclass = ls_okey-okey. " and this entry from MAIN is gone forever
        exit.
      else. "requeue item, decreasing a freq
        mhead->freq = mhead->freq - 1.
        mtail->next = mhead. " link OLD head to the tail
        mtail = mhead. " adjust tail
        mhead ?= mhead->next. " adjust head
        clear mtail->next. " otherwise contains garbage, but this is not really necessary
      endif.
    endwhile.

    read table keys with table key okey = iv_&2 reference into lr_okey." check if this key was WARM
    if sy-subrc = 0. " we've seen it before, let's delete it from KEYS and promote it right to the MAIN!
      if lines( keys ) = 1. " last line, clear everything
        clear: khead, ktail, keys[].
      else.
        if lr_okey = khead.     " head deletion
          khead ?= khead->next. " update khead to the next entry
          clear khead->prev.    " clear the link to the head
      elseif lr_okey = ktail. " we found the tail, update only one ref from prev to it
          ktail ?= lr_okey->prev. " get previous node,
          clear ktail->next. " clear the link to the tail
        else. " typical node in the middle, delete from the middle
          cast ty_key_node( lr_okey->next )->prev = lr_okey->prev. "lr_tkey ?= lr_okey->next. lr_tkey->prev = lr_okey->prev.
          cast ty_key_node( lr_okey->prev )->next = lr_okey->next. "lr_tkey ?= lr_okey->prev. lr_tkey->next = lr_okey->next.
        endif.
        delete table keys with table key okey = iv_&2.
      endif.

      if mtail is initial. " first entry, adjust tail
        mhead = sr_node.
      else.
        mtail->next = sr_node.
      endif.
      mtail = sr_node.
    else. " never heard about it or already completely forgotten, append to the INPUT
      if itail is initial. " first entry
        ihead = sr_node.
      else.
        itail->next = sr_node.
      endif.
      itail = sr_node. " adjust head
      clear itail->next.
      add 1 to incnt. " keep count in INPUT
    endif.
  endmethod.

  method select.
*    select single * from tdevc into rs_&1 where devclass = iv_&2.
*  endmethod.
*endclass.
end-of-definition.
