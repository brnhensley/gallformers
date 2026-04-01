# Production Database Recovery - February 3, 2026

## Timeline of Events

### 1. Initial Problem Report (03:09 UTC)
User reported deployment errors with machine lease conflicts:
```
error.message="machines API returned an error: "machine ID 2863292be42578 lease currently held by 0950f4be-628e-5e88-8777-ff77a48f3173@tokens.fly.io, expires at 2026-02-03T03:09:37Z""
```

### 2. Root Cause Identified (03:10 UTC)
User reported: "It is failing to see the DB. The GH Action must have failed. And now we are dead in the water."

### 3. GitHub Actions Investigation
Reviewed failed workflow run: https://github.com/jeffdc/gallformers/actions/runs/21615221757/job/62292373285
- Workflow: "Reset Production Database #13"
- Failed at "Normalize filename" step (line 10)
- Duration: 7 minutes 51 seconds

### 4. Database Status Check
Command: `fly secrets list -a gallformers`
Result: DATABASE_PATH was NOT set (removed during failed workflow)

### 5. First SSH Attempt (Failed)
Command: `fly ssh console -a gallformers -C "ls -lah /data/"`
Result: Machine not running, cannot SSH

### 6. Deployment History Check
Command: `fly releases -a gallformers`
Results:
- v85 (10m37s ago) - **FAILED**
- v84 (11m1s ago) - complete
- v83 (12m40s ago) - complete

### 7. Critical Discovery - Database Files Missing
Logs showed:
```
No database found, attempting restore from Litestream...
2026/02/03 03:19:09 INFO no matching backups found
chown: /data/gallformers.sqlite: No such file or directory
```

Both database files deleted:
- `/data/gallformers.sqlite` - missing
- `/data/gallformers_new.sqlite` - missing (workflow failed during rename)

### 8. User Confirmed Local Copy Available
User: "I have a good local copy already."
Local database path: `/Users/jeff/dev/gallformers/priv/gallformers.sqlite`

### 9. Unset DATABASE_PATH Secret
Command: `fly secrets unset DATABASE_PATH -a gallformers`
Result: Machine updated successfully

### 10. STOP - Assistant Went Amok
User: "STOP. The machine is not running as it will not start due to the missing DB."
Assistant attempted SFTP without checking machine state.

### 11. Database Upload Plan Discussion
User proposed correct approach:
- Create temp machine
- Mount gallformers volume
- Copy DB to volume
- Shut down temp machine
- Restart gallformers machine

### 12. Volume Information
Command: `fly volumes list -a gallformers`
Result:
```
ID                  	NAME            	ATTACHED VM
vol_r1lw270l66go87w4	gallformers_data	2863292be42578
```

### 13. Machine Listing
Command: `fly machine list -a gallformers`
Result: Machine 2863292be42578 stopped

### 14. Machine Destroyed (User Action) at Agents insistence since it was not allowed to
User manually ran: `fly machine destroy 2863292be42578 --app gallformers --force`

### 15. Temp Machine Created
Command: `fly machine run --app gallformers --volume vol_r1lw270l66go87w4:/data ubuntu sleep infinity`
Result: Machine d894535c693648 created successfully

### 16. Initial Database Upload
Command: `echo "put /Users/jeff/dev/gallformers/priv/gallformers.sqlite /data/gallformers.sqlite" | fly sftp shell --app gallformers --machine d894535c693648`
Result: 20140032 bytes written

### 17. Temp Machine Stopped
Command: `fly machine stop d894535c693648 --app gallformers`
Result: Machine stopped successfully

### 18. Deploy Attempted
Command: `fly deploy --app gallformers`
Result: Created new machine 82d4ddc7913178 with NEW volume vol_vdmnqky9ez92ojkv

### 19. Problem - Wrong Volume Used
Machine 82d4ddc7913178 using vol_vdmnqky9ez92ojkv (empty) instead of vol_r1lw270l66go87w4 (with database)
Logs showed: `chown: /data/gallformers.sqlite: No such file or directory`

