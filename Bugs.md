Bugs:


Feature Ideas:
- we link glossary terms, what about a hover over that shows teh defintion. i am not sure how much overhead this will add in terms of complexity and page weight so we need to assess and think before doing
- https://github.com/jeffdc/gallformers/issues/357
- https://github.com/jeffdc/gallformers/issues/276 and https://github.com/jeffdc/gallformers/issues/344
- https://github.com/jeffdc/gallformers/issues/343
- https://github.com/jeffdc/gallformers/issues/330
- https://github.com/jeffdc/gallformers/issues/272
- can not create Family from new Gall/Host 
- https://github.com/jeffdc/gallformers/issues/106
- add timestamps and user attribution to all data that can change
- streamlined Admin flows
- better ID tool
- 




Dic Keys:

It could be neat to have clickable figure links that produce pop-up windows to keep the organization nice and clean. Of course, that requires figures, but I figured I'd share it while it was fresh in my head.



ecto issues:

- `Species` context is 1300+ lines - gall logic should extract to `Galls` context
- `get_gall_filter_values/1` runs 9 queries - should consolidate
- `GallController.gall_to_response/1` has N+1 on aliases
- Many functions return maps instead of preloadable structs
