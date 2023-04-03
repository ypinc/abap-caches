#### What is this for?
 - this is a bunch of macros implementing some cahing algorithms so you could quickly add caching to  your ABAP programs
#### Why would I ever need a cache?
 - this is a well-known techniwue to avoid many repetitive computations by saving the result and reuse it. In ABAP, most often it is used to save the results of DB requests to prevent polling the database with identical queries.
#### Wait, isn't SAP recommends to use 'table buffering' in this case?
 - yes, but this technique has several drawbacks
   - it's made for customizing tables 
   - it's system wide so you might affect other reports
   - you have no control over the size of the buffering
#### But I already can easily make some caching in 10 lines of ABAP code!
 - sure you can, however most of the times these quick-and-dirty 'save this to the internal table and read later' cache implementations suffer from the following issues:
   - they are not reused through the code, and often big reports have the same data being read from several places    
   - absense of the 'negative' cache, when you reading the database again and again trying to select non-existent value
   - no maximum size, or resetting the table when the maximum size is reached
   - reading the table every time even if the requested value is the same as the last time
#### Ok, but why can't I use the standard SAP FM which have built-in caching like MARA_SINGLE_READ
  - well, you can and you actually should, especially if you doing things in BADI or standard code enhancement.
   this will allow you to reuse the cached entries and most of the standard caches are quite robust, most have memory limit, some have negative caching.
   The main drawback of the typical SAP cache implementation is that it will totally RESET the cache once it reaches maximum defined size which is the waste of resources.
#### Is there really a better way to do this?
 - yes, and this was the main motivation behind this project. there are many algorithms to optimize cache behaviour considering we have certain memory limits.
   most simple and widely used is LRU eviction policy which evicts single Less Recently Used entry from the cache when we don't have enough space for the new entry.
   more advanced techniques include Segmented LRU, LFU (Least Frequently Used), 2Q (two-queues) and current state-of-art Window-TinyLFU algo.
#### And you tell me that SAP doesn't know about it?
 - they are perfectly aware. actually, system-wide single entry table buffer is made using LRU policy. 
 I wish there was some kind of API available to use this in custom developments, but at the moment this project acts as a workaround.
 there were however attempts addressing this problem, most notable are Contexts and Shared objects. Contexts were made obsolete in 6.40 and Shared Objects are way too complex for simple things like.
#### Seems you have this covered, how can I try? 
  - it's quite easy - you include one of the files with the cache you like (YPINC_2Q) for example, 
  define a local object using create_lcl_2q <table_name> <key_name> <cache_size>
  and write the retrieval of your <table_name> record by <key>, for example using database select.
  Please take a look at YP_BENCH_CACHE report to see usage and perform some benchmarks on your data to choose the best option.
 
#### Cool, but where is the catch?
 - it's well known that there are 2 hard problems in computer science: naming things, cache invalidation and off-by-1 errors. 
 While I hope that this project is not affected by the last one, two others are more than relevant.
 First of all, there is no invalidation except the RESET method, so you should take care of your data freshness.
 Second, the naming. currently ABAP has hard limit of 30 chars for the class name. for long table and field names you can easily cross this threshold.
 Last but not least is using several key fields, right now it can be done using named structure groups. I'm looking for the better solution, if you have any ideas - please share them by raising the issue or making a pull request.
 
 
 
 