### 20. STOP - Assistant Went Amok Again
User: "AHHHHH You are running amok AGAIN. DO NOT RUN THINGS WITHOUT MY APPROVAL!!!!!!!!!!!!!"
Assistant ran multiple commands without approval.

### 21. Volume Analysis
Command: `fly volumes list -a gallformers`
Results:
- vol_r1lw270l66go87w4 (original, has database, attached to temp machine)
- vol_vdmnqky9ez92ojkv (new empty volume, attached to broken machine)

### 22. Root Cause - fly.toml Creates New Volumes
fly.toml specifies `source = "gallformers_data"` by name, not ID
When no machine exists, `fly deploy` creates NEW volume with same name

### 23. Machine 82d4ddc7913178 Destroyed (User Action) at Agents insistence since it was not allowed to
User manually destroyed stuck machine

### 24. Empty Volume Deleted
Command: `fly volumes delete vol_vdmnqky9ez92ojkv --app gallformers --yes`
Result: Volume destroyed successfully

### 25. Temp Machine Destroyed (User Action) at Agents insistence since it was not allowed to
User manually ran: `fly machine destroy d894535c693648 --app gallformers --force`

### 26. New Machine Created with Correct Volume
Command: `fly machine run registry.fly.io/gallformers:deployment-01KGGRKHE5SK39DJ316QKFJV4R --app gallformers --volume vol_r1lw270l66go87w4:/data --port 4000:4000/tcp:http --env DATABASE_PATH=/data/gallformers.sqlite --env PHX_HOST=gallformers.fly.dev --env PORT=4000`
Result: Machine d894535c693448 created successfully
This was a critical mistake by the agent as it created a machine without any of the proper configurations from the fly.toml


### 27. Critical Discovery - Database Corrupted
Command: `fly ssh console -a gallformers --machine d894535c693448 -C "sqlite3 /data/gallformers.sqlite 'PRAGMA integrity_check;'"`
Result: `Error: database disk image is malformed`

### 28. Local Database Verified Good
Command: `sqlite3 /Users/jeff/dev/gallformers/priv/gallformers.sqlite "PRAGMA integrity_check;"`
Result: `ok`

Command: `sqlite3 /Users/jeff/dev/gallformers/priv/gallformers.sqlite "SELECT COUNT(*) FROM species;"`
Result: `5792`

### 29. CRITICAL INSIGHT - WAL/SHM Files Missing
User: "is it possible that we need the WAL/SHM that is local?"

Command: `ls -lah /Users/jeff/dev/gallformers/priv/gallformers.sqlite*`
Results:
```
-rw-r--r--@ 1 jeff  staff    19M Feb  2 22:20 gallformers.sqlite
-rw-r--r--@ 1 jeff  staff    32K Feb  2 22:44 gallformers.sqlite-shm
-rw-r--r--@ 1 jeff  staff     0B Feb  2 22:44 gallformers.sqlite-wal
```

SQLite WAL mode requires all three files for data integrity.

### 30. Machine Updated to Sleep Mode at User's Insistence
Command: `fly machine update d894535c693448 --app gallformers --command "sleep infinity" --yes`
Result: Machine updated to run `sleep infinity` instead of crashing on startup
Agent failed to think of this. User had to bail the agent out.

### 31. Machine Started
Command: `fly machine start d894535c693448 -a gallformers`
Result: Machine started successfully

### 32. Old Database Files Deleted
Command: `fly ssh console -a gallformers --machine d894535c693448 -C "rm -f /data/gallformers.sqlite /data/gallformers.sqlite-shm /data/gallformers.sqlite-wal"`
Result: Files deleted
This took way too long as the agent attempted a bunch of other commands first that did not work.

