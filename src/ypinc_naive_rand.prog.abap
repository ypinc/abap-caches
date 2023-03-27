*& ABAP Naive cache with random entry eviction (c) Pavel Niherysh 2023
*&---------------------------------------------------------------------*
* This is a MACRO to define a CLASS which implements a NAIVE cache
*   of the structures by their key (one key field)
*
* This is provided just for the reference to compare with more
* advanced cache algorithms and not intended for production use

* Usage pattern - you define a cache for the data from the TABLE
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
*  create_lcl_naive KNA1 KUNNR 128
*      select single * from KNA1 into RS_KNA1 where KUNNR = IV_KUNNR.
*    endmethod. " because we finishing the method implementation
*  endclass. " because we finishing the class implementation
*
* Now you can call it in your program like that:
*   lv_name = lcl_naive_kna1_by_kunnr( lt_vbap-kunag )-name1.

define create_lcl_nvrnd. "&1 table &2 key &3 size

class lcl_nvrnd_&1_by_&2 definition.
public section.
  class-methods:
    class_constructor,
    get    importing iv_&2 type &1-&2 returning value(rs_&1) type &1,
    select importing iv_&2 type &1-&2 returning value(rs_&1) type &1.
  class-data:
    miss type i,
    hits type i.
private section.
  class-data:
    heap type sorted table of &1 with unique key &2 initial size &3, " entries
    anti type hashed table of &1-&2 with unique key table_line, " negative cache
    msize type i.
endclass.

class lcl_nvrnd_&1_by_&2 implementation.
  method class_constructor.
    msize = &3.
  endmethod.
  method get.
    read table heap into rs_&1 with key &2 = iv_&2.
    if sy-subrc = 0. " 1. found, not at head
      add 1 to hits.
    else.
      if anti[] is not initial. " do we have negative cache items?
        read table anti with table key table_line = iv_&2 transporting no fields.
        if sy-subrc = 0.
          add 1 to hits.
          clear rs_&1. return.
        endif.
      endif.
      add 1 to miss.
      rs_&1 = select( iv_&2 ). " the actual reading is done within a custom method
      if rs_&1-&2 is initial. " there is no data, keep it in the negative?
        insert iv_&2 into table anti. return.
      endif.
      if lines( heap ) = msize. " 2. HEAP is full, delete
        call function 'QF05_RANDOM_INTEGER'
          EXPORTING
            RAN_INT_MAX         = msize
            RAN_INT_MIN         = 1
         IMPORTING
            RAN_INT             = sy-tfill.

        delete heap index sy-tfill.
      endif.
      insert rs_&1 into table heap.
    endif.
  endmethod.
  method select.
end-of-definition.
