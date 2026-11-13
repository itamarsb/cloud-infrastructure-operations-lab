# Lab 29 — Zabbix Monitoring: Controlled HTTP Service Failure

[**Português (Brasil)**](README.md) · **English**

## Status

**In development — environment configuration prepared; end-to-end experiment not yet executed.**

This lab is designed to demonstrate how Zabbix distinguishes **a failed HTTP service** from **a still-responsive Linux monitoring agent**. The intended sequence is to establish a healthy baseline, stop only the HTTP service, observe the corresponding Zabbix problem event, restore HTTP, and verify that the trigger returns to OK.

The committed repository already contains a Docker Compose topology, a purpose-built Linux target image, configuration files and one PowerShell environment-initialization script. However, **the original README explicitly states that the monitoring scenario has not been executed**. No deployed containers, configured host/items, observed trigger transitions, incident timings, or verified cleanup results are claimed here.

This English edition is based on a **static review** of the committed files and the inventory of 14 historical screenshots. Neither Docker nor Zabbix nor AWS was run during the documentation review.

## Learning objectives and acceptance criteria

The lab is intended to establish the following independently observable conditions:

1. Zabbix Server receives values for the monitored Linux host.
2. The target HTTP service responds normally before the experiment.
3. The HTTP service becomes unavailable after a deliberate intervention.
4. The Zabbix Agent remains responsive while HTTP is unavailable.
5. A correctly configured trigger records the service failure as a problem.
6. Restarting the HTTP service restores the expected response.
7. The trigger returns to OK after the required successful observations.
8. The exclusive lab containers, networks and database volume are removed, without touching any other Zabbix environment.

**These are acceptance criteria, not completed results.** Collection intervals, trigger expressions and recovery timings still require runtime configuration, measurement and evidence.

## Prepared local architecture

~~~text
Windows 11 / Docker Desktop / Docker Compose
                         |
               Project: cloud-operations-lab29
                         |
            +------------+-------------+
            |                          |
        database                    monitoring
      (internal)                   (internal)
            |                          |
            v                          v
   PostgreSQL 16.15          Zabbix Server 7.0.30
            ^                     |
            |                     v
            +---- shared DB -- Linux target container
            |                  Zabbix Agent 2
            |                  Nginx HTTP :8080
            |
      Zabbix Web 7.0.30
            |
       frontend network
            |
    127.0.0.1:18080 on host
~~~

The Docker Compose project uses **three isolated networks**: database, monitoring and frontend. The database and monitoring networks are declared internal. The web frontend is attached to the database network, so it can communicate with both PostgreSQL and Zabbix Server through the shared network; its published HTTP interface binds to host loopback.

### Container services

| Compose service | Committed image or build | Purpose |
|---|---|---|
| postgres | postgres:16.15-alpine3.24 | Dedicated Zabbix database |
| zabbix-server | zabbix/zabbix-server-pgsql:ubuntu-7.0.30 | Metric collection and trigger evaluation |
| zabbix-web | zabbix/zabbix-web-nginx-pgsql:ubuntu-7.0.30 | Web administration and problem views |
| linux-target | Local build based on zabbix/zabbix-agent2:ubuntu-7.0.30 | Zabbix Agent 2 and Nginx target |

These are **source-selected image tags**, not proof that an image was pulled successfully or that a specific immutable digest was verified. Reproducibility can be strengthened in future by recording image digests.

The database resides in its **own named Compose volume**, separate from any PostgreSQL volume or backup used in earlier Zabbix work. The project does not use a Zabbix agent installed on the Windows host.

## Local configuration

The [lab29-settings.json](config/lab29-settings.json) file defines the intended local parameters:

| Parameter | Committed value |
|---|---|
| Compose project name | cloud-operations-lab29 |
| Web bind address | 127.0.0.1 |
| Web host port | 18080 |
| Linux target hostname | lab29-linux |
| Proposed Zabbix host group | Lab29 |
| Proposed collection interval | 10 seconds |
| Proposed failure criterion | Three consecutive samples |
| Proposed recovery criterion | Three consecutive samples |
| Proposed baseline observation | 60 seconds |
| Proposed failure window | 60 seconds |
| Proposed recovery timeout | 120 seconds |

**Configuration boundary:** The current Compose and target files do not create the Zabbix host group, register the host in the Zabbix API, configure monitored items, or install a trigger expression. The collection and experiment parameters above are **design targets**, not implemented trigger behavior or validated detection intervals.

The settings do not assign immutable container digests or define an automated end-to-end experiment script.

### Target Linux image

The [Dockerfile](config/target/Dockerfile) extends the Zabbix Agent 2 Ubuntu image with Nginx, Supervisor and curl. The image build checks that the required executables exist and validates the Nginx configuration syntax.

The target [Zabbix Agent configuration](config/target/zabbix_agent2.conf) specifies:

- Passive check access from the lab's zabbix-server service.
- Listener on port 10050 within the container.
- Hostname derived from the container hostname.
- Console logging and a three-second check timeout.

The container hostname is supplied from the settings-generated environment file, and is intended to match the eventual host registration in Zabbix.

