# Lab 5: Map the Virtualization Stack — Notes

Complete this worksheet during [Chapter 5](../../../docs/part-i-foundations/05-virtualization.md).

## 1. Host CPU and memory

**Linux:** `lscpu | head -15` and `free -h`  
**macOS:** `sysctl -n hw.ncpu hw.memsize`

| Resource | Your host |
|----------|-----------|
| CPU cores (physical / logical) | |
| Total memory | |

## 2. Host disk layout

**Linux:** `lsblk`  
**macOS:** `diskutil list`

Root filesystem device and size:

Additional volumes (if any):

## 3. Optional — Local VM comparison

If you launched Multipass `hermes-practice`:

| Resource | Host | Inside VM |
|----------|------|-----------|
| CPUs | | |
| Memory | | |
| Disk | | |

What changed when you crossed the hypervisor boundary?

## 4. Stack diagram

Fill in each layer for the Hermes platform (initial single-node design):

```text
Physical data center (AWS)
  └── _________________________  ← AWS service name
        └── _____________________  ← OS
              └── _______________  ← Ch 12
                    └── ___________  ← Ch 13
                          └── Hermes, PostgreSQL, Redis, llama.cpp
```

## 5. Sizing exercise

Estimated RAM needs:

| Component | RAM |
|-----------|-----|
| llama.cpp (GGUF inference) | 8 GiB |
| PostgreSQL + Redis + Hermes | 4 GiB |
| Ubuntu + k3s overhead | ? GiB (your estimate) |
| **Minimum instance memory** | |

Which EC2 instance **family** would you investigate first in Chapter 9—burstable (`t3`) or general-purpose (`m7i`)? Why?

## 6. VMs vs containers

In one or two sentences: why does this book run containers **inside** an EC2 instance instead of skipping EC2?

## 7. Reflection

When you reboot the EC2 instance hosting Hermes, what stops? When you restart only the Hermes container (later chapters), what keeps running?

| Action | Stops | Keeps running |
|--------|-------|---------------|
| EC2 reboot | | |
| Hermes container restart | | |
