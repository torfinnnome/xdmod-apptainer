# XDMoD Apptainer Container

Apptainer container for Open XDMoD with MariaDB, running as a persistent background instance.

## Building the container image

```bash
# Build from the definition file
sudo apptainer build xdmod-apptainer.sif xdmod-apptainer.def
```

This creates the `xdmod-apptainer.sif` container image. You only need to rebuild if you modify the `%post` or `%environment` sections in the .def file.

## Initial setup (first time only)

Before starting the instance for the first time, you need to run the interactive XDMoD setup:

```bash
# Start a temporary instance to run setup
./start.sh

# Run the interactive setup
apptainer exec instance://xdmod xdmod-setup

# Stop the temporary instance after setup completes
./stop.sh
```

The `xdmod-setup` command will guide you through configuring:
- Database connection settings
- Organization information
- Admin user credentials
- Other XDMoD settings

This only needs to be done once. The configuration is saved in `./xdmod/etc`.

## Starting the instance

```bash
# Start XDMoD as a background instance
./start.sh
```

This will:
- Copy default configs if missing
- Start a persistent apptainer instance named "xdmod"
- Initialize MariaDB and XDMoD on first run
- Run the startup script from `xdmod-start.sh`

## Managing the instance

```bash
# Check instance status and view logs
./status.sh

# Stop the instance
./stop.sh

# Manual commands
apptainer instance list              # List running instances
apptainer instance stop xdmod        # Stop by name
```

## Configuration

All persistent data is stored in local directories:
- `./xdmod/etc` - XDMoD configuration
- `./xdmod/data` - XDMoD data
- `./xdmod/log` - XDMoD logs
- `./mariadb/lib` - MariaDB database files
- `./mariadb/log` - MariaDB logs
- `./httpd/*` - Apache logs and configuration

## Modifying startup behavior

The startup sequence is defined in `xdmod-start.sh`. You can modify this script without rebuilding the container image - just restart the instance:

```bash
./stop.sh
./start.sh
```

## Ingesting Slurm data

**Note:** The scripts in this section are specifically for **Slurm clusters**. If you're using a different job scheduler (PBS, LSF, SGE, etc.), you'll need to use different data collection methods. See the [XDMoD documentation](https://open.xdmod.org/11.0/shredder.html) for other resource managers.

XDMoD requires job data from your Slurm cluster. The `scripts/` directory contains automated ingestion scripts for Slurm:

### Manual ingestion

```bash
# 1. Collect Slurm job data (run on Slurm controller/head node)
./scripts/cron-root-collect-slurm-data.sh

# 2. Ingest the data into XDMoD (run where the container is)
./scripts/cron-xdmod-ingest-digest.sh
```

### Automated ingestion with cron

Add these crontab entries to automate data collection and ingestion:

```cron
# Collect Slurm data daily at 2 AM (on Slurm controller)
0 2 * * * /path/to/xdmod-apptainer/scripts/cron-root-collect-slurm-data.sh

# Ingest data into XDMoD at 3 AM (where container runs)
0 3 * * * /path/to/xdmod-apptainer/scripts/cron-xdmod-ingest-digest.sh
```

### Script details

- **cron-root-collect-slurm-data.sh**: Collects job data from Slurm using `sacct`. Must run on the Slurm controller with access to accounting data. Outputs to `./ingest/slurm-jobs.csv`.
  - Configurable via environment variable: `DAYS_BACK=7` (default: 1 day)

- **ingest-digest.sh**: Runs inside the container to shred and ingest CSV data into XDMoD using `xdmod-shredder` and `xdmod-ingestor`.
  - Configurable via environment variable: `RESOURCE_NAME=fox` (must match your XDMoD resource configuration)

- **cron-xdmod-ingest-digest.sh**: Wrapper that executes `ingest-digest.sh` inside the running container instance.

### Data directory

All ingestion data and logs are stored in `./ingest/`:
- `slurm-jobs.csv` - Raw Slurm job data
- `ingest.log` - Ingestion process logs

## Architecture

- **MariaDB**: Runs on port 9306 (non-standard to avoid conflicts)
- **Apache**: HTTP on port 8089, HTTPS on port 8443
- **PHP-FPM**: Backend for XDMoD web interface (Unix socket)
- **Startup**: Uses `%startscript` in the .def file, which calls `xdmod-start.sh` for flexibility
