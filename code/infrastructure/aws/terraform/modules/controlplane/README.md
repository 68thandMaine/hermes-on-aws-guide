# Control plane module (Chapter 30+)

Codifies Chapter 9 (provisioning the Hermes server):

- `aws_instance` — `hermes-controlplane-01` (`m7i.2xlarge`)
- `aws_security_group` — SSH from operator IP, 80/443 for Ingress
- EBS volumes — `hermes-root`, `hermes-models`, `hermes-data`
- Elastic IP
- `user_data` — `../../cloud-init/hermes-controlplane-bootstrap.sh`

**Inputs:** `module.network` outputs (`vpc_id`, `public_subnet_id`).

**Not yet implemented** — network module ships first; controlplane module follows the same RFC workflow as Part II chapters.
