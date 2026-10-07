# Ansible Container Lab

A local infrastructure automation lab that uses Ansible to configure Nginx on two Ubuntu containers. A dedicated control container connects to the managed nodes over SSH and deploys a web page identifying each node.

## Features

- One Ansible control node and two managed nodes, orchestrated with Docker Compose.
- SSH public-key authentication between the control node and managed nodes.
- Automated Nginx installation and site configuration.
- A node-specific HTML page generated with `inventory_hostname`.
- Separate HTTP and SSH host ports for each managed node.

## Tech Stack

| Component | Technology |
| --- | --- |
| Container base | Ubuntu 22.04 |
| Automation | Ansible, installed through pip |
| Remote access | OpenSSH |
| Web server | Nginx |
| Runtime | Docker and Docker Compose |

## Architecture

The control container connects to `managed1` and `managed2` on port 22 over the default Compose network. Host SSH ports are provided for direct access; Ansible uses the internal container ports.

| Service | Role | Host SSH port | Host HTTP port |
| --- | --- | --- | --- |
| `control` | Runs Ansible | — | — |
| `managed1` | First Nginx node | 2222 | 8081 |
| `managed2` | Second Nginx node | 2223 | 8082 |

## Repository Structure

The Compose project is inside the repository's `ansible/` directory.

```text
ansible/
├── control/
│   ├── Dockerfile
│   ├── ansible.cfg
│   ├── inventory.ini
│   ├── playbook.yml
│   └── ssh/
│       ├── id_rsa
│       └── id_rsa.pub
├── managed/
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── ssh/
│       └── authorized_keys
└── docker-compose.yml
```

## Getting Started

### Prerequisites

- Git
- Docker Engine with Docker Compose v2, or Docker Desktop
- OpenSSH tools to generate a local key pair
- Available ports 2222, 2223, 8081, and 8082

### 1. Clone and open the Compose directory

```bash
git clone https://github.com/xtilda/ansible.git
cd ansible/ansible
```

### 2. Make the entrypoint executable

The repository currently stores `managed/entrypoint.sh` without an executable Git file mode. In `managed/Dockerfile`, add the following instruction after `COPY entrypoint.sh /entrypoint.sh` and before `ENTRYPOINT`:

```dockerfile
RUN chmod +x /entrypoint.sh
```

This avoids a permission error when Docker starts the managed containers.

### 3. Generate a local SSH key pair

The repository currently includes a private key. Replace it with a newly generated key dedicated to this disposable lab. From the Compose directory, run the following commands in Bash (macOS, Linux, WSL, or Git Bash):

```bash
mkdir -p control/ssh managed/ssh
ssh-keygen -t rsa -b 4096 -N '' -f control/ssh/id_rsa
cp control/ssh/id_rsa.pub managed/ssh/authorized_keys
```

If prompted to overwrite the existing lab key, confirm only for `control/ssh/id_rsa`. Do not commit the new private key. If the committed key has been authorized on any other system, revoke it there and generate a replacement. Removing a key from the current repository does not remove it from Git history.

The current Dockerfile copies the private key into the control image, so keep that image local. For a more durable setup, exclude private keys from Git and inject credentials at runtime instead of baking them into images.

### 4. Build and start the containers

```bash
docker compose up --build -d
docker compose ps
```

Compose starts the control container after the managed containers have started, but does not check SSH readiness. If the next command reports a connection error, wait for SSH initialization and retry.

### 5. Verify Ansible connectivity

```bash
docker compose exec control ansible managed -m ping
```

A successful response from both nodes includes `"ping": "pong"`. This checks SSH connectivity and remote Python execution.

### 6. Run the playbook

```bash
docker compose exec control ansible-playbook /ansible/playbook.yml
```

The playbook:

1. Installs Nginx through APT.
2. Removes the default enabled site.
3. Writes a custom site configuration.
4. Creates `/var/www/my_site` and a node-specific `index.html`.
5. Creates the Nginx runtime directory.
6. Checks the Nginx configuration and starts Nginx directly, without systemd.

### 7. View the deployed pages

| URL | Expected heading |
| --- | --- |
| [http://localhost:8081](http://localhost:8081) | Hello from managed1 |
| [http://localhost:8082](http://localhost:8082) | Hello from managed2 |

HTTP pages become available after the playbook installs and starts Nginx.

## Configuration

`control/inventory.ini` defines the `managed` host group. Both nodes use the root account and internal SSH port 22.

`control/ansible.cfg` sets the inventory path, disables host-key checking and retry files, enables SSH pipelining, and requests the `yaml` output callback.

The control image installs Ansible without a version pin. If your installed version cannot load the `yaml` callback, change `stdout_callback = yaml` to `stdout_callback = default` and rebuild the control image.

Configuration files and keys are copied into images rather than mounted. After changing them, rebuild the affected containers:

```bash
docker compose up --build -d
```

## Useful Commands

View container logs:

```bash
docker compose logs -f
```

Open the control container:

```bash
docker compose exec control bash
```

Check playbook syntax:

```bash
docker compose exec control ansible-playbook /ansible/playbook.yml --syntax-check
```

Check Nginx configuration on a managed node:

```bash
docker compose exec managed1 nginx -t
```

Connect directly to the first managed node from the host:

```bash
ssh -i control/ssh/id_rsa -p 2222 root@localhost
```

Stop and remove the lab containers:

```bash
docker compose down
```

## Limitations and Troubleshooting

- **Entrypoint permission error:** Add the `chmod` instruction shown above and rebuild.
- **SSH authentication failure:** Confirm that `managed/ssh/authorized_keys` matches `control/ssh/id_rsa.pub`, then rebuild both images.
- **Port conflict:** Change the host side of the relevant Compose port mapping.
- **Repeated playbook runs:** The final task runs `nginx` unconditionally. It is not an idempotent service-management task and may report bind errors when Nginx is already running. For repeatable provisioning, check process state and use a handler to reload Nginx after configuration changes. `changed_when: false` only affects reporting; it does not make this task idempotent.
- **Container restart:** The managed entrypoint starts SSH only. Nginx must be started again after a restart.
- **Persistence:** No data volumes are configured. Installed packages and deployed pages live in container writable layers and are lost when managed containers are removed or recreated. Run the playbook again after recreation.


