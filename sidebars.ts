import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  bookSidebar: [
    'preface/00-preface',
    {
      type: 'category',
      label: 'Part I — Foundations',
      collapsed: false,
      items: [
        'part-i-foundations/01-introduction',
        'part-i-foundations/02-how-computers-work',
        'part-i-foundations/03-linux',
        'part-i-foundations/04-networking',
        'part-i-foundations/05-virtualization',
        'part-i-foundations/06-designing-the-hermes-platform',
      ],
    },
    {
      type: 'category',
      label: 'Part II — AWS & Platform',
      collapsed: true,
      items: [
        'part-ii-aws/07-provisioning-aws-account',
        'part-ii-aws/08-creating-network-for-hermes',
        'part-ii-aws/09-provisioning-hermes-server',
        'part-ii-aws/10-establishing-trust',
        'part-ii-aws/11-persistent-storage',
        'part-ii-aws/12-building-the-application-platform',
        'part-ii-aws/13-the-first-control-plane',
        'part-ii-aws/14-routing-traffic-to-hermes',
        'part-ii-aws/15-observing-hermes-platform',
        'part-ii-aws/16-managing-platform-costs',
      ],
    },
    {
      type: 'category',
      label: 'Part III — Containers',
      collapsed: true,
      items: [
        'part-iii-containers/16-docker',
        'part-iii-containers/17-docker-compose',
        'part-iii-containers/18-oci',
      ],
    },
    {
      type: 'category',
      label: 'Part IV — Kubernetes',
      collapsed: true,
      items: [
        'part-iv-kubernetes/19-why-kubernetes-exists',
        'part-iv-kubernetes/20-pods',
        'part-iv-kubernetes/21-deployments',
        'part-iv-kubernetes/22-services',
        'part-iv-kubernetes/23-ingress',
        'part-iv-kubernetes/24-kubernetes-storage',
        'part-iv-kubernetes/25-helm',
        'part-iv-kubernetes/26-configuration-configmaps-secrets',
        'part-iv-kubernetes/27-kubernetes-security',
        'part-iv-kubernetes/28-scaling',
      ],
    },
    {
      type: 'category',
      label: 'Part V — Infrastructure',
      collapsed: true,
      items: [
        'part-v-infrastructure/29-terraform',
        'part-v-infrastructure/30-github-actions',
        'part-v-infrastructure/31-secrets-management',
        'part-v-infrastructure/32-monitoring',
        'part-v-infrastructure/33-logging',
      ],
    },
    {
      type: 'category',
      label: 'Part VI — AI Infrastructure',
      collapsed: true,
      items: [
        'part-vi-ai/34-running-hermes',
        'part-vi-ai/35-vector-databases',
        'part-vi-ai/36-model-serving',
        'part-vi-ai/37-gpu-instances',
        'part-vi-ai/38-ai-agent-architecture',
      ],
    },
    {
      type: 'category',
      label: 'Part VII — Hermes Agent Platform',
      collapsed: true,
      items: [
        'part-vii-hermes/39-distributed-cognitive-execution',
        'part-vii-hermes/40-operating-hermes-in-production',
        'part-vii-hermes/41-platform-governance',
        'part-vii-hermes/42-extending-hermes',
        'part-vii-hermes/43-from-development-to-production',
        'part-vii-hermes/44-the-platform-you-built',
      ],
    },
    {
      type: 'category',
      label: 'Appendices',
      collapsed: true,
      items: [
        'appendices/glossary',
        'appendices/command-reference',
        'appendices/repository-walkthrough',
        'appendices/cost-estimates',
        'appendices/troubleshooting',
        'appendices/references',
        'appendices/diagrams',
        'appendices/labs',
      ],
    },
  ],
};

export default sidebars;
