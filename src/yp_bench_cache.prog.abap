report yp_bench_cache. " reference class-based lru macro
constants: gc_heapsize type i value 1024.

include ypinc_2q.
include ypinc_lru.
include ypinc_naive.
include ypinc_naive_rand.

create_lcl_2q tdevc devclass gc_heapsize.     " put your code here
  select single * from tdevc" bypassing buffer
    into rs_tdevc where devclass = iv_devclass.
  endmethod.
endclass.

create_lcl_lru tdevc devclass gc_heapsize.     " put your code here
   select single * from tdevc" bypassing buffer
        into rs_tdevc where devclass = iv_devclass.
  endmethod.
endclass.

create_lcl_naive tdevc devclass gc_heapsize.     " put your code here
  select single * from tdevc" bypassing buffer
    into rs_tdevc where devclass = iv_devclass.
  endmethod.
endclass.

create_lcl_nvrnd tdevc devclass gc_heapsize.     " put your code here
  select single * from tdevc" bypassing buffer
    into rs_tdevc where devclass = iv_devclass.
  endmethod.
endclass.

**********************************************************************
end-of-selection.
  data: ls_tadir type tadir.
  data: lv_prc type p decimals 4.

  select * from tadir into ls_tadir up to 700000 rows.
    lcl_naive_tdevc_by_devclass=>get( ls_tadir-devclass ).
    lcl_nvrnd_tdevc_by_devclass=>get( ls_tadir-devclass ).
    lcl_lru_tdevc_by_devclass=>get( ls_tadir-devclass ).
    lcl_2q_tdevc_by_devclass=>get( ls_tadir-devclass ).
  endselect.

  write: / '500K entries from TADIR, caching for DEVCLASS, cache size =', gc_heapsize. skip.

  write: / 'Naive cache: hits / miss, hitratio %'.
  write: / lcl_naive_tdevc_by_devclass=>hits, lcl_naive_tdevc_by_devclass=>miss.
  lv_prc = ( lcl_naive_tdevc_by_devclass=>hits * 100 ) / ( lcl_naive_tdevc_by_devclass=>hits + lcl_naive_tdevc_by_devclass=>miss ).
  write: / lv_prc. skip.

  write: / 'Naive cache with random eviction: hits / miss, hitratio %'.
  write: / lcl_nvrnd_tdevc_by_devclass=>hits, lcl_nvrnd_tdevc_by_devclass=>miss.
  lv_prc = ( lcl_nvrnd_tdevc_by_devclass=>hits * 100 ) / ( lcl_nvrnd_tdevc_by_devclass=>hits + lcl_nvrnd_tdevc_by_devclass=>miss ).
  write: / lv_prc. skip.

  write: / 'LRU: hits / miss, hitratio %'.
  write: / lcl_lru_tdevc_by_devclass=>hits, lcl_lru_tdevc_by_devclass=>miss.
  lv_prc = ( lcl_lru_tdevc_by_devclass=>hits * 100 ) / ( lcl_lru_tdevc_by_devclass=>hits + lcl_lru_tdevc_by_devclass=>miss ).
  write: / lv_prc. skip.

  write: / '2Q: hits / miss, hitratio %'.
  write: / lcl_2q_tdevc_by_devclass=>hits, lcl_2q_tdevc_by_devclass=>miss.
  lv_prc = ( lcl_2q_tdevc_by_devclass=>hits * 100 ) / ( lcl_2q_tdevc_by_devclass=>hits + lcl_2q_tdevc_by_devclass=>miss ).
  write: / lv_prc. skip.
