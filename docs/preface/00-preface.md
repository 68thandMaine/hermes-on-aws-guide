---
sidebar_position: 0
description: "Preface to Building a Personal AI Cloud."
---

# Preface

> _Why this book exists, and how to use it._

---

## Learning Objectives

After reading this preface, you will understand:

- [ ] Why this book was written as a personal infrastructure manual, not a generic AWS guide
- [ ] How each chapter is structured and why consistency matters
- [ ] What you will have built by the end of the book
- [ ] How to approach the labs and what to do when things break

---

## Background

<!-- TODO: Write about the gap between certification prep and actually building something -->
<!-- TODO: Why Notion/docs failed as a medium for this kind of deep learning -->
<!-- TODO: The decision to write an O'Reilly-style technical book -->

_Content coming soon._

---

## Theory

<!-- TODO: Explain the pedagogical approach — theory before practice, labs as proof -->
<!-- TODO: How "understanding why" differs from "knowing how to click" -->

_Content coming soon._

---

## Architecture

This book builds a single, coherent platform. By Chapter 18, your environment looks like this:

```
           Internet
               │
        Internet Gateway
               │
        Public Subnet (VPC)
               │
         EC2 Instance
               │
          Docker Engine
               │
            k3s Node
               │
      Hermes Agent + PostgreSQL
               │
    Agent Tools + Local Models
               │
      Production Deployment
```

Each chapter adds one layer toward running **Hermes** in production. Nothing is throwaway—you keep everything you build.

---

## AWS Console Walkthrough

_Not applicable to this chapter._

The Preface introduces the book's scope and approach. No AWS resources are created here.

---

## CLI Walkthrough

_Not applicable to this chapter._

---

## Terraform Walkthrough

_Not applicable to this chapter._

---

## Lab

_No lab for the Preface. Start with [Chapter 1: Introduction](../part-i-foundations/01-introduction.md)._

---

## Verification

_Not applicable._

---

## Troubleshooting

_Not applicable._

---

## Review Questions

1. What is the difference between this book and a typical AWS certification guide?
2. Why does every chapter follow the same structure?
3. What platform components will you have built by the end of Part V?
4. What should you do when a lab fails?

---

## Further Reading

- [The Missing README — Titus Winters](https://abseil.io/resources/swe-book) — how to think about technical documentation
- [A Philosophy of Software Design — John Ousterhout](https://web.stanford.edu/~ouster/cgi-bin/book.php)

---

## References

_None for this chapter._

---

[Next: Chapter 1 — Introduction →](../part-i-foundations/01-introduction.md)
