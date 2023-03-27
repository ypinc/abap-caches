*& ABAP 2Q cache (c) Pavel Niherysh 2023
*&---------------------------------------------------------------------*
* This is a MACRO to define a CLASS which implements an 2Q cache
*   of the structures by their key (one key field)
* This version is the downport and should be compatible with 7.02 BASIS
* Usage pattern - you define a 2Q cache for the data from the TABLE
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
*  create_lcl_2q KNA1 KUNNR 128
*      select single * from KNA1 into RS_KNA1 where KUNNR = IV_KUNNR.
*    endmethod. " because we finishing the method implementation
*  endclass. " because we finishing the class implementation
*
* Now you can call it in your program like that:
*   lv_name = lcl_2q_kna1_by_kunnr( lt_vbap-kunag )-name1.
*
* You can even combine this with standard SAP where the code is used
* from several places and enhancements within one session:
*
*  create_lcl_2q MARA MATNR 100
*      CALL FUNCTION 'MARA_SINGLE_READ'
*        EXPORTING MATNR = IV_MATNR
*        IMPORTING W_MARA = RS_MARA
*        EXCEPTIONS OTHERS = 4.
*    endmethod. " because we finishing the method implementation
*  endclass. " because we finishing the class implementation

define create_lcl_2q. "&1 table &2 key &3 size

class lcl_2q_&1_by_&2 definition.
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
      prev type ref to data, " double-linked list over the hash in order
      next type ref to data, " to have an ability to emulate queue
      main type xfeld, " indicator that the node belongs to the MAIN queue
      freq type int4,
      data type &1,
    end of ty_node,
    begin of ty_key_node,
      prev type ref to data, " double-linked list over the hash in order
      next type ref to data, " to have an ability to emulate queue
      okey type &1-&2,
    end of ty_key_node.
  class-data:
    heap type hashed table of ty_node with unique key data-&2 initial size 64, " both "hot" and "cold" entries
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
    sr_node type ref to ty_node.  " static link to the last accessed node
endclass.

class lcl_2q_&1_by_&2 implementation.
  method class_constructor.
    msize = &3.
    if msize < 4. msize = 4. endif.
    ksize = msize div 2. " outsize contains only keys for 50% of buffer
    isize = msize div 4. " input contains minimum 25% of values
    msize = &3 - isize.  " main contains 75% of values
  endmethod.
  method get.
    data: ls_node type ty_node,
          lv_freq type i,
          ls_okey type ty_key_node,
          lr_temp type ref to ty_node,
          lr_okey type ref to ty_key_node, " to check how WARM the entry is
          lr_tkey type ref to ty_key_node. " temporary node for deletion
*1. if X in AM/AI -> 2q AM, return
    if sr_node is not bound or sr_node->data-&2 ne iv_&2. " not the last access
      read table heap reference into sr_node with key data-&2 = iv_&2.
    endif.
    if sr_node is bound and sr_node->data-&2 = iv_&2. " 1. found in MAIN/INPUT
      rs_&1 = sr_node->data.
      add 1 to hits. " hit, return the value
      add 1 to sr_node->freq.
      if sr_node->main is not initial. " 1.1 found in MAIN, make an LRU update, move node to the head
        if sr_node = mhead.
          return. " nothing to update, we found the head itself
        elseif sr_node = mtail. " we found the tail, update only one ref from prev to it
          mtail ?= sr_node->prev. " get previous node,
          clear mtail->next. " clear the link to the tail
        else. " typical node in the middle, delete from the middle
          cast ty_node( sr_node->next )->prev = sr_node->prev. "lr_temp ?= sr_node->next. lr_temp->prev = sr_node->prev.
          cast ty_node( sr_node->prev )->next = sr_node->next. "lr_temp ?= sr_node->prev. lr_temp->next = sr_node->next.
        endif.
        clear sr_node->prev.
        sr_node->next = mhead. " link existing head as next node
        mhead->prev = sr_node. " backlink from existing head back to node
        mhead = sr_node. " now we have a new head
      endif.
      return. " 1.2 found in INPUT, do nothing
    endif.

    add 1 to miss. " well, it's a miss, baby, we shoulf find some place in HEAP to read the whole new data
    ls_node-data = select( iv_&2 ). " the actual reading is done within a custom method
    rs_&1 = ls_node-data.
    if ls_node-data is initial. " there is no data, keep it in the negative?
      return.
    endif.
    insert ls_node into table heap reference into sr_node. " add X to the HEAP, classify later

    if lines( heap ) > msize + isize. " 2. HEAP is full
      if incnt >= isize. "3. we can cut something from the INPUT
        subtract 1 from incnt.
        ls_okey-okey = itail->data-&2. " save the key, delete the tail
        if incnt = 0.
          clear: ihead, itail.
        else.
          itail ?= itail->prev. " get previous node,
          clear itail->next. " clear the link to the tail
        endif.
        delete table heap with table key data-&2 = ls_okey-okey. " free entry from INPUT

        insert ls_okey into table keys reference into lr_tkey. " 3.1 remove entry as WARM
        if khead is initial. " first entry, adjust tail
          ktail = lr_tkey.
        else.
          lr_tkey->next = khead. " adjust link to the current head
          khead->prev = lr_tkey.
        endif.
        khead = lr_tkey." and replace the head

      else. "3.3 our HEAP is full and we cannot cut more from INPUT, so evict from MAIN
        ls_okey-okey = mtail->data-&2. " save the key, delete the tail
        mtail ?= mtail->prev. " get previous node,
        clear mtail->next. " clear the link to the tail
        delete table heap with table key data-&2 = ls_okey-okey. " and this entry from MAIN is gone forever
      endif.
    endif.

    read table keys with table key okey = iv_&2 reference into lr_okey. " check if this key was WARM
    if sy-subrc = 0. " we've seen it before, let's delete it from KEYS and promote it right to the MAIN!
      if lines( keys ) = 1. " last line, clear everything
        clear: khead, ktail, keys[].
      else.
        if lr_okey = khead.
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

      sr_node->main = abap_true. " 4. MAIN promotion
      if mhead is initial. " first entry, adjust tail
        mtail = sr_node.
      else.
        sr_node->next = mhead.
        mhead->prev = sr_node.
      endif.
      mhead = sr_node.
    else. " never heard about it or already completely forgotten, append to the INPUT
      if ihead is initial. " first entry, adjust tail
        itail = sr_node.
      else.
        sr_node->next = ihead.
        ihead->prev = sr_node.
      endif.
      ihead = sr_node. " adjust head
      add 1 to incnt. " keep count in INPUT
    endif.
    if lines( keys ) > ksize. " 3.2 overflow, delete last key
      ls_okey-okey = ktail->okey. " save the key, delete the tail
      ktail ?= ktail->prev. " get previous node,
      clear ktail->next. " clear the link to the tail
      delete table keys with table key okey = ls_okey-okey. " clear the space
    endif.
  endmethod.

  method select.
end-of-definition.
