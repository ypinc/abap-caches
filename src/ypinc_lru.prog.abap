*& ABAP LRU cache (c) Pavel Niherysh 2023
*&---------------------------------------------------------------------*
* This is a MACRO to define a CLASS which implements an LRU cache
*   of the structures by their key (one key field)
* This version is the downport and should be compatible with 6.40 BASIS
* Usage pattern - you define an LRU cache for the data from the TABLE
* with the given KEY as a class with two methods:
* - GET( importing iv_KEY type TABLE-KEY ) returning rs_TABLE
*   which returns the TABLE entry from the cache and if it is missing -
*   calls another method SELECT to retrieve it. You have to code this:
* - SELECT( importing iv_KEY type TABLE-KEY ) returning rs_TABLE
* As a bonus, you have two static attributes for hits and misses count
* to estimate the performance of your caching
*
* This cache supports negative caching - if your SELECT returns an
* empty key - next time this request will be served from the cache
* and you will get an empty entry as a result.
* Right now there is no limit on a negative cache size as we
* expect the number of negative entries to be low compared to the
* normal ones, moreover only keys are cached so memory footprint is
* significantly lower.
*
* Usage example: we want to cache our beloved KNA1 customers
*   by their KUNNR number in order to keep a cache for 128 of them:
*
*  create_lcl_lru KNA1 KUNNR 128
*      select single * from KNA1 into RS_KNA1 where KUNNR = IV_KUNNR.
*    endmethod. " because we finishing the method implementation
*  endclass. " because we finishing the class implementation
*
* Now you can call it in your program like that:
*   lv_name = lcl_lru_kna1_by_kunnr( lt_vbap-kunag )-name1.
*
* You can even combine this with standard SAP where the code is used
* from several places and enhancements within one session:
*
*  create_lcl_lru MARA MATNR 100
*      CALL FUNCTION 'MARA_SINGLE_READ'
*        EXPORTING MATNR = IV_MATNR
*        IMPORTING W_MARA = RS_MARA
*        EXCEPTIONS OTHERS = 4.
*    endmethod. " because we finishing the method implementation
*  endclass. " because we finishing the class implementation

define create_lcl_lru. "&1 table &2 key &3 size

  class lcl_lru_&1_by_&2 definition.
    public section.
    class-methods:
    class_constructor,
    get    importing iv_&2 type &1-&2 returning value(rs_&1) type &1,
    select importing iv_&2 type &1-&2 returning value(rs_&1) type &1.
    class-data:
          miss type i,
          hits type i.
    private section.
    types:
    begin of ty_node,
      prev type ref to data, " double-linked list over the hash in order
      next type ref to data, " to have an ability to emulate queue
      data type &1,
    end of ty_node.
    class-data:
    heap type hashed table of ty_node with unique key data-&2 initial size 128, " entries
          anti type hashed table of &1-&2 with unique key table_line, " negative cache
          mhead type ref   to ty_node, " head of MAIN LRU list
          mtail type ref   to ty_node, " tail of MAIN LRU list
          msize type i,                " max size of LRU
          sr_node type ref to ty_node. " static link to the last accessed node
  endclass.

  class lcl_lru_&1_by_&2 implementation.
  method class_constructor.
    msize = &3.
  endmethod.
  method get.
    data: ls_node type ty_node,
          lr_temp type ref to ty_node.
    if sr_node is not bound or sr_node->data-&2 ne iv_&2. " 1. not found at head
      read table heap reference into sr_node with key data-&2 = iv_&2.
      if sy-subrc = 0. " 1. found, not at head
        if sr_node = mtail. " we found the tail, update only one ref from prev to it
          mtail ?= sr_node->prev. " get previous node,
          clear mtail->next. " clear the link to the tail
        else. " typical node in the middle, delete from the middle
          lr_temp ?= sr_node->next. lr_temp->prev = sr_node->prev."cast ty_node( sr_node->next )->prev = sr_node->prev. "
          lr_temp ?= sr_node->prev. lr_temp->next = sr_node->next."cast ty_node( sr_node->prev )->next = sr_node->next. "
        endif.
        clear sr_node->prev.   " this is going to be head, no previous entry
        sr_node->next = mhead. " link existing head as next node
        mhead->prev = sr_node. " backlink from existing head back to node
        mhead = sr_node. " now we have a new head
      else.
        if anti[] is not initial. " do we have negative cache items?
          read table anti with table key table_line = iv_&2 transporting no fields.
          if sy-subrc = 0.
            add 1 to hits.
            clear rs_&1. return.
          endif.
        endif.
        add 1 to miss. " well, it's a miss, baby, we should find some place in HEAP to read the whole new data
        rs_&1 = ls_node-data = select( iv_&2 ). " the actual reading is done within a custom method
        if ls_node-data-&2 is initial. " there is no data, keep it in the negative?
          insert iv_&2 into table anti. return.
        endif.
        if lines( heap ) = msize. " 2. HEAP is full, delete from tail
          lr_temp ?= mtail->prev. " get previous node,
          clear mtail->next. " clear the link to the tail
          delete table heap with table key data-&2 = mtail->data-&2. " and this entry from MAIN is gone forever
          mtail = lr_temp.
        endif.
        insert ls_node into table heap reference into sr_node. " add X to the HEAP, classify later
        if mhead is initial. " maybe first entry, adjust tail
          mtail = sr_node.
        else.  " just append at head
          mhead->prev = sr_node.
        endif.
        sr_node->next = mhead.
        mhead = sr_node.
        return.
      endif.
    endif.
    add 1 to hits. " hit, return the value
    rs_&1 = sr_node->data.
  endmethod.
  method select.
end-of-definition.