The [Nginx configuration](config/target/nginx.conf) listens on **port 8080** inside the target container and defines:

| Endpoint | Expected HTTP response | Body |
|---|---|---|
| / | 200 | LAB 29 - HTTP service running |
| /health | 200 | healthy |
| Other paths | 404 | not found |

These are **declared Nginx behaviors**. They have not yet been independently confirmed against a running Lab 29 container.

### Keeping the agent alive during the HTTP failure

The [Supervisor configuration](config/target/supervisord.conf) manages two processes:

- zabbix-agent: automatic startup; restart on unexpected termination.
- nginx: automatic startup; **autorestart=false**.

That distinction supports the proposed fault injection: stopping Nginx intentionally should leave the Supervisor process and Zabbix Agent running, rather than immediately restarting the HTTP service.

The Dockerfile deliberately disables its inherited health check with **HEALTHCHECK NONE**. Compose has a database health check, but no equivalent independent health check for the target's HTTP endpoint or Zabbix Agent. A running target container is therefore **not proof** that both target services are healthy.

The target does not publish its ports to the Windows host. Checks from the Zabbix Server or an authorized container on the monitoring network will be required to verify the target service. A host-side request to localhost:8080 would not test the target through the current Compose configuration.

## Preparing local environment variables

The only committed PowerShell script is [initialize-lab29-environment.ps1](scripts/initialize-lab29-environment.ps1).

It performs **local preparation**, not deployment. Its intended sequence is:

1. Load the versioned settings JSON.
2. Confirm the expected Compose project name and loopback-only web address.
3. Validate the web port and Linux hostname format.
4. Check that Git ignores the local environment file.
5. Preserve a pre-existing environment file rather than overwrite its database password.
6. Refuse to generate a new password if a Docker volume from the same project already exists.
7. Generate 24 cryptographically random bytes and encode them as a 48-character hexadecimal database password.
8. Create the environment file in UTF-8 without BOM, without printing the password.

The output path is:

~~~text
labs/29-zabbix-monitoring/local-artifacts/lab29.env
~~~

The generated variables supply the Compose project name, web bind address/port, target hostname and PostgreSQL password.

From the repository root in Windows PowerShell 5.1:

~~~powershell
& ".\labs\29-zabbix-monitoring\scripts\initialize-lab29-environment.ps1"
~~~

**Important:** This command is documented from source but was **not executed during this review**. A generated password is stored in a local plaintext environment file. Git ignore rules reduce accidental inclusion in normal commits; they **do not encrypt the file, restrict filesystem access, or prevent exposure through container inspection, process environments, backups or careless sharing**. Use appropriate local file protections.

If the file already exists, the script currently returns without validating its existing contents. The README's reference to a later validation step describes **planned follow-up work**, not functionality already implemented by this script.

## Docker Compose preparation and limitations

The committed [compose.yaml](compose.yaml) defines the four services, the three networks and the dedicated PostgreSQL volume. Its variables are required through Compose interpolation, so a missing value should cause configuration resolution to fail rather than silently substitute an empty password.

