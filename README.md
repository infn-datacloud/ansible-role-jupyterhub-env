# ansible-role-jupyterhub-env

Ansible role to deploy a **single-node JupyterHub stack (LAB-only)** on
**Debian 13 (trixie)** with Docker Compose. 

## Stack architecture

```
Internet ──443/80──> Traefik (TLS ingress)
                        │  ACME (letsencrypt) | file provider (self-signed)
                        ▼
                 configurable-http-proxy   (plain HTTP, internal network)
                        ▼
                   JupyterHub (DockerSpawner) ──> single-user container (jlab)
Inline monitoring: Prometheus + cAdvisor + node-exporter + Grafana
```

Main characteristics compared to the previous version:
- **Path** `/usr/local/share/infndatacloud/...`.
- **Secrets** as *Docker Compose secrets* (`*_FILE`).
- **TLS** terminated only by Traefik; `configurable-http-proxy` over internal HTTP.
- **Inline monitoring** in the same compose (no external role).
- **Docker** installed by the role (official repo, codename `trixie`).
- CVMFS and partitioned GPUs TBD.

## Requirements

- ansible-core ≥ 2.18
- Collections (see `requirements.yml`): `community.docker`, `community.crypto`,
  `community.general`, `ansible.posix`
- Target: Debian 13, user with sudo privileges, public IP

```bash
ansible-galaxy collection install -r requirements.yml
```

## Main variables

| Variable | Default | Description |
|----------|---------|-------------|
| `jupyterhub_dns_name` | `""` | Public FQDN; if empty, derived as `<public_ip>.<base_dns_name>` |
| `jupyterhub_cert_manager_type` | `self-signed` | `self-signed` / `letsencrypt-staging` / `letsencrypt-prod` |
| `jupyterhub_contact_email` | `""` | ACME email (required for Let's Encrypt) |
| `jupyterhub_iam_url` | `https://iam.cloud.infn.it/` | IAM issuer |
| `jupyterhub_iam_client_id` / `_token` | `""` | IAM client + registration access token |
| `jupyterhub_iam_client_secret` | `""` | client_secret of a pre-registered client (alternative to `_token`) |
| `jupyterhub_iam_groups` / `_admin_groups` | `""` | allowed / admin groups |
| `jupyterhub_hub_image` | `…/jhub-singlenode:2.3.0` | Hub image |
| `jupyterhub_images` | `…/jlab-base:2.3.0` | single-user images (CSV) |
| `jupyterhub_monitoring` | `true` | enable Prometheus/Grafana |
| `jupyterhub_use_gpu` / `jupyterhub_with_cvmfs` | `false` | future features |

Full list and validation in `defaults/main.yml` and `meta/argument_specs.yml`.

## Example

```yaml
- hosts: jupyter_vm
  become: true
  roles:
    - role: ansible-role-jupyterhub-env
      vars:
        jupyterhub_dns_name: "xxx.xxx.xxx.xxx.cloud.infn.it"
        jupyterhub_cert_manager_type: self-signed
        jupyterhub_contact_email: "admin@infn.it"
        jupyterhub_iam_client_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        jupyterhub_iam_token: "xxx..."
        jupyterhub_iam_subject: "xxxxxxxx-xxxx-..."
        jupyterhub_iam_groups: "users/ai-infn"
        jupyterhub_iam_admin_groups: "admins/ai-infn"
```
## Operational notes
s
- **IAM client**: requires the registration of following redirect_uris:
  `https://<DNS>/hub/oauth_callback` and, if monitoring is enabled,
  `https://<DNS>/grafana/login/generic_oauth`. 
- **Grafana** is served **behind Traefik at `/grafana`** in every TLS variant
  (self-signed uses the file provider default certificate, Let's Encrypt uses the
  ACME certificate). The IAM redirect   to register is therefore always
   `https://<DNS>/grafana/login/generic_oauth`.
- **S3 / FUSE**: single-user containers mount the S3 buckets via `rclone mount`
  (FUSE). The spawner grants `/dev/fuse` + `SYS_ADMIN`; the role installs `fuse3`
  on the host to ensure `/dev/fuse` is present.
- **Let's Encrypt — rate limit**: LE-prod allows max 5 issuances per exact set of
  domains every 168h. **Never destroy the `letsencrypt` volume** (it holds the
  ACME storage): preserve it across redeploys so LE *renews* instead of
  *re-issuing*. For testing use `self-signed` or `letsencrypt-staging`; switch
  to `letsencrypt-prod` only for the final deploy. Staging and prod use
  **separate storage files** (`acme-staging.json` / `acme-prod.json`), so
  switching staging↔prod is safe.

## Test

```bash
make lint     # yamllint + ansible-lint
make syntax   # --syntax-check
make test     # run on localhost (jupyterhub_run=false)
```

## License

Apache-2.0
