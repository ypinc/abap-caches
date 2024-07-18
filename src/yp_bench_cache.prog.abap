**********************************************************************
* Cache Benchmark report to compare different implementation
* performance using the sample selection of package names from TADIR
**********************************************************************
report yp_bench_cache.

parameters:
  p_count type i default 1000000, " Record count to select from TADIR
  p_csize type i default 512. " Cache size in TDEVC entries

" common class to reuse the same data selection between
* different cache implementations.
class lcl_get_data definition.
  public section. class-methods: get_devc importing iv_devclass type devclass returning value(rs_tdevc) type tdevc.
endclass.
class lcl_get_data implementation.
  method get_devc.
    select single * from tdevc" bypassing buffer
    into rs_tdevc where devclass = iv_devclass.
  endmethod.
endclass.

* cache definition together with class definition before the actual code

include ypinc_naive. " Naive caching - empty when the cache full
create_lcl_naive tdevc devclass p_csize.
    rs_tdevc = lcl_get_data=>get_devc( iv_devclass ).
  endmethod.
endclass.

include ypinc_naive_rand. " Naive cache with random entry eviction
create_lcl_nvrnd tdevc devclass p_csize.
    rs_tdevc = lcl_get_data=>get_devc( iv_devclass ).
  endmethod.
endclass.

include ypinc_lru. " Classic LRU cache
create_lcl_lru tdevc devclass p_csize.
    rs_tdevc = lcl_get_data=>get_devc( iv_devclass ).
  endmethod.
endclass.

include ypinc_sieve. " SIEVE cache (LRU family)
create_lcl_sieve tdevc devclass p_csize.     " put your code here
    rs_tdevc = lcl_get_data=>get_devc( iv_devclass ).
  endmethod.
endclass.

include ypinc_2q. " 2Q cache (25/75% partition)
create_lcl_2q tdevc devclass p_csize.     " put your code here
    rs_tdevc = lcl_get_data=>get_devc( iv_devclass ).
  endmethod.
endclass.

include ypinc_s3fifo. "S3FIFO cache
create_lcl_s3f tdevc devclass p_csize.     " put your code here
    rs_tdevc = lcl_get_data=>get_devc( iv_devclass ).
  endmethod.
endclass.

**********************************************************************
end-of-selection.
  data:
    ls_tadir type tadir,          " Master data serves as a driver to the cache
    lt_tadir type table of tadir, " Preselected data to minimize DB interaction
    lv_prc   type p decimals 4,   " Hitratio, percentage
    lv_start type timestampl,
    lv_stop  type timestampl.

select * from tadir into table lt_tadir up to p_count rows.
p_count = sy-dbcnt. " adjust for the real entry count
write: / p_count, ' entries from TADIR, caching for TDEVC-DEVCLASS, cache size =', p_csize. skip.

write: / 'Cache type', 40(10) 'Hits', 50(10) 'Miss', 60(10) 'Hit Ratio %', 85(10) 'Time, sec'.
uline.

**********************************************************************
get time stamp field lv_start.
loop at lt_tadir into ls_tadir.
  lcl_naive_tdevc_by_devclass=>get( ls_tadir-devclass ).
endloop.
get time stamp field lv_stop.
lv_stop = lv_stop - lv_start. " time diff
lv_prc = ( lcl_naive_tdevc_by_devclass=>hits * 100 ) / ( lcl_naive_tdevc_by_devclass=>hits + lcl_naive_tdevc_by_devclass=>miss ).

