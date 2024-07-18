*& ABAP SIEVE cache (c) Pavel Niherysh 2024
*&---------------------------------------------------------------------*
* This is a MACRO to define a CLASS which implements an sieve cache
*   of the structures by their key (one key field)
* This version is the downport and should be compatible with 6.40 BASIS
* Usage pattern - you define an sieve cache for the data from the TABLE
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
*  create_lcl_sieve KNA1 KUNNR 128
*      select single * from KNA1 into RS_KNA1 where KUNNR = IV_KUNNR.
*    endmethod. " because we finishing the method implementation
*  endclass. " because we finishing the class implementation
*
* Now you can call it in your program like that:
*   lv_name = lcl_sieve_kna1_by_kunnr( lt_vbap-kunag )-name1.
*
* You can even combine this with standard SAP where the code is used
* from several places and enhancements within one session:
*
*  create_lcl_sieve MARA MATNR 100
*      CALL FUNCTION 'MARA_SINGLE_READ'
*        EXPORTING MATNR = IV_MATNR
*        IMPORTING W_MARA = RS_MARA
*        EXCEPTIONS OTHERS = 4.
*    endmethod. " because we finishing the method implementation
*  endclass. " because we finishing the class implementation

define create_lcl_sieve. "tadir table &2 key &3 size
  class lcl_sieve_&1_by_&2 definition.
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
      data type &1,
            keep type boolean,
    end of ty_node.
    class-data:
    mt_heap type hashed table of ty_node with unique key data-&2 initial size 64, " entries
          mv_head type ref to ty_node, " head of MAIN sieve list
          mv_hand type ref to ty_node, " eviction hand
          mv_size type i,              " max size of sieve
          ms_node type ty_node,
          mr_node type ref to ty_node. " static link to the last accessed node
  endclass.

  class lcl_sieve_&1_by_&2 implementation.
  method class_constructor.
    mv_size = &3.
    get reference of ms_node into mr_node.
  endmethod.
  method get.
    data: lr_temp type ref to ty_node.
    if mr_node->data-&2 ne iv_&2.
      read table mt_heap reference into mr_node with key data-&2 = iv_&2.
      if sy-subrc ne 0. " 1. found, not at head
        add 1 to miss. " well, it's a miss, baby, we should find some place in mt_heap to read the whole new data
        clear: ms_node-prev, ms_node-next, ms_node-keep.
        rs_&1 = ms_node-data = select( iv_&2 ). " the actual reading is done within a custom method
        if ms_node-data-&2 is initial.
          return.
        endif.
        if mv_size = 0. "lines( mt_heap ) = mv_size. " 2. mt_heap is full, eviction
          do.
            if mv_hand->keep = 1. " is this the second chance for the item?
              mv_hand->keep = 0.  " clear usage indicator
              mv_hand ?= mv_hand->prev. " and take the next record
            else. " burn that witch!
              if mv_hand = mv_head. " time to wrap?
                mv_head ?= mv_head->next. " shift head
              endif.
              lr_temp ?= mv_hand->next. lr_temp->prev = mv_hand->prev."cast ty_node( mr_node->next )->prev = mr_node->prev. "
              lr_temp ?= mv_hand->prev. lr_temp->next = mv_hand->next."cast ty_node( mr_node->prev )->next = mr_node->next. "
              delete table mt_heap with table key data-&2 = mv_hand->data-&2. " and this entry from MAIN is gone forever
              mv_hand = lr_temp.
              add 1 to mv_size.
              exit. " evicted.
            endif.
          enddo.
        endif.
        subtract 1 from mv_size.
        insert ms_node into table mt_heap reference into mr_node. " add X to the mt_heap, classify later
        if mv_head is initial. " maybe first entry, adjust tail
          mv_hand = mr_node.
          mr_node->prev = mr_node. " wrap-a-loop
          mr_node->next = mr_node.
        else.  " just append at head
          lr_temp ?= mv_head->prev.
          mr_node->prev = lr_temp.
          lr_temp->next = mr_node.
          mv_head->prev   = mr_node.
          mr_node->next = mv_head.
        endif.
        mv_head = mr_node.
        return.
      endif.
    endif.
    mr_node->keep = 1. " used, give this
    add 1 to hits. " hit, return the value
    rs_&1 = mr_node->data.
  endmethod.
  method select.
*    select single * from tdevc into rs_tadir where devclass = iv_devclass.
*  endmethod.
*endclass.
end-of-definition.
