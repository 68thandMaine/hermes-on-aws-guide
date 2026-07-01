---
sidebar_position: 14
description: "Route 53, TLS, and DNS so clients reach the platform over HTTPS."
---

# Chapter 14: Routing Traffic to Hermes

> How does HTTPS traffic from your laptop find the platform?

---

> 📋 **Outline** — RFC not started. Optional AWS polish—**execution only** (no new ontology). Complete after Kubernetes core objects (Part IV) or when exposing HTTPS.

:::note[Why this matters for Hermes]

Your laptop sends requests to a hostname—not a raw IP you memorize. Route 53 maps that name to your Elastic IP; TLS protects tokens in transit. Deploy Hermes first on Kubernetes; add public DNS when you are ready for HTTPS access.

:::

**Prerequisites:** [Chapter 13: The First Control Plane](13-the-first-control-plane.md) and core Ingress concepts ([Part IV](../part-iv-kubernetes/23-ingress.md))

---

[← Chapter 13: The First Control Plane](13-the-first-control-plane.md) | [Next: Chapter 15 — Observing the Hermes Platform →](15-observing-hermes-platform.md)
