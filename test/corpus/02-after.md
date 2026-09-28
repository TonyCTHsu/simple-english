**Connection timeouts.** sqlpipe stops with `dial tcp: i/o timeout` when it cannot reach the Postgres port (5432 by default).

1. Make sure that the host that runs sqlpipe can reach the Postgres port. A firewall or security group usually blocks it.
2. If the database is managed (RDS, Cloud SQL), make sure that the instance accepts connections from the IP of sqlpipe.
3. If the network is slow, increase `source.connect_timeout_seconds` in the configuration.
