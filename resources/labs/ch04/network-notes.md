# Lab 4: Network Diagnostics — Notes

Complete this worksheet during [Chapter 4](../../../docs/part-i-foundations/04-networking.md).

## 1. Public IP

```bash
curl -s https://checkip.amazonaws.com
```

Your public IP:

## 2. Default route / gateway

**Linux:** `ip route`  
**macOS:** `netstat -rn`

Default gateway:

Interface:

## 3. Traceroute to AWS

```bash
traceroute ec2.us-west-2.amazonaws.com
```

Number of hops to first AWS address:

Any timeouts (`* * *`)? Note which hop:

## 4. DNS resolution

```bash
dig ec2.us-west-2.amazonaws.com +short
```

IP address(es) returned:

## 5. HTTPS connectivity

From `curl -v https://aws.amazon.com` — did DNS resolve, TCP connect, and TLS succeed?

## 6. Local listening ports

Notable LISTEN ports on your machine (if any):

## 7. CIDR calculations

| CIDR | Total addresses | Usable hosts (classic) |
|------|-----------------|------------------------|
| `/24` | | |
| `/28` | | |

## 8. Reflection

Which debug layer would you check first for each symptom?

| Symptom | First check |
|---------|-------------|
| `Could not resolve host` | |
| `Connection timed out` | |
| `Connection refused` | |
