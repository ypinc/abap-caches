# ABAP-Caches
Cache algorithms implementation in ABAP

Algos
-  Naive: Empty cache when full
-  Naive with random eviction
-  Classic LRU: Least Recently Used eviction
-  2Q: A low overhead high-performance buffer management replacement algorithm https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=e0508499b4cf5794d5aeaf717e7ad9541e9c2bba
-  SIEVE:  SIEVE is Simpler than LRU: an Efficient Turn-Key Eviction Algorithm for Web Caches NSDI'24 https://yazhuozhang.com/assets/publication/nsdi24-sieve.pdf
-  S3-FIFO: "FIFO queues are all you need for cache eviction" ACM SOSP'23 https://doi.org/10.1145/3600006.3613147

## Usage: 
Include choosen algorithm in your program.
Use CREATE_LCL_* macro to define a local class. Provide StructureName, KeyName and CacheSize. 
Fill in the code to retrieve data in case it wasn't found in a cache (usually DB selection, but can be anything)
Close method and class definition.

Later in a program just call the GET method of the defined local class to retrieve data from the cache.

```
include ypinc_sieve. " SIEVE cache macro
create_lcl_sieve tdevc devclass 512. " create SIEVE cache of TDEVC structures with DEVCLASS key - size 512 entries
    select single * from tdevc into rs_tdevc where devclass = iv_devclass. " data retrival code in case of cache miss 
  endmethod.
endclass.

... Later in a program ...

data(rs_tdevc) = lcl_sieve_tdevc_by_devclass=>get( ls_tadir-devclass ). " get structure from the cache
```

## Benchmarks: 
Performed on a local ABAP 2022 Trial installation using YP_BENCH_CACHE report

```
Cache hitratio benchmark
                                                                                        
 1.000.000   entries from TADIR, caching for TDEVC-DEVCLASS, cache size = 512 entries

Cache type                               Hits       Miss    Hit Ratio %              Time, sec
-----------------------------------------------------------------------------------------------
Naive cache, empty when full            915.149    84.851     91,5149                0,5338070
Naive cache with random eviction        922.883    77.117     92,2883                0,6916430
LRU cache                               925.113    74.887     92,5113                0,6325540
2Q cache (25/75% partition)             926.965    73.035     92,6965                0,8449050
SIEVE cache                             926.956    73.044     92,6956                0,5732030
S3FIFO cache                            927.151    72.849     92,7151                1,7748800

```