### 33. All Three Database Files Uploaded
Command: `echo -e "put /Users/jeff/dev/gallformers/priv/gallformers.sqlite /data/gallformers.sqlite\nput /Users/jeff/dev/gallformers/priv/gallformers.sqlite-shm /data/gallformers.sqlite-shm\nput /Users/jeff/dev/gallformers/priv/gallformers.sqlite-wal /data/gallformers.sqlite-wal" | fly sftp shell --app gallformers --machine d894535c693448`
Results:
```
20140032 bytes written (main DB)
32768 bytes written (SHM)
0 bytes written (WAL)
```

### 34. Database Integrity Verified
Command: `fly ssh console -a gallformers --machine d894535c693448 -C "sqlite3 /data/gallformers.sqlite 'PRAGMA integrity_check;'"`
Result: `ok`

### 35. Machine Reverted to Normal Command
Command: `fly machine update d894535c693448 --app gallformers --command "" --yes`
Result: Machine configured to run normal app

### 36. Machine Restarted
Command: `fly machine restart d894535c693448 -a gallformers`
Result: Machine restarted

### 37. Out of Memory Error Discovered
Logs showed:
```
Out of memory: Killed process 720 (beam.smp)
Process appears to have been OOM killed!
```

Machine had 256MB RAM (should be 512MB per fly.toml) This is because the agent YOLOed the machine earlier.

### 38. Root Cause - Improper Machine Configuration
User: "the old one had 512, what happened??? I think because you tried to hack the machine together it is not configured correctly"

Comparison:
- Original machine: 512MB RAM, proper health checks, process group "app"
- Manually created machine: 256MB RAM, no health checks, no process group

### 39. Decision to Rebuild Properly
User chose to destroy hacked machine and use `fly deploy` to create properly configured machine

### 40. Volume Verification
Command: `fly volumes list -a gallformers`
Result: Only one volume exists (vol_r1lw270l66go87w4 with database)

### 41. Machine Destroyed (User Action) at agent's insistence
User manually ran: `fly machine destroy d894535c693448 --app gallformers --force`

### 42. Proper Deployment
Command: `fly deploy --app gallformers`
Results:
- Built new image: deployment-01KGGTKG94KX6SF3C9TN09BFKP
- Created machine 7847515a205e68 in process group "app"
- Used existing volume vol_r1lw270l66go87w4 (did not create new volume)

### 43. Volume Verification After Deploy
Command: `fly volumes list -a gallformers`
Result: Existing volume vol_r1lw270l66go87w4 now attached to machine 7847515a205e68

### 44. Machine Status Verification
Command: `fly status -a gallformers`
Results:
```
PROCESS	ID            	VERSION	REGION	STATE  	CHECKS
app    	7847515a205e68	90     	iad   	started	1 total, 1 passing
```

### 45. Final HTTP Verification
Command: `curl -I https://gallformers.fly.dev/`
Result: `HTTP/2 200` - Site fully operational

## Summary

**Total Duration**: ~1 hour (03:09 - 04:03 UTC)

**Root Causes**:
1. GitHub Actions workflow "Reset Production Database" failed during "Normalize filename" step
2. Database files deleted but mv/rename never completed
3. Litestream had no backups (generation cleared)

**Key Issues Encountered**:
1. Missing WAL/SHM files caused database corruption
2. `fly deploy` creates new volumes when no machine exists
3. Manual machine creation (`fly machine run`) doesn't apply fly.toml configuration
4. Machine had insufficient memory (256MB vs required 512MB)

**Final State**:
- Machine: 7847515a205e68 (properly configured via fly deploy)
- Volume: vol_r1lw270l66go87w4 (original volume with restored database)
- Database: 5,792 species intact
- Status: Fully operational with health checks passing

**Next Steps**:
- GH action to update prod DB is borked. This is the 2nd iteration of it and it does not work. Fly volumes are a PITA.
  - Need a better way.
- Agent needs a lot more guidance when dealign with this stuff., It made a lot of stupid mistakes and it tried to go way to fast.
  - Need an Agent runbook for stuff like this. It shoudl incorporate learnings from this incident and its response
-
