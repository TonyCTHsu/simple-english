# Syncing 東京 DataHub

The connector pulls metrics from 東京 DataHub every 5 minutes. It serves teams
that need cached reads, and it ships as one binary.

## Limits

The cache invalidates on write. You do not need a manual flush. Norwegian users
see their locale as nb-NO by default. The 準備 step runs before the first
sync.