Compose does **not automatically read a file named lab29.env inside local-artifacts/**. When the environment file has been generated, an operator must explicitly supply it, for example by using the Compose CLI's env-file option with a verified path.

A future controlled deployment from the lab directory would begin with a configuration inspection such as:

~~~powershell
Set-Location ".\labs\29-zabbix-monitoring"

docker compose --env-file ".\local-artifacts\lab29.env" config
~~~

This command is presented as a **proposed verification step**, not as a historically successful check. The database password may appear in expanded Compose configuration output. **Do not upload, paste or publicly commit the rendered configuration without redaction.**

### Deployment is not yet documented as executed

The repository currently has **no committed deployment/validation script**, no Zabbix API registration script, no failure-injection script, no restore script and no cleanup validator for this lab.

Once the Compose configuration is validated and the relevant images are available, the intended next phase would be to bring up the isolated project, check all container/process states, register the target host, configure items and triggers, and test the HTTP endpoint from inside the monitoring network.

That phase should be conducted separately and recorded with observed results before marking any execution checkbox complete.

## Proposed monitoring and fault experiment

To make the planned acceptance criteria technically meaningful, the next implementation phase should specify and verify:

| Phase | Required observation |
|---|---|
| Baseline | Agent available, HTTP 200 and /health healthy; recent item values |
| Controlled fault | Stop Nginx only in the target container; do not stop Agent 2 |
| Detection | HTTP becomes unavailable; Agent 2 continues responding; trigger records a PROBLEM event |
| Recovery | Start Nginx; verify HTTP responses and subsequent trigger OK |
| Timing | UTC timestamps for intervention, problem detection, restoration and recovery |
| Cleanup | Only project-owned containers, networks and intended database volume removed; unrelated Zabbix assets preserved |

The settings anticipate a **10-second item interval**, **three consecutive failures**, **three consecutive successes**, **60-second baseline/failure windows** and a **120-second recovery allowance**. Those numbers are provisional design parameters. Real trigger timing depends on configured Zabbix items, preprocessing, evaluation logic, polling and state changes, not just the JSON settings.

The intended failure is **HTTP-specific**. The agent remaining responsive must be demonstrated with actual Zabbix observations, rather than inferred solely because its container remains running.

No SNMP, email notifications, production failover, external AWS infrastructure or previous-environment database restore is in scope.

## Evidence and current project state

The [images directory](images/) currently contains **14 PNG files**, dated October 20–23, 2026:

| Filename | Reference |
|---|---|
| Clipboard_10-20-2026_23.png | [Image 23](images/Clipboard_10-20-2026_23.png) |
| Clipboard_10-20-2026_24.png | [Image 24](images/Clipboard_10-20-2026_24.png) |
| Clipboard_10-20-2026_25.png | [Image 25](images/Clipboard_10-20-2026_25.png) |
| Clipboard_10-21-2026_26.png | [Image 26](images/Clipboard_10-21-2026_26.png) |
| Clipboard_10-21-2026_27.png | [Image 27](images/Clipboard_10-21-2026_27.png) |
| Clipboard_10-21-2026_28.png | [Image 28](images/Clipboard_10-21-2026_28.png) |
| Clipboard_10-21-2026_29.png | [Image 29](images/Clipboard_10-21-2026_29.png) |
| Clipboard_10-22-2026_30.png | [Image 30](images/Clipboard_10-22-2026_30.png) |
| Clipboard_10-22-2026_31.png | [Image 31](images/Clipboard_10-22-2026_31.png) |
| Clipboard_10-22-2026_32.png | [Image 32](images/Clipboard_10-22-2026_32.png) |
| Clipboard_10-23-2026_33.png | [Image 33](images/Clipboard_10-23-2026_33.png) |
| Clipboard_10-23-2026_34.png | [Image 34](images/Clipboard_10-23-2026_34.png) |
| Clipboard_10-23-2026_35.png | [Image 35](images/Clipboard_10-23-2026_35.png) |
| Clipboard_10-23-2026_36.png | [Image 36](images/Clipboard_10-23-2026_36.png) |

The current Portuguese README **does not attribute specific execution results to these screenshots**. They are linked here as historical image assets only. Their pixels have **not been inspected at full resolution**. They cannot be used, without further examination, as proof that the scenario ran or that its proposed trigger and cleanup requirements passed.

### Current completion state

| Workstream | Verified from repository | Runtime validated |
|---|---|---|
| Scenario goals and isolation boundaries | Yes | Not applicable |
| Compose topology and version choices | Present | No |
| Linux image and service configuration | Present | No |
| Local environment preparation script | Present | No |
| Host/group registration, monitoring items, trigger | Not implemented in committed scripts | No |
| Baseline, service failure, recovery | Planned | No |
| Cleanup and independent absence checks | Planned | No |

The original README's completion checklist marks only **scenario and scope definition** as complete. That remains the correct overall status despite the additional prepared implementation files.

## Safety, isolation and reproducibility

**Isolation:** Only project-specific Docker resources should be created or deleted. The old Zabbix PostgreSQL volume, its backup, previous restoration exercises, Windows agent and resources from separate projects must remain untouched.

**Persistence:** The named PostgreSQL volume preserves the new lab database across ordinary container restarts. Removing a Compose project with volumes can permanently delete that new data. Before cleanup, verify the Compose project name, volume labels and backup requirements.

**Access:** The Zabbix web interface is intended to bind to **127.0.0.1:18080**, not every network interface. Network bindings and actual published ports must be verified after deployment; a source declaration alone is not a network-security test.

**Credentials:** The generated database password is local and random, but the environment file is plaintext. Zabbix web-login credentials, access hardening and password rotation remain separate operational concerns.

**Resource readiness:** The PostgreSQL service declares a health check. The Zabbix server and web services use startup ordering, while the Linux target does not have a Docker health check. Neither dependency ordering nor container status alone verifies an operational Zabbix dashboard or healthy agent.

**Versioning:** The Compose source uses explicit image version tags for PostgreSQL and Zabbix, but not digest pins. Build-time package installation may also resolve newer package builds. Record image digests and relevant package versions when executing the lab.

**Costs:** This is designed for Docker Desktop on the local workstation, without AWS charges from the lab itself. It still uses local CPU, memory, disk space and potentially network downloads.

## Next stage

The next authorized phase for Lab 29 is **runtime preparation and validation**, followed by explicit Zabbix host/item/trigger configuration and the controlled HTTP failure/recovery test.

The original README states that a broader correlation of metrics, logs and system state is intended for **Lab 30**. At this review, **no Lab 30 directory is present** in this repository, so no link to a nonexistent lab is included.

## Conclusion

Lab 29 has a concrete **local Docker/Zabbix implementation foundation**, with dedicated services, an HTTP target, an Agent 2 process and local credential preparation. It is **not yet a completed monitoring experiment**.

A successful future lab must independently show **real item ingestion, the agent remaining available through HTTP failure, a Zabbix problem event, recovery to OK and verified removal of exclusive resources**. Until those observations exist, they remain clearly stated acceptance criteria rather than historical results.

---

[English repository overview](../../README.en.md) · [Portuguese repository overview](../../README.md)
