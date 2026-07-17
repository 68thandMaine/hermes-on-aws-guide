# Hermes network resource IDs

Created in Chapter 8. Source this file in later labs:

```bash
source ~/hermes-platform/notes/network-resources.env
```

## Expected variables

| Variable | Resource |
|----------|----------|
| `HERMES_VPC_ID` | `hermes-vpc` |
| `HERMES_IGW_ID` | `hermes-igw` |
| `HERMES_PUBLIC_SUBNET_ID` | `hermes-public-usw2a` |
| `HERMES_PUBLIC_RT_ID` | `hermes-public-rt` |

## Verification checklist

- [ ] `aws ec2 describe-vpcs --vpc-ids $HERMES_VPC_ID --profile hermes`
- [ ] Route table has `0.0.0.0/0` → IGW
- [ ] Subnet `MapPublicIpOnLaunch` is true

Do not commit this file with real IDs to a public repository.