write: / 'Naive cache, empty when full',
         |{ lcl_naive_tdevc_by_devclass=>hits NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Hits',
         |{ lcl_naive_tdevc_by_devclass=>miss NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Miss',
         |{ lv_prc  NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Hit Ratio %',
         |{ lv_stop NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Time, sec'.
skip.

***********************************************************************
get time stamp field lv_start.
loop at lt_tadir into ls_tadir.
  lcl_nvrnd_tdevc_by_devclass=>get( ls_tadir-devclass ).
endloop.
get time stamp field lv_stop.
lv_stop = lv_stop - lv_start. " time diff
lv_prc = ( lcl_nvrnd_tdevc_by_devclass=>hits * 100 ) / ( lcl_nvrnd_tdevc_by_devclass=>hits + lcl_nvrnd_tdevc_by_devclass=>miss ).

write: / 'Naive cache with random eviction',
        |{ lcl_nvrnd_tdevc_by_devclass=>hits NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Hits',
        |{ lcl_nvrnd_tdevc_by_devclass=>miss NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Miss',
        |{ lv_prc  NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Hit Ratio %',
        |{ lv_stop NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Time, sec'.
skip.

***********************************************************************
get time stamp field lv_start.
loop at lt_tadir into ls_tadir.
  lcl_lru_tdevc_by_devclass=>get( ls_tadir-devclass ).
endloop.
get time stamp field lv_stop.
lv_stop = lv_stop - lv_start. " time diff
lv_prc = ( lcl_lru_tdevc_by_devclass=>hits * 100 ) / ( lcl_lru_tdevc_by_devclass=>hits + lcl_lru_tdevc_by_devclass=>miss ).

write: / 'LRU cache',
|{ lcl_lru_tdevc_by_devclass=>hits NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Hits',
|{ lcl_lru_tdevc_by_devclass=>miss NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Miss',
|{ lv_prc  NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Hit Ratio %',
|{ lv_stop NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Time, sec'.
skip.

***********************************************************************
get time stamp field lv_start.
loop at lt_tadir into ls_tadir.
  lcl_2q_tdevc_by_devclass=>get( ls_tadir-devclass ).
endloop.
get time stamp field lv_stop.
lv_stop = lv_stop - lv_start. " time diff
lv_prc = ( lcl_2q_tdevc_by_devclass=>hits * 100 ) / ( lcl_2q_tdevc_by_devclass=>hits + lcl_2q_tdevc_by_devclass=>miss ).

write: / '2Q cache (25/75% partition)',
|{ lcl_2q_tdevc_by_devclass=>hits NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Hits',
|{ lcl_2q_tdevc_by_devclass=>miss NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Miss',
|{ lv_prc  NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Hit Ratio %',
|{ lv_stop NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Time, sec'.
skip.

***********************************************************************
get time stamp field lv_start.
loop at lt_tadir into ls_tadir.
  lcl_sieve_tdevc_by_devclass=>get( ls_tadir-devclass ).
endloop.
get time stamp field lv_stop.
lv_stop = lv_stop - lv_start. " time diff
lv_prc = ( lcl_sieve_tdevc_by_devclass=>hits * 100 ) / ( lcl_sieve_tdevc_by_devclass=>hits + lcl_sieve_tdevc_by_devclass=>miss ).

write: / 'SIEVE cache',
|{ lcl_sieve_tdevc_by_devclass=>hits NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Hits',
|{ lcl_sieve_tdevc_by_devclass=>miss NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Miss',
|{ lv_prc  NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Hit Ratio %',
|{ lv_stop NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Time, sec'.
skip.

***********************************************************************
get time stamp field lv_start.
select * from tadir into ls_tadir up to p_count rows.
  lcl_s3f_tdevc_by_devclass=>get( ls_tadir-devclass ).
endselect.
get time stamp field lv_stop.
lv_stop = lv_stop - lv_start. " time diff
lv_prc = ( lcl_s3f_tdevc_by_devclass=>hits * 100 ) / ( lcl_s3f_tdevc_by_devclass=>hits + lcl_s3f_tdevc_by_devclass=>miss ).

write: / 'S3FIFO cache',
|{ lcl_s3f_tdevc_by_devclass=>hits NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Hits',
|{ lcl_s3f_tdevc_by_devclass=>miss NUMBER = USER WIDTH = 8 ALIGN = RIGHT }| under 'Miss',
|{ lv_prc  NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Hit Ratio %',
|{ lv_stop NUMBER = USER WIDTH = 10 ALIGN = RIGHT }| under 'Time, sec'.
skip.
